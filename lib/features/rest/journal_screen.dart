import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/actions.dart' as act;
import '../../domain/repository.dart';
import '../character/character_bloc.dart';
import '../character/character_event.dart';
import '../character/loaded_builder.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LoadedBuilder(
      builder: (context, s) {
        final c = s.character;
        final bloc = context.read<CharacterBloc>();
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Panel(
              title: 'Rest',
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _rest(context, s, longRest: false),
                      icon: const Icon(Icons.coffee),
                      label: const Text('Short rest'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _rest(context, s, longRest: true),
                      icon: const Icon(Icons.bedtime),
                      label: const Text('Long rest'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Panel(
              title: 'Notes',
              parchment: true,
              child: _NotesField(
                initial: c.notes,
                onChanged: (v) => bloc.add(NotesChanged(v)),
              ),
            ),
            const SizedBox(height: 12),
            Panel(
              title: 'Character settings',
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mage Armor active'),
                    subtitle: const Text('AC 13 + DEX when unarmored'),
                    value: c.flags.contains('mageArmor'),
                    onChanged: (v) => bloc.add(FlagSet('mageArmor', v)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Draconic Resilience'),
                    subtitle: const Text('AC 13 + DEX when unarmored'),
                    value: c.flags.contains('draconicResilience'),
                    onChanged: (v) =>
                        bloc.add(FlagSet('draconicResilience', v)),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.copy),
                    title: const Text('Copy backup JSON'),
                    onTap: () async {
                      final repo = context.read<CharacterRepository>();
                      final json = await repo.exportJson(c.id);
                      await Clipboard.setData(ClipboardData(text: json));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Backup copied to the clipboard.'),
                          ),
                        );
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.delete_outline,
                      color: Palette.crimsonHi,
                    ),
                    title: const Text('Delete character'),
                    onTap: () async {
                      final repo = context.read<CharacterRepository>();
                      final router = GoRouter.of(context);
                      if (await confirm(
                        context,
                        'Delete ${c.name} and its history? This cannot be undone.',
                        yes: 'Delete',
                      )) {
                        router.go('/');
                        await repo.delete(c.id);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _LogPanel(characterId: c.id),
          ],
        );
      },
    );
  }

  Future<void> _rest(
    BuildContext context,
    CharacterLoaded s, {
    required bool longRest,
  }) async {
    final bloc = context.read<CharacterBloc>();
    final lines = act.restPreview(s.character, longRest: longRest);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(longRest ? 'Take a long rest?' : 'Take a short rest?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will restore:'),
            const SizedBox(height: 6),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• $l'),
              ),
            if (lines.isEmpty) const Text('Nothing needs restoring.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rest'),
          ),
        ],
      ),
    );
    if (ok == true) bloc.add(RestTaken(longRest: longRest));
  }
}

class _NotesField extends StatefulWidget {
  const _NotesField({required this.initial, required this.onChanged});
  final String initial;
  final ValueChanged<String> onChanged;
  @override
  State<_NotesField> createState() => _NotesFieldState();
}

class _NotesFieldState extends State<_NotesField> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial,
  );
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    // Flush pending edits.
    if (_c.text != widget.initial) widget.onChanged(_c.text);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      minLines: 5,
      maxLines: 12,
      style: const TextStyle(color: Palette.ink),
      decoration: const InputDecoration(
        hintText: 'Quests, NPCs, loot...',
        hintStyle: TextStyle(color: Palette.goldDim),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
      onChanged: (v) {
        _debounce?.cancel();
        _debounce = Timer(
          const Duration(milliseconds: 600),
          () => widget.onChanged(v),
        );
      },
    );
  }
}

class _LogPanel extends StatelessWidget {
  const _LogPanel({required this.characterId});
  final String characterId;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CharacterRepository>();
    return Panel(
      title: 'Event log',
      child: StreamBuilder<List<LogEntry>>(
        stream: repo.watchLog(characterId),
        builder: (context, snap) {
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return const Text(
              'Nothing yet.',
              style: TextStyle(color: Palette.textDim),
            );
          }
          final firstUndoable = list.where((e) => e.undoable).firstOrNull;
          return Column(
            children: [
              if (firstUndoable != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => context.read<CharacterBloc>().add(
                      const UndoRequested(),
                    ),
                    icon: const Icon(Icons.undo),
                    label: Text(
                      'Undo: ${firstUndoable.description}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              for (final e in list.take(50))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    e.description,
                    style: TextStyle(
                      color: e.type == 'undo' ? Palette.textDim : Palette.text,
                    ),
                  ),
                  trailing: Text(
                    '${e.createdAt.hour.toString().padLeft(2, '0')}:${e.createdAt.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Palette.textDim),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
