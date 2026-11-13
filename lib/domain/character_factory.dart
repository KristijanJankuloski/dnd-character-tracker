/// Builds a new character from a class template.
library;

import 'package:uuid/uuid.dart';

import 'class_templates.dart';
import 'models.dart';
import 'rules.dart';
import 'srd_data.dart';

int _idCounter = 0;
String newId([String prefix = 'id']) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

Character createCharacter({
  required String name,
  required String race,
  required String className,
  required int level,
  required Map<Ability, int> abilities,
  String subclass = '',
  String background = '',
  Set<Skill> skills = const {},
  List<Spell> spells = const [],
  bool starterGear = true,
  int baseSpeed = 30,
  List<Feature> traits = const [],
}) {
  final t = classTemplates[className]!;
  var c = Character(
    id: const Uuid().v4(),
    name: name.trim().isEmpty ? 'Unnamed' : name.trim(),
    race: race,
    background: background,
    classes: [ClassLevel(className, level, subclass: subclass)],
    abilities: abilities,
    saveProfs: t.saves,
    armorProfs: t.armor,
    weaponProfs: t.weaponProfs,
    baseSpeed: baseSpeed,
    skills: {for (final s in skills) s: Proficiency.proficient},
    hpCurrent: 1,
    features: [...t.features, ...traits],
    spells: spells,
    flags: {
      if (className == 'Sorcerer' &&
          subclass.toLowerCase().contains('draconic'))
        'draconicResilience',
    },
  );
  final stats = resolveStats(c);
  final resources = [
    for (final rt in t.resources)
      rt.build(
        className,
        (r) => r.maxFormula.resolve(
          level: level,
          prof: stats.proficiency,
          mod: (a) => stats.mods[a]!,
        ),
      ),
  ];
  c = c.copyWith(resources: resources);
  if (starterGear) {
    final names = [
      'Dagger',
      'Backpack',
      'Rations (1 day)',
      'Potion of Healing',
    ];
    final gear = [
      for (final n in names) srdItems.firstWhere((i) => i.name == n),
      if (t.armor.contains('heavy'))
        srdItems.firstWhere((i) => i.name == 'Chain Mail'),
      if (t.armor.contains('shields'))
        srdItems.firstWhere((i) => i.name == 'Shield'),
      if (!t.armor.contains('heavy') && t.armor.contains('light'))
        srdItems.firstWhere((i) => i.name == 'Leather'),
      if (const {'Sorcerer', 'Wizard', 'Warlock'}.contains(className))
        srdItems.firstWhere((i) => i.name == 'Arcane Focus'),
    ];
    c = c.copyWith(
      items: [
        for (final g in gear)
          Item(
            id: newId('item'),
            name: g.name,
            type: g.type,
            quantity: g.quantity,
            weight: g.weight,
            valueGp: g.valueGp,
            description: g.description,
            armor: g.armor,
            weapon: g.weapon,
            healAmount: g.healAmount,
            source: 'SRD',
            equipped:
                g.type == ItemType.weapon ||
                g.type == ItemType.armor ||
                g.type == ItemType.shield,
          ),
      ],
      wallet: const Wallet(gp: 15),
    );
  }
  return c.copyWith(hpCurrent: resolveStats(c).maxHp);
}

/// Standard array for quick creation.
const Map<Ability, int> standardArray = {
  Ability.str: 8,
  Ability.dex: 14,
  Ability.con: 13,
  Ability.int_: 10,
  Ability.wis: 12,
  Ability.cha: 15,
};
