import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/feat_catalog.dart';
import '../../domain/models.dart';
import 'feat_editor.dart';

/// Bottom sheet for choosing a feat to add: the imported feat list with
/// search, plus a hand-made custom feat. Pops the chosen [Feat]. Feats the
/// character already has ([taken], by name) are marked and cannot be added.
class FeatPicker extends StatefulWidget {
  const FeatPicker({super.key, this.taken = const {}});

  /// Lower-case names of the feats the character already has.
  final Set<String> taken;

  @override
  State<FeatPicker> createState() => _FeatPickerState();
}

class _FeatPickerState extends State<FeatPicker> {
  String _q = '';

  Future<void> _preview(Feat f, bool have) async {
    final add = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(f.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (f.prerequisite.isNotEmpty)
                Text(
                  'Prerequisite: ${f.prerequisite}',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              if (f.source.isNotEmpty)
                Text(f.source, style: const TextStyle(color: Palette.textDim)),
              if (f.prerequisite.isNotEmpty || f.source.isNotEmpty)
                const SizedBox(height: 8),
              Text(f.text.isEmpty ? 'No description.' : f.text),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Close'),
          ),
          if (!have)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add'),
            ),
        ],
      ),
    );
    if (add == true && mounted) Navigator.pop(context, f);
  }

  Future<void> _custom() async {
    final result = await showFeatEditor(
      context,
      nameError: (n) => widget.taken.contains(n.trim().toLowerCase())
          ? 'This character already has a feat with this name'
          : null,
    );
    final f = result?.feat;
    if (f != null && mounted) Navigator.pop(context, f);
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = featCatalog
        .where((f) => f.name.toLowerCase().contains(q))
        .toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      builder: (ctx, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search feats',
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: 1 + (list.isEmpty ? 1 : list.length),
              itemBuilder: (ctx, i) {
                if (i == 0) {
                  return ListTile(
                    leading: const Icon(Icons.edit, color: Palette.gold),
                    title: const Text('Create a custom feat'),
                    onTap: _custom,
                  );
                }
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        featCatalog.isEmpty
                            ? 'No feats imported yet. On the Characters '
                                  'screen, open the menu and choose Import '
                                  'feats.'
                            : 'No feats match',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Palette.textDim),
                      ),
                    ),
                  );
                }
                final f = list[i - 1];
                final have = widget.taken.contains(f.name.trim().toLowerCase());
                return ListTile(
                  shape: const Border(
                    top: BorderSide(color: Color(0x408A6D2F)),
                  ),
                  title: Text(
                    f.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: f.prerequisite.isEmpty
                      ? null
                      : Text(
                          f.prerequisite,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                  trailing: have
                      ? const Icon(
                          Icons.check,
                          color: Palette.gold,
                          semanticLabel: 'Already added',
                        )
                      : null,
                  onTap: () => _preview(f, have),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
