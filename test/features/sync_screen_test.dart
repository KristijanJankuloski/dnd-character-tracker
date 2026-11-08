import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/core/app.dart';
import 'package:jjs_character_tracker/data/database.dart';
import 'package:jjs_character_tracker/data/drift_repository.dart';
import 'package:jjs_character_tracker/data/drift_sync_store.dart';
import 'package:jjs_character_tracker/data/nearby_discovery.dart';
import 'package:jjs_character_tracker/domain/sync.dart';

class FakeDiscovery implements PeerDiscovery {
  final _c = StreamController<List<NearbyPeer>>.broadcast();
  bool started = false, stopped = false;
  SyncIdentity? self;

  @override
  Stream<List<NearbyPeer>> get peers => _c.stream;

  void show(List<NearbyPeer> p) => _c.add(p);

  @override
  Future<void> start({required SyncIdentity self, required int port}) async {
    started = true;
    this.self = self;
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }
}

/// Lets Drift's stream cleanup timers run before the test ends.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('sync screen lists nearby devices and stops when left', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => tester.runAsync(db.close));
    final discovery = FakeDiscovery();
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      DnDApp(
        repository: DriftCharacterRepository(db),
        syncStore: DriftSyncStore(db, defaultName: () => 'My phone'),
        discoveryFactory: () => discovery,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byTooltip('Sync with nearby devices'));
    await tester.pump();
    for (var i = 0; i < 80 && find.text('My phone').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }
    expect(discovery.started, isTrue);
    expect(find.text('My phone'), findsOneWidget);
    expect(find.textContaining('Looking for other devices'), findsOneWidget);

    discovery.show([
      const NearbyPeer(
        id: '22222222-2222-4222-8222-222222222222',
        name: 'Dragon tablet',
        hosts: ['10.0.0.9'],
        port: 1234,
      ),
    ]);
    await tester.pump();
    expect(find.text('Dragon tablet'), findsOneWidget);
    expect(find.text('Not paired yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Pair'), findsOneWidget);

    // Leaving the screen stops announcing and searching.
    await tester.pageBack();
    await tester.pump();
    await tester.pump();
    expect(discovery.stopped, isTrue);
    await _unmount(tester);
  });

  testWidgets('the sync button is hidden when sync is not set up', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => tester.runAsync(db.close));
    await tester.pumpWidget(DnDApp(repository: DriftCharacterRepository(db)));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byTooltip('Sync with nearby devices'), findsNothing);
    await _unmount(tester);
  });
}
