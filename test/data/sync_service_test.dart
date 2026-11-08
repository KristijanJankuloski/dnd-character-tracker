import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/data/database.dart';
import 'package:jjs_character_tracker/data/drift_repository.dart';
import 'package:jjs_character_tracker/data/drift_sync_store.dart';
import 'package:jjs_character_tracker/data/nearby_discovery.dart';
import 'package:jjs_character_tracker/data/sync_channel.dart';
import 'package:jjs_character_tracker/data/sync_service.dart';
import 'package:jjs_character_tracker/domain/character_factory.dart';
import 'package:jjs_character_tracker/domain/models.dart';
import 'package:jjs_character_tracker/domain/repository.dart';
import 'package:jjs_character_tracker/domain/sync.dart';

/// A device: its own database, repository, sync store and sync service.
class Device {
  Device(String name, {Duration clockAhead = Duration.zero}) {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftCharacterRepository(db);
    store = DriftSyncStore(db, defaultName: () => name);
    service = SyncService(
      repository: repo,
      store: store,
      clock: () => DateTime.now().add(clockAhead),
    );
  }
  late final AppDatabase db;
  late final DriftCharacterRepository repo;
  late final DriftSyncStore store;
  late final SyncService service;
  int? port;

  Future<NearbyPeer> listen() async {
    port = await service.start(address: InternetAddress.loopbackIPv4);
    final self = await store.identity();
    return NearbyPeer(
      id: self.id,
      name: self.name,
      hosts: const ['127.0.0.1'],
      port: port!,
    );
  }

  Future<Character> add(String name, {int level = 1}) async {
    final c = createCharacter(
      name: name,
      race: 'Elf',
      className: 'Wizard',
      level: level,
      abilities: standardArray,
    );
    await repo.create(c);
    return c;
  }

  Future<void> setTime(String id, int ms) =>
      (db.update(db.characters)..where((t) => t.id.equals(id))).write(
        CharactersCompanion(updatedAt: Value(ms)),
      );

  Future<List<String>> names() async =>
      ((await repo.watchAll().first).map((c) => c.name).toList()..sort());

  Future<void> close() async {
    await service.close();
    await db.close();
  }
}

SyncCallbacks callbacks(
  Device server, {
  List<String?> codes = const [],
  Map<String, ConflictChoice>? Function(List<SyncConflict>)? onConflicts,
  List<String>? seen,
}) {
  final queue = [...codes];
  return SyncCallbacks(
    askCode: (_) async {
      if (queue.isEmpty) {
        // Read what the other device displays.
        return server.service.incomingPairing.value?.code;
      }
      final next = queue.removeAt(0);
      return next == 'SHOWN'
          ? server.service.incomingPairing.value?.code
          : next;
    },
    resolveConflicts: (cs) async {
      seen?.addAll(cs.map((c) => c.name));
      return onConflicts == null ? <String, ConflictChoice>{} : onConflicts(cs);
    },
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Device a, b;
  late NearbyPeer aPeer, bPeer;

  setUp(() async {
    a = Device('Phone A');
    b = Device('Phone B');
    aPeer = await a.listen();
    bPeer = await b.listen();
  });
  tearDown(() async {
    await a.close();
    await b.close();
  });

  test('first contact pairs with a code, then sync needs none', () async {
    await a.add('Aria');
    final first = await b.service.sync(aPeer, callbacks(a));
    expect(first.paired, isTrue);
    expect(first.received, 1);
    expect(await b.names(), ['Aria']);
    expect((await a.store.peers()).single.name, 'Phone B');
    expect((await b.store.peers()).single.name, 'Phone A');
    // Same key on both sides.
    expect(
      (await a.store.peers()).single.key,
      (await b.store.peers()).single.key,
    );

    await b.add('Borin');
    // No codes available this time: pairing would fail the sync.
    final second = await b.service.sync(
      aPeer,
      SyncCallbacks(
        askCode: (_) async => fail('should not ask for a code'),
        resolveConflicts: (_) async => {},
      ),
    );
    expect(second.paired, isFalse);
    expect(second.sent, 1);
    expect(await a.names(), ['Aria', 'Borin']);

    // Either device can start: A syncs with B, nothing to move.
    final third = await a.service.sync(bPeer, callbacks(b));
    expect(third.changedNothing, isTrue);
  });

  test('a wrong code is refused and the right one still works', () async {
    await a.add('Aria');
    final out = await b.service.sync(
      aPeer,
      callbacks(a, codes: ['000000', 'SHOWN']),
    );
    expect(out.paired, isTrue);
    expect(await b.names(), ['Aria']);
  });

  test('three wrong codes end pairing and nothing is saved', () async {
    await a.add('Aria');
    await expectLater(
      b.service.sync(
        aPeer,
        callbacks(a, codes: ['111111', '222222', '333333']),
      ),
      throwsA(isA<SyncException>()),
    );
    expect(await b.store.peers(), isEmpty);
    expect(await a.store.peers(), isEmpty);
    expect(await b.names(), isEmpty);
  });

  test('cancelling the code prompt cancels without pairing', () async {
    await a.add('Aria');
    await expectLater(
      b.service.sync(aPeer, callbacks(a, codes: [null])),
      throwsA(isA<SyncException>()),
    );
    expect(await a.store.peers(), isEmpty);
  });

  test('only changed characters move, newest edit wins', () async {
    final x = await a.add('Aria');
    await a.add('Untouched');
    await b.service.sync(aPeer, callbacks(a));
    expect(await b.names(), ['Aria', 'Untouched']);

    // Edit Aria on B only.
    final onB = (await b.repo.get(x.id))!;
    await b.repo.save(onB.copyWith(notes: 'edited on B'));
    final out = await b.service.sync(aPeer, callbacks(a));
    expect(out.sent, 1);
    expect(out.received, 0);
    expect((await a.repo.get(x.id))!.notes, 'edited on B');

    // Now edit on A and sync from A.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await a.repo.save((await a.repo.get(x.id))!.copyWith(notes: 'then on A'));
    final back = await a.service.sync(bPeer, callbacks(b));
    expect(back.sent, 1);
    expect((await b.repo.get(x.id))!.notes, 'then on A');
  });

  test('a delete spreads and the character does not come back', () async {
    final x = await a.add('Doomed');
    await b.service.sync(aPeer, callbacks(a));
    expect(await b.names(), ['Doomed']);

    await b.repo.delete(x.id);
    final out = await b.service.sync(aPeer, callbacks(a));
    expect(out.deletedThere, 1);
    expect(await a.names(), isEmpty);

    // Syncing again from either side must not resurrect it.
    await b.service.sync(aPeer, callbacks(a));
    await a.service.sync(bPeer, callbacks(b));
    expect(await a.names(), isEmpty);
    expect(await b.names(), isEmpty);
  });

  test('a delete made on the other device is copied here', () async {
    final x = await a.add('Doomed');
    await b.service.sync(aPeer, callbacks(a));
    await a.repo.delete(x.id);
    final out = await b.service.sync(aPeer, callbacks(a));
    expect(out.deletedHere, 1);
    expect(await b.names(), isEmpty);
  });

  test('re-creating a deleted id clears the tombstone', () async {
    final x = await a.add('Phoenix');
    await a.repo.delete(x.id);
    expect((await a.repo.syncSummaries()).single.isDeleted, isTrue);
    await a.repo.create(x);
    expect((await a.repo.syncSummaries()).single.isDeleted, isFalse);
  });

  test('both changed since the last sync: the user chooses', () async {
    final x = await a.add('Contested');
    await b.service.sync(aPeer, callbacks(a));
    await a.repo.save((await a.repo.get(x.id))!.copyWith(notes: 'A says'));
    await b.repo.save((await b.repo.get(x.id))!.copyWith(notes: 'B says'));

    // Skipping leaves both untouched.
    final seen = <String>[];
    final skipped = await b.service.sync(aPeer, callbacks(a, seen: seen));
    expect(seen, ['Contested']);
    expect(skipped.skipped, 1);
    expect((await a.repo.get(x.id))!.notes, 'A says');
    expect((await b.repo.get(x.id))!.notes, 'B says');

    // Keep mine pushes B's version.
    await b.service.sync(
      aPeer,
      callbacks(
        a,
        onConflicts: (cs) => {
          for (final c in cs) c.id: ConflictChoice.keepMine,
        },
      ),
    );
    expect((await a.repo.get(x.id))!.notes, 'B says');
  });

  test('keep both leaves two characters here', () async {
    final x = await a.add('Twin');
    await b.service.sync(aPeer, callbacks(a));
    await a.repo.save((await a.repo.get(x.id))!.copyWith(notes: 'A says'));
    await b.repo.save((await b.repo.get(x.id))!.copyWith(notes: 'B says'));
    final out = await b.service.sync(
      aPeer,
      callbacks(
        a,
        onConflicts: (cs) => {
          for (final c in cs) c.id: ConflictChoice.keepBoth,
        },
      ),
    );
    expect(out.copies, 1);
    expect(out.sent, 1);
    final all = await b.repo.watchAll().first;
    expect(all.map((c) => c.notes).toSet(), {'A says', 'B says'});
    expect((await a.repo.get(x.id))!.notes, 'B says');
  });

  test('legacy ids become UUIDs before syncing', () async {
    final legacy = createCharacter(
      name: 'Old',
      race: 'Elf',
      className: 'Wizard',
      level: 1,
      abilities: standardArray,
    );
    final old = Character.fromJson({...legacy.toJson(), 'id': 'char-12345'});
    await a.repo.create(old);
    await a.repo.save(old.copyWith(notes: 'history')); // no log needed
    expect(await a.repo.assignLegacyIds(), 1);
    final all = await a.repo.watchAll().first;
    expect(isSyncId(all.single.id), isTrue);
    expect(all.single.notes, 'history');
    expect(await a.repo.get('char-12345'), isNull);
    // The log followed the character and nothing is left to change.
    expect((await a.repo.watchLog(all.single.id).first), isNotEmpty);
    expect(await a.repo.assignLegacyIds(), 0);

    await b.service.sync(aPeer, callbacks(a));
    expect(await b.names(), ['Old']);
  });

  test('clock skew: edit order is judged by corrected time', () async {
    // A's clock is an hour fast. B really edited 30 minutes after A, but A's
    // stamp looks 30 minutes newer than B's.
    await a.close();
    a = Device('Fast', clockAhead: const Duration(hours: 1));
    aPeer = await a.listen();
    final x = await a.add('Skewed');
    final json = await a.repo.exportForSync(x.id);
    final copy = decodeCharacterJson(json!);
    await b.repo.create(copy.copyWith(notes: 'B edited later'));
    final now = DateTime.now().millisecondsSinceEpoch;
    await a.setTime(x.id, now - 10 * 60000 + 60 * 60000); // A edit, A clock
    await b.setTime(x.id, now); // B edit, 10 minutes after A's real time

    final out = await b.service.sync(aPeer, callbacks(a));
    expect(out.clockOffset.inMinutes, closeTo(60, 1));
    expect(out.clocksFarApart, isTrue);
    expect(out.sent, 1, reason: 'B is really newer');
    expect((await a.repo.get(x.id))!.notes, 'B edited later');
  });

  test('forgetting a device on one side requires pairing again', () async {
    await a.add('Aria');
    await b.service.sync(aPeer, callbacks(a));
    await a.store.forgetPeer((await b.store.identity()).id);
    // B still holds a key, A does not: pairing starts over, then works.
    final out = await b.service.sync(aPeer, callbacks(a));
    expect(out.paired, isTrue);
  });
}
