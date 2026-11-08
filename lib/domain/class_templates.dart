/// Class templates are data: they seed resources, proficiencies and spellcasting
/// when a character is created. Everything stays editable per character.
library;

import 'models.dart';

class ClassTemplate {
  const ClassTemplate({
    required this.name,
    required this.hitDie,
    required this.saves,
    this.caster = CasterType.none,
    this.spellAbility,
    this.spellModel = SpellModel.none,
    this.armor = const {},
    this.resources = const [],
    this.features = const [],
    this.skillChoices = 2,
    this.skillList = const [],
    this.ritualCaster = false,
  });

  final String name;
  final int hitDie;
  final Set<Ability> saves;
  final CasterType caster;
  final Ability? spellAbility;
  final SpellModel spellModel;
  final Set<String> armor;
  final List<ResourceTemplate> resources;
  final List<Feature> features;
  final int skillChoices;
  final List<Skill> skillList;
  final bool ritualCaster;
}

class ResourceTemplate {
  const ResourceTemplate(
    this.id,
    this.name,
    this.formula,
    this.rules, {
    this.minLevel = 1,
    this.spendCost = 1,
    this.pool = false,
    this.toggleable = false,
    this.note = '',
  });
  final String id;
  final String name;
  final MaxFormula formula;
  final List<RechargeRule> rules;
  final int minLevel;
  final int spendCost;
  final bool pool;
  final bool toggleable;
  final String note;

  Resource build(int level, int Function(Resource) maxOf) {
    final r = Resource(
      id: id,
      name: name,
      maxFormula: formula,
      current: 0,
      spendCost: spendCost,
      rules: rules,
      minLevel: minLevel,
      pool: pool,
      toggleable: toggleable,
      note: note,
    );
    return r.copyWith(current: maxOf(r));
  }
}

const _long = [RechargeRule(RechargeWhen.longRest, RechargeAmount.all)];
const _short = [RechargeRule(RechargeWhen.shortRest, RechargeAmount.all)];

final Map<String, ClassTemplate> classTemplates = {
  for (final t in _templates) t.name: t,
};

const List<ClassTemplate> _templates = [
  ClassTemplate(
    name: 'Barbarian',
    hitDie: 12,
    saves: {Ability.str, Ability.con},
    armor: {'light', 'medium', 'shields'},
    skillList: [
      Skill.animalHandling,
      Skill.athletics,
      Skill.intimidation,
      Skill.nature,
      Skill.perception,
      Skill.survival,
    ],
    resources: [
      ResourceTemplate(
        'rage',
        'Rage',
        MaxFormula.table([
          2,
          2,
          3,
          3,
          3,
          4,
          4,
          4,
          4,
          4,
          4,
          5,
          5,
          5,
          5,
          5,
          6,
          6,
          6,
          99,
        ]),
        _long,
        toggleable: true,
        note: 'Rage damage +2 (+3 at 9, +4 at 16). 99 = unlimited.',
      ),
    ],
    features: [
      Feature('Unarmored Defense', 'AC = 10 + DEX + CON while unarmored.'),
    ],
  ),
  ClassTemplate(
    name: 'Bard',
    hitDie: 8,
    saves: {Ability.dex, Ability.cha},
    caster: CasterType.full,
    spellAbility: Ability.cha,
    spellModel: SpellModel.known,
    armor: {'light'},
    skillChoices: 3,
    ritualCaster: true,
    resources: [
      ResourceTemplate(
        'bardic-inspiration',
        'Bardic Inspiration',
        MaxFormula.abilityMod(Ability.cha),
        [
          RechargeRule(RechargeWhen.longRest, RechargeAmount.all),
          RechargeRule(RechargeWhen.shortRest, RechargeAmount.all, minLevel: 5),
        ],
        note: 'Die: d6, d8 at 5, d10 at 10, d12 at 15.',
      ),
    ],
  ),
  ClassTemplate(
    name: 'Cleric',
    hitDie: 8,
    saves: {Ability.wis, Ability.cha},
    caster: CasterType.full,
    spellAbility: Ability.wis,
    spellModel: SpellModel.prepared,
    armor: {'light', 'medium', 'shields'},
    ritualCaster: true,
    skillList: [
      Skill.history,
      Skill.insight,
      Skill.medicine,
      Skill.persuasion,
      Skill.religion,
    ],
    resources: [
      ResourceTemplate(
        'channel-divinity',
        'Channel Divinity',
        MaxFormula.table([
          0,
          1,
          1,
          1,
          1,
          2,
          2,
          2,
          2,
          2,
          2,
          2,
          2,
          2,
          2,
          2,
          2,
          3,
          3,
          3,
        ]),
        _short,
        minLevel: 2,
      ),
    ],
  ),
  ClassTemplate(
    name: 'Druid',
    hitDie: 8,
    saves: {Ability.int_, Ability.wis},
    caster: CasterType.full,
    spellAbility: Ability.wis,
    spellModel: SpellModel.prepared,
    armor: {'light', 'medium', 'shields'},
    ritualCaster: true,
    skillList: [
      Skill.arcana,
      Skill.animalHandling,
      Skill.insight,
      Skill.medicine,
      Skill.nature,
      Skill.perception,
      Skill.religion,
      Skill.survival,
    ],
    resources: [
      ResourceTemplate(
        'wild-shape',
        'Wild Shape',
        MaxFormula.fixed(2),
        _short,
        minLevel: 2,
        toggleable: true,
      ),
    ],
  ),
  ClassTemplate(
    name: 'Fighter',
    hitDie: 10,
    saves: {Ability.str, Ability.con},
    armor: {'light', 'medium', 'heavy', 'shields'},
    skillList: [
      Skill.acrobatics,
      Skill.animalHandling,
      Skill.athletics,
      Skill.history,
      Skill.insight,
      Skill.intimidation,
      Skill.perception,
      Skill.survival,
    ],
    resources: [
      ResourceTemplate(
        'second-wind',
        'Second Wind',
        MaxFormula.fixed(1),
        _short,
        note: 'Heals 1d10 + fighter level.',
      ),
      ResourceTemplate(
        'action-surge',
        'Action Surge',
        MaxFormula.table([
          0,
          1,
          1,
          1,
          1,
          1,
          1,
          1,
          1,
          1,
          1,
          1,
          1,
          1,
          1,
          1,
          2,
          2,
          2,
          2,
        ]),
        _short,
        minLevel: 2,
      ),
      ResourceTemplate(
        'superiority-dice',
        'Superiority Dice',
        MaxFormula.table([
          0,
          0,
          4,
          4,
          4,
          4,
          5,
          5,
          5,
          5,
          5,
          5,
          5,
          5,
          6,
          6,
          6,
          6,
          6,
          6,
        ]),
        _short,
        minLevel: 3,
        note: 'Battle Master only. Delete if not used.',
      ),
    ],
  ),
  ClassTemplate(
    name: 'Monk',
    hitDie: 8,
    saves: {Ability.str, Ability.dex},
    skillList: [
      Skill.acrobatics,
      Skill.athletics,
      Skill.history,
      Skill.insight,
      Skill.religion,
      Skill.stealth,
    ],
    resources: [
      ResourceTemplate('ki', 'Ki', MaxFormula.level(), _short, minLevel: 2),
    ],
    features: [
      Feature(
        'Unarmored Defense',
        'AC = 10 + DEX + WIS while unarmored and without a shield.',
      ),
    ],
  ),
  ClassTemplate(
    name: 'Paladin',
    hitDie: 10,
    saves: {Ability.wis, Ability.cha},
    caster: CasterType.half,
    spellAbility: Ability.cha,
    spellModel: SpellModel.prepared,
    armor: {'light', 'medium', 'heavy', 'shields'},
    skillList: [
      Skill.athletics,
      Skill.insight,
      Skill.intimidation,
      Skill.medicine,
      Skill.persuasion,
      Skill.religion,
    ],
    resources: [
      ResourceTemplate(
        'lay-on-hands',
        'Lay on Hands',
        MaxFormula.level(n: 5),
        _long,
        pool: true,
        spendCost: 1,
      ),
      ResourceTemplate(
        'channel-divinity',
        'Channel Divinity',
        MaxFormula.fixed(1),
        _short,
        minLevel: 3,
      ),
    ],
  ),
  ClassTemplate(
    name: 'Ranger',
    hitDie: 10,
    saves: {Ability.str, Ability.dex},
    caster: CasterType.half,
    spellAbility: Ability.wis,
    spellModel: SpellModel.known,
    armor: {'light', 'medium', 'shields'},
    skillChoices: 3,
    skillList: [
      Skill.animalHandling,
      Skill.athletics,
      Skill.insight,
      Skill.investigation,
      Skill.nature,
      Skill.perception,
      Skill.stealth,
      Skill.survival,
    ],
    features: [
      Feature(
        'Favored Enemy',
        'Note your favored enemy types and languages here.',
      ),
      Feature('Natural Explorer', 'Note your favored terrain here.'),
    ],
  ),
  ClassTemplate(
    name: 'Rogue',
    hitDie: 8,
    saves: {Ability.dex, Ability.int_},
    armor: {'light'},
    skillChoices: 4,
    skillList: [
      Skill.acrobatics,
      Skill.athletics,
      Skill.deception,
      Skill.insight,
      Skill.intimidation,
      Skill.investigation,
      Skill.perception,
      Skill.performance,
      Skill.persuasion,
      Skill.sleightOfHand,
      Skill.stealth,
    ],
    features: [
      Feature(
        'Sneak Attack',
        'Extra damage dice = half rogue level, rounded up (1d6 at 1, 3d6 at 5, 10d6 at 19). Once per turn.',
      ),
    ],
  ),
  ClassTemplate(
    name: 'Sorcerer',
    hitDie: 6,
    saves: {Ability.con, Ability.cha},
    caster: CasterType.full,
    spellAbility: Ability.cha,
    spellModel: SpellModel.known,
    skillList: [
      Skill.arcana,
      Skill.deception,
      Skill.insight,
      Skill.intimidation,
      Skill.persuasion,
      Skill.religion,
    ],
    resources: [
      ResourceTemplate(
        'sorcery-points',
        'Sorcery Points',
        MaxFormula.level(),
        _long,
        minLevel: 2,
        note: 'Flexible Casting: convert to and from slots.',
      ),
    ],
    features: [
      Feature(
        'Metamagic',
        'Choose options from level 3. Spend Sorcery Points when you use one.',
      ),
    ],
  ),
  ClassTemplate(
    name: 'Warlock',
    hitDie: 8,
    saves: {Ability.wis, Ability.cha},
    caster: CasterType.pact,
    spellAbility: Ability.cha,
    spellModel: SpellModel.known,
    armor: {'light'},
    skillList: [
      Skill.arcana,
      Skill.deception,
      Skill.history,
      Skill.intimidation,
      Skill.investigation,
      Skill.nature,
      Skill.religion,
    ],
  ),
  ClassTemplate(
    name: 'Wizard',
    hitDie: 6,
    saves: {Ability.int_, Ability.wis},
    caster: CasterType.full,
    spellAbility: Ability.int_,
    spellModel: SpellModel.prepared,
    ritualCaster: true,
    skillList: [
      Skill.arcana,
      Skill.history,
      Skill.insight,
      Skill.investigation,
      Skill.medicine,
      Skill.religion,
    ],
    resources: [
      ResourceTemplate(
        'arcane-recovery',
        'Arcane Recovery',
        MaxFormula.fixed(1),
        _long,
        note: 'Recover slots totalling up to half wizard level (rounded up) on a short rest.',
      ),
    ],
  ),
];
