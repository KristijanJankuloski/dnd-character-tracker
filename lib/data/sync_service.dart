/// Syncs characters between two paired devices on the same network.
///
/// Either device can start a sync. The starting device (the "initiator")
/// connects to the other one's sync server, proves it knows the pairing key
/// (or pairs first, see below), asks for the other device's list of
/// (uuid, updatedAt) summaries, decides what has to move with [planSync], and
/// then fetches and sends only those characters.
///
/// Pairing: the first time two devices meet, the one being connected to shows
/// a six digit code and the initiator's user types it in. Both sides prove
/// they know the code (HMAC over fresh nonces) and derive a shared key from
/// it; the code itself never crosses the network. After three wrong tries the
/// code is dead. Later syncs only need the key. A device somebody else
/// could watch pairing on the network could in principle guess a six digit
/// code offline, which is why pairing should happen on a network you trust.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/models.dart';
import '../domain/repository.dart';
import '../domain/sync.dart';
import 'nearby_discovery.dart';
import 'sync_channel.dart';

const _protocolVersion = 1;
const _maxItems = 1000;
const _maxPairingAttempts = 3;

/// What the person on the other device has to type.
class IncomingPairing {
  const IncomingPairing({
    required this.deviceName,
    required this.code,
    required this.expiresAt,
  });
  final String deviceName;
  final String code;
  final DateTime expiresAt;
}

/// Asked of the user while pairing from this device.
class PairPrompt {
  const PairPrompt({required this.deviceName, required this.wrongCode});
  final String deviceName;

  /// True when the previous attempt was wrong.
  final bool wrongCode;
}

class SyncCallbacks {
  const SyncCallbacks({
    required this.askCode,
    required this.resolveConflicts,
    this.onStatus,
  });

  /// Returns the code typed in, or null to cancel.
  final Future<String?> Function(PairPrompt prompt) askCode;

  /// Returns the choice per conflicting character id, or null to cancel the
  /// sync. Characters left out of the map are skipped.
  final Future<Map<String, ConflictChoice>?> Function(
    List<SyncConflict> conflicts,
  )
  resolveConflicts;
  final void Function(String status)? onStatus;
}

class SyncOutcome {
  const SyncOutcome({
    required this.peerName,
    this.sent = 0,
    this.received = 0,
    this.deletedHere = 0,
    this.deletedThere = 0,
    this.copies = 0,
    this.skipped = 0,
    this.clockOffset = Duration.zero,
    this.paired = false,
  });
  final String peerName;
  final int sent, received, deletedHere, deletedThere, copies, skipped;

  /// How far ahead the other device's clock is.
  final Duration clockOffset;

  /// True when this sync also paired the devices.
  final bool paired;

  bool get changedNothing =>
      sent + received + deletedHere + deletedThere + copies == 0;
  bool get clocksFarApart => clockOffset.abs() > clockWarnThreshold;
}

class SyncService {
  SyncService({
    required this.repository,
    required this.store,
    DateTime Function()? clock,
    Random? random,
  }) : _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure();

  final CharacterRepository repository;
  final SyncStore store;
  final DateTime Function() _clock;
  final Random _random;

  /// Non-null while another device is pairing with this one.
  final ValueNotifier<IncomingPairing?> incomingPairing = ValueNotifier(null);

  /// Fires when another device finished a sync with this one.
  final ValueNotifier<int> incomingSyncs = ValueNotifier(0);

  ServerSocket? _server;
  bool _busy = false;

  int get _now => _clock().millisecondsSinceEpoch;
  int? get port => _server?.port;

  /// Starts accepting connections from other devices and returns the port.
  Future<int> start({InternetAddress? address, int port = 0}) async {
    await repository.assignLegacyIds();
    final server = await ServerSocket.bind(
      address ?? InternetAddress.anyIPv4,
      port,
    );
    _server = server;
    server.listen(_accept, onError: (Object _) {});
    return server.port;
  }

  Future<void> close() async {
    await _server?.close();
    _server = null;
    incomingPairing.value = null;
  }

  String _nonce() =>
      base64Url.encode(List.generate(16, (_) => _random.nextInt(256)));

  // ---------------------------------------------------------------- crypto

  List<int> _proof(
    List<int> key,
    String role,
    String nI,
    String nR,
    String idI,
    String idR,
  ) => hmacSha256(key, utf8.encode('$role|$nI|$nR|$idI|$idR'));

  Uint8List _deriveKey(
    String code,
    String nI,
    String nR,
    String idI,
    String idR,
  ) => hmacSha256(utf8.encode(code), utf8.encode('jjct-key|$nI|$nR|$idI|$idR'));

  Uint8List _sessionKey(List<int> key, String nI, String nR) =>
      hmacSha256(key, utf8.encode('jjct-session|$nI|$nR'));

  bool _proofOk(Object? got, List<int> expected) {
    if (got is! String) return false;
    try {
      return constantTimeEquals(base64Decode(got), expected);
    } on FormatException {
      return false;
    }
  }

  String _b64(List<int> bytes) => base64Encode(bytes);

  // ---------------------------------------------------------------- server

  void _accept(Socket socket) {
    if (_busy) {
      final ch = SyncChannel(socket, isInitiator: false);
      ch
          .send({'t': 'error', 'm': 'This device is busy. Try again.'})
          .whenComplete(ch.close);
      return;
    }
    _busy = true;
    final ch = SyncChannel(socket, isInitiator: false);
    _serve(ch)
        .catchError((Object e) {
          // The other side gave up or sent rubbish; nothing to report.
          return false;
        })
        .whenComplete(() {
          _busy = false;
          incomingPairing.value = null;
          ch.close();
        });
  }

  Future<bool> _serve(SyncChannel ch) async {
    final self = await store.identity();
    final hello = await ch.receive(timeout: const Duration(seconds: 10));
    final peerId = hello['id'];
    final nI = hello['nonce'];
    if (hello['t'] != 'hello' ||
        hello['v'] != _protocolVersion ||
        peerId is! String ||
        !isSyncId(peerId) ||
        nI is! String ||
        nI.length > 64) {
      await ch.send({'t': 'error', 'm': 'Not a compatible device.'});
      return false;
    }
    final peerName = _cleanName(hello['name']);
    final nR = _nonce();
    final peer = await store.peer(peerId);

    if (peer != null && hello['paired'] == true) {
      await ch.send({
        't': 'challenge',
        'id': self.id,
        'name': self.name,
        'nonce': nR,
        'proof': _b64(_proof(peer.key, 'R', nI, nR, peerId, self.id)),
      });
      final auth = await ch.receive(timeout: const Duration(seconds: 10));
      if (auth['t'] != 'auth' ||
          !_proofOk(
            auth['proof'],
            _proof(peer.key, 'I', nI, nR, peerId, self.id),
          )) {
        await ch.send({
          't': 'error',
          'm': 'Could not verify the device. Pair them again.',
        });
        return false;
      }
      ch.enableAuth(_sessionKey(peer.key, nI, nR));
      await ch.send({'t': 'ready'});
    } else {
      if (!await _pairServer(ch, self, peerId, peerName, nI, nR)) return false;
    }
    await _sessionLoop(ch, peerId);
    return true;
  }

  String _cleanName(Object? n) {
    final s = (n is String ? n : '').trim();
    if (s.isEmpty) return 'Another device';
    return s.length > 60 ? s.substring(0, 60) : s;
  }

  String _newCode() => (_random.nextInt(900000) + 100000).toString();

  Future<bool> _pairServer(
    SyncChannel ch,
    SyncIdentity self,
    String peerId,
    String peerName,
    String nI,
    String nR,
  ) async {
    final code = _newCode();
    incomingPairing.value = IncomingPairing(
      deviceName: peerName,
      code: code,
      expiresAt: _clock().add(const Duration(minutes: 2)),
    );
    await ch.send({
      't': 'unpaired',
      'id': self.id,
      'name': self.name,
      'nonce': nR,
    });
    for (var attempt = 0; attempt < _maxPairingAttempts; attempt++) {
      final msg = await ch.receive(timeout: const Duration(minutes: 2));
      final key = _deriveKey(code, nI, nR, peerId, self.id);
      if (msg['t'] == 'pair' &&
          _proofOk(
            msg['proof'],
            _proof(utf8.encode(code), 'pair-I', nI, nR, peerId, self.id),
          )) {
        final now = _now;
        await store.savePeer(
          SyncPeer(id: peerId, name: peerName, key: key, pairedAt: now),
        );
        await ch.send({
          't': 'paired',
          'proof': _b64(
            _proof(utf8.encode(code), 'pair-R', nI, nR, peerId, self.id),
          ),
        });
        ch.enableAuth(_sessionKey(key, nI, nR));
        incomingPairing.value = null;
        return true;
      }
      if (msg['t'] == 'bye') return false;
      await ch.send({
        't': 'pairFailed',
        'left': _maxPairingAttempts - attempt - 1,
      });
    }
    return false;
  }

  Future<void> _sessionLoop(SyncChannel ch, String peerId) async {
    while (true) {
      final msg = await ch.receive(timeout: const Duration(seconds: 60));
      switch (msg['t']) {
        case 'summaries':
          final all = await repository.syncSummaries();
          await ch.send({
            't': 'summaries',
            'now': _now,
            'items': [for (final s in all) s.toJson()],
          });
        case 'get':
          await ch.send(await _serveGet(msg));
        case 'put':
          await ch.send(await _servePut(msg));
        case 'bye':
          await _saveServerBases(peerId, msg['bases']);
          await store.markSynced(peerId, _now);
          incomingSyncs.value++;
          await ch.send({'t': 'done'});
          return;
        default:
          await ch.send({'t': 'error', 'm': 'Unknown request.'});
          return;
      }
    }
  }

  /// The initiator reports what both devices now agree on; keep it from this
  /// side's point of view (its remote time is our local time).
  Future<void> _saveServerBases(String peerId, Object? raw) async {
    if (raw is! List || raw.length > _maxItems) return;
    final bases = <String, SyncBase>{};
    for (final e in raw) {
      if (e is! Map) continue;
      final id = e['id'], l = e['l'], r = e['r'];
      if (id is String && isSyncId(id) && l is int && r is int) {
        bases[id] = SyncBase(localTime: r, remoteTime: l);
      }
    }
    if (bases.isNotEmpty) await store.saveBases(peerId, bases);
  }

  List<String> _ids(Object? o) {
    if (o is! List || o.length > _maxItems) return const [];
    return [
      for (final e in o)
        if (e is String && isSyncId(e)) e,
    ];
  }

  Future<Map<String, Object?>> _serveGet(Map<String, Object?> msg) async {
    final byId = {for (final s in await repository.syncSummaries()) s.id: s};
    final items = <Map<String, Object?>>[];
    for (final id in _ids(msg['ids'])) {
      final s = byId[id];
      final json = await repository.exportForSync(id);
      if (s == null || json == null) continue;
      items.add({'id': id, 'u': s.updatedAt, 'json': json});
    }
    return {'t': 'chars', 'items': items};
  }

  Future<Map<String, Object?>> _servePut(Map<String, Object?> msg) async {
    // The initiator measured how far our clock is ahead of its own.
    final offset = (msg['offset'] as num?)?.toInt() ?? 0;
    final applied = <Map<String, Object?>>[];
    final items = msg['items'];
    if (items is List && items.length <= _maxItems) {
      for (final e in items) {
        if (e is! Map) continue;
        final id = e['id'], u = e['u'], json = e['json'];
        if (id is! String || !isSyncId(id) || u is! int || json is! String) {
          continue;
        }
        try {
          final c = decodeCharacterJson(json);
          if (c.id != id) continue;
          final at = await repository.applySynced(
            c,
            remoteTime: u,
            skewMs: -offset,
          );
          applied.add({'id': id, 't': at});
        } on FormatException {
          continue;
        }
      }
    }
    final deletes = msg['deletes'];
    if (deletes is List && deletes.length <= _maxItems) {
      for (final e in deletes) {
        if (e is! Map) continue;
        final id = e['id'], d = e['d'], n = e['n'];
        if (id is! String || !isSyncId(id) || d is! int) continue;
        final at = await repository.applySyncedDelete(
          id,
          name: n is String ? n : '',
          remoteTime: d,
          skewMs: -offset,
        );
        applied.add({'id': id, 't': at});
      }
    }
    return {'t': 'applied', 'items': applied};
  }

  // ---------------------------------------------------------------- client

  /// Syncs with [peer]. Throws [SyncException] with a message fit to show.
  Future<SyncOutcome> sync(
    NearbyPeer peer,
    SyncCallbacks callbacks, {
    Duration connectTimeout = const Duration(seconds: 5),
  }) async {
    final self = await store.identity();
    await repository.assignLegacyIds();
    callbacks.onStatus?.call('Connecting to ${peer.name}');
    final socket = await _connect(peer, connectTimeout);
    final ch = SyncChannel(socket, isInitiator: true);
    try {
      return await _run(ch, self, peer, callbacks);
    } on SocketException {
      throw const SyncException('Lost the connection to the other device.');
    } finally {
      await ch.close();
    }
  }

  Future<Socket> _connect(NearbyPeer peer, Duration timeout) async {
    for (final host in peer.hosts) {
      try {
        return await Socket.connect(host, peer.port, timeout: timeout);
      } catch (_) {
        continue;
      }
    }
    throw const SyncException(
      'Could not reach the other device. Make sure both are on the same '
      'Wi-Fi network and the Sync screen is open on both.',
    );
  }

  Future<SyncOutcome> _run(
    SyncChannel ch,
    SyncIdentity self,
    NearbyPeer peer,
    SyncCallbacks cb,
  ) async {
    final known = await store.peer(peer.id);
    final nI = _nonce();
    await ch.send({
      't': 'hello',
      'v': _protocolVersion,
      'id': self.id,
      'name': self.name,
      'nonce': nI,
      'paired': known != null,
    });
    final first = await ch.receive();
    var peerName = known?.name ?? peer.name;
    var paired = false;
    switch (first['t']) {
      case 'challenge':
        final nR = first['nonce'];
        if (known == null || nR is! String || first['id'] != peer.id) {
          throw const SyncException('Could not verify the other device.');
        }
        if (!_proofOk(
          first['proof'],
          _proof(known.key, 'R', nI, nR, self.id, peer.id),
        )) {
          throw const SyncException(
            'Could not verify the other device. Forget it on both devices '
            'and pair again.',
          );
        }
        await ch.send({
          't': 'auth',
          'proof': _b64(_proof(known.key, 'I', nI, nR, self.id, peer.id)),
        });
        ch.enableAuth(_sessionKey(known.key, nI, nR));
        final ready = await ch.receive();
        if (ready['t'] != 'ready') {
          throw SyncException(_errorText(ready));
        }
      case 'unpaired':
        final nR = first['nonce'];
        if (nR is! String || first['id'] != peer.id) {
          throw const SyncException('Could not verify the other device.');
        }
        peerName = _cleanName(first['name']);
        await _pairClient(ch, self, peer, peerName, nI, nR, cb);
        paired = true;
      default:
        throw SyncException(_errorText(first));
    }

    cb.onStatus?.call('Comparing characters');
    final t0 = _now;
    await ch.send({'t': 'summaries'});
    final reply = await ch.receive();
    final t1 = _now;
    if (reply['t'] != 'summaries') throw SyncException(_errorText(reply));
    final remoteNow = (reply['now'] as num?)?.toInt() ?? t1;
    // How far the other clock is ahead of ours, assuming the reply took as
    // long to come back as the request took to arrive.
    final offset = remoteNow - ((t0 + t1) ~/ 2);
    final remote = <String, SyncSummary>{};
    final rawItems = reply['items'];
    if (rawItems is List && rawItems.length <= _maxItems) {
      for (final e in rawItems) {
        final s = SyncSummary.tryFromJson(e);
        if (s != null) remote[s.id] = s;
      }
    }
    final local = {for (final s in await repository.syncSummaries()) s.id: s};
    final peerId = peer.id;
    final bases = await store.bases(peerId);
    final plan = planSync(
      local: local,
      remote: remote,
      bases: bases,
      skewMs: offset,
    );

    var choices = <String, ConflictChoice>{};
    if (plan.conflicts.isNotEmpty) {
      final picked = await cb.resolveConflicts(plan.conflicts);
      if (picked == null) {
        await _bye(ch);
        throw const SyncException('Sync cancelled.');
      }
      choices = picked;
    }
    final skipped = plan.conflicts
        .where((c) => !choices.containsKey(c.id))
        .length;
    final items = plan.resolve(choices);
    final newBases = <String, SyncBase>{
      for (final id in plan.inSync)
        id: SyncBase(localTime: local[id]!.time, remoteTime: remote[id]!.time),
    };

    var received = 0, sent = 0, deletedHere = 0, deletedThere = 0, copies = 0;

    // Fetch what is newer over there.
    final pulls = items
        .where((i) => i.step == SyncStep.pullCharacter)
        .map((i) => i.id)
        .toSet()
        .toList();
    if (pulls.isNotEmpty) {
      cb.onStatus?.call('Receiving ${pulls.length} character(s)');
      await ch.send({'t': 'get', 'ids': pulls});
      final got = await ch.receive(timeout: const Duration(minutes: 2));
      if (got['t'] != 'chars') throw SyncException(_errorText(got));
      final byId = <String, Map>{};
      final rawChars = got['items'];
      if (rawChars is List) {
        for (final e in rawChars) {
          if (e is Map && e['id'] is String) byId[e['id'] as String] = e;
        }
      }
      for (final item in items.where((i) => i.step == SyncStep.pullCharacter)) {
        final e = byId[item.id];
        final json = e?['json'];
        if (json is! String) continue;
        final Character c;
        try {
          c = decodeCharacterJson(json);
        } on FormatException {
          continue;
        }
        if (c.id != item.id) continue;
        if (item.asCopy) {
          await repository.receive(c, asCopy: true);
          copies++;
          continue;
        }
        final r = remote[item.id]!;
        final at = await repository.applySynced(
          c,
          remoteTime: r.updatedAt,
          skewMs: offset,
        );
        newBases[item.id] = SyncBase(localTime: at, remoteTime: r.time);
        received++;
      }
    }
    for (final item in items.where((i) => i.step == SyncStep.pullDelete)) {
      final r = remote[item.id]!;
      final at = await repository.applySyncedDelete(
        item.id,
        name: r.name,
        remoteTime: r.deletedAt!,
        skewMs: offset,
      );
      newBases[item.id] = SyncBase(localTime: at, remoteTime: r.time);
      deletedHere++;
    }

    // Send what is newer here.
    final puts = <Map<String, Object?>>[];
    final deletes = <Map<String, Object?>>[];
    final sentTimes = <String, int>{};
    for (final item in items) {
      final l = local[item.id];
      if (l == null) continue;
      if (item.step == SyncStep.pushCharacter) {
        final json = await repository.exportForSync(item.id);
        if (json == null) continue;
        puts.add({'id': item.id, 'u': l.updatedAt, 'json': json});
        sentTimes[item.id] = l.time;
      } else if (item.step == SyncStep.pushDelete) {
        deletes.add({'id': item.id, 'n': l.name, 'd': l.deletedAt});
        sentTimes[item.id] = l.time;
      }
    }
    if (puts.isNotEmpty || deletes.isNotEmpty) {
      cb.onStatus?.call('Sending ${puts.length + deletes.length} change(s)');
      await ch.send({
        't': 'put',
        'offset': offset,
        'items': puts,
        'deletes': deletes,
      });
      final ack = await ch.receive(timeout: const Duration(minutes: 2));
      if (ack['t'] != 'applied') throw SyncException(_errorText(ack));
      final done = ack['items'];
      if (done is List) {
        for (final e in done) {
          if (e is! Map) continue;
          final id = e['id'], t = e['t'];
          if (id is String && t is int && sentTimes.containsKey(id)) {
            newBases[id] = SyncBase(localTime: sentTimes[id]!, remoteTime: t);
            if (deletes.any((d) => d['id'] == id)) {
              deletedThere++;
            } else {
              sent++;
            }
          }
        }
      }
    }

    await store.saveBases(peerId, newBases);
    await store.markSynced(peerId, _now);
    await _bye(ch, bases: newBases);
    return SyncOutcome(
      peerName: peerName,
      sent: sent,
      received: received,
      deletedHere: deletedHere,
      deletedThere: deletedThere,
      copies: copies,
      skipped: skipped,
      clockOffset: Duration(milliseconds: offset),
      paired: paired,
    );
  }

  Future<void> _pairClient(
    SyncChannel ch,
    SyncIdentity self,
    NearbyPeer peer,
    String peerName,
    String nI,
    String nR,
    SyncCallbacks cb,
  ) async {
    var wrong = false;
    for (var attempt = 0; attempt < _maxPairingAttempts; attempt++) {
      final code = await cb.askCode(
        PairPrompt(deviceName: peerName, wrongCode: wrong),
      );
      if (code == null) {
        await _bye(ch, wait: false);
        throw const SyncException('Pairing cancelled.');
      }
      final digits = code.replaceAll(RegExp(r'\D'), '');
      await ch.send({
        't': 'pair',
        'proof': _b64(
          _proof(utf8.encode(digits), 'pair-I', nI, nR, self.id, peer.id),
        ),
      });
      final r = await ch.receive();
      if (r['t'] == 'paired') {
        if (!_proofOk(
          r['proof'],
          _proof(utf8.encode(digits), 'pair-R', nI, nR, self.id, peer.id),
        )) {
          throw const SyncException('Could not verify the other device.');
        }
        final key = _deriveKey(digits, nI, nR, self.id, peer.id);
        await store.savePeer(
          SyncPeer(id: peer.id, name: peerName, key: key, pairedAt: _now),
        );
        ch.enableAuth(_sessionKey(key, nI, nR));
        return;
      }
      if (r['t'] != 'pairFailed') throw SyncException(_errorText(r));
      wrong = true;
    }
    throw const SyncException(
      'The code was wrong too many times. Start again to get a new code.',
    );
  }

  Future<void> _bye(
    SyncChannel ch, {
    Map<String, SyncBase> bases = const {},
    bool wait = true,
  }) async {
    try {
      await ch.send({
        't': 'bye',
        if (bases.isNotEmpty)
          'bases': [
            for (final e in bases.entries)
              {'id': e.key, 'l': e.value.localTime, 'r': e.value.remoteTime},
          ],
      });
      // Wait until the other side has stored everything, so a sync started
      // right after this one does not find it still busy.
      if (wait) await ch.receive(timeout: const Duration(seconds: 5));
    } catch (_) {}
  }

  String _errorText(Map<String, Object?> m) {
    final text = m['m'];
    return m['t'] == 'error' && text is String
        ? text
        : 'The other device sent something unexpected.';
  }
}
