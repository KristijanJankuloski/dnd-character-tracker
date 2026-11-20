import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../character/character_bloc.dart';
import '../character/character_event.dart';
import 'feat_editor.dart';
import 'feat_picker.dart';

/// The character's feats, listed in the order they were taken. Tap one to
/// edit or delete it; Add feat opens the catalogue picker (custom feats too).
class FeatsPanel extends StatelessWidget {
  const FeatsPanel({super.key, required this.state});
  final CharacterLoaded state;

  Future<void> _add(BuildContext context) async {
    final bloc = context.read<CharacterBloc>();
    final taken = {
      for (final f in state.character.feats) f.name.trim().toLowerCase(),
    };
    final picked = await showModalBottomSheet<Feat>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FeatPicker(taken: taken),
    );
    if (picked != null) bloc.add(FeatAdded(picked));
  }

  Future<void> _edit(BuildContext context, Feat f) async {
    final bloc = context.read<CharacterBloc>();
    final result = await showFeatEditor(
      context,
      initial: f,
      nameError: (n) =>
          state.character.feats.any(
            (x) =>
                x.id != f.id &&
                x.name.trim().toLowerCase() == n.trim().toLowerCase(),
          )
          ? 'This character already has a feat with this name'
          : null,
    );
    if (result == null) return;
    bloc.add(
      result.delete ? FeatRemoved(f.id) : FeatEdited(f.id, result.feat!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feats = state.character.feats;
    return Panel(
      title: 'Feats',
      trailing: TextButton.icon(
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add feat'),
        onPressed: () => _add(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (feats.isEmpty)
            const Text(
              'No feats yet.',
              style: TextStyle(color: Palette.textDim),
            ),
          for (final f in feats)
            InkWell(
              onTap: () => _edit(context, f),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (f.prerequisite.isNotEmpty)
                      Text(
                        'Prerequisite: ${f.prerequisite}',
                        style: const TextStyle(
                          color: Palette.textDim,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    if (f.text.isNotEmpty)
                      Text(
                        f.text,
                        style: const TextStyle(color: Palette.textDim),
                      ),
                    if (f.source.isNotEmpty)
                      Text(
                        f.source,
                        style: const TextStyle(
                          color: Palette.goldDim,
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
  }
}
