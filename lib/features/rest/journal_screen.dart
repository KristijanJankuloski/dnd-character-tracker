import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/character_files.dart';
import '../../domain/actions.dart' as act;
import '../../domain/class_templates.dart';
import '../../domain/rules.dart';
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
              title: 'Level ${c.level}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.classLine,
                    style: const TextStyle(color: Palette.textDim),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: c.level >= 20
                        ? null
                        : () => _levelUp(context, s),
                    icon: const Icon(Icons.arrow_upward),
                    label: const Text('Level up'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _adjustLevels(context, s),
                    icon: const Icon(Icons.swap_vert),
                    label: const Text('Adjust levels'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
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
                    leading: const Icon(Icons.qr_code_2),
                    title: const Text('Share with another device'),
                    subtitle: const Text('Show a QR code to scan'),
                    onTap: () => context.push('/share/${c.id}'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.file_download_outlined),
                    title: const Text('Export character'),
                    subtitle: const Text('Save as a .json file'),
                    onTap: () async {
                      final repo = context.read<CharacterRepository>();
                      final files = context.read<CharacterFiles>();
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final json = await repo.exportJson(c.id);
                        final saved = await files.save(
                          CharacterFiles.fileNameFor(c.name),
                          json,
                        );
                        if (saved) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Exported ${c.name}.')),
                          );
                        }
                      } catch (_) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Could not save the file.'),
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

  Future<void> _levelUp(BuildContext context, CharacterLoaded s) async {
    final bloc = context.read<CharacterBloc>();
    var className = s.character.primaryClass.className;
    final subclass = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Level up'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: className,
                decoration: const InputDecoration(
                  labelText: 'Gain a level in',
                  helperText: 'Pick another class to multiclass',
                ),
                items: [
                  for (final n in classTemplates.keys)
                    DropdownMenuItem(value: n, child: Text(n)),
                ],
                onChanged: (v) => set(() => className = v ?? className),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: subclass,
                decoration: const InputDecoration(
                  labelText: 'Subclass (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Level up'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      bloc.add(LeveledUp(className, subclass: subclass.text.trim()));
    }
  }

  Future<void> _adjustLevels(BuildContext context, CharacterLoaded s) async {
    final bloc = context.read<CharacterBloc>();
    final original = s.character;
    final levels = <String, int>{
      for (final cl in original.classes) cl.className: cl.level,
    };
    String? toAdd;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final changes = {
            for (final e in levels.entries)
              if (e.value !=
                  (original.classes
                          .where((x) => x.className == e.key)
                          .firstOrNull
                          ?.level ??
                      0))
                e.key: e.value,
          };
          final preview = changes.isEmpty
              ? null
              : act.adjustLevels(original, changes);
          final total = levels.values.fold(0, (a, b) => a + b);
          final available = [
            for (final n in classTemplates.keys)
              if (!levels.containsKey(n)) n,
          ];
          return AlertDialog(
            title: const Text('Adjust levels'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in levels.entries)
                    Row(
                      children: [
                        Expanded(child: Text(e.key)),
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: e.value > 0 && total > 1
                              ? () => set(() => levels[e.key] = e.value - 1)
                              : null,
                        ),
                        SizedBox(
                          width: 28,
                          child: Text('${e.value}', textAlign: TextAlign.center),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: total < 20
                              ? () => set(() => levels[e.key] = e.value + 1)
                              : null,
                        ),
                      ],
                    ),
                  if (available.isNotEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: toAdd,
                            decoration: const InputDecoration(
                              labelText: 'Add class',
                            ),
                            items: [
                              for (final n in available)
                                DropdownMenuItem(value: n, child: Text(n)),
                            ],
                            onChanged: (v) => set(() {
                              if (v != null) {
                                levels[v] = 1;
                                toAdd = null;
                              }
                            }),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Text('Total level: $total (was ${original.level})'),
                  if (preview != null && !preview.blocked) ...[
                    Text(
                      'Max HP: ${resolveStats(original).maxHp} to ${resolveStats(preview.character).maxHp}',
                    ),
                    Text(preview.character.classLine),
                    for (final w in preview.warnings)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          w,
                          style: const TextStyle(color: Palette.textDim),
                        ),
                      ),
                  ],
                  if (preview != null && preview.blocked)
                    Text(preview.description),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: preview == null || preview.blocked
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
    if (ok == true) {
      bloc.add(
        LevelsAdjusted({
          for (final e in levels.entries)
            if (e.value !=
                (original.classes
                        .where((x) => x.className == e.key)
                        .firstOrNull
                        ?.level ??
                    0))
              e.key: e.value,
        }),
      );
    }
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
              for (final e in list.take(20))
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
