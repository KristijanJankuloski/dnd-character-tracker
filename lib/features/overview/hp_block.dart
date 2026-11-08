import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../domain/tables.dart';
import '../character/character_bloc.dart';
import '../character/character_event.dart';

/// HP: tap the number, type, press Damage or Heal. -1/+1 for small changes.
class HpBlock extends StatelessWidget {
  const HpBlock({super.key, required this.state, this.compact = false});
  final CharacterLoaded state;
  final bool compact;

  Color _barColor(double f) =>
      f <= 0.25 ? Palette.crimsonHi : (f <= 0.5 ? Palette.warn : Palette.good);

  @override
  Widget build(BuildContext context) {
    final c = state.character;
    final max = state.stats.maxHp;
    final fraction = max == 0 ? 0.0 : (c.hpCurrent / max).clamp(0.0, 1.0);
    final bloc = context.read<CharacterBloc>();
    return Panel(
      child: Column(
        children: [
          Row(
            children: [
              IconButton.outlined(
                tooltip: 'Damage 1',
                onPressed: () => bloc.add(const HpDamageApplied(1)),
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Semantics(
                  button: true,
                  label:
                      'Hit points ${c.hpCurrent} of $max. Tap to enter damage or healing.',
                  child: InkWell(
                    onTap: () => showHpPad(context, state),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.favorite,
                            color: Palette.crimsonHi,
                            size: 30,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${c.hpCurrent}',
                            style: TextStyle(
                              fontSize: compact ? 36 : 44,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            ' / $max',
                            style: TextStyle(
                              fontSize: compact ? 22 : 26,
                              color: Palette.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton.outlined(
                tooltip: 'Heal 1',
                onPressed: () => bloc.add(const HpHealed(1)),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 10,
              color: _barColor(fraction),
              backgroundColor: Palette.panelHi,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final v = await askNumber(
                context,
                'Temp HP (replaces the current value)',
                initial: c.tempHp,
              );
              if (v == null || !context.mounted) return;
              if (c.tempHp > 0 && v > 0 && v != c.tempHp) {
                final ok = await confirm(
                  context,
                  'Replace ${c.tempHp} temp HP with $v? Temp HP does not stack.',
                  yes: 'Replace',
                );
                if (!ok) return;
              }
              bloc.add(TempHpSet(v));
            },
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: Palette.textDim,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Temp HP: ${c.tempHp}',
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

Future<void> showHpPad(BuildContext context, CharacterLoaded state) {
  final bloc = context.read<CharacterBloc>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => BlocProvider.value(
      value: bloc,
      child: _HpPad(atZero: state.character.hpCurrent == 0),
    ),
  );
}

class _HpPad extends StatefulWidget {
  const _HpPad({required this.atZero});
  final bool atZero;
  @override
  State<_HpPad> createState() => _HpPadState();
}

class _HpPadState extends State<_HpPad> {
  final _controller = TextEditingController();
  bool _crit = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Returns (amount, forcedKind). `-7` is damage, `+7` is healing.
  (int, String?)? _parse() {
    final t = _controller.text.trim();
    if (t.isEmpty) return null;
    final n = int.tryParse(t.replaceFirst('+', ''));
    if (n == null) return null;
    if (t.startsWith('-')) return (n.abs(), 'damage');
    if (t.startsWith('+')) return (n.abs(), 'heal');
    return (n, null);
  }

  void _apply(String kind) {
    final p = _parse();
    if (p == null || p.$1 == 0) return;
    final bloc = context.read<CharacterBloc>();
    final k = p.$2 ?? kind;
    bloc.add(
      k == 'damage' ? HpDamageApplied(p.$1, crit: _crit) : HpHealed(p.$1),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            decoration: const InputDecoration(hintText: 'Amount (or -7 / +7)'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              final p = _parse();
              if (p?.$2 != null) _apply(p!.$2!);
            },
          ),
          if (widget.atZero)
            CheckboxListTile(
              value: _crit,
              onChanged: (v) => setState(() => _crit = v ?? false),
              title: const Text('Critical hit (two death save failures)'),
              dense: true,
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _parse() == null ? null : () => _apply('damage'),
                  icon: const Icon(Icons.heart_broken),
                  label: const Text('Damage'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _parse() == null ? null : () => _apply('heal'),
                  icon: const Icon(Icons.healing),
                  label: const Text('Heal'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: const Color(0xFF2F5A2B),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Death saves appear only at 0 HP.
class DeathSavesPanel extends StatelessWidget {
  const DeathSavesPanel({super.key, required this.character});
  final Character character;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CharacterBloc>();
    final c = character;
    return Panel(
      title: c.dead ? 'Dead' : (c.stable ? 'Stable' : 'Death saves'),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Successes'),
              const SizedBox(width: 10),
              Pips(
                total: 3,
                filled: c.deathSuccesses,
                color: Palette.good,
                size: 20,
              ),
              const Spacer(),
              const Text('Failures'),
              const SizedBox(width: 10),
              Pips(
                total: 3,
                filled: c.deathFailures,
                color: Palette.crimsonHi,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (c.dead)
            Row(
              children: [
                const Expanded(
                  child: Text('Marked dead. Dismiss this if it was a mistake.'),
                ),
                OutlinedButton(
                  onPressed: () => bloc.add(const DeathDismissed()),
                  child: const Text('Dismiss'),
                ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => bloc.add(const DeathSaveRecorded('success')),
                  child: const Text('Success'),
                ),
                OutlinedButton(
                  onPressed: () => bloc.add(const DeathSaveRecorded('failure')),
                  child: const Text('Failure'),
                ),
                OutlinedButton(
                  onPressed: () => bloc.add(const DeathSaveRecorded('nat20')),
                  child: const Text('Natural 20'),
                ),
                OutlinedButton(
                  onPressed: () => bloc.add(const DeathSaveRecorded('nat1')),
                  child: const Text('Natural 1'),
                ),
                TextButton(
                  onPressed: () async {
                    if (await confirm(
                      context,
                      'Mark ${c.name} as dead? Use this for instant death from massive damage.',
                      yes: 'Mark dead',
                    )) {
                      bloc.add(const DeathMarked());
                    }
                  },
                  child: const Text('Mark as dead'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Hit dice: tap to spend one (enter the roll, adds CON mod, heals).
class HitDicePanel extends StatelessWidget {
  const HitDicePanel({super.key, required this.state});
  final CharacterLoaded state;

  @override
  Widget build(BuildContext context) {
    final c = state.character;
    final bloc = context.read<CharacterBloc>();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in state.stats.hitDice.entries)
          ActionChip(
            avatar: const Icon(Icons.casino_outlined, size: 18),
            label: Text(
              '${e.value - (c.hitDiceUsed[e.key] ?? 0)}/${e.value} d${e.key}',
            ),
            onPressed: () async {
              final roll = await askNumber(
                context,
                'Hit die d${e.key}: enter your roll (adds CON ${signed0(state.stats.mods[Ability.con]!)})',
                confirm: 'Heal',
              );
              if (roll != null) bloc.add(HitDieSpent(e.key, roll));
            },
          ),
      ],
    );
  }
}

String signed0(int v) => v >= 0 ? '+$v' : '$v';

/// Conditions chips with a "+" menu. Tap a chip for rules, long-press removes.
class ConditionsPanel extends StatelessWidget {
  const ConditionsPanel({super.key, required this.character});
  final Character character;

  @override
  Widget build(BuildContext context) {
    final c = character;
    final bloc = context.read<CharacterBloc>();
    final chips = <Widget>[
      for (final id in c.conditions)
        GestureDetector(
          onLongPress: () => bloc.add(ConditionToggled(id)),
          child: ActionChip(
            avatar: const Icon(
              Icons.warning_amber,
              size: 16,
              color: Palette.warn,
            ),
            label: Text(_title(id)),
            onPressed: () => showWhy(
              context,
              _title(id),
              conditionRules[id] ?? '',
              notes: const ['Long-press the chip to remove it.'],
            ),
          ),
        ),
      if (c.exhaustion > 0)
        GestureDetector(
          onLongPress: () => bloc.add(const ExhaustionSet(0)),
          child: ActionChip(
            label: Text('Exhaustion ${c.exhaustion}'),
            onPressed: () => showWhy(
              context,
              'Exhaustion ${c.exhaustion}',
              exhaustionRules.take(c.exhaustion + 1).skip(1).join('\n'),
            ),
          ),
        ),
      if (c.concentration != null)
        ActionChip(
          avatar: const Icon(Icons.psychology, size: 16, color: Palette.arcane),
          label: Text('Concentrating: ${c.concentration}'),
          onPressed: () => bloc.add(const ConcentrationEnded()),
          tooltip: 'Tap to end concentration',
        ),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...chips,
        if (chips.isEmpty)
          const Text('No conditions', style: TextStyle(color: Palette.textDim)),
        IconButton.outlined(
          tooltip: 'Add condition',
          icon: const Icon(Icons.add),
          onPressed: () => _add(context),
        ),
      ],
    );
  }

  String _title(String id) => id[0].toUpperCase() + id.substring(1);

  Future<void> _add(BuildContext context) async {
    final bloc = context.read<CharacterBloc>();
    final c = character;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final id in conditionRules.keys)
              CheckboxListTile(
                value: c.conditions.contains(id),
                title: Text(_title(id)),
                subtitle: Text(
                  conditionRules[id]!,
                  style: const TextStyle(fontSize: 12, color: Palette.textDim),
                ),
                onChanged: (_) {
                  bloc.add(ConditionToggled(id));
                  Navigator.pop(ctx);
                },
              ),
            ListTile(
              title: const Text('Exhaustion'),
              subtitle: Text('Level ${c.exhaustion}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      bloc.add(ExhaustionSet(c.exhaustion - 1));
                      Navigator.pop(ctx);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      bloc.add(ExhaustionSet(c.exhaustion + 1));
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
