import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/actions.dart' as act;
import '../character/character_bloc.dart';
import '../character/character_event.dart';

/// Slot pips by level, shared by the overview, compact view and Spells tab.
class SlotsPanel extends StatelessWidget {
  const SlotsPanel({super.key, required this.state, this.dense = false});
  final CharacterLoaded state;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = state.character;
    final s = state.stats;
    final bloc = context.read<CharacterBloc>();
    final rows = <Widget>[];
    // Include levels that only exist because Flexible Casting created a slot.
    final levels = {
      ...s.slotMax.keys,
      for (final e in c.slotsUsed.entries)
        if (e.value < 0) e.key,
    }.toList()..sort();
    for (final level in levels) {
      final e = MapEntry(level, s.slotMax[level] ?? 0);
      final used = c.slotsUsed[e.key] ?? 0;
      final remaining = e.value - used;
      final total = remaining > e.value ? remaining : e.value;
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: dense ? 54 : 64,
                child: Text(
                  'Lv ${e.key}',
                  style: const TextStyle(color: Palette.textDim),
                ),
              ),
              Expanded(
                child: Pips(
                  total: total,
                  filled: remaining.clamp(0, total),
                  semanticsLabel: 'Level ${e.key} slots',
                  onSpend: () => bloc.add(SlotChanged(e.key, spend: true)),
                  onRestore: () => bloc.add(SlotChanged(e.key, spend: false)),
                ),
              ),
              Text(
                '$remaining/${e.value}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }
    if (s.pactSlots != null) {
      final (count, level) = s.pactSlots!;
      final remaining = act.pactRemaining(c, s);
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: dense ? 54 : 64,
                child: Text(
                  'Pact $level',
                  style: const TextStyle(color: Palette.textDim),
                ),
              ),
              Expanded(
                child: Pips(
                  total: count,
                  filled: remaining,
                  color: Palette.violet,
                  semanticsLabel: 'Pact slots',
                  onSpend: () => bloc.add(const PactSlotChanged(spend: true)),
                  onRestore: () =>
                      bloc.add(const PactSlotChanged(spend: false)),
                ),
              ),
              Text(
                '$remaining/$count',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }
    if (rows.isEmpty) {
      return const Text(
        'No spell slots.',
        style: TextStyle(color: Palette.textDim),
      );
    }
    return Column(children: rows);
  }
}
