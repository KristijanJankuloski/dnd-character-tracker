import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../domain/repository.dart';
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
          IconButton(
            tooltip: 'Receive a character from another device',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => context.push('/receive'),
          ),
          IconButton(
            tooltip: 'Import backup from clipboard',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => _import(context),
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
            padding: const EdgeInsets.all(16),
            itemCount: state.characters.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final c = state.characters[i];
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Palette.goldDim, width: 1.5),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: Palette.crimson,
                    child: Text(
                      c.name.isEmpty ? '?' : c.name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  title: Text(
                    c.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
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
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (text == null || text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('The clipboard is empty. Copy a backup first.'),
        ),
      );
      return;
    }
    try {
      final c = await cubit.import(text);
      messenger.showSnackBar(SnackBar(content: Text('Imported ${c.name}.')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('That does not look like a character backup.')),
      );
    }
  }
}
