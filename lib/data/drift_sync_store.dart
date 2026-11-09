import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/sync.dart';
import 'database.dart';

/// Drift-backed [SyncStore].
class DriftSyncStore implements SyncStore {
  DriftSyncStore(this._db, {this.defaultName});
  final AppDatabase _db;

  /// Name for this device until the user picks one.
  final String Function()? defaultName;

  Future<String?> _get(String key) async {
    final r = await (_db.select(
      _db.syncSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return r?.value;
  }

  Future<void> _set(String key, String value) => _db
      .into(_db.syncSettings)
      .insertOnConflictUpdate(
        SyncSettingsCompanion.insert(key: key, value: value),
      );

  @override
  Future<SyncIdentity> identity() async {
    var id = await _get('device_id');
    if (id == null) {
      id = const Uuid().v4();
      await _set('device_id', id);
    }
    var name = await _get('device_name');
    if (name == null) {
      name = defaultName?.call() ?? 'Device ${id.substring(0, 4)}';
      await _set('device_name', name);
    }
    return SyncIdentity(id: id, name: name);
  }

  @override
  Future<void> setDeviceName(String name) async {
    final n = name.trim();
    if (n.isNotEmpty) await _set('device_name', n);
  }

  SyncPeer _peer(PeerRow r) => SyncPeer(
    id: r.id,
    name: r.name,
    key: base64Decode(r.key),
    pairedAt: r.pairedAt,
    lastSyncAt: r.lastSyncAt,
  );

  @override
  Future<List<SyncPeer>> peers() async => [
    for (final r in await (_db.select(
      _db.syncPeers,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).get())
      _peer(r),
  ];

  @override
  Future<SyncPeer?> peer(String id) async {
    final r = await (_db.select(
      _db.syncPeers,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return r == null ? null : _peer(r);
  }

  @override
  Future<void> savePeer(SyncPeer p) => _db.transaction(() async {
    final old = await peer(p.id);
    // A new pairing starts from scratch: old agreements used another key.
    if (old != null && !_sameKey(old.key, p.key)) {
      await (_db.delete(
        _db.syncBases,
      )..where((t) => t.peerId.equals(p.id))).go();
    }
    await _db
        .into(_db.syncPeers)
        .insertOnConflictUpdate(
          SyncPeersCompanion.insert(
            id: p.id,
            name: p.name,
            key: base64Encode(p.key),
            pairedAt: p.pairedAt,
            lastSyncAt: Value(p.lastSyncAt),
          ),
        );
  });

  bool _sameKey(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Future<void> forgetPeer(String id) => _db.transaction(() async {
    await (_db.delete(_db.syncBases)..where((t) => t.peerId.equals(id))).go();
    await (_db.delete(_db.syncPeers)..where((t) => t.id.equals(id))).go();
  });

  @override
  Future<void> markSynced(String peerId, int at) =>
      (_db.update(_db.syncPeers)..where((t) => t.id.equals(peerId))).write(
        SyncPeersCompanion(lastSyncAt: Value(at)),
      );

  @override
  Future<Map<String, SyncBase>> bases(String peerId) async => {
    for (final r in await (_db.select(
      _db.syncBases,
    )..where((t) => t.peerId.equals(peerId))).get())
      r.characterId: SyncBase(localTime: r.localTime, remoteTime: r.remoteTime),
  };

  @override
  Future<void> saveBases(String peerId, Map<String, SyncBase> bases) =>
      _db.batch((b) {
        b.insertAllOnConflictUpdate(_db.syncBases, [
          for (final e in bases.entries)
            SyncBasesCompanion.insert(
              peerId: peerId,
              characterId: e.key,
              localTime: e.value.localTime,
              remoteTime: e.value.remoteTime,
            ),
        ]);
      });
}
