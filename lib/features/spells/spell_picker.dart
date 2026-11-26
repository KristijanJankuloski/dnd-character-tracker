import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../domain/srd_data.dart';
import 'custom_spell_page.dart';
import 'spell_detail_sheet.dart';

/// Bottom sheet for choosing a spell to add: the imported spell list with search
/// and level filters, plus a hand-made custom spell. Pops the chosen [Spell].
class SpellPicker extends StatefulWidget {
  const SpellPicker({super.key, this.classes = const []});

  /// The character's class names. Only spells open to one of them are offered
  /// (spells with no class list are open to all). Empty offers every spell.
  final List<String> classes;

  @override
  State<SpellPicker> createState() => _SpellPickerState();
}

class _SpellPickerState extends State<SpellPicker> {
  String _q = '';
  int? _level; // null = all levels, 0 = cantrips

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = spellCatalog
        .where(
          (s) =>
              (widget.classes.isEmpty || s.availableTo(widget.classes)) &&
              (_level == null || s.level == _level) &&
              s.name.toLowerCase().contains(q),
        )
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
                hintText: 'Search spells',
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final (label, level) in <(String, int?)>[
                  ('All', null),
                  ('Cantrip', 0),
                  for (var i = 1; i <= 9; i++) ('$i', i),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _level == level,
                      onSelected: (_) => setState(() => _level = level),
                    ),
                  ),
              ],
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
                    title: const Text('Create a custom spell'),
                    onTap: () async {
                      final sp = await CustomSpellPage.open(
                        context,
                        // A new spell is for the character's class (the main
                        // one for a multiclass character; it can be changed).
                        initialClasses: widget.classes.isEmpty
                            ? const []
                            : [widget.classes.first],
                      );
                      if (sp != null && context.mounted) {
                        Navigator.pop(context, sp);
                      }
                    },
                  );
                }
                if (spellCatalog.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No spells imported yet. On the Characters screen, '
                        'open the menu and choose Import spells.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Palette.textDim),
                      ),
                    ),
                  );
                }
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No spells match',
                        style: TextStyle(color: Palette.textDim),
                      ),
                    ),
                  );
                }
                final s = list[i - 1];
                return ListTile(
                  // A hairline between entries, as in an index.
                  shape: const Border(
                    top: BorderSide(color: Color(0x408A6D2F)),
                  ),
                  title: Text(
                    s.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    [
                      s.level == 0 ? 'Cantrip' : 'Level ${s.level}',
                      if (s.school.isNotEmpty) s.school,
                      spellCastingLabel(s),
                      if (s.range.isNotEmpty) s.range,
                    ].join(' · '),
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s.concentration)
                        const Icon(
                          Icons.psychology,
                          size: 18,
                          color: Palette.arcane,
                          semanticLabel: 'Concentration',
                        ),
                      if (s.ritual)
                        const Icon(
                          Icons.history_edu,
                          size: 18,
                          color: Palette.gold,
                          semanticLabel: 'Ritual',
                        ),
                    ],
                  ),
                  onTap: () async {
                    final add = await showSpellDetailSheet(
                      context,
                      s,
                      canAdd: true,
                    );
                    if (add == true && context.mounted) {
                      Navigator.pop(context, s);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
