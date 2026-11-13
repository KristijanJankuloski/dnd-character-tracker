import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/character_factory.dart';
import '../../domain/models.dart';
import '../../domain/srd_data.dart';
import 'spell_detail_sheet.dart';

const _attribution =
    'Spell data: SRD 5.1 © Wizards of the Coast, CC-BY-4.0';

/// Bottom sheet for choosing a spell to add: the SRD encyclopedia with search
/// and level filters, plus a hand-made custom spell. Pops the chosen [Spell].
class SpellPicker extends StatefulWidget {
  const SpellPicker({super.key});
  @override
  State<SpellPicker> createState() => _SpellPickerState();
}

class _SpellPickerState extends State<SpellPicker> {
  String _q = '';
  int? _level; // null = all levels, 0 = cantrips

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = srdSpells
        .where(
          (s) =>
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
                hintText: 'Search SRD spells',
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
                    leading: const Icon(Icons.edit),
                    title: const Text('Create a custom spell'),
                    onTap: () async {
                      final sp = await _custom(context);
                      if (sp != null && context.mounted) {
                        Navigator.pop(context, sp);
                      }
                    },
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
                  title: Text(s.name),
                  subtitle: Text(
                    [
                      s.level == 0 ? 'Cantrip' : 'Level ${s.level}',
                      if (s.school.isNotEmpty) s.school,
                      spellCastingLabel(s),
                      if (s.range.isNotEmpty) s.range,
                    ].join(' · '),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              _attribution,
              style: TextStyle(fontSize: 11, color: Palette.textDim),
            ),
          ),
        ],
      ),
    );
  }

  Future<Spell?> _custom(BuildContext context) {
    final name = TextEditingController();
    var level = 1;
    var time = CastingTime.action;
    var conc = false;
    var ritual = false;
    final range = TextEditingController();
    final damageType = TextEditingController();
    var shape = AreaShape.none;
    final areaSize = TextEditingController();
    final desc = TextEditingController();
    return showDialog<Spell>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Custom spell'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: level,
                  decoration: const InputDecoration(labelText: 'Level'),
                  items: [
                    for (var i = 0; i <= 9; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(i == 0 ? 'Cantrip' : 'Level $i'),
                      ),
                  ],
                  onChanged: (v) => set(() => level = v ?? 1),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<CastingTime>(
                  initialValue: time,
                  decoration: const InputDecoration(labelText: 'Casting time'),
                  items: [
                    for (final t in CastingTime.values)
                      DropdownMenuItem(value: t, child: Text(castingLabel(t))),
                  ],
                  onChanged: (v) => set(() => time = v ?? CastingTime.action),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: range,
                  decoration: InputDecoration(
                    labelText: 'Range',
                    hintText: 'Self, Touch, 30 ft...',
                    suffixIcon: PopupMenuButton<String>(
                      icon: const Icon(Icons.arrow_drop_down),
                      onSelected: (v) => range.text = v,
                      itemBuilder: (_) => [
                        for (final r in const [
                          'Self',
                          'Touch',
                          '30 ft',
                          '60 ft',
                          '120 ft',
                        ])
                          PopupMenuItem(value: r, child: Text(r)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: damageType,
                  decoration: const InputDecoration(
                    labelText: 'Damage type',
                    hintText: 'fire, cold, none...',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<AreaShape>(
                  initialValue: shape,
                  decoration: const InputDecoration(labelText: 'Area / target'),
                  items: [
                    for (final a in AreaShape.values)
                      DropdownMenuItem(value: a, child: Text(a.label)),
                  ],
                  onChanged: (v) => set(() => shape = v ?? AreaShape.none),
                ),
                if (shape != AreaShape.none &&
                    shape != AreaShape.singleTarget) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: areaSize,
                    decoration: const InputDecoration(
                      labelText: 'Size (optional)',
                      hintText: '20 ft',
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: desc,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Short description',
                  ),
                ),
                CheckboxListTile(
                  value: conc,
                  onChanged: (v) => set(() => conc = v ?? false),
                  title: const Text('Concentration'),
                  dense: true,
                ),
                CheckboxListTile(
                  value: ritual,
                  onChanged: (v) => set(() => ritual = v ?? false),
                  title: const Text('Ritual'),
                  dense: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(
                  ctx,
                  Spell(
                    id: newId('spell'),
                    name: name.text.trim(),
                    level: level,
                    castingTime: time,
                    concentration: conc,
                    ritual: ritual,
                    range: range.text.trim(),
                    damageType: damageType.text.trim(),
                    areaShape: shape,
                    areaSize:
                        shape == AreaShape.none ||
                            shape == AreaShape.singleTarget
                        ? ''
                        : areaSize.text.trim(),
                    text: desc.text.trim(),
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
