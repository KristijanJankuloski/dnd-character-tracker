import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/actions.dart' as act;
import '../../domain/character_factory.dart';
import '../../domain/models.dart';
import '../../domain/rules.dart';
import '../../domain/srd_data.dart';
import '../../domain/tables.dart';
import '../character/character_bloc.dart';
import '../character/character_event.dart';
import '../character/loaded_builder.dart';
import '../resources/resources_panel.dart';
import 'slots_panel.dart';
import 'spell_detail_sheet.dart';

class SpellsScreen extends StatefulWidget {
  const SpellsScreen({super.key, required this.tablet});
  final bool tablet;
  @override
  State<SpellsScreen> createState() => _SpellsScreenState();
}

class _SpellsScreenState extends State<SpellsScreen> {
  bool _concOnly = false;
  bool _ritualOnly = false;
  bool _preparedOnly = false;

  @override
  Widget build(BuildContext context) {
    return LoadedBuilder(
      builder: (context, s) {
        final c = s.character;
        final bloc = context.read<CharacterBloc>();
        final casting = s.stats.spellcasting;
        final template = templateFor(c.primaryClass.className);
        final model = spellModelFor(c.primaryClass, template);
        final prepares = model == SpellModel.prepared;
        final limits = knownLimits(
          c.primaryClass.className,
          c.primaryClass.level,
        );
        final cantripCount = c.spells.where((x) => x.isCantrip).length;
        var spells = [...c.spells]
          ..sort(
            (a, b) => a.level != b.level
                ? a.level.compareTo(b.level)
                : a.name.compareTo(b.name),
          );
        if (_concOnly) spells = spells.where((e) => e.concentration).toList();
        if (_ritualOnly) spells = spells.where((e) => e.ritual).toList();
        if (_preparedOnly) {
          spells = spells.where((e) => e.prepared || e.isCantrip).toList();
        }
        final byLevel = <int, List<Spell>>{};
        for (final sp in spells) {
          byLevel.putIfAbsent(sp.level, () => []).add(sp);
        }
        final preparedCount = c.spells
            .where((x) => x.prepared && !x.isCantrip && !x.alwaysPrepared)
            .length;

        final header = Panel(
          title: 'Spellcasting',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (casting.isEmpty)
                const Text(
                  'This class has no spellcasting. You can still add spells from items or feats.',
                  style: TextStyle(color: Palette.textDim),
                )
              else
                for (final info in casting)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (casting.length > 1)
                          Chip(label: Text(info.className)),
                        ActionChip(
                          label: Text('Ability ${info.ability.abbr}'),
                          onPressed: () {},
                        ),
                        ActionChip(
                          label: Text('Save DC ${info.dc}'),
                          onPressed: () => showWhy(
                            context,
                            'Spell save DC',
                            '${info.dc} = 8 + proficiency ${s.stats.proficiency} + ${info.ability.abbr} ${signed(s.stats.mods[info.ability]!)}',
                          ),
                        ),
                        ActionChip(
                          label: Text('Spell attack ${signed(info.attack)}'),
                          onPressed: () => showWhy(
                            context,
                            'Spell attack',
                            '${signed(info.attack)} = proficiency ${s.stats.proficiency} + ${info.ability.abbr} ${signed(s.stats.mods[info.ability]!)}',
                          ),
                        ),
                      ],
                    ),
                  ),
              if (s.stats.warnings.any((w) => w.contains("can't cast")))
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    "Warning: you're wearing armor you aren't proficient with, so you can't cast spells.",
                    style: TextStyle(color: Palette.warn),
                  ),
                ),
              const SizedBox(height: 4),
              InkWell(
                onTap: c.concentration == null
                    ? null
                    : () => bloc.add(const ConcentrationEnded()),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: c.concentration == null
                        ? Palette.panelHi
                        : const Color(0xFF1F2A4A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: c.concentration == null
                          ? Palette.goldDim
                          : Palette.arcane,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.psychology, color: Palette.arcane),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          c.concentration == null
                              ? 'Not concentrating'
                              : 'Concentrating: ${c.concentration}',
                        ),
                      ),
                      if (c.concentration != null)
                        const Text(
                          'Tap to end',
                          style: TextStyle(
                            color: Palette.textDim,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

        final slots = Panel(
          title: 'Spell slots',
          trailing: c.resources.any((r) => r.id == 'sorcery-points')
              ? TextButton(
                  onPressed: () => showFlexibleCasting(context, s),
                  child: const Text('Convert SP'),
                )
              : null,
          child: SlotsPanel(state: s),
        );

        final list = Panel(
          title: 'Spells',
          trailing: IconButton.filledTonal(
            tooltip: 'Add spell',
            icon: const Icon(Icons.add),
            onPressed: () => _addSpell(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Concentration'),
                    selected: _concOnly,
                    onSelected: (v) => setState(() => _concOnly = v),
                  ),
                  FilterChip(
                    label: const Text('Ritual'),
                    selected: _ritualOnly,
                    onSelected: (v) => setState(() => _ritualOnly = v),
                  ),
                  if (prepares)
                    FilterChip(
                      label: const Text('Prepared'),
                      selected: _preparedOnly,
                      onSelected: (v) => setState(() => _preparedOnly = v),
                    ),
                ],
              ),
              if (prepares)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${c.primaryClass.className == 'Wizard' ? 'Spellbook: ${c.spells.where((x) => !x.isCantrip).length} spells. ' : ''}Prepared: $preparedCount / ${preparedLimit(c, s.stats)}${limits == null ? '' : ' · Cantrips: $cantripCount / ${limits.cantrips}'}',
                    style: const TextStyle(color: Palette.textDim),
                  ),
                ),
              if (model == SpellModel.known)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Known: ${c.spells.where((x) => !x.isCantrip).length}${limits?.spells == null ? '' : ' / ${limits!.spells}'} spells, $cantripCount${limits == null ? '' : ' / ${limits.cantrips}'} cantrips',
                    style: const TextStyle(color: Palette.textDim),
                  ),
                ),
              if (c.spells.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No spells yet. Tap + to add from the SRD list or create your own.',
                  ),
                ),
              for (final e in byLevel.entries) ...[
                SectionLabel(e.key == 0 ? 'Cantrips' : 'Level ${e.key}'),
                for (final sp in e.value)
                  _SpellTile(spell: sp, state: s, prepares: prepares),
              ],
            ],
          ),
        );

        if (widget.tablet) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [header, const SizedBox(height: 12), slots],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(flex: 6, child: list),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            header,
            const SizedBox(height: 12),
            slots,
            const SizedBox(height: 12),
            list,
          ],
        );
      },
    );
  }

  Future<void> _addSpell(BuildContext context) async {
    final bloc = context.read<CharacterBloc>();
    final picked = await showModalBottomSheet<Spell>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _SpellPicker(),
    );
    if (picked != null) bloc.add(SpellAdded(picked));
  }
}

class _SpellTile extends StatelessWidget {
  const _SpellTile({
    required this.spell,
    required this.state,
    required this.prepares,
  });
  final Spell spell;
  final CharacterLoaded state;
  final bool prepares;

  @override
  Widget build(BuildContext context) {
    final dim = prepares && !spell.prepared && !spell.isCantrip;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        spell.name,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: dim ? Palette.textDim : Palette.text,
        ),
      ),
      subtitle: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Uses: ${castingLabel(spell.castingTime)}',
            style: const TextStyle(fontSize: 12),
          ),
          if (spell.range.isNotEmpty)
            Text(
              spell.range,
              style: const TextStyle(fontSize: 12, color: Palette.textDim),
            ),
          if (spell.concentration)
            const Icon(
              Icons.psychology,
              size: 14,
              color: Palette.arcane,
              semanticLabel: 'Concentration',
            ),
          if (spell.ritual)
            const Icon(
              Icons.history_edu,
              size: 14,
              color: Palette.gold,
              semanticLabel: 'Ritual',
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (prepares && !spell.isCantrip)
            Checkbox(
              value: spell.prepared,
              onChanged: spell.alwaysPrepared
                  ? null
                  : (_) => context.read<CharacterBloc>().add(
                      SpellPreparedToggled(spell.id),
                    ),
            ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: () => _cast(context),
            child: const Text('Cast'),
          ),
        ],
      ),
      onTap: () => showSpellDetailSheet(context, spell, canAdd: false),
      onLongPress: () async {
        if (await confirm(context, 'Remove ${spell.name}?', yes: 'Remove') &&
            context.mounted) {
          context.read<CharacterBloc>().add(SpellRemoved(spell.id));
        }
      },
    );
  }

  Future<void> _cast(BuildContext context) async {
    final bloc = context.read<CharacterBloc>();
    final c = state.character;
    final s = state.stats;
    // Casting a second concentration spell ends the first: ask first.
    var replace = false;
    if (spell.concentration &&
        c.concentration != null &&
        c.concentration != spell.name) {
      final ok = await confirm(
        context,
        'You are concentrating on ${c.concentration}. Casting ${spell.name} will end it.',
        yes: 'End it and cast',
      );
      if (!ok) return;
      replace = true;
    }
    if (spell.isCantrip) {
      bloc.add(SpellCast(spell, replaceConcentration: replace));
      return;
    }
    if (!context.mounted) return;
    final choice = await showModalBottomSheet<_CastChoice>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cast ${spell.name}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Uses: ${castingLabel(spell.castingTime)}${spell.concentration ? ' · Concentration' : ''}',
                style: const TextStyle(color: Palette.textDim),
              ),
              const SizedBox(height: 12),
              const Text('Choose a slot level'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var lvl = spell.level; lvl <= 9; lvl++)
                    if ((s.slotMax[lvl] ?? 0) > 0 ||
                        (c.slotsUsed[lvl] ?? 0) < 0)
                      ChoiceChip(
                        selected: false,
                        label: Text(
                          'Lv $lvl (${act.slotsRemaining(c, s, lvl)})${lvl > spell.level ? ' upcast' : ''}',
                        ),
                        onSelected: act.slotsRemaining(c, s, lvl) > 0
                            ? (_) => Navigator.pop(ctx, _CastChoice(lvl))
                            : null,
                      ),
                  if (s.pactSlots != null && s.pactSlots!.$2 >= spell.level)
                    ChoiceChip(
                      selected: false,
                      label: Text(
                        'Pact slot Lv ${s.pactSlots!.$2} (${act.pactRemaining(c, s)})',
                      ),
                      onSelected: act.pactRemaining(c, s) > 0
                          ? (_) => Navigator.pop(
                              ctx,
                              const _CastChoice(null, pact: true),
                            )
                          : null,
                    ),
                ],
              ),
              if (canRitualCast(c, spell)) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pop(ctx, const _CastChoice(null, ritual: true)),
                  icon: const Icon(Icons.history_edu),
                  label: const Text('Cast as ritual (no slot, +10 minutes)'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (choice != null) {
      bloc.add(
        SpellCast(
          spell,
          slotLevel: choice.level,
          ritual: choice.ritual,
          pact: choice.pact,
          replaceConcentration: replace,
        ),
      );
    }
  }
}

class _CastChoice {
  const _CastChoice(this.level, {this.ritual = false, this.pact = false});
  final int? level;
  final bool ritual;
  final bool pact;
}

class _SpellPicker extends StatefulWidget {
  const _SpellPicker();
  @override
  State<_SpellPicker> createState() => _SpellPickerState();
}

class _SpellPickerState extends State<_SpellPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = srdSpells
        .where((s) => s.name.toLowerCase().contains(_q.toLowerCase()))
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
          Expanded(
            child: ListView(
              controller: scroll,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Create a custom spell'),
                  onTap: () async {
                    final sp = await _custom(context);
                    if (sp != null && context.mounted) {
                      Navigator.pop(context, sp);
                    }
                  },
                ),
                for (final s in list)
                  ListTile(
                    title: Text(s.name),
                    subtitle: Text(
                      '${s.level == 0 ? 'Cantrip' : 'Level ${s.level}'} · ${castingLabel(s.castingTime)}${s.concentration ? ' · Conc.' : ''}',
                    ),
                    onTap: () => Navigator.pop(context, s),
                  ),
              ],
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
