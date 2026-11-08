import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jjs_character_tracker/data/database.dart';
import 'package:jjs_character_tracker/data/drift_repository.dart';
import 'package:jjs_character_tracker/data/local_share.dart';
import 'package:jjs_character_tracker/domain/character_factory.dart';
import 'package:jjs_character_tracker/domain/models.dart';
import 'package:jjs_character_tracker/domain/repository.dart';
import 'package:jjs_character_tracker/domain/share_ticket.dart';
import 'package:jjs_character_tracker/features/share/receive_screen.dart';
import 'package:jjs_character_tracker/features/share/share_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  late AppDatabase db;
  late DriftCharacterRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftCharacterRepository(db);
  });

  final ticket = ShareTicket(
    hosts: const ['192.168.1.2'],
    port: 4000,
    token: ShareTicket.newToken(),
  );

  Character make() => createCharacter(
    name: 'Wanderer',
    race: 'Dwarf',
    className: 'Cleric',
    level: 3,
    abilities: standardArray,
  );

  Future<void> pump(WidgetTester tester, Widget home) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => home),
        GoRoute(
          path: '/c/:id',
          builder: (_, s) => Text('opened ${s.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      RepositoryProvider<CharacterRepository>.value(
        value: repo,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('a new character is previewed and saved with its id', (
    tester,
  ) async {
    final c = make();
    await pump(
      tester,
      ReceivePreviewScreen(
        ticket: ticket,
        fetch: (_) async => jsonEncode(c.toJson()),
      ),
    );
    await waitFor(tester, find.text('Save character'));
    expect(find.text('Wanderer'), findsOneWidget);
    expect(find.text('Replace mine'), findsNothing);
    await tester.tap(find.text('Save character'));
    await waitFor(tester, find.text('opened ${c.id}'));
    expect(find.text('opened ${c.id}'), findsOneWidget);
    expect((await tester.runAsync(() => repo.get(c.id)))!.name, 'Wanderer');
  });

  testWidgets('a clash offers replace or save as copy', (tester) async {
    final c = make();
    await tester.runAsync(() => repo.create(c));
    await pump(
      tester,
      ReceivePreviewScreen(
        ticket: ticket,
        fetch: (_) async => jsonEncode(c.toJson()),
      ),
    );
    await waitFor(tester, find.text('Save as a copy'));
    expect(find.text('Replace mine'), findsOneWidget);
    await tester.tap(find.text('Save as a copy'));
    await waitFor(tester, find.textContaining('opened '));
    final all = await tester.runAsync(() => repo.watchAll().first);
    expect(all, hasLength(2));
  });

  testWidgets('a failed fetch explains and offers a retry', (tester) async {
    var calls = 0;
    await pump(
      tester,
      ReceivePreviewScreen(
        ticket: ticket,
        fetch: (_) async {
          calls++;
          throw const ShareException('Could not reach the other device.');
        },
      ),
    );
    await waitFor(tester, find.text('Try again'));
    expect(find.text('Could not reach the other device.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await waitFor(tester, find.text('Try again'));
    expect(calls, 2);
  });

  testWidgets('share screen shows a QR code and reports when sent', (
    tester,
  ) async {
    final c = make();
    await tester.runAsync(() => repo.create(c));
    // Started outside the fake-async zone so its sockets run for real.
    final json = (await tester.runAsync(() => repo.exportJson(c.id)))!;
    final server = (await tester.runAsync(
      () => ShareServer.start(json, addresses: () async => ['127.0.0.1']),
    ))!;
    addTearDown(server.close);
    await pump(
      tester,
      ShareScreen(characterId: c.id, startServer: (_) async => server),
    );
    await waitFor(tester, find.byType(QrImageView));
    expect(find.text('Share Wanderer'), findsOneWidget);
    final got = await tester.runAsync(() => fetchShared(server.ticket));
    expect(decodeCharacterJson(got!).id, c.id);
    await waitFor(tester, find.text('Wanderer was sent.'));
    expect(find.text('Wanderer was sent.'), findsOneWidget);
  });
}
