import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/widgets.dart';
import '../character/character_bloc.dart';
import '../character/character_event.dart';
import '../character/loaded_builder.dart';
import '../resources/resources_panel.dart';
import '../spells/slots_panel.dart';
import 'combat_screen.dart';
import 'hp_block.dart';

/// Compact combat mode: only what is used every turn.
class CompactView extends StatelessWidget {
  const CompactView({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return LoadedBuilder(
      builder: (context, s) {
        final c = s.character;
        final bloc = context.read<CharacterBloc>();
        final children = <Widget>[
          Row(
            children: [
              Expanded(
                child: Text(
                  c.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'AC ${s.stats.ac.total}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              if (!embedded)
                IconButton(
                  tooltip: 'Exit compact combat mode',
                  icon: const Icon(Icons.unfold_more),
                  onPressed: () => bloc.add(const CompactModeSet(false)),
                ),
            ],
          ),
          HpBlock(state: s, compact: true),
          if (c.hpCurrent == 0 || c.dead) DeathSavesPanel(character: c),
          ConditionsPanel(character: c),
          TurnTracker(state: s),
          Panel(
            title: 'Slots & resources',
            child: Column(
              children: [
                SlotsPanel(state: s, dense: true),
                ResourcesPanel(state: s, limit: 3),
              ],
            ),
          ),
        ];
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: children.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => children[i],
        );
      },
    );
  }
}
