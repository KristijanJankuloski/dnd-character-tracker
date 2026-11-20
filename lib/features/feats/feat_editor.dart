import 'package:flutter/material.dart';

import '../../domain/character_factory.dart';
import '../../domain/models.dart';

/// What the player did in the feat editor: saved a feat or deleted it.
class FeatEdit {
  const FeatEdit.save(Feat f) : feat = f, delete = false;
  const FeatEdit.delete() : feat = null, delete = true;

  final Feat? feat;
  final bool delete;
}

/// Opens the feat editor. Returns null when cancelled. A Delete button is
/// offered only when editing an existing feat ([initial] set). [nameError]
/// may refuse a name (for example one already taken); it is shown under the
/// Name field and blocks Save.
Future<FeatEdit?> showFeatEditor(
  BuildContext context, {
  Feat? initial,
  String? Function(String name)? nameError,
}) => showDialog<FeatEdit>(
  context: context,
  builder: (_) => _FeatEditorDialog(initial: initial, nameError: nameError),
);

class _FeatEditorDialog extends StatefulWidget {
  const _FeatEditorDialog({this.initial, this.nameError});
  final Feat? initial;
  final String? Function(String name)? nameError;

  @override
  State<_FeatEditorDialog> createState() => _FeatEditorDialogState();
}

class _FeatEditorDialogState extends State<_FeatEditorDialog> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _prereq = TextEditingController(
    text: widget.initial?.prerequisite,
  );
  late final _source = TextEditingController(text: widget.initial?.source);
  late final _text = TextEditingController(text: widget.initial?.text);
  String? _problem;

  @override
  void dispose() {
    _name.dispose();
    _prereq.dispose();
    _source.dispose();
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final problem = name.isEmpty
        ? 'Give the feat a name.'
        : widget.nameError?.call(name);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Navigator.pop(
      context,
      FeatEdit.save(
        Feat(
          id: widget.initial?.id ?? newId('feat'),
          name: name,
          text: _text.text.trim(),
          prerequisite: _prereq.text.trim(),
          source: _source.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return AlertDialog(
      title: Text(editing ? 'Edit feat' : 'New feat'),
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
                decoration: InputDecoration(
                  labelText: 'Name',
                  errorText: _problem,
                ),
                onChanged: (_) {
                  if (_problem != null) setState(() => _problem = null);
                },
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _prereq,
                decoration: const InputDecoration(
                  labelText: 'Prerequisite (optional)',
                  hintText: 'e.g. Strength 13 or higher',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _source,
                decoration: const InputDecoration(
                  labelText: 'Source (optional)',
                  hintText: 'e.g. PHB p. 165, Homebrew',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _text,
                decoration: const InputDecoration(labelText: 'Description'),
                minLines: 3,
                maxLines: 10,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (editing)
          TextButton(
            onPressed: () => Navigator.pop(context, const FeatEdit.delete()),
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
