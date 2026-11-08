/// 2014 PHB/SRD tables. Pure Dart.
library;

/// Full-caster slots by caster level (index 0 = level 1). Each row lists the
/// slots for spell levels 1..9.
const List<List<int>> fullCasterSlots = [
  [2],
  [3],
  [4, 2],
  [4, 3],
  [4, 3, 2],
  [4, 3, 3],
  [4, 3, 3, 1],
  [4, 3, 3, 2],
  [4, 3, 3, 3, 1],
  [4, 3, 3, 3, 2],
  [4, 3, 3, 3, 2, 1],
  [4, 3, 3, 3, 2, 1],
  [4, 3, 3, 3, 2, 1, 1],
  [4, 3, 3, 3, 2, 1, 1],
  [4, 3, 3, 3, 2, 1, 1, 1],
  [4, 3, 3, 3, 2, 1, 1, 1],
  [4, 3, 3, 3, 2, 1, 1, 1, 1],
  [4, 3, 3, 3, 3, 1, 1, 1, 1],
  [4, 3, 3, 3, 3, 2, 1, 1, 1],
  [4, 3, 3, 3, 3, 2, 2, 1, 1],
];

/// Warlock Pact Magic: (slot count, slot level) by warlock level.
(int, int) pactMagic(int level) {
  final l = level.clamp(1, 20);
  final count = l >= 17 ? 4 : (l >= 11 ? 3 : (l >= 2 ? 2 : 1));
  final slotLevel = l >= 9 ? 5 : (l >= 7 ? 4 : (l >= 5 ? 3 : (l >= 3 ? 2 : 1)));
  return (count, slotLevel);
}

/// Proficiency bonus by total level.
int proficiencyForLevel(int level) => 2 + ((level.clamp(1, 20) - 1) ~/ 4);

/// Cost in Sorcery Points to create a slot of the given level (max level 5).
const Map<int, int> sorceryPointSlotCost = {1: 2, 2: 3, 3: 5, 4: 6, 5: 7};

/// Hit dice per class.
/// Sorcerer Metamagic options (SRD 5.1).
class MetamagicOption {
  const MetamagicOption(this.name, this.cost, this.text);
  final String name;

  /// Sorcery Point cost as written (some scale with spell level).
  final String cost;
  final String text;
}

const List<MetamagicOption> metamagicOptions = [
  MetamagicOption(
    'Careful Spell',
    '1 SP',
    'Choose up to CHA modifier creatures (min 1); they automatically succeed on the spell\'s saving throw.',
  ),
  MetamagicOption(
    'Distant Spell',
    '1 SP',
    'Double the range of a spell with range 5 ft or more, or make a touch spell 30 ft.',
  ),
  MetamagicOption(
    'Empowered Spell',
    '1 SP',
    'Reroll up to CHA modifier damage dice (min 1) and use the new rolls. Combines with other Metamagic.',
  ),
  MetamagicOption(
    'Extended Spell',
    '1 SP',
    'Double the duration of a spell lasting 1 minute or longer, up to 24 hours.',
  ),
  MetamagicOption(
    'Heightened Spell',
    '3 SP',
    'One target of the spell has disadvantage on its first saving throw against it.',
  ),
  MetamagicOption(
    'Quickened Spell',
    '2 SP',
    'Cast a spell with a casting time of 1 action as a bonus action instead.',
  ),
  MetamagicOption(
    'Subtle Spell',
    '1 SP',
    'Cast without somatic or verbal components.',
  ),
  MetamagicOption(
    'Twinned Spell',
    'SP = spell level (1 for cantrips)',
    'Target a second creature with a spell that targets only one creature and is not range self.',
  ),
];

/// How many Metamagic options a sorcerer of [sorcererLevel] knows.
int metamagicKnownFor(int sorcererLevel) {
  if (sorcererLevel >= 17) return 4;
  if (sorcererLevel >= 10) return 3;
  if (sorcererLevel >= 3) return 2;
  return 0;
}

const Map<String, int> hitDieByClass = {
  'Barbarian': 12,
  'Bard': 8,
  'Cleric': 8,
  'Druid': 8,
  'Fighter': 10,
  'Monk': 8,
  'Paladin': 10,
  'Ranger': 10,
  'Rogue': 8,
  'Sorcerer': 6,
  'Warlock': 8,
  'Wizard': 6,
};

/// Rules text for conditions (2014), one line each.
const Map<String, String> conditionRules = {
  'blinded': "Can't see. Attacks against you have advantage; your attacks have disadvantage.",
  'charmed': "Can't attack the charmer. The charmer has advantage on social checks against you.",
  'deafened': "Can't hear. Auto-fail checks that need hearing.",
  'frightened': 'Disadvantage on checks and attacks while the source is in sight. Cannot move closer.',
  'grappled': 'Speed is 0.',
  'incapacitated': "Can't take actions or reactions.",
  'invisible':
      'Attacks against you have disadvantage; your attacks have advantage.',
  'paralyzed': 'Incapacitated, cannot move or speak. Attacks have advantage, hits within 5 ft. are crits.',
  'petrified': 'Turned to stone. Incapacitated, resistant to all damage.',
  'poisoned': 'Disadvantage on attack rolls and ability checks.',
  'prone': 'Disadvantage on your attacks. Melee attacks against you have advantage, ranged have disadvantage.',
  'restrained': 'Speed 0. Attacks against you have advantage; your attacks and DEX saves have disadvantage.',
  'stunned': 'Incapacitated, cannot move. Attacks against you have advantage. Auto-fail STR and DEX saves.',
  'unconscious': 'Incapacitated, prone, unaware. Attacks have advantage, hits within 5 ft. are crits.',
};

const List<String> exhaustionRules = [
  '',
  'Disadvantage on ability checks.',
  'Speed halved.',
  'Disadvantage on attack rolls and saving throws.',
  'Hit point maximum halved.',
  'Speed reduced to 0.',
  'Death.',
];

/// Cantrips and spells known (or null when the class prepares or has none)
/// by class level, from the 2014 class tables.
({int cantrips, int? spells})? knownLimits(String className, int level) {
  final l = level.clamp(1, 20);
  int pick(List<int> t) => t[l - 1];
  switch (className) {
    case 'Sorcerer':
      return (
        cantrips: l >= 10 ? 6 : (l >= 4 ? 5 : 4),
        spells: pick(const [
          2,
          3,
          4,
          5,
          6,
          7,
          8,
          9,
          10,
          11,
          12,
          12,
          13,
          13,
          14,
          14,
          15,
          15,
          15,
          15,
        ]),
      );
    case 'Bard':
      return (
        cantrips: l >= 10 ? 4 : (l >= 4 ? 3 : 2),
        spells: pick(const [
          4,
          5,
          6,
          7,
          8,
          9,
          10,
          11,
          12,
          14,
          15,
          15,
          16,
          18,
          19,
          19,
          20,
          22,
          22,
          22,
        ]),
      );
    case 'Warlock':
      return (
        cantrips: l >= 10 ? 4 : (l >= 4 ? 3 : 2),
        spells: pick(const [
          2,
          3,
          4,
          5,
          6,
          7,
          8,
          9,
          10,
          10,
          11,
          11,
          12,
          12,
          13,
          13,
          14,
          14,
          15,
          15,
        ]),
      );
    case 'Ranger':
      return (
        cantrips: 0,
        spells: pick(const [
          0,
          2,
          3,
          3,
          4,
          4,
          5,
          5,
          6,
          6,
          7,
          7,
          8,
          8,
          9,
          9,
          10,
          10,
          11,
          11,
        ]),
      );
    case 'Wizard':
    case 'Cleric':
      return (cantrips: l >= 10 ? 5 : (l >= 4 ? 4 : 3), spells: null);
    case 'Druid':
      return (cantrips: l >= 10 ? 4 : (l >= 4 ? 3 : 2), spells: null);
  }
  return null;
}

/// Extra Attack: attacks per Attack action for a class at a level.
int attacksPerActionFor(String className, int level) {
  switch (className) {
    case 'Fighter':
      return level >= 20 ? 4 : (level >= 11 ? 3 : (level >= 5 ? 2 : 1));
    case 'Barbarian':
    case 'Monk':
    case 'Paladin':
    case 'Ranger':
      return level >= 5 ? 2 : 1;
  }
  return 1;
}
