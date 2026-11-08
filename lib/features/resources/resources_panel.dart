import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/actions.dart' as act;
import '../../domain/models.dart';
import '../../domain/tables.dart';
import '../character/character_bloc.dart';
import '../character/character_event.dart';

String rechargeLabel(Resource r) {
  final kinds = r.rules.map((e) => e.when).toSet();
  if (kinds.contains(RechargeWhen.shortRest)) return 'short rest';
  if (kinds.contains(RechargeWhen.longRest)) return 'long rest';
  return 'manual';
}

/// Class resources: tap a pip to spend or restore, long-press for more.
class ResourcesPanel extends StatelessWidget {
  const ResourcesPanel({super.key, required this.state, this.limit});
  final CharacterLoaded state;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final c = state.character;
    var visible = c.resources.where((r) => c.level >= r.minLevel).toList();
    if (limit != null && visible.length > limit!) {
      visible = visible.sublist(0, limit!);
    }
    if (visible.isEmpty) {
      return const Text(
        'No class resources. Add one in Journal > Settings.',
        style: TextStyle(color: Palette.textDim),
      );
    }
    return Column(
      children: [
        for (final r in visible) ResourceRow(state: state, resource: r),
      ],
    );
  }
}

class ResourceRow extends StatelessWidget {
  const ResourceRow({super.key, required this.state, required this.resource});
  final CharacterLoaded state;
  final Resource resource;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CharacterBloc>();
    final r = resource;
    final max = act.resourceMax(state.character, r);
    final unlimited = max >= 99;
    return GestureDetector(
      onLongPress: () => _longPress(context, max),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          r.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        rechargeLabel(r) == 'manual'
                            ? Icons.touch_app
                            : (rechargeLabel(r) == 'short rest'
                                  ? Icons.coffee
                                  : Icons.bedtime),
                        size: 14,
                        color: Palette.textDim,
                        semanticLabel: 'Recharges on ${rechargeLabel(r)}',
                      ),
                    ],
                  ),
                  if (unlimited)
                    const Text(
                      'Unlimited',
                      style: TextStyle(color: Palette.textDim),
                    )
                  else if (r.pool || max > 8)
                    Row(
                      children: [
                        Text(
                          '${r.current} / $max',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Spend ${r.spendCost}',
                          onPressed: () =>
                              bloc.add(ResourceChanged(r.id, -r.spendCost)),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        IconButton(
                          tooltip: 'Restore ${r.spendCost}',
                          onPressed: () =>
                              bloc.add(ResourceChanged(r.id, r.spendCost)),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Pips(
                          total: max,
                          filled: r.current,
                          color: Palette.violet,
                          semanticsLabel: r.name,
                          onSpend: () =>
                              bloc.add(ResourceChanged(r.id, -r.spendCost)),
                          onRestore: () =>
                              bloc.add(ResourceChanged(r.id, r.spendCost)),
                        ),
                        Text('${r.current}/$max'),
                      ],
                    ),
                ],
              ),
            ),
            if (r.toggleable)
              Switch(
                value: r.active,
                onChanged: (_) => bloc.add(ResourceActiveToggled(r.id)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _longPress(BuildContext context, int max) async {
    final bloc = context.read<CharacterBloc>();
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                resource.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (resource.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  resource.note,
                  style: const TextStyle(color: Palette.textDim),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Set exact value'),
              onTap: () => Navigator.pop(ctx, 'set'),
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Restore to full'),
              onTap: () => Navigator.pop(ctx, 'full'),
            ),
            ListTile(
              leading: const Icon(Icons.warning_amber),
              title: const Text('Spend below zero (override)'),
              onTap: () => Navigator.pop(ctx, 'force'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    switch (choice) {
      case 'set':
        final v = await askNumber(
          context,
          'Set ${resource.name}',
          initial: resource.current,
        );
        if (v != null) bloc.add(ResourceSet(resource.id, v));
      case 'full':
        bloc.add(ResourceSet(resource.id, max));
      case 'force':
        bloc.add(
          ResourceChanged(resource.id, -resource.spendCost, force: true),
        );
    }
  }
}

/// Flexible Casting dialog: Sorcery Points to slot and back.
Future<void> showFlexibleCasting(BuildContext context, CharacterLoaded state) {
  final bloc = context.read<CharacterBloc>();
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final sp = state.character.resources
          .where((r) => r.id == 'sorcery-points')
          .firstOrNull;
      return AlertDialog(
        title: const Text('Flexible Casting'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sorcery Points: ${sp?.current ?? 0}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text('Create a slot (costs points):'),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in sorceryPointSlotCost.entries)
                    ActionChip(
                      label: Text('Lv ${e.key}: ${e.value} SP'),
                      onPressed: () {
                        bloc.add(SorceryPointsConverted(e.key, toSlot: true));
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Burn a slot for points (= slot level):'),
              Wrap(
                spacing: 8,
                children: [
                  for (final lvl in state.stats.slotMax.keys)
                    ActionChip(
                      label: Text('Lv $lvl: +$lvl SP'),
                      onPressed: () {
                        bloc.add(SorceryPointsConverted(lvl, toSlot: false));
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
