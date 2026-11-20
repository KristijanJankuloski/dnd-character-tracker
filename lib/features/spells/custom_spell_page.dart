import 'package:flutter/material.dart';

import '../../domain/character_factory.dart';
import '../../domain/models.dart';
import 'spell_detail_sheet.dart';

/// Full-screen form for a hand-made spell. It carries every field an imported
/// spell has. Pops the new [Spell] when saved.
class CustomSpellPage extends StatefulWidget {
  const CustomSpellPage({super.key});

  static Future<Spell?> open(BuildContext context) => Navigator.of(context)
      .push<Spell>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const CustomSpellPage(),
        ),
      );

  @override
  State<CustomSpellPage> createState() => _CustomSpellPageState();
}

class _CustomSpellPageState extends State<CustomSpellPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _school = TextEditingController();
  final _castingText = TextEditingController();
  final _range = TextEditingController();
  final _components = TextEditingController();
  final _duration = TextEditingController();
  final _damage = TextEditingController();
  final _damageType = TextEditingController();
  final _areaSize = TextEditingController();
  final _text = TextEditingController();
  final _higher = TextEditingController();
  int _level = 1;
  CastingTime _time = CastingTime.action;
  bool _conc = false;
  bool _ritual = false;
  bool _attack = false;
  bool _alwaysPrepared = false;
  Ability? _save;
  AreaShape _shape = AreaShape.none;

  @override
  void dispose() {
    for (final c in [
      _name,
      _school,
      _castingText,
      _range,
      _components,
      _duration,
      _damage,
      _damageType,
      _areaSize,
      _text,
      _higher,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _hasSize =>
      _shape != AreaShape.none && _shape != AreaShape.singleTarget;

  void _submit() {
    if (!_form.currentState!.validate()) return;
    String t(TextEditingController c) => c.text.trim();
    Navigator.pop(
      context,
      Spell(
        id: newId('spell'),
        name: t(_name),
        level: _level,
        castingTime: _time,
        castingTimeText: t(_castingText),
        concentration: _conc,
        ritual: _ritual,
        alwaysPrepared: _alwaysPrepared,
        school: t(_school),
        range: t(_range),
        components: t(_components),
        duration: t(_duration),
        damage: t(_damage),
        damageType: t(_damageType),
        save: _save,
        attackRoll: _attack,
        areaShape: _shape,
        areaSize: _hasSize ? t(_areaSize) : '',
        text: t(_text),
        higherLevels: t(_higher),
      ),
    );
  }

  Widget _gap() => const SizedBox(height: 12);

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom spell'),
        actions: [TextButton(onPressed: _submit, child: const Text('Add'))],
      ),
      // The body scrolls and pads for the keyboard itself.
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              _gap(),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _level,
                      decoration: const InputDecoration(labelText: 'Level'),
                      items: [
                        for (var i = 0; i <= 9; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(i == 0 ? 'Cantrip' : 'Level $i'),
                          ),
                      ],
                      onChanged: (v) => setState(() => _level = v ?? 1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _school,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'School',
                        hintText: 'Evocation',
                      ),
                    ),
                  ),
                ],
              ),
              _section('Casting'),
              DropdownButtonFormField<CastingTime>(
                initialValue: _time,
                decoration: const InputDecoration(labelText: 'Casting time'),
                items: [
                  for (final t in CastingTime.values)
                    DropdownMenuItem(value: t, child: Text(castingLabel(t))),
                ],
                onChanged: (v) =>
                    setState(() => _time = v ?? CastingTime.action),
              ),
              if (_time == CastingTime.other) ...[
                _gap(),
                TextFormField(
                  controller: _castingText,
                  decoration: const InputDecoration(
                    labelText: 'Casting time as written',
                    hintText: '1 minute',
                  ),
                ),
              ],
              _gap(),
              TextFormField(
                controller: _range,
                decoration: InputDecoration(
                  labelText: 'Range',
                  hintText: 'Self, Touch, 30 ft...',
                  suffixIcon: PopupMenuButton<String>(
                    icon: const Icon(Icons.arrow_drop_down),
                    onSelected: (v) => _range.text = v,
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
              _gap(),
              TextFormField(
                controller: _components,
                decoration: const InputDecoration(
                  labelText: 'Components',
                  hintText: 'V, S, M (a pinch of sulfur)',
                ),
              ),
              _gap(),
              TextFormField(
                controller: _duration,
                decoration: const InputDecoration(
                  labelText: 'Duration',
                  hintText: 'Instantaneous, 1 minute...',
                ),
              ),
              CheckboxListTile(
                value: _conc,
                onChanged: (v) => setState(() => _conc = v ?? false),
                title: const Text('Concentration'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              CheckboxListTile(
                value: _ritual,
                onChanged: (v) => setState(() => _ritual = v ?? false),
                title: const Text('Ritual'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              CheckboxListTile(
                value: _alwaysPrepared,
                onChanged: (v) => setState(() => _alwaysPrepared = v ?? false),
                title: const Text('Always prepared'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              _section('Effect'),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _damage,
                      decoration: const InputDecoration(
                        labelText: 'Damage',
                        hintText: '8d6',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _damageType,
                      decoration: const InputDecoration(
                        labelText: 'Damage type',
                        hintText: 'fire',
                      ),
                    ),
                  ),
                ],
              ),
              _gap(),
              DropdownButtonFormField<Ability?>(
                initialValue: _save,
                decoration: const InputDecoration(labelText: 'Saving throw'),
                items: [
                  const DropdownMenuItem<Ability?>(
                    value: null,
                    child: Text('None'),
                  ),
                  for (final a in Ability.values)
                    DropdownMenuItem<Ability?>(value: a, child: Text(a.label)),
                ],
                onChanged: (v) => setState(() => _save = v),
              ),
              CheckboxListTile(
                value: _attack,
                onChanged: (v) => setState(() => _attack = v ?? false),
                title: const Text('Spell attack roll'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              DropdownButtonFormField<AreaShape>(
                initialValue: _shape,
                decoration: const InputDecoration(labelText: 'Area / target'),
                items: [
                  for (final a in AreaShape.values)
                    DropdownMenuItem(value: a, child: Text(a.label)),
                ],
                onChanged: (v) =>
                    setState(() => _shape = v ?? AreaShape.none),
              ),
              if (_hasSize) ...[
                _gap(),
                TextFormField(
                  controller: _areaSize,
                  decoration: const InputDecoration(
                    labelText: 'Size (optional)',
                    hintText: '20 ft',
                  ),
                ),
              ],
              _section('Description'),
              TextFormField(
                controller: _text,
                minLines: 4,
                maxLines: 10,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                ),
              ),
              _gap(),
              TextFormField(
                controller: _higher,
                minLines: 2,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'At higher levels',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _submit, child: const Text('Add spell')),
            ],
          ),
        ),
      ),
    );
  }
}
