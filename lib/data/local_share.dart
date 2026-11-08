/// Sends one character from one device to another over the local network.
///
/// The sharing device opens a TCP server on a random port and shows a QR code
/// with its addresses, the port and a one-time token ([ShareTicket]). The
/// receiving device scans it, connects, sends the token and reads the
/// character. Nothing leaves the local network and no third-party service is
/// involved. Plain sockets rather than HTTP keep it dependency-free and clear
/// of the platforms' cleartext-HTTP restrictions.
///
/// Wire format:
///   receiver -> sender: `JJCT1 <token>\n`
///   sender -> receiver: `JJCT1\n` followed by the gzipped character JSON,
///   then the sender closes the connection.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../domain/share_ticket.dart';

const _magic = 'JJCT1';
const _maxRequestBytes = 256;
const _maxResponseBytes = 8 * 1024 * 1024;

class ShareException implements Exception {
  const ShareException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Serves [json] to the first device that presents the token, then stops.
class ShareServer {
  ShareServer._(this._server, this.ticket, this._payload);

  final ServerSocket _server;
  final ShareTicket ticket;
  final Uint8List _payload;
  final _sent = Completer<void>();
  bool _closed = false;
  int _badAttempts = 0;
  Timer? _expiry;

  /// Completes once the character has been sent.
  Future<void> get sent => _sent.future;
  bool get isClosed => _closed;

  /// Starts serving. Throws [ShareException] when the device has no local
  /// network address, for example when Wi-Fi is off.
  static Future<ShareServer> start(
    String json, {
    Duration expiry = const Duration(minutes: 10),
    Future<List<String>> Function()? addresses,
  }) async {
    final hosts = await (addresses ?? localAddresses)();
    if (hosts.isEmpty) {
      throw const ShareException(
        'This device is not on a local network. Connect to Wi-Fi '
        '(or turn on a hotspot) and try again.',
      );
    }
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    final ticket = ShareTicket(
      hosts: hosts,
      port: server.port,
      token: ShareTicket.newToken(),
    );
    final payload = Uint8List.fromList(
      GZipCodec(level: 9).encode(utf8.encode(json)),
    );
    final s = ShareServer._(server, ticket, payload);
    server.listen(s._handle, onError: (Object _) {});
    s._expiry = Timer(expiry, s.close);
    return s;
  }

  void _handle(Socket socket) {
    if (_closed) {
      socket.destroy();
      return;
    }
    final buf = BytesBuilder();
    late StreamSubscription<Uint8List> sub;
    final timeout = Timer(const Duration(seconds: 10), socket.destroy);
    sub = socket.listen(
      (chunk) async {
        buf.add(chunk);
        final bytes = buf.toBytes();
        final nl = bytes.indexOf(10);
        if (nl < 0) {
          if (bytes.length > _maxRequestBytes) {
            timeout.cancel();
            socket.destroy();
          }
          return;
        }
        await sub.cancel();
        timeout.cancel();
        final line = latin1.decode(bytes.sublist(0, nl)).trim();
        if (_closed || line != '$_magic ${ticket.token}') {
          socket.destroy();
          // Stop guessing attempts from other devices on the network.
          if (++_badAttempts >= 20) close();
          return;
        }
        // One-time: refuse everyone else from now on.
        _closed = true;
        try {
          socket.add(utf8.encode('$_magic\n'));
          socket.add(_payload);
          await socket.flush();
          await socket.close();
          if (!_sent.isCompleted) _sent.complete();
        } catch (e) {
          // The receiver went away mid-transfer; let it try again.
          _closed = false;
          socket.destroy();
        } finally {
          if (_sent.isCompleted) close();
        }
      },
      onError: (Object _) {
        timeout.cancel();
        socket.destroy();
      },
      cancelOnError: true,
    );
  }

  Future<void> close() async {
    _closed = true;
    _expiry?.cancel();
    await _server.close();
  }
}

/// Fetches the character JSON described by [ticket].
Future<String> fetchShared(
  ShareTicket ticket, {
  Duration connectTimeout = const Duration(seconds: 4),
  Duration readTimeout = const Duration(seconds: 20),
}) async {
  for (final host in ticket.hosts) {
    Socket? socket;
    try {
      socket = await Socket.connect(host, ticket.port, timeout: connectTimeout);
    } catch (_) {
      continue;
    }
    try {
      socket.add(utf8.encode('$_magic ${ticket.token}\n'));
      await socket.flush();
      final buf = BytesBuilder(copy: false);
      await for (final chunk in socket.timeout(readTimeout)) {
        buf.add(chunk);
        if (buf.length > _maxResponseBytes) {
          throw const ShareException('The shared character is too large.');
        }
      }
      final bytes = buf.takeBytes();
      final header = utf8.encode('$_magic\n');
      if (bytes.length <= header.length || !_startsWith(bytes, header)) {
        throw const ShareException(
          'The other device did not send a character. The code may have '
          'been used already or expired. Ask them to tap Share again.',
        );
      }
      final body = GZipCodec().decode(bytes.sublist(header.length));
      return utf8.decode(body);
    } on ShareException {
      rethrow;
    } on TimeoutException {
      throw const ShareException('The transfer timed out. Try again.');
    } on FormatException {
      throw const ShareException('The character arrived damaged. Try again.');
    } finally {
      socket.destroy();
    }
  }
  throw ShareException(
    'Could not reach the other device. Make sure both are on the same '
    'Wi-Fi network and the share screen is still open.',
  );
}

bool _startsWith(List<int> bytes, List<int> prefix) {
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

/// This device's IPv4 addresses on local networks, Wi-Fi first.
Future<List<String>> localAddresses() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
    includeLinkLocal: false,
  );
  final scored = <(int, String)>[];
  for (final i in interfaces) {
    final name = i.name.toLowerCase();
    // Cellular data interfaces never reach the other phone.
    if (name.startsWith('rmnet') ||
        name.startsWith('ccmni') ||
        name.startsWith('pdp_ip') ||
        name.startsWith('tun') ||
        name.startsWith('utun')) {
      continue;
    }
    for (final a in i.addresses) {
      if (!isPrivateIpv4(a.address)) continue;
      final wifi =
          name.startsWith('wlan') ||
          name.startsWith('en') ||
          name.startsWith('ap') ||
          name.startsWith('swlan') ||
          name.startsWith('bridge');
      scored.add((wifi ? 0 : 1, a.address));
    }
  }
  scored.sort((a, b) => a.$1.compareTo(b.$1));
  return {for (final s in scored) s.$2}.take(4).toList();
}

bool isPrivateIpv4(String address) {
  final p = address.split('.').map(int.tryParse).toList();
  if (p.length != 4 || p.any((n) => n == null)) return false;
  final a = p[0]!, b = p[1]!;
  return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
}
