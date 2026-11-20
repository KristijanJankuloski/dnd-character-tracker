import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/character_files.dart';
import '../../data/feat_library.dart';
import '../../data/spell_library.dart';
import '../../domain/feat_catalog.dart';
import '../../domain/repository.dart';
import '../../domain/spell_catalog.dart';
import '../../domain/sync.dart';
import 'character_list_cubit.dart';

class CharacterListScreen extends StatelessWidget {
  const CharacterListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => CharacterListCubit(ctx.read<CharacterRepository>()),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Characters'),
        actions: [
          if (context.read<SyncStore?>() != null)
            IconButton(
              tooltip: 'Sync with nearby devices',
              icon: const Icon(Icons.sync),
              onPressed: () => context.push('/sync'),
            ),
          IconButton(
            tooltip: 'Receive a character from another device',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => context.push('/receive'),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) {
              if (v == 'backup') _import(context);
              if (v == 'spells') _importSpells(context);
              if (v == 'catalogue') context.push('/spells');
              if (v == 'feats') _importFeats(context);
              if (v == 'featCatalogue') context.push('/feats');
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'backup',
                child: Text('Import character'),
              ),
              if (context.read<SpellLibrary?>() != null)
                PopupMenuItem(
                  value: 'spells',
                  child: Text(
                    spellCatalog.isEmpty
                        ? 'Import spells'
                        : 'Import spells (${spellCatalog.length} loaded)',
                  ),
                ),
              if (context.read<SpellLibrary?>() != null)
                const PopupMenuItem(
                  value: 'catalogue',
                  child: Text('Edit spell catalogue'),
                ),
              if (context.read<FeatLibrary?>() != null)
                PopupMenuItem(
                  value: 'feats',
                  child: Text(
                    featCatalog.isEmpty
                        ? 'Import feats'
                        : 'Import feats (${featCatalog.length} loaded)',
                  ),
                ),
              if (context.read<FeatLibrary?>() != null)
                const PopupMenuItem(
                  value: 'featCatalogue',
                  child: Text('Edit feat catalogue'),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Palette.crimson,
        foregroundColor: Palette.text,
        onPressed: () => context.push('/create'),
        icon: const Icon(Icons.add),
        label: const Text('New character'),
      ),
      body: BlocBuilder<CharacterListCubit, CharacterListState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null) {
            return Center(
              child: Text('Could not load characters: ${state.error}'),
            );
          }
          if (state.characters.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_stories,
                      size: 64,
                      color: Palette.gold,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No characters yet',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create one to start tracking HP, spell slots and your turn.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Palette.textDim),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.push('/create'),
                      child: const Text('Create a character'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              16 + MediaQuery.paddingOf(context).left,
              16,
              16 + MediaQuery.paddingOf(context).right,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            itemCount: state.characters.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final c = state.characters[i];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: WaxSeal(
                    initials: c.name.isEmpty ? '?' : c.name[0].toUpperCase(),
                    size: 54,
                  ),
                  title: Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      c.name,
                      style: displayStyle(size: 18, spacing: .4),
                    ),
                  ),
                  subtitle: Text(
                    '${c.race} · ${c.classLine}\nHP ${c.hpCurrent}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Share ${c.name}',
                    icon: const Icon(Icons.qr_code_2),
                    onPressed: () => context.push('/share/${c.id}'),
                  ),
                  onTap: () => context.go('/c/${c.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _import(BuildContext context) async {
    final cubit = context.read<CharacterListCubit>();
    final files = context.read<CharacterFiles>();
    final messenger = ScaffoldMessenger.of(context);
    String? text;
    try {
      text = await files.pick();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open that file.')),
      );
      return;
    }
    if (text == null) return; // cancelled
    try {
      final c = await cubit.import(text);
      messenger.showSnackBar(SnackBar(content: Text('Imported ${c.name}.')));
    } on FormatException catch (e) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Character file not imported'),
          content: SingleChildScrollView(
            child: Text('${e.message}\n\nNo character was added.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save the character.')),
      );
    }
  }

  Future<void> _importSpells(BuildContext context) async {
    final lib = context.read<SpellLibrary?>()!;
    final messenger = ScaffoldMessenger.of(context);
    String? text;
    try {
      text = await lib.pick();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open that file.')),
      );
      return;
    }
    if (text == null) return; // cancelled
    try {
      final n = await lib.import(text);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Imported $n ${n == 1 ? 'spell' : 'spells'}. '
            'They replace the previous list.',
          ),
        ),
      );
    } on SpellImportException catch (e) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Spell file not imported'),
          content: SingleChildScrollView(
            child: Text(
              [
                ...e.problems.take(10),
                if (e.problems.length > 10)
                  '…and ${e.problems.length - 10} more.',
                '',
                'Your previous spell list is unchanged.',
              ].join('\n'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save the spell list.')),
      );
    }
  }

  Future<void> _importFeats(BuildContext context) async {
    final lib = context.read<FeatLibrary?>()!;
    final messenger = ScaffoldMessenger.of(context);
    String? text;
    try {
      text = await lib.pick();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open that file.')),
      );
      return;
    }
    if (text == null) return; // cancelled
    try {
      final n = await lib.import(text);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Imported $n ${n == 1 ? 'feat' : 'feats'}. '
            'They replace the previous list.',
          ),
        ),
      );
    } on FeatImportException catch (e) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Feat file not imported'),
          content: SingleChildScrollView(
            child: Text(
              [
                ...e.problems.take(10),
                if (e.problems.length > 10)
                  '…and ${e.problems.length - 10} more.',
                '',
                'Your previous feat list is unchanged.',
              ].join('\n'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save the feat list.')),
      );
    }
  }
}
