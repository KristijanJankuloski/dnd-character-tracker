import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../domain/rules.dart';
import '../character/character_bloc.dart';
import '../character/character_event.dart';
import '../character/loaded_builder.dart';
import '../resources/resources_panel.dart';
import '../spells/slots_panel.dart';
import 'compact_view.dart';
import 'hp_block.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key, required this.tablet});
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    return LoadedBuilder(
      builder: (context, s) {
        if (s.character.compactMode && !tablet) return const CompactView();
        final left = _leftColumn(context, s);
        final right = _rightColumn(context, s);
        if (tablet) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: Column(children: left)),
                const SizedBox(width: 16),
                Expanded(flex: 6, child: Column(children: right)),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [...left, const SizedBox(height: 12), ...right],
        );
      },
    );
  }

  List<Widget> _leftColumn(BuildContext context, CharacterLoaded s) {
    final c = s.character;
    final st = s.stats;
    final bloc = context.read<CharacterBloc>();
    return [
      _Identity(state: s),
      const SizedBox(height: 10),
      const OrnamentRule(),
      const SizedBox(height: 12),
      HpBlock(state: s),
      const SizedBox(height: 12),
      _CoreNumbers(state: s),
      const SizedBox(height: 12),
      DeathSavesPanel(character: c),
      const SizedBox(height: 12),
      Panel(
        title: 'Hit dice & inspiration',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HitDicePanel(state: s),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Inspiration'),
              value: c.inspiration,
              onChanged: (_) => bloc.add(const InspirationToggled()),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Panel(
        title: 'Conditions',
        child: ConditionsPanel(character: c),
      ),
      if (st.warnings.isNotEmpty) ...[
        const SizedBox(height: 12),
        Panel(
          title: 'Heads up',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final w in st.warnings)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Palette.warn,
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text(w)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 12),
      Panel(
        title: 'Resources',
        trailing: c.resources.any((r) => r.id == 'sorcery-points')
            ? TextButton(
                onPressed: () => showFlexibleCasting(context, s),
                child: const Text('Convert'),
              )
            : null,
        child: Column(
          children: [
            SlotsPanel(state: s),
            if (c.resources.isNotEmpty) const Divider(),
            ResourcesPanel(state: s),
          ],
        ),
      ),
    ];
  }

  List<Widget> _rightColumn(BuildContext context, CharacterLoaded s) {
    return [
      _PassiveStrip(state: s),
      const SizedBox(height: 12),
      if (s.stats.traits.isNotEmpty) ...[
        Panel(
          title: 'Senses & resistances',
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final t in s.stats.traits)
                Chip(label: Text('${t.$2} (${t.$1})')),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      AbilitiesPanel(state: s),
      const SizedBox(height: 12),
      SavesPanel(state: s),
      const SizedBox(height: 12),
      SkillsPanel(state: s),
    ];
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.state});
  final CharacterLoaded state;

  @override
  Widget build(BuildContext context) {
    final c = state.character;
    final bloc = context.read<CharacterBloc>();
    final initials = c.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    final subtitle = [
      c.race,
      c.classLine,
      if (c.background.isNotEmpty) c.background,
    ].where((e) => e.isNotEmpty).join(' · ');
    return Row(
      children: [
        IconButton(
          tooltip: 'All characters',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        WaxSeal(initials: initials),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.name,
                style: displayStyle(size: 21, spacing: .4),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Palette.textDim,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Tooltip(
          message: 'Compact combat mode',
          child: IconButton.filledTonal(
            style: framedIconStyle(filled: true),
            icon: const Icon(Icons.bolt),
            isSelected: c.compactMode,
            onPressed: () => bloc.add(CompactModeSet(!c.compactMode)),
          ),
        ),
      ],
    );
  }
}

class _CoreNumbers extends StatelessWidget {
  const _CoreNumbers({required this.state});
  final CharacterLoaded state;

  @override
  Widget build(BuildContext context) {
    final st = state.stats;
    void why(String title, Breakdown b, [List<String> notes = const []]) =>
        showWhy(context, title, '${b.total} = ${b.describe()}', notes: notes);
    Widget cell(Widget w) => Expanded(
      child: Padding(padding: const EdgeInsets.only(left: 8), child: w),
    );
    return Row(
      children: [
        StatShield(
          label: 'AC',
          value: '${st.ac.total}',
          onTap: () => why('Armor Class', st.ac, st.acNotes),
          changed: st.ac.parts.length > 2,
          shield: true,
        ),
        cell(
          StatShield(
            label: 'Initiative',
            value: signed(st.initiative.total),
            onTap: () => why('Initiative', st.initiative),
          ),
        ),
        cell(
          StatShield(
            label: 'Speed',
            value: '${st.speed.total} ft',
            onTap: () => why('Speed', st.speed),
          ),
        ),
        cell(
          StatShield(
            label: 'Prof.',
            value: signed(st.proficiency),
            onTap: () => showWhy(
              context,
              'Proficiency bonus',
              'Level ${state.character.level}: ${signed(st.proficiency)}',
            ),
          ),
        ),
      ],
    );
  }
}

class _PassiveStrip extends StatelessWidget {
  const _PassiveStrip({required this.state});
  final CharacterLoaded state;
  @override
  Widget build(BuildContext context) {
    final p = state.stats.passives;
    Widget cell(String label, Skill s) => Expanded(
      child: Column(
        children: [
          Text('${p[s]}', style: numberStyle(size: 25)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: displayStyle(size: 10.5, color: Palette.textDim),
            ),
          ),
        ],
      ),
    );
    const rule = SizedBox(
      height: 38,
      child: VerticalDivider(width: 9, color: Color(0x808A6D2F)),
    );
    return Panel(
      title: 'Passive scores',
      child: Row(
        children: [
          cell('Perception', Skill.perception),
          rule,
          cell('Investigation', Skill.investigation),
          rule,
          cell('Insight', Skill.insight),
        ],
      ),
    );
  }
}

class AbilitiesPanel extends StatelessWidget {
  const AbilitiesPanel({super.key, required this.state});
  final CharacterLoaded state;

  @override
  Widget build(BuildContext context) {
    final st = state.stats;
    final c = state.character;
    final bloc = context.read<CharacterBloc>();
    return Panel(
      title: 'Ability scores',
      parchment: true,
      child: GridView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisExtent: AbilityFrame.height,
          mainAxisSpacing: 12,
          crossAxisSpacing: 10,
        ),
        children: [
          for (final a in Ability.values)
            AbilityFrame(
              abbr: a.abbr,
              modifier: signed(st.mods[a]!),
              score: '${st.scores[a]}',
              changed: st.changedScores.contains(a),
              semanticsLabel:
                  '${a.label} ${signed(st.mods[a]!)}, score ${st.scores[a]}',
              onTap: () async {
                final changed = st.changedScores.contains(a);
                final v = await askNumber(
                  context,
                  'Base ${a.label}${changed ? ' (current ${st.scores[a]} from modifiers)' : ''}',
                  initial: c.abilities[a] ?? 10,
                );
                if (v != null) bloc.add(AbilityScoreSet(a, v));
              },
            ),
        ],
      ),
    );
  }
}

class SavesPanel extends StatelessWidget {
  const SavesPanel({super.key, required this.state});
  final CharacterLoaded state;
  @override
  Widget build(BuildContext context) {
    final st = state.stats;
    final c = state.character;
    return Panel(
      title: 'Saving throws',
      parchment: true,
      child: Column(
        children: [
          const Text(
            'Tap the diamond for proficiency. Long-press a row to add a bonus.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontStyle: FontStyle.italic,
              color: Palette.inkDim,
            ),
          ),
          const SizedBox(height: 4),
          for (final a in Ability.values)
            InkWell(
              onTap: () => showWhy(
                context,
                '${a.label} save',
                '${signed(st.saves[a]!.total)} = ${st.saves[a]!.describe()}',
              ),
              onLongPress: () async {
                final v = await askNumber(
                  context,
                  '${a.label} save bonus',
                  initial: c.saveBonuses[a] ?? 0,
                  confirm: 'Set',
                );
                if (v != null && context.mounted) {
                  context.read<CharacterBloc>().add(SaveBonusSet(a, v));
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Tooltip(
                      message: 'Toggle ${a.label} save proficiency',
                      child: InkWell(
                        onTap: () => context.read<CharacterBloc>().add(
                          SaveProficiencyToggled(a),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: ProficiencyMark(
                            c.saveProfs.contains(a)
                                ? ProficiencyLevel.proficient
                                : ProficiencyLevel.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      a.label,
                      style: TextStyle(
                        fontWeight: c.saveProfs.contains(a)
                            ? FontWeight.w700
                            : null,
                      ),
                    ),
                    const Expanded(child: DotLeader()),
                    Text(
                      signed(st.saves[a]!.total),
                      style: numberStyle(size: 17),
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

class SkillsPanel extends StatelessWidget {
  const SkillsPanel({super.key, required this.state});
  final CharacterLoaded state;

  @override
  Widget build(BuildContext context) {
    final st = state.stats;
    final c = state.character;
    final bloc = context.read<CharacterBloc>();
    return Panel(
      title: 'Skills',
      parchment: true,
      child: Column(
        children: [
          for (final s in Skill.values)
            InkWell(
              onTap: () => _sheet(context, s, bloc),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    _marker(c.skills[s] ?? Proficiency.none, c.jackOfAllTrades),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          text: s.label,
                          style: TextStyle(
                            fontWeight:
                                (c.skills[s] ?? Proficiency.none) ==
                                    Proficiency.none
                                ? null
                                : FontWeight.w700,
                          ),
                          children: [
                            TextSpan(
                              text: '  ${s.ability.abbr}',
                              style: displayStyle(
                                size: 10,
                                color: Palette.inkDim,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Expanded(child: DotLeader()),
                    if ((c.skillAdv[s] ?? AdvState.none) != AdvState.none)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stamp(
                          c.skillAdv[s] == AdvState.advantage ? 'ADV' : 'DIS',
                        ),
                      ),
                    Text(
                      signed(st.skills[s]!.total),
                      style: numberStyle(size: 17),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _marker(Proficiency p, bool jack) {
    return ProficiencyMark(switch (p) {
      Proficiency.none => jack ? ProficiencyLevel.half : ProficiencyLevel.none,
      Proficiency.proficient => ProficiencyLevel.proficient,
      Proficiency.expertise => ProficiencyLevel.expertise,
    });
  }

  void _sheet(BuildContext context, Skill s, CharacterBloc bloc) {
    final b = state.stats.skills[s]!;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(s.label),
              subtitle: Text('${signed(b.total)} = ${b.describe()}'),
            ),
            ListTile(
              leading: const Icon(Icons.school),
              title: const Text(
                'Cycle proficiency (none, proficient, expertise)',
              ),
              onTap: () {
                bloc.add(SkillProficiencyCycled(s));
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_vert),
              title: const Text('Cycle advantage marker'),
              onTap: () {
                bloc.add(SkillAdvantageCycled(s));
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}
