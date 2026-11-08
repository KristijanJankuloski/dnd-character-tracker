import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../domain/repository.dart';
import '../inventory/inventory_screen.dart';
import '../overview/combat_screen.dart';
import '../overview/compact_view.dart';
import '../overview/overview_screen.dart';
import '../rest/journal_screen.dart';
import '../spells/spells_screen.dart';
import 'character_bloc.dart';
import 'character_event.dart';
import 'loaded_builder.dart';

class CharacterPage extends StatelessWidget {
  const CharacterPage({super.key, required this.characterId});
  final String characterId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => CharacterBloc(
        repository: ctx.read<CharacterRepository>(),
        characterId: characterId,
      ),
      child: const _Shell(),
    );
  }
}

class _Tab {
  const _Tab(this.label, this.icon);
  final String label;
  final IconData icon;
}

const _tabs = [
  _Tab('Sheet', Icons.shield_outlined),
  _Tab('Combat', Icons.gavel),
  _Tab('Spells', Icons.auto_awesome),
  _Tab('Items', Icons.backpack_outlined),
  _Tab('Journal', Icons.menu_book_outlined),
];

class _Shell extends StatefulWidget {
  const _Shell();
  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _index = 0;

  void _onNotice(BuildContext context, CharacterState state) {
    if (state is! CharacterLoaded || state.notice == null) return;
    final n = state.notice!;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(n.message),
        duration: Duration(seconds: n.warning ? 8 : 5),
        backgroundColor: n.warning ? const Color(0xFF4A3410) : Palette.panelHi,
        behavior: SnackBarBehavior.floating,
        action: n.undoable
            ? SnackBarAction(
                label: 'Undo',
                textColor: Palette.gold,
                onPressed: () =>
                    context.read<CharacterBloc>().add(const UndoRequested()),
              )
            : null,
      ),
    );
  }

  Widget _body(bool tablet, CharacterLoaded s) {
    final screens = <Widget>[
      OverviewScreen(tablet: tablet),
      CombatScreen(tablet: tablet),
      SpellsScreen(tablet: tablet),
      InventoryScreen(tablet: tablet),
      const JournalScreen(),
    ];
    return IndexedStack(index: _index, children: screens);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CharacterBloc, CharacterState>(
      listenWhen: (p, n) =>
          n is CharacterLoaded &&
          n.notice != null &&
          (p is! CharacterLoaded || p.notice != n.notice),
      listener: _onNotice,
      builder: (context, state) {
        if (state is CharacterLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state is CharacterMissing) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('This character no longer exists.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Back to characters'),
                  ),
                ],
              ),
            ),
          );
        }
        if (state is CharacterFailure) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Something went wrong: ${state.message}'),
              ),
            ),
          );
        }
        final loaded = state as CharacterLoaded;
        return LayoutBuilder(
          builder: (context, c) {
            final tablet = c.maxWidth >= 840;
            if (tablet) {
              return Scaffold(
                body: SafeArea(
                  child: Row(
                    children: [
                      NavigationRail(
                        selectedIndex: _index,
                        onDestinationSelected: (i) =>
                            setState(() => _index = i),
                        labelType: NavigationRailLabelType.all,
                        leading: IconButton(
                          tooltip: 'All characters',
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => context.go('/'),
                        ),
                        destinations: [
                          for (final t in _tabs)
                            NavigationRailDestination(
                              icon: Icon(t.icon),
                              label: Text(t.label),
                            ),
                        ],
                      ),
                      Expanded(child: _body(true, loaded)),
                      if (loaded.character.compactMode && _index != 0)
                        const SizedBox(
                          width: 300,
                          child: CompactView(embedded: true),
                        ),
                    ],
                  ),
                ),
              );
            }
            return Scaffold(
              body: SafeArea(bottom: false, child: _body(false, loaded)),
              bottomNavigationBar: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                destinations: [
                  for (final t in _tabs)
                    NavigationDestination(icon: Icon(t.icon), label: t.label),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Small helper so tabs can share the loaded state.
class WithCharacter extends StatelessWidget {
  const WithCharacter({super.key, required this.builder});
  final Widget Function(BuildContext, CharacterLoaded) builder;
  @override
  Widget build(BuildContext context) => LoadedBuilder(builder: builder);
}
