import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../domain/repository.dart';
import '../features/character/character_page.dart';
import '../features/list/character_list_screen.dart';
import '../features/list/create_character_screen.dart';
import 'theme.dart';

GoRouter buildRouter() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const CharacterListScreen()),
    GoRoute(path: '/create', builder: (_, _) => const CreateCharacterScreen()),
    GoRoute(
      path: '/c/:id',
      builder: (_, state) =>
          CharacterPage(characterId: state.pathParameters['id']!),
    ),
  ],
);

class DnDApp extends StatefulWidget {
  const DnDApp({super.key, required this.repository});
  final CharacterRepository repository;

  @override
  State<DnDApp> createState() => _DnDAppState();
}

class _DnDAppState extends State<DnDApp> {
  late final GoRouter _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<CharacterRepository>.value(
      value: widget.repository,
      child: MaterialApp.router(
        title: 'D&D Character Tracker',
        theme: buildTheme(),
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
