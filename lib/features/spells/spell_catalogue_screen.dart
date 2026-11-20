import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme.dart';
import '../../data/character_files.dart';
import '../../data/spell_library.dart';
import '../../domain/models.dart';
import '../../domain/spell_catalog.dart';
import 'custom_spell_page.dart';

/// Lists every spell in the catalogue (the list that feeds spell suggestions)
/// and lets the user add, edit, delete and export them. Every change is saved
/// straight away and applies to suggestions for all characters. Spells a
/// character has already learned are copies, so they are never touched here.
class SpellCatalogueScreen extends StatefulWidget {
  const SpellCatalogueScreen({super.key});

  @override
  State<SpellCatalogueScreen> createState() => _SpellCatalogueScreenState();
}

class _SpellCatalogueScreenState extends State<SpellCatalogueScreen> {
  String _q = '';
  int? _level; // null = all levels, 0 = cantrips

  SpellLibrary get _lib => context.read<SpellLibrary?>()!;

  static String _key(String name) => name.trim().toLowerCase();

  /// Rejects a name another catalogue spell already uses (ignoring case).
  String? _nameError(String name, {String? exceptId}) {
    final k = _key(name);
    final taken = spellCatalog.any(
      (s) => s.id != exceptId && _key(s.name) == k,
    );
    return taken ? 'The catalogue already has a spell with this name' : null;
  }

  Future<void> _persist(List<Spell> next, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _lib.save(next);
      if (mounted) setState(() {});
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save the spell list.')),
      );
    }
  }

  Future<void> _add() async {
    final sp = await CustomSpellPage.open(context, nameError: _nameError);
    if (sp == null || !mounted) return;
    await _persist([...spellCatalog, sp], 'Added ${sp.name}.');
  }

  Future<void> _edit(Spell old) async {
    final sp = await CustomSpellPage.open(
      context,
      initial: old,
      nameError: (n) => _nameError(n, exceptId: old.id),
    );
    if (sp == null || !mounted) return;
    await _persist([
      for (final s in spellCatalog) s.id == old.id ? sp : s,
    ], 'Saved ${sp.name}.');
  }

  Future<void> _delete(Spell s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${s.name}?'),
        content: const Text(
          'It is removed from the catalogue and from spell suggestions. '
          'Characters that already know it keep it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _persist([
      for (final x in spellCatalog)
        if (x.id != s.id) x,
    ], 'Deleted ${s.name}.');
  }

  Future<void> _export() async {
    final files = context.read<CharacterFiles>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await files.save(
        'spell-catalogue',
        await _lib.exportJson(),
      );
      if (saved) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Exported the spell catalogue.')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save the file.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = spellCatalog;
    final q = _q.trim().toLowerCase();
    final list =
        all
            .where(
              (s) =>
                  (_level == null || s.level == _level) &&
                  s.name.toLowerCase().contains(q),
            )
            .toList()
          ..sort((a, b) {
            final c = a.level.compareTo(b.level);
            return c != 0
                ? c
                : a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spell catalogue'),
        actions: [
          IconButton(
            tooltip: 'Export catalogue',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: all.isEmpty ? null : _export,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Palette.crimson,
        foregroundColor: Palette.text,
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add spell'),
      ),
      body: SafeArea(
        bottom: false,
        child: all.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'The catalogue is empty. Add a spell, or import a list '
                    'from the Characters menu.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Palette.textDim),
                  ),
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search spells',
                      ),
                      onChanged: (v) => setState(() => _q = v),
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final level in <int?>[
                          null,
                          for (var i = 0; i <= 9; i++) i,
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                level == null
                                    ? 'All'
                                    : level == 0
                                    ? 'Cantrip'
                                    : 'Lv $level',
                              ),
                              selected: _level == level,
                              onSelected: (_) => setState(() => _level = level),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: list.isEmpty
                        ? const Center(
                            child: Text(
                              'No spells match',
                              style: TextStyle(color: Palette.textDim),
                            ),
                          )
                        : ListView.builder(
                            // Room for the button, and for the gesture bar.
                            padding: EdgeInsets.only(
                              bottom: 88 + pad.bottom,
                              left: pad.left,
                              right: pad.right,
                            ),
                            itemCount: list.length,
                            itemBuilder: (ctx, i) {
                              final s = list[i];
                              return ListTile(
                                title: Text(s.name),
                                subtitle: Text(
                                  [
                                    s.level == 0
                                        ? 'Cantrip'
                                        : 'Level ${s.level}',
                                    if (s.school.isNotEmpty) s.school,
                                  ].join(' · '),
                                ),
                                trailing: IconButton(
                                  tooltip: 'Delete ${s.name}',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _delete(s),
                                ),
                                onTap: () => _edit(s),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
