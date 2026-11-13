import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/character_factory.dart';
import '../../domain/class_templates.dart';
import '../../domain/models.dart';
import '../../domain/repository.dart';
import '../../domain/srd_data.dart';
import '../character/feature_editor.dart';

const _starterSpells = <String, List<String>>{
  'Sorcerer': [
    'Fire Bolt',
    'Light',
    'Mage Hand',
    'Minor Illusion',
    'Magic Missile',
    'Shield',
    'Mage Armor',
    'Misty Step',
    'Fireball',
  ],
  'Wizard': [
    'Fire Bolt',
    'Light',
    'Mage Hand',
    'Minor Illusion',
    'Magic Missile',
    'Shield',
    'Detect Magic',
    'Misty Step',
    'Fireball',
  ],
  'Cleric': [
    'Sacred Flame',
    'Guidance',
    'Light',
    'Cure Wounds',
    'Healing Word',
    'Bless',
    'Hold Person',
  ],
  'Druid': [
    'Guidance',
    'Druidcraft',
    'Cure Wounds',
    'Healing Word',
    'Thunderwave',
  ],
  'Bard': [
    'Vicious Mockery',
    'Minor Illusion',
    'Healing Word',
    'Charm Person',
    'Hold Person',
  ],
  'Warlock': [
    'Eldritch Blast',
    'Minor Illusion',
    'Charm Person',
    'Hold Person',
  ],
  'Paladin': ['Bless', 'Cure Wounds'],
  'Ranger': ['Cure Wounds'],
};

class CreateCharacterScreen extends StatefulWidget {
  const CreateCharacterScreen({super.key});
  @override
  State<CreateCharacterScreen> createState() => _CreateCharacterScreenState();
}

class _CreateCharacterScreenState extends State<CreateCharacterScreen> {
  final _name = TextEditingController();
  final _race = TextEditingController();
  final _background = TextEditingController();
  final _subclass = TextEditingController();
  String _class = 'Sorcerer';
  int _level = 1;
  int _speed = 30;
  final Map<Ability, int> _scores = Map.of(standardArray);
  final Set<Skill> _skills = {};
  final List<Feature> _traits = [];
  bool _starterSpellsOn = true;
  bool _starterGear = true;
  bool _saving = false;

  ClassTemplate get _t => classTemplates[_class]!;

  @override
  void dispose() {
    _name.dispose();
    _race.dispose();
    _background.dispose();
    _subclass.dispose();
    super.dispose();
  }

  List<Spell> _spells() {
    if (!_starterSpellsOn || _t.caster == CasterType.none) return const [];
    final names = _starterSpells[_class] ?? const [];
    final maxLevel = (_level + 1) ~/ 2;
    return [
      for (final n in names)
        ...srdSpells.where(
          (s) =>
              s.name == n &&
              s.level <=
                  (_t.caster == CasterType.half
                      ? (maxLevel / 2).ceil()
                      : maxLevel),
        ),
    ];
  }

  Future<void> _addTrait() async {
    final f = (await showFeatureEditor(context))?.feature;
    if (f != null) setState(() => _traits.add(f));
  }

  Future<void> _editTrait(int index) async {
    final result = await showFeatureEditor(context, initial: _traits[index]);
    if (result == null) return;
    setState(() {
      if (result.delete) {
        _traits.removeAt(index);
      } else {
        _traits[index] = result.feature!;
      }
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give your character a name.')),
      );
      return;
    }
    setState(() => _saving = true);
    final repo = context.read<CharacterRepository>();
    final router = GoRouter.of(context);
    final c = createCharacter(
      name: _name.text,
      race: _race.text.trim(),
      background: _background.text.trim(),
      className: _class,
      subclass: _subclass.text.trim(),
      level: _level,
      abilities: _scores,
      skills: _skills,
      spells: _spells(),
      starterGear: _starterGear,
      baseSpeed: _speed,
      traits: _traits,
    );
    await repo.create(c);
    router.go('/c/${c.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New character')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _race,
            decoration: const InputDecoration(labelText: 'Race / species'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _background,
            decoration: const InputDecoration(
              labelText: 'Background (optional)',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _class,
            decoration: const InputDecoration(labelText: 'Class'),
            items: [
              for (final n in classTemplates.keys)
                DropdownMenuItem(value: n, child: Text(n)),
            ],
            onChanged: (v) => setState(() {
              _class = v ?? _class;
              _skills.clear();
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subclass,
            decoration: const InputDecoration(labelText: 'Subclass (optional)'),
          ),
          const SectionLabel('Traits (optional)'),
          const Text(
            'Species, background or subclass traits, typed in by hand. '
            'Pin one to show it on the Sheet.',
            style: TextStyle(color: Palette.textDim),
          ),
          for (var i = 0; i < _traits.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_traits[i].name),
              subtitle: Text(
                [
                  _traits[i].source.label,
                  if (_traits[i].pinned.isNotEmpty) _traits[i].pinned,
                ].join(' · '),
              ),
              trailing: _traits[i].pinned.isNotEmpty
                  ? const Icon(Icons.push_pin, size: 16)
                  : null,
              onTap: () => _editTrait(i),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add trait'),
              onPressed: _addTrait,
            ),
          ),
          const SectionLabel('Base speed'),
          Wrap(
            spacing: 8,
            children: [
              for (final v in const [25, 30, 35])
                ChoiceChip(
                  label: Text('$v ft'),
                  selected: _speed == v,
                  onSelected: (_) => setState(() => _speed = v),
                ),
            ],
          ),
          const SectionLabel('Level'),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _level.toDouble(),
                  min: 1,
                  max: 20,
                  divisions: 19,
                  label: '$_level',
                  onChanged: (v) => setState(() => _level = v.round()),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '$_level',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SectionLabel('Ability scores'),
          const Text(
            'Starts from the standard array (15, 14, 13, 12, 10, 8). Adjust to taste.',
            style: TextStyle(color: Palette.textDim),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in Ability.values)
                SizedBox(
                  width: 150,
                  child: Panel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            a.abbr,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.remove),
                          onPressed: () => setState(
                            () => _scores[a] = (_scores[a]! - 1).clamp(3, 20),
                          ),
                        ),
                        Text(
                          '${_scores[a]}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.add),
                          onPressed: () => setState(
                            () => _scores[a] = (_scores[a]! + 1).clamp(3, 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (_t.skillList.isNotEmpty) ...[
            SectionLabel('Skills (choose ${_t.skillChoices})'),
            Wrap(
              spacing: 8,
              children: [
                for (final s in _t.skillList)
                  FilterChip(
                    label: Text(s.label),
                    selected: _skills.contains(s),
                    onSelected: (v) => setState(() {
                      if (v) {
                        if (_skills.length < _t.skillChoices) _skills.add(s);
                      } else {
                        _skills.remove(s);
                      }
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (_t.caster != CasterType.none)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Add a few starter spells'),
              subtitle: const Text('SRD spells you can edit later'),
              value: _starterSpellsOn,
              onChanged: (v) => setState(() => _starterSpellsOn = v),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Add starter gear'),
            value: _starterGear,
            onChanged: (v) => setState(() => _starterGear = v),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Create character'),
          ),
        ],
      ),
    );
  }
}
