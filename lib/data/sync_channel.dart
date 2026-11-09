/// Framed, optionally authenticated messages over a TCP socket.
///
/// A frame is a 4 byte big-endian length followed by that many bytes:
///
///   flag (1 byte: 0 = plain UTF-8 JSON, 1 = gzipped JSON)
///   mac  (32 bytes, only once a session key is set)
///   payload
///
/// Before pairing completes the channel carries only tiny, plain handshake
/// messages. Afterwards every frame carries an HMAC-SHA256 over its direction,
/// a per-direction counter, the flag and the payload, so a device on the same
/// network can neither alter nor replay nor reorder what is sent. Characters
/// are not encrypted (the QR share is not either); they never leave the local
/// network.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class SyncException implements Exception {
  const SyncException(this.message);
  final String message;
  @override
  String toString() => message;
}

const _maxPlainFrame = 64 * 1024;
const _maxFrame = 16 * 1024 * 1024;
const _gzipOver = 1024;

Uint8List hmacSha256(List<int> key, List<int> data) =>
    Uint8List.fromList(Hmac(sha256, key).convert(data).bytes);

bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

class SyncChannel {
  SyncChannel(this._socket, {required this.isInitiator}) {
    _sub = _socket.listen(
      _onData,
      onError: (Object e) => _fail(const SyncException('Connection lost.')),
      onDone: () =>
          _fail(const SyncException('The other device disconnected.')),
      cancelOnError: true,
    );
  }

  final Socket _socket;
  final bool isInitiator;
  late final StreamSubscription<Uint8List> _sub;

  final _buf = BytesBuilder(copy: false);
  int? _need;
  final _frames = Queue<Uint8List>();
  Completer<void>? _waiting;
  Object? _error;

  Uint8List? _key;
  int _sendSeq = 0, _recvSeq = 0;

  /// Authenticates everything from now on with [key].
  void enableAuth(Uint8List key) => _key = key;

  void _fail(Object e) {
    _error ??= e;
    _waiting?.complete();
    _waiting = null;
  }

  void _onData(Uint8List chunk) {
    _buf.add(chunk);
    while (true) {
      if (_need == null) {
        if (_buf.length < 4) return;
        final all = _buf.takeBytes();
        final len = ByteData.sublistView(all).getUint32(0);
        final limit = _key == null ? _maxPlainFrame : _maxFrame;
        if (len == 0 || len > limit) {
          _fail(
            const SyncException('The other device sent something invalid.'),
          );
          _socket.destroy();
          return;
        }
        _need = len;
        _buf.add(Uint8List.sublistView(all, 4));
      }
      if (_buf.length < _need!) return;
      final all = _buf.takeBytes();
      final need = _need!;
      _frames.add(Uint8List.sublistView(all, 0, need));
      if (all.length > need) _buf.add(Uint8List.sublistView(all, need));
      _need = null;
      _waiting?.complete();
      _waiting = null;
    }
  }

  List<int> _macInput(int dir, int seq, int flag, List<int> payload) {
    final head = ByteData(10)
      ..setUint8(0, dir)
      ..setUint64(1, seq)
      ..setUint8(9, flag);
    return [...head.buffer.asUint8List(), ...payload];
  }

  int _dir(bool fromInitiator) => fromInitiator ? 0x49 : 0x52; // 'I' / 'R'

  Future<void> send(Map<String, Object?> message) async {
    final json = utf8.encode(jsonEncode(message));
    final key = _key;
    // Compress only authenticated frames, so unauthenticated input can not
    // make a device inflate anything.
    final gz = key != null && json.length > _gzipOver;
    final payload = gz ? GZipCodec().encode(json) : json;
    final flag = gz ? 1 : 0;
    final mac = key == null
        ? const <int>[]
        : hmacSha256(
            key,
            _macInput(_dir(isInitiator), _sendSeq++, flag, payload),
          );
    final bodyLen = 1 + mac.length + payload.length;
    final out = BytesBuilder(copy: false)
      ..add((ByteData(4)..setUint32(0, bodyLen)).buffer.asUint8List())
      ..addByte(flag)
      ..add(mac)
      ..add(payload);
    _socket.add(out.takeBytes());
    await _socket.flush();
  }

  Future<Map<String, Object?>> receive({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (_frames.isEmpty) {
      if (_error != null) throw _error!;
      final left = deadline.difference(DateTime.now());
      if (left <= Duration.zero) {
        throw const SyncException('The other device did not answer in time.');
      }
      final w = _waiting = Completer<void>();
      await w.future.timeout(left, onTimeout: () {});
    }
    final body = _frames.removeFirst();
    final flag = body[0];
    final key = _key;
    Uint8List payload;
    if (key == null) {
      if (flag != 0) throw const SyncException('Unexpected data format.');
      payload = Uint8List.sublistView(body, 1);
    } else {
      if (body.length < 33) throw const SyncException('Message too short.');
      final mac = Uint8List.sublistView(body, 1, 33);
      payload = Uint8List.sublistView(body, 33);
      final expected = hmacSha256(
        key,
        _macInput(_dir(!isInitiator), _recvSeq++, flag, payload),
      );
      if (!constantTimeEquals(mac, expected)) {
        throw const SyncException(
          'A message from the other device could not be verified.',
        );
      }
      if (flag == 1) {
        payload = Uint8List.fromList(GZipCodec().decode(payload));
      } else if (flag != 0) {
        throw const SyncException('Unexpected data format.');
      }
    }
    try {
      final decoded = jsonDecode(utf8.decode(payload));
      if (decoded is Map) return decoded.cast<String, Object?>();
    } on FormatException {
      // fall through
    }
    throw const SyncException('The other device sent something invalid.');
  }

  Future<void> close() async {
    await _sub.cancel();
    _socket.destroy();
  }
}
