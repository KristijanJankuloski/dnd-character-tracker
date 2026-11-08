/// Pure sync rules: what each device has, and what has to move.
///
/// Every character, and every deleted character (a tombstone), is summarised
/// as a [SyncSummary]. Two devices swap their summaries and [planSync] decides
/// per character whether to send it, fetch it, copy a deletion or ask the
/// user. Nothing in here touches the database or the network.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

/// How two devices' clocks may differ before an unrelated edit and an edit
/// from the other device are treated as "at the same time" when there is no
/// shared history to go by.
const defaultSyncTolerance = Duration(minutes: 2);

/// A character older than this clock difference gets a warning in the UI.
const clockWarnThreshold = Duration(minutes: 5);

bool isSyncId(String id) => Uuid.isValidUUID(fromString: id);

/// Short fingerprint of a character's saved JSON. Equal fingerprints mean
/// identical content, whatever the timestamps say.
String contentHash(String json) =>
    sha256.convert(utf8.encode(json)).toString().substring(0, 16);

/// One character or tombstone as one device sees it.
class SyncSummary {
  const SyncSummary({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.deletedAt,
    this.hash = '',
  });

  final String id;
  final String name;

  /// Last save, in the owning device's clock (ms since epoch). For a
  /// tombstone this is the time the character was last saved before deletion.
  final int updatedAt;

  /// When it was deleted, or null if it still exists.
  final int? deletedAt;
  final String hash;

  bool get isDeleted => deletedAt != null;

  /// The moment of the latest change, edit or delete.
  int get time => deletedAt ?? updatedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'n': name,
    'u': updatedAt,
    if (deletedAt != null) 'd': deletedAt,
    'h': hash,
  };

  static SyncSummary? tryFromJson(Object? o) {
    if (o is! Map) return null;
    final id = o['id'], n = o['n'], u = o['u'], d = o['d'], h = o['h'];
    if (id is! String || !isSyncId(id)) return null;
    if (u is! int || (d != null && d is! int)) return null;
    return SyncSummary(
      id: id,
      name: n is String ? n : '',
      updatedAt: u,
      deletedAt: d as int?,
      hash: h is String ? h : '',
    );
  }
}

/// The two devices' times for one character when they last agreed. Each is in
/// its own device's clock, so comparing a time against its own base is immune
/// to clock skew.
class SyncBase {
  const SyncBase({required this.localTime, required this.remoteTime});
  final int localTime;
  final int remoteTime;
}

enum SyncStep { pushCharacter, pullCharacter, pushDelete, pullDelete }

class SyncItem {
  const SyncItem(this.id, this.step, {this.asCopy = false});
  final String id;
  final SyncStep step;

  /// Pull the remote version as a new character instead of replacing mine.
  final bool asCopy;

  @override
  String toString() => 'SyncItem($id, ${step.name}${asCopy ? ', copy' : ''})';
}

/// A character both devices changed since they last agreed.
class SyncConflict {
  const SyncConflict({required this.id, this.local, this.remote});
  final String id;
  final SyncSummary? local;
  final SyncSummary? remote;

  String get name {
    final l = local?.name ?? '';
    return l.isNotEmpty ? l : (remote?.name ?? '');
  }

  bool get localDeleted => local?.isDeleted ?? false;
  bool get remoteDeleted => remote?.isDeleted ?? false;

  /// Both versions exist, so keeping both as two characters makes sense.
  bool get canKeepBoth => !localDeleted && !remoteDeleted;
}

enum ConflictChoice { keepMine, useTheirs, keepBoth }

class SyncPlan {
  const SyncPlan({
    required this.items,
    required this.conflicts,
    required this.inSync,
  });

  final List<SyncItem> items;
  final List<SyncConflict> conflicts;

  /// Characters that already match; only their bases need recording.
  final List<String> inSync;

  bool get isEmpty => items.isEmpty && conflicts.isEmpty;

  /// The plan with every conflict settled by [choices]. A conflict without a
  /// choice is left alone (nothing moves and it stays a conflict next time).
  List<SyncItem> resolve(Map<String, ConflictChoice> choices) {
    final out = [...items];
    for (final c in conflicts) {
      switch (choices[c.id]) {
        case null:
          break;
        case ConflictChoice.keepMine:
          out.add(
            SyncItem(
              c.id,
              c.localDeleted ? SyncStep.pushDelete : SyncStep.pushCharacter,
            ),
          );
        case ConflictChoice.useTheirs:
          out.add(
            SyncItem(
              c.id,
              c.remoteDeleted ? SyncStep.pullDelete : SyncStep.pullCharacter,
            ),
          );
        case ConflictChoice.keepBoth:
          if (c.canKeepBoth) {
            out.add(SyncItem(c.id, SyncStep.pullCharacter, asCopy: true));
            out.add(SyncItem(c.id, SyncStep.pushCharacter));
          }
      }
    }
    return out;
  }
}

/// Decides what to do for every character either device knows about.
///
/// [skewMs] is how far the other device's clock is ahead of ours. [bases] is
/// what the two last agreed on, per character.
///
/// - Changed on one side only since the last sync: that side wins. Clocks do
///   not matter, because each time is compared with a base from its own clock.
/// - Changed on both sides since the last sync: a conflict the user settles.
/// - Never synced before: the newest change wins, with the other device's
///   times shifted by [skewMs]; changes within [tolerance] of each other count
///   as a conflict because skew can not be ruled out.
SyncPlan planSync({
  required Map<String, SyncSummary> local,
  required Map<String, SyncSummary> remote,
  required Map<String, SyncBase> bases,
  int skewMs = 0,
  Duration tolerance = defaultSyncTolerance,
}) {
  final items = <SyncItem>[];
  final conflicts = <SyncConflict>[];
  final inSync = <String>[];

  SyncItem winnerLocal(SyncSummary l) => SyncItem(
    l.id,
    l.isDeleted ? SyncStep.pushDelete : SyncStep.pushCharacter,
  );
  SyncItem winnerRemote(SyncSummary r) => SyncItem(
    r.id,
    r.isDeleted ? SyncStep.pullDelete : SyncStep.pullCharacter,
  );

  final ids = {...local.keys, ...remote.keys}.toList()..sort();
  for (final id in ids) {
    final l = local[id], r = remote[id];
    if (l == null && r == null) continue;
    if (l == null) {
      if (!r!.isDeleted) items.add(winnerRemote(r));
      continue;
    }
    if (r == null) {
      if (!l.isDeleted) items.add(winnerLocal(l));
      continue;
    }
    if (l.isDeleted && r.isDeleted) {
      inSync.add(id);
      continue;
    }
    if (!l.isDeleted && !r.isDeleted && l.hash.isNotEmpty && l.hash == r.hash) {
      inSync.add(id);
      continue;
    }

    final b = bases[id];
    final lChanged = b == null || l.time > b.localTime;
    final rChanged = b == null || r.time > b.remoteTime;
    if (lChanged && rChanged) {
      if (b != null) {
        conflicts.add(SyncConflict(id: id, local: l, remote: r));
        continue;
      }
      final diff = l.time - (r.time - skewMs);
      if (diff.abs() <= tolerance.inMilliseconds) {
        conflicts.add(SyncConflict(id: id, local: l, remote: r));
      } else {
        items.add(diff > 0 ? winnerLocal(l) : winnerRemote(r));
      }
    } else if (lChanged) {
      items.add(winnerLocal(l));
    } else if (rChanged) {
      items.add(winnerRemote(r));
    } else {
      // Neither moved since the last sync yet they differ (an app update that
      // re-encodes characters, say). Newest wins, ties are left alone.
      final diff = l.time - (r.time - skewMs);
      if (diff > 0) {
        items.add(winnerLocal(l));
      } else if (diff < 0) {
        items.add(winnerRemote(r));
      }
    }
  }
  return SyncPlan(items: items, conflicts: conflicts, inSync: inSync);
}

/// One paired device.
class SyncPeer {
  const SyncPeer({
    required this.id,
    required this.name,
    required this.key,
    required this.pairedAt,
    this.lastSyncAt,
  });
  final String id;
  final String name;

  /// Shared secret from pairing.
  final List<int> key;
  final int pairedAt;
  final int? lastSyncAt;
}

/// This device's identity for syncing.
class SyncIdentity {
  const SyncIdentity({required this.id, required this.name});
  final String id;
  final String name;
}

/// Where sync keeps its own bookkeeping: who this device is, which devices it
/// is paired with and what they last agreed on.
abstract class SyncStore {
  /// Created on first use.
  Future<SyncIdentity> identity();
  Future<void> setDeviceName(String name);

  Future<List<SyncPeer>> peers();
  Future<SyncPeer?> peer(String id);
  Future<void> savePeer(SyncPeer peer);

  /// Forgets the device and what was agreed with it.
  Future<void> forgetPeer(String id);
  Future<void> markSynced(String peerId, int at);

  Future<Map<String, SyncBase>> bases(String peerId);
  Future<void> saveBases(String peerId, Map<String, SyncBase> bases);
}
