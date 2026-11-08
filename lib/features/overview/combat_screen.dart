import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/rules.dart';
import '../character/character_bloc.dart';
import '../character/character_event.dart';
import '../character/loaded_builder.dart';
import '../resources/resources_panel.dart';

class CombatScreen extends StatelessWidget {
  const CombatScreen({super.key, required this.tablet});
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    return LoadedBuilder(
      builder: (context, s) {
        final c = s.character;
        final turn = TurnTracker(state: s);
        final attacks = _Attacks(state: s);
        final resources = Panel(
          title: 'Class resources',
          child: Column(children: [ResourcesPanel(state: s)]),
        );
        final features = c.features.isEmpty
            ? const SizedBox.shrink()
            : Panel(
                title: 'Features',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final f in c.features)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              f.text,
                              style: const TextStyle(color: Palette.textDim),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
        if (tablet) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      turn,
                      const SizedBox(height: 12),
                      resources,
                      const SizedBox(height: 12),
                      features,
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: attacks),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            turn,
            const SizedBox(height: 12),
            attacks,
            const SizedBox(height: 12),
            resources,
            const SizedBox(height: 12),
            features,
          ],
        );
      },
    );
  }
}

/// Action / Bonus Action / Reaction toggles plus movement.
class TurnTracker extends StatelessWidget {
  const TurnTracker({super.key, required this.state});
  final CharacterLoaded state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CharacterBloc>();
    final t = state.character.turn;
    final speed = state.stats.speed.total;
    final left = speed - t.movementUsed;
    Widget toggle(String label, String kind, bool used, IconData icon) =>
        Expanded(
          child: Semantics(
            button: true,
            label: '$label ${used ? 'used' : 'available'}',
            child: InkWell(
              onTap: () => bloc.add(TurnToggled(kind)),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: used ? Palette.bg : Palette.panelHi,
                  border: Border.all(
                    color: used ? Palette.textDim : Palette.gold,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    Icon(
                      used ? Icons.check_circle : icon,
                      color: used ? Palette.textDim : Palette.gold,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: used ? Palette.textDim : Palette.text,
                        decoration: used ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    Text(
                      used ? 'Used' : 'Available',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Palette.textDim,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    return Panel(
      title: 'Your turn',
      trailing: FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
        onPressed: () => bloc.add(const NewTurnStarted()),
        child: const Text('New turn'),
      ),
      child: Column(
        children: [
          Row(
            children: [
              toggle('Action', 'action', t.action, Icons.flash_on),
              toggle('Bonus', 'bonus', t.bonusAction, Icons.bolt),
              toggle('Reaction', 'reaction', t.reaction, Icons.reply),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.directions_walk, color: Palette.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Movement: $left / $speed ft',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () => bloc.add(const MovementUsed(5)),
                child: const Text('-5'),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () => bloc.add(const MovementUsed(10)),
                child: const Text('-10'),
              ),
            ],
          ),
          if (t.leveledActionSpell || t.bonusActionSpell)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                t.bonusActionSpell
                    ? 'A bonus-action spell was cast: only a cantrip with a 1-action casting time can follow.'
                    : 'A leveled spell was cast with your action.',
                style: const TextStyle(color: Palette.textDim, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _Attacks extends StatelessWidget {
  const _Attacks({required this.state});
  final CharacterLoaded state;

  /// Two-Weapon Fighting: offered for Light weapons when two are equipped.
  bool _canOffHand(AttackInfo a) {
    if (a.itemId == null) return false;
    final lights = state.character.items.where(
      (i) => i.equipped && i.weapon?.light == true && !i.weapon!.ranged,
    );
    final item = state.character.items
        .where((i) => i.id == a.itemId)
        .firstOrNull;
    return lights.length >= 2 && item?.weapon?.light == true;
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CharacterBloc>();
    final attacks = state.stats.attacks;
    final t = state.character.turn;
    return Panel(
      title: 'Attacks',
      parchment: true,
      child: Column(
        children: [
          for (final a in attacks)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: Palette.goldDim),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          [
                            if (a.bonus != null) 'Attack ${signed(a.bonus!)}',
                            if (a.saveDc != null)
                              'DC ${a.saveDc} ${a.saveAbility!.abbr} save',
                            a.damage,
                          ].where((e) => e.isNotEmpty).join(' · '),
                        ),
                        if (a.versatileDamage != null)
                          Text(
                            'Two-handed: ${a.versatileDamage}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        Text(
                          [
                            if (a.range.isNotEmpty) a.range,
                            ...a.properties,
                            if (!a.proficient) 'not proficient',
                          ].join(' · '),
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (a.spellId == null &&
                            state.stats.attacksPerAction > 1)
                          Text(
                            'Attack ${t.attacksMade + 1} of ${state.stats.attacksPerAction}',
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  if (a.spellId != null && !a.properties.contains('Cantrip'))
                    const Text(
                      'Cast from\nSpells',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    )
                  else
                    FilledButton(
                      onPressed: () {
                        final spellId = a.spellId;
                        if (spellId != null) {
                          // Cantrips cost no slot: cast it so the action is marked.
                          final spell = state.character.spells.firstWhere(
                            (x) => x.id == spellId,
                          );
                          bloc.add(SpellCast(spell));
                        } else {
                          bloc.add(
                            AttackUsed(
                              a,
                              attacksPerAction: state.stats.attacksPerAction,
                            ),
                          );
                        }
                      },
                      child: const Text('Use'),
                    ),
                  if (_canOffHand(a))
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: OutlinedButton(
                        onPressed: () => bloc.add(AttackUsed(a, offHand: true)),
                        child: const Text('Off-hand'),
                      ),
                    ),
                ],
              ),
            ),
          const Text(
            'Roll at the table; the app tracks the action.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
