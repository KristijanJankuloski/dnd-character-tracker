import 'package:flutter/material.dart';

import '../../domain/models.dart';

/// What the player did in the trait editor: saved a trait or deleted it.
class FeatureEdit {
  const FeatureEdit.save(Feature f) : feature = f, delete = false;
  const FeatureEdit.delete() : feature = null, delete = true;

  final Feature? feature;
  final bool delete;
}

/// Opens the trait editor. Returns null when cancelled. A Delete button is
/// offered only when editing an existing trait ([initial] set).
Future<FeatureEdit?> showFeatureEditor(
  BuildContext context, {
  Feature? initial,
}) => showDialog<FeatureEdit>(
  context: context,
  builder: (_) => _FeatureEditorDialog(initial: initial),
);

class _FeatureEditorDialog extends StatefulWidget {
  const _FeatureEditorDialog({this.initial});
  final Feature? initial;

  @override
  State<_FeatureEditorDialog> createState() => _FeatureEditorDialogState();
}

class _FeatureEditorDialogState extends State<_FeatureEditorDialog> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _text = TextEditingController(text: widget.initial?.text);
  late final _pinned = TextEditingController(text: widget.initial?.pinned);
  late FeatureSource _source = widget.initial?.source ?? FeatureSource.species;

  @override
  void dispose() {
    _name.dispose();
    _text.dispose();
    _pinned.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      FeatureEdit.save(
        Feature(
          name,
          _text.text.trim(),
          source: _source,
          pinned: _pinned.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return AlertDialog(
      title: Text(editing ? 'Edit trait' : 'New trait'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                autofocus: !editing,
                decoration: const InputDecoration(labelText: 'Name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final s in FeatureSource.values)
                    ChoiceChip(
                      label: Text(s.label),
                      selected: _source == s,
                      onSelected: (_) => setState(() => _source = s),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _text,
                decoration: const InputDecoration(labelText: 'Description'),
                minLines: 2,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pinned,
                decoration: const InputDecoration(
                  labelText: 'Show in Senses & resistances as (optional)',
                  hintText: 'e.g. Fire resistance, Darkvision 120 ft',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (editing)
          TextButton(
            onPressed: () => Navigator.pop(context, const FeatureEdit.delete()),
            child: const Text('Delete'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
