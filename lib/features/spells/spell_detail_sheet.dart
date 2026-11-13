import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/models.dart';

String castingLabel(CastingTime t) => switch (t) {
  CastingTime.action => 'Action',
  CastingTime.bonusAction => 'Bonus Action',
  CastingTime.reaction => 'Reaction',
  CastingTime.other => 'Longer',
};

/// Short casting time for list rows: the written text up to the first comma
/// ("1 reaction, which you take when..." becomes "1 reaction"), or the enum
/// label for custom spells and older saves that have no written text.
String spellCastingLabel(Spell s) => s.castingTimeText.isEmpty
    ? castingLabel(s.castingTime)
    : s.castingTimeText.split(',').first.trim();

/// Opens the spell's details in a draggable bottom sheet. Completes with true
/// when "Add to character" is pressed (only offered when [canAdd]), otherwise
/// null.
Future<bool?> showSpellDetailSheet(
  BuildContext context,
  Spell spell, {
  required bool canAdd,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  builder: (ctx) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.75,
    minChildSize: 0.4,
    maxChildSize: 0.95,
    builder: (ctx, scroll) =>
        _SpellDetail(spell: spell, canAdd: canAdd, scroll: scroll),
  ),
);

class _SpellDetail extends StatelessWidget {
  const _SpellDetail({
    required this.spell,
    required this.canAdd,
    required this.scroll,
  });
  final Spell spell;
  final bool canAdd;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final s = spell;
    final theme = Theme.of(context).textTheme;
    final subtitle = [
      s.level == 0 ? 'Cantrip' : 'Level ${s.level}',
      if (s.school.isNotEmpty) s.school,
    ].join(' · ');
    final area = s.areaShape == AreaShape.none
        ? ''
        : '${s.areaShape.label}${s.areaSize.isEmpty ? '' : ' (${s.areaSize})'}';
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, style: theme.titleLarge),
                Text(subtitle, style: const TextStyle(color: Palette.textDim)),
                if (s.concentration || s.ritual)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 12,
                      children: [
                        if (s.concentration)
                          const _Flag(Icons.psychology, 'Concentration'),
                        if (s.ritual)
                          const _Flag(Icons.history_edu, 'Ritual'),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                _DetailRow(
                  'Casting time',
                  s.castingTimeText.isEmpty
                      ? castingLabel(s.castingTime)
                      : s.castingTimeText,
                ),
                _DetailRow('Range', s.range),
                _DetailRow('Components', s.components),
                _DetailRow('Duration', s.duration),
                _DetailRow('Damage', s.damage),
                _DetailRow('Area', area),
                _DetailRow('Save', s.save?.label ?? ''),
                _DetailRow('Attack', s.attackRoll ? 'Spell attack roll' : ''),
                if (s.text.isNotEmpty) ...[
                  const Divider(height: 24),
                  for (final p in s.text.split('\n\n'))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(p),
                    ),
                ],
                if (s.higherLevels.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'At Higher Levels',
                    style: theme.titleSmall?.copyWith(color: Palette.gold),
                  ),
                  const SizedBox(height: 4),
                  Text(s.higherLevels),
                ],
              ],
            ),
          ),
        ),
        if (canAdd)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Add to character'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(
                color: Palette.textDim,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _Flag extends StatelessWidget {
  const _Flag(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 16,
        color: icon == Icons.psychology ? Palette.arcane : Palette.gold,
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}
