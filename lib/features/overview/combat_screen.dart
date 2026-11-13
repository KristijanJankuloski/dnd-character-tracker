import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../domain/rules.dart';
import '../../domain/tables.dart';
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
            : FeaturesPanel(state: s);
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

/// Class features. Metamagic gets a picker for the chosen options.
class FeaturesPanel extends StatelessWidget {
  const FeaturesPanel({super.key, required this.state});
  final CharacterLoaded state;

  @override
  Widget build(BuildContext context) {
    final c = state.character;
    return Panel(
      title: 'Features',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final f in c.features)
            if (f.name == 'Metamagic')
              _MetamagicFeature(feature: f, character: c)
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
  }
}

int _sorcererLevel(Character c) => c.classes
    .where((x) => x.className == 'Sorcerer')
    .fold(0, (s, x) => s + x.level);

class _MetamagicFeature extends StatelessWidget {
  const _MetamagicFeature({required this.feature, required this.character});
  final Feature feature;
  final Character character;

  @override
  Widget build(BuildContext context) {
    final allowed = metamagicKnownFor(_sorcererLevel(character));
    final chosen = metamagicOptions
        .where((o) => character.metamagic.contains(o.name))
        .toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Metamagic${allowed > 0 ? ' (${chosen.length}/$allowed)' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: Text(chosen.isEmpty ? 'Choose' : 'Change'),
                onPressed: () => showMetamagicPicker(context, character),
              ),
            ],
          ),
          if (chosen.isEmpty)
            Text(
              allowed == 0
                  ? 'Sorcerers choose Metamagic options from level 3.'
                  : 'No options chosen yet. You can pick $allowed.',
              style: const TextStyle(color: Palette.textDim),
            )
          else
            for (final o in chosen)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${o.name} (${o.cost}): ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: o.text,
                        style: const TextStyle(color: Palette.textDim),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Lets the player pick Metamagic options. Going over the level allowance is
/// allowed (house rules) but the count turns to a warning colour.
Future<void> showMetamagicPicker(BuildContext context, Character c) {
  final bloc = context.read<CharacterBloc>();
  final allowed = metamagicKnownFor(_sorcererLevel(c));
  final picked = {...c.metamagic};
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Metamagic'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${picked.length} of $allowed chosen',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: picked.length > allowed
                        ? Palette.warn
                        : Palette.textDim,
                  ),
                ),
                for (final o in metamagicOptions)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: picked.contains(o.name),
                    title: Text('${o.name} · ${o.cost}'),
                    subtitle: Text(o.text),
                    onChanged: (v) => setState(
                      () => v == true
                          ? picked.add(o.name)
                          : picked.remove(o.name),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              bloc.add(MetamagicSet(picked));
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
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
              customBorder: const BeveledRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: CutBox(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  fill: used ? Palette.bg : Palette.plateTop,
                  fillEnd: used ? null : Palette.plateBottom,
                  stroke: used ? Palette.goldDim : Palette.gold,
                  strokeWidth: 1.5,
                  cut: 8,
                  inner: used ? null : Palette.goldHairline,
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
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          color: Palette.textDim,
                        ),
                      ),
                    ],
                  ),
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
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CutBox.onParchment(
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
                          onPressed: () =>
                              bloc.add(AttackUsed(a, offHand: true)),
                          child: const Text('Off-hand'),
                        ),
                      ),
                  ],
                ),
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
