import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../data/nearby_discovery.dart';
import '../domain/repository.dart';
import '../domain/sync.dart';
import '../features/character/character_page.dart';
import '../features/list/character_list_screen.dart';
import '../features/list/create_character_screen.dart';
import '../features/share/receive_screen.dart';
import '../features/share/share_screen.dart';
import '../features/sync/sync_screen.dart';
import 'theme.dart';

GoRouter buildRouter({PeerDiscovery Function()? discoveryFactory}) => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const CharacterListScreen()),
    GoRoute(path: '/create', builder: (_, _) => const CreateCharacterScreen()),
    GoRoute(
      path: '/sync',
      builder: (_, _) => SyncScreen(discoveryFactory: discoveryFactory),
    ),
    GoRoute(path: '/receive', builder: (_, _) => const ReceiveScreen()),
    GoRoute(
      path: '/share/:id',
      builder: (_, state) =>
          ShareScreen(characterId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/c/:id',
      builder: (_, state) =>
          CharacterPage(characterId: state.pathParameters['id']!),
    ),
  ],
);

class DnDApp extends StatefulWidget {
  const DnDApp({
    super.key,
    required this.repository,
    this.syncStore,
    this.discoveryFactory,
  });
  final CharacterRepository repository;

  /// Enables syncing with nearby devices when given.
  final SyncStore? syncStore;

  /// Replaceable in tests.
  final PeerDiscovery Function()? discoveryFactory;

  @override
  State<DnDApp> createState() => _DnDAppState();
}

class _DnDAppState extends State<DnDApp> {
  late final GoRouter _router = buildRouter(
    discoveryFactory: widget.discoveryFactory,
  );

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<CharacterRepository>.value(
      value: widget.repository,
      child: RepositoryProvider<SyncStore?>.value(
        value: widget.syncStore,
        child: MaterialApp.router(
          title: 'JJs Character Tracker',
          theme: buildTheme(),
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
