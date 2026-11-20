import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme.dart';
import '../../data/character_files.dart';
import '../../data/feat_library.dart';
import '../../domain/feat_catalog.dart';
import '../../domain/models.dart';
import 'feat_editor.dart';

/// Lists every feat in the catalogue (the list the feat picker offers) and
/// lets the user add, edit, delete and export them. Every change is saved
/// straight away. Feats a character has already taken are copies, so they are
/// never touched here.
class FeatCatalogueScreen extends StatefulWidget {
  const FeatCatalogueScreen({super.key});

  @override
  State<FeatCatalogueScreen> createState() => _FeatCatalogueScreenState();
}

class _FeatCatalogueScreenState extends State<FeatCatalogueScreen> {
  String _q = '';

  FeatLibrary get _lib => context.read<FeatLibrary?>()!;

  static String _key(String name) => name.trim().toLowerCase();

  /// Rejects a name another catalogue feat already uses (ignoring case).
  String? _nameError(String name, {String? exceptId}) {
    final k = _key(name);
    final taken = featCatalog.any((f) => f.id != exceptId && _key(f.name) == k);
    return taken ? 'The catalogue already has a feat with this name' : null;
  }

  Future<void> _persist(List<Feat> next, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _lib.save(next);
      if (mounted) setState(() {});
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save the feat list.')),
      );
    }
  }

  Future<void> _add() async {
    final r = await showFeatEditor(context, nameError: _nameError);
    final f = r?.feat;
    if (f == null || !mounted) return;
    await _persist([...featCatalog, f], 'Added ${f.name}.');
  }

  Future<void> _edit(Feat old) async {
    final r = await showFeatEditor(
      context,
      initial: old,
      // An imported file may already hold two feats with one name; keeping the
      // name you have is always fine, only a rename must be free.
      nameError: (n) =>
          _key(n) == _key(old.name) ? null : _nameError(n, exceptId: old.id),
    );
    if (r == null || !mounted) return;
    if (r.delete) {
      await _persist([
        for (final x in featCatalog)
          if (x.id != old.id) x,
      ], 'Deleted ${old.name}.');
      return;
    }
    final f = r.feat!;
    await _persist([
      for (final x in featCatalog) x.id == old.id ? f : x,
    ], 'Saved ${f.name}.');
  }

  Future<void> _export() async {
    final files = context.read<CharacterFiles>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await files.save('feat-catalogue', await _lib.exportJson());
      if (saved) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Exported the feat catalogue.')),
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
    final all = featCatalog;
    final q = _q.trim().toLowerCase();
    final list = all.where((f) => f.name.toLowerCase().contains(q)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feat catalogue'),
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
        label: const Text('Add feat'),
      ),
      body: SafeArea(
        bottom: false,
        child: all.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'The catalogue is empty. Add a feat, or import a list '
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
                        hintText: 'Search feats',
                      ),
                      onChanged: (v) => setState(() => _q = v),
                    ),
                  ),
                  Expanded(
                    child: list.isEmpty
                        ? const Center(
                            child: Text(
                              'No feats match',
                              style: TextStyle(color: Palette.textDim),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.only(bottom: 88 + pad.bottom),
                            itemCount: list.length,
                            itemBuilder: (ctx, i) {
                              final f = list[i];
                              return ListTile(
                                title: Text(f.name),
                                subtitle: f.prerequisite.isEmpty
                                    ? null
                                    : Text(f.prerequisite),
                                onTap: () => _edit(f),
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
