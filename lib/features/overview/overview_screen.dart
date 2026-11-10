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
        CircleAvatar(
          radius: 28,
          backgroundColor: Palette.crimson,
          child: Text(
            initials,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Palette.text,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: const TextStyle(color: Palette.textDim),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Tooltip(
          message: 'Compact combat mode',
          child: IconButton.filledTonal(
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: w,
      ),
    );
    return Row(
      children: [
        cell(
          StatShield(
            label: 'AC',
            value: '${st.ac.total}',
            onTap: () => why('Armor Class', st.ac, st.acNotes),
            changed: st.ac.parts.length > 2,
          ),
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
          Text(
            '${p[s]}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Palette.textDim),
          ),
        ],
      ),
    );
    return Panel(
      title: 'Passive scores',
      child: Row(
        children: [
          cell('Perception', Skill.perception),
          cell('Investigation', Skill.investigation),
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
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        childAspectRatio: 1.35,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          for (final a in Ability.values)
            InkWell(
              onTap: () async {
                final changed = st.changedScores.contains(a);
                final v = await askNumber(
                  context,
                  'Base ${a.label}${changed ? ' (current ${st.scores[a]} from modifiers)' : ''}',
                  initial: c.abilities[a] ?? 10,
                );
                if (v != null) bloc.add(AbilityScoreSet(a, v));
              },
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Palette.goldDim),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      a.abbr,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          signed(st.mods[a]!),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (st.changedScores.contains(a))
                          const Icon(
                            Icons.circle,
                            size: 7,
                            color: Palette.crimson,
                          ),
                      ],
                    ),
                    Text(
                      '${st.scores[a]}',
                      style: const TextStyle(fontSize: 13),
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
            'Tap the dot for proficiency. Long-press a row to add a bonus.',
            style: TextStyle(fontSize: 12),
          ),
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
                          child: Icon(
                            c.saveProfs.contains(a)
                                ? Icons.circle
                                : Icons.circle_outlined,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(child: Text(a.label)),
                    Text(
                      signed(st.saves[a]!.total),
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
                    Expanded(child: Text('${s.label} (${s.ability.abbr})')),
                    if ((c.skillAdv[s] ?? AdvState.none) != AdvState.none)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          c.skillAdv[s] == AdvState.advantage ? 'ADV' : 'DIS',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    Text(
                      signed(st.skills[s]!.total),
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
    switch (p) {
      case Proficiency.none:
        return Icon(jack ? Icons.contrast : Icons.circle_outlined, size: 14);
      case Proficiency.proficient:
        return const Icon(Icons.circle, size: 14);
      case Proficiency.expertise:
        return const Icon(Icons.album, size: 14);
    }
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
