import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/character_factory.dart';
import '../../domain/models.dart';
import '../../domain/srd_data.dart';
import '../character/character_bloc.dart';
import '../character/character_event.dart';
import '../character/loaded_builder.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key, required this.tablet});
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    return LoadedBuilder(
      builder: (context, s) {
        final c = s.character;
        final st = s.stats;
        final bloc = context.read<CharacterBloc>();
        final pct = st.capacity == 0
            ? 0.0
            : (st.carried / st.capacity).clamp(0.0, 1.0);

        final top = Panel(
          title: 'Attunement & capacity',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Attuned'),
                  const SizedBox(width: 12),
                  Pips(
                    total: 3,
                    filled: st.attuned,
                    color: Palette.gold,
                    size: 20,
                  ),
                  Text('${st.attuned}/3'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Carrying ${st.carried.toStringAsFixed(1)} / ${st.capacity.toStringAsFixed(0)} lb',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              HpBar(
                fraction: pct,
                color: pct > 0.66 ? Palette.warn : Palette.gold,
                height: 12,
              ),
              const SizedBox(height: 4),
              Text(
                'Push, drag or lift up to ${(st.scores[Ability.str]! * 30)} lb',
                style: const TextStyle(fontSize: 12, color: Palette.textDim),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Variant encumbrance'),
                subtitle: const Text(
                  'Off by default. Slows you when heavily loaded.',
                ),
                value: c.variantEncumbrance,
                onChanged: (v) => bloc.add(FlagSet('variantEncumbrance', v)),
              ),
            ],
          ),
        );

        final wallet = Panel(
          title: 'Currency',
          trailing: Text(
            '${c.wallet.totalGp.toStringAsFixed(2)} gp total',
            style: const TextStyle(color: Palette.textDim),
          ),
          child: Column(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _coin(context, 'CP', c.wallet.cp, (v) => CoinsChanged(cp: v)),
                  _coin(context, 'SP', c.wallet.sp, (v) => CoinsChanged(sp: v)),
                  _coin(context, 'EP', c.wallet.ep, (v) => CoinsChanged(ep: v)),
                  _coin(context, 'GP', c.wallet.gp, (v) => CoinsChanged(gp: v)),
                  _coin(context, 'PP', c.wallet.pp, (v) => CoinsChanged(pp: v)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('1 PP to GP'),
                    onPressed: () => bloc.add(const CoinConverted('pp')),
                  ),
                  ActionChip(
                    label: const Text('1 GP to SP'),
                    onPressed: () => bloc.add(const CoinConverted('gp')),
                  ),
                  ActionChip(
                    label: const Text('1 SP to CP'),
                    onPressed: () => bloc.add(const CoinConverted('sp')),
                  ),
                ],
              ),
            ],
          ),
        );

        final equipped = c.items.where((i) => i.equipped).toList();
        final carried = c.items.where((i) => !i.equipped).toList();
        final list = Panel(
          title: 'Equipment',
          parchment: true,
          trailing: IconButton.filled(
            style: framedIconStyle(filled: true),
            tooltip: 'Add item',
            icon: const Icon(Icons.add),
            onPressed: () => _add(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (c.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No items yet. Tap + to add.'),
                ),
              if (equipped.isNotEmpty)
                const Text(
                  'Equipped',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              for (final i in equipped) _ItemTile(item: i),
              if (carried.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Carried',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              for (final i in carried) _ItemTile(item: i),
            ],
          ),
        );

        final warnings = st.warnings.isEmpty
            ? const SizedBox.shrink()
            : Panel(
                title: 'Heads up',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final w in st.warnings)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(w),
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
                      top,
                      const SizedBox(height: 12),
                      wallet,
                      const SizedBox(height: 12),
                      warnings,
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: list),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            top,
            const SizedBox(height: 12),
            list,
            const SizedBox(height: 12),
            wallet,
            const SizedBox(height: 12),
            warnings,
          ],
        );
      },
    );
  }

  Widget _coin(
    BuildContext context,
    String label,
    int value,
    CharacterAction Function(int) make,
  ) {
    return SizedBox(
      width: 92,
      child: OutlinedButton(
        onPressed: () async {
          final v = await askNumber(context, label, initial: value);
          if (v != null && context.mounted) {
            context.read<CharacterBloc>().add(make(v));
          }
        },
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(
              '$value',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final bloc = context.read<CharacterBloc>();
    final item = await showModalBottomSheet<Item>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _ItemPicker(),
    );
    if (item != null) {
      bloc.add(
        ItemAdded(
          Item(
            id: newId('item'),
            name: item.name,
            type: item.type,
            quantity: item.quantity,
            weight: item.weight,
            valueGp: item.valueGp,
            description: item.description,
            requiresAttunement: item.requiresAttunement,
            cursed: item.cursed,
            rarity: item.rarity,
            magicBonus: item.magicBonus,
            armor: item.armor,
            weapon: item.weapon,
            effects: item.effects,
            healAmount: item.healAmount,
            source: item.source,
          ),
        ),
      );
    }
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CharacterBloc>();
    final i = item;
    final used = i.quantity <= 0;
    final tags = [
      i.type.name,
      if (i.armor != null) 'AC ${i.armor!.baseAc + i.magicBonusActive}',
      if (i.type == ItemType.shield) '+${2 + i.magicBonusActive} AC',
      if (i.weight > 0)
        '${(i.weight * i.quantity).toStringAsFixed(i.weight * i.quantity == (i.weight * i.quantity).roundToDouble() ? 0 : 1)} lb',
      if (i.rarity.isNotEmpty) i.rarity,
      if (i.requiresAttunement) i.attuned ? 'attuned' : 'needs attunement',
      for (final e in i.effects)
        if (e.target == StatTarget.note)
          e.note
        else
          '${e.target.label}${e.subject.isEmpty ? '' : ' (${e.subject})'} ${e.mode == EffectMode.set ? '=' : (e.value >= 0 ? '+' : '')}${e.value}',
    ];
    return Opacity(
      opacity: used ? 0.45 : 1,
      // The equipment list sits on a parchment panel, so the tile needs dark
      // ink instead of the theme's light text.
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        textColor: Palette.ink,
        iconColor: Palette.ink,
        title: Text(
          '${i.name}${i.quantity != 1 ? ' ×${i.quantity}' : ''}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(tags.join(' · '), style: const TextStyle(fontSize: 12)),
        onTap: () => showWhy(
          context,
          i.name,
          [
            if (i.description.isNotEmpty) i.description,
            if (i.weapon != null)
              '${i.weapon!.damageDice} ${i.weapon!.damageType}${i.weapon!.properties.isEmpty ? '' : ' (${i.weapon!.properties.join(', ')})'}',
            if (i.armor != null)
              'Armor: ${i.armor!.category.name}${i.armor!.strReq > 0 ? ', STR ${i.armor!.strReq}' : ''}${i.armor!.stealthDisadv ? ', stealth disadvantage' : ''}',
            'Value: ${i.valueGp} gp',
          ].join('\n'),
        ),
        onLongPress: () async {
          final choice = await showModalBottomSheet<String>(
            context: context,
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(
                      i.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (i.type == ItemType.weapon)
                    ListTile(
                      leading: const Icon(Icons.school),
                      title: Text(
                        'Proficiency: ${i.proficientOverride == null ? 'automatic' : (i.proficientOverride! ? 'proficient' : 'not proficient')}',
                      ),
                      subtitle: const Text(
                        'Tap to cycle automatic / proficient / not',
                      ),
                      onTap: () => Navigator.pop(ctx, 'prof'),
                    ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Delete'),
                    onTap: () => Navigator.pop(ctx, 'delete'),
                  ),
                ],
              ),
            ),
          );
          if (!context.mounted) return;
          if (choice == 'prof') {
            bloc.add(WeaponProficiencyCycled(i.id));
          } else if (choice == 'delete' &&
              await confirm(context, 'Delete ${i.name}?', yes: 'Delete') &&
              context.mounted) {
            bloc.add(ItemRemoved(i.id));
          }
        },
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (i.type == ItemType.consumable)
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(56, 40)),
                onPressed: used
                    ? null
                    : () async {
                        int? roll;
                        if (i.healAmount != null) {
                          roll = await askNumber(
                            context,
                            '${i.name}: enter healing rolled',
                            initial: i.healAmount,
                            confirm: 'Use',
                          );
                          if (roll == null) return;
                        }
                        bloc.add(ConsumableUsed(i.id, healRoll: roll));
                      },
                child: const Text('Use'),
              ),
            if (i.type == ItemType.ammo ||
                i.type == ItemType.gear && i.quantity > 1) ...[
              IconButton(
                color: Palette.ink,
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: 'One less',
                onPressed: () => bloc.add(ItemQuantityChanged(i.id, -1)),
              ),
            ],
            if (i.requiresAttunement)
              IconButton(
                color: Palette.ink,
                tooltip: i.attuned ? 'End attunement' : 'Attune',
                icon: Icon(i.attuned ? Icons.link : Icons.link_off),
                onPressed: () async {
                  if (i.attuned && i.cursed) {
                    if (!await confirm(
                      context,
                      '${i.name} is cursed. End attunement anyway?',
                      yes: 'End',
                    )) {
                      return;
                    }
                    bloc.add(AttunementToggled(i.id, confirmCursed: true));
                  } else {
                    bloc.add(AttunementToggled(i.id));
                  }
                },
              ),
            if (i.equippable)
              Switch(
                value: i.equipped,
                onChanged: (_) => bloc.add(ItemEquippedToggled(i.id)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemPicker extends StatefulWidget {
  const _ItemPicker();
  @override
  State<_ItemPicker> createState() => _ItemPickerState();
}

class _ItemPickerState extends State<_ItemPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = srdItems
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
                hintText: 'Search SRD items',
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
                  title: const Text('Create a custom item'),
                  onTap: () async {
                    final item = await _custom(context);
                    if (item != null && context.mounted) {
                      Navigator.pop(context, item);
                    }
                  },
                ),
                for (final i in list)
                  ListTile(
                    title: Text(i.name),
                    subtitle: Text(i.type.name),
                    onTap: () => Navigator.pop(context, i),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<Item?> _custom(BuildContext context) {
    final name = TextEditingController();
    final weight = TextEditingController(text: '0');
    final desc = TextEditingController();
    final bonus = TextEditingController(text: '0');
    var type = ItemType.gear;
    var attune = false;
    StatTarget? target;
    var effectValue = 1;
    var setMode = false;
    var subject = '';
    final noteText = TextEditingController();
    return showDialog<Item>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Custom item'),
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
                DropdownButtonFormField<ItemType>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    for (final t in ItemType.values)
                      DropdownMenuItem(value: t, child: Text(t.name)),
                  ],
                  onChanged: (v) => set(() => type = v ?? ItemType.gear),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: weight,
                  decoration: const InputDecoration(labelText: 'Weight (lb)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bonus,
                  decoration: const InputDecoration(
                    labelText: 'Magic bonus (armor, shield, weapon)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: desc,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                CheckboxListTile(
                  value: attune,
                  onChanged: (v) => set(() => attune = v ?? false),
                  title: const Text('Requires attunement'),
                  dense: true,
                ),
                DropdownButtonFormField<StatTarget?>(
                  initialValue: target,
                  decoration: const InputDecoration(
                    labelText: 'Effect while equipped (optional)',
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    for (final t in StatTarget.values)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: (v) => set(() => target = v),
                ),
                if (target == StatTarget.save)
                  DropdownButtonFormField<String>(
                    initialValue: subject.isEmpty ? Ability.str.name : subject,
                    decoration: const InputDecoration(labelText: 'Which save'),
                    items: [
                      for (final a in Ability.values)
                        DropdownMenuItem(value: a.name, child: Text(a.label)),
                    ],
                    onChanged: (v) => set(() => subject = v ?? ''),
                  ),
                if (target == StatTarget.skill)
                  DropdownButtonFormField<String>(
                    initialValue: subject.isEmpty
                        ? Skill.acrobatics.name
                        : subject,
                    decoration: const InputDecoration(labelText: 'Which skill'),
                    items: [
                      for (final k in Skill.values)
                        DropdownMenuItem(value: k.name, child: Text(k.label)),
                    ],
                    onChanged: (v) => set(() => subject = v ?? ''),
                  ),
                if (target == StatTarget.note)
                  TextField(
                    controller: noteText,
                    decoration: const InputDecoration(
                      labelText: 'Note, e.g. Resistance to fire',
                    ),
                  ),
                if (target != null && target != StatTarget.note)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(labelText: 'Value'),
                          keyboardType: const TextInputType.numberWithOptions(
                            signed: true,
                          ),
                          controller: TextEditingController(
                            text: '$effectValue',
                          ),
                          onChanged: (v) =>
                              effectValue = int.tryParse(v) ?? effectValue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Set (if higher)'),
                        selected: setMode,
                        onSelected: (v) => set(() => setMode = v),
                      ),
                    ],
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
                  Item(
                    id: newId('item'),
                    name: name.text.trim(),
                    type: type,
                    weight: double.tryParse(weight.text) ?? 0,
                    description: desc.text,
                    requiresAttunement: attune,
                    magicBonus: int.tryParse(bonus.text) ?? 0,
                    effects: target == null
                        ? const []
                        : [
                            Effect(
                              target: target!,
                              mode: setMode ? EffectMode.set : EffectMode.add,
                              value: target == StatTarget.note
                                  ? 0
                                  : effectValue,
                              note: noteText.text.trim(),
                              subject: switch (target!) {
                                StatTarget.save =>
                                  subject.isEmpty ? Ability.str.name : subject,
                                StatTarget.skill =>
                                  subject.isEmpty
                                      ? Skill.acrobatics.name
                                      : subject,
                                _ => '',
                              },
                            ),
                          ],
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
