/// The rules engine: every derived number comes from here. Pure Dart.
library;

import 'class_templates.dart';
import 'models.dart';
import 'tables.dart';

int abilityModOf(int score) => ((score - 10) / 2).floor();

class Part {
  const Part(this.label, this.value);
  final String label;
  final int value;
}

/// A resolved number with the reasons behind it (the "why" panel).
class Breakdown {
  const Breakdown(this.parts);
  final List<Part> parts;
  int get total => parts.fold(0, (s, p) => s + p.value);

  String describe() => parts
      .map((p) => '${p.label} ${p.value >= 0 ? '' : '-'}${p.value.abs()}')
      .join(' + ')
      .replaceAll('+ -', '- ');
}

class AttackInfo {
  const AttackInfo({
    required this.name,
    required this.bonus,
    required this.damage,
    required this.range,
    required this.properties,
    required this.proficient,
    this.itemId,
    this.spellId,
    this.saveDc,
    this.saveAbility,
    this.versatileDamage,
  });
  final String name;
  final int? bonus;
  final String damage;
  final String range;
  final List<String> properties;
  final bool proficient;
  final String? itemId;
  final String? spellId;
  final int? saveDc;
  final Ability? saveAbility;
  final String? versatileDamage;
}

class SpellcastingInfo {
  const SpellcastingInfo(this.className, this.ability, this.dc, this.attack);
  final String className;
  final Ability ability;
  final int dc;
  final int attack;
}

class CharacterStats {
  const CharacterStats({
    required this.scores,
    required this.mods,
    required this.proficiency,
    required this.maxHp,
    required this.ac,
    required this.acNotes,
    required this.initiative,
    required this.speed,
    required this.saves,
    required this.skills,
    required this.passives,
    required this.spellcasting,
    required this.slotMax,
    required this.pactSlots,
    required this.carried,
    required this.capacity,
    required this.attuned,
    required this.attacks,
    required this.warnings,
    required this.hitDice,
    required this.attacksPerAction,
    required this.traits,
    required this.changedScores,
  });

  final Map<Ability, int> scores;
  final Map<Ability, int> mods;
  final int proficiency;
  final int maxHp;
  final Breakdown ac;
  final List<String> acNotes;
  final Breakdown initiative;
  final Breakdown speed;
  final Map<Ability, Breakdown> saves;
  final Map<Skill, Breakdown> skills;
  final Map<Skill, int> passives;
  final List<SpellcastingInfo> spellcasting;

  /// Slot maximum by spell level (1..9). Pact slots are separate.
  final Map<int, int> slotMax;

  /// (count, slotLevel) or null.
  final (int, int)? pactSlots;
  final double carried;
  final double capacity;
  final int attuned;
  final List<AttackInfo> attacks;
  final List<String> warnings;

  /// Max hit dice by die size.
  final Map<int, int> hitDice;

  /// Attacks per Attack action (Extra Attack).
  final int attacksPerAction;

  /// Notes from active effects (resistances, senses) as (source, text).
  final List<(String, String)> traits;
  final Set<Ability> changedScores;
}

String signed(int v) => v >= 0 ? '+$v' : '$v';

/// Active modifiers: item effects (equipped and attuned if required) plus
/// manual character modifiers.
List<Effect> activeEffects(Character c) => [
  for (final i in c.items)
    if (i.effectsActive)
      for (final e in i.effects) e.copyWith(source: i.name),
  for (final m in c.modifiers)
    if (m.active) m,
];

/// Applies `set` (only if higher) then `add` effects to [base].
Breakdown applyEffects(
  Breakdown base,
  StatTarget target,
  List<Effect> effects,
) {
  final parts = [...base.parts];
  var total = base.total;
  for (final e in effects.where(
    (e) => e.target == target && e.mode == EffectMode.set,
  )) {
    if (e.value > total) {
      parts
        ..clear()
        ..add(Part(e.source.isEmpty ? 'Set' : e.source, e.value));
      total = e.value;
    }
  }
  for (final e in effects.where(
    (e) => e.target == target && e.mode == EffectMode.add,
  )) {
    parts.add(Part(e.source.isEmpty ? 'Bonus' : e.source, e.value));
  }
  return Breakdown(parts);
}

ClassTemplate? templateFor(String className) => classTemplates[className];

/// Total slots by level, including multiclass rules.
Map<int, int> slotTotals(List<ClassLevel> classes) {
  var casterLevel = 0;
  var half = 0;
  var third = 0;
  var casterClasses = 0;
  var single = CasterType.none;
  var singleLevel = 0;
  for (final cl in classes) {
    final t = templateFor(cl.className);
    final type = _casterTypeFor(cl, t);
    switch (type) {
      case CasterType.full:
        casterLevel += cl.level;
      case CasterType.half:
        half += cl.level;
      case CasterType.third:
        third += cl.level;
      case CasterType.pact:
      case CasterType.none:
        continue;
    }
    casterClasses++;
    single = type;
    singleLevel = cl.level;
  }
  if (casterClasses == 0) return {};
  int effective;
  if (casterClasses == 1) {
    effective = switch (single) {
      CasterType.full => singleLevel,
      CasterType.half => singleLevel >= 2 ? (singleLevel + 1) ~/ 2 : 0,
      CasterType.third => singleLevel >= 3 ? (singleLevel + 2) ~/ 3 : 0,
      _ => 0,
    };
  } else {
    effective = casterLevel + half ~/ 2 + third ~/ 3;
  }
  if (effective <= 0) return {};
  final row = fullCasterSlots[effective.clamp(1, 20) - 1];
  return {for (var i = 0; i < row.length; i++) i + 1: row[i]};
}

CasterType _casterTypeFor(ClassLevel cl, ClassTemplate? t) {
  if (t == null) return CasterType.none;
  // Eldritch Knight and Arcane Trickster are third casters.
  if (cl.className == 'Fighter' && cl.subclass == 'Eldritch Knight') {
    return CasterType.third;
  }
  if (cl.className == 'Rogue' && cl.subclass == 'Arcane Trickster') {
    return CasterType.third;
  }
  return t.caster;
}

/// The level a resource scales with: its class level, or the total level for
/// resources that aren't tied to a class. Zero if the class isn't taken.
int resourceLevel(Character c, Resource r) {
  if (r.className.isEmpty) return c.level;
  return c.classes
      .where((cl) => cl.className == r.className)
      .fold(0, (sum, cl) => sum + cl.level);
}

int maxResource(Character c, Resource r, int Function(Ability) mod) =>
    r.maxFormula.resolve(
      level: resourceLevel(c, r).clamp(1, 20),
      prof: proficiencyForLevel(c.level),
      mod: mod,
    );

/// The casting ability for a class level entry. Eldritch Knight and Arcane
/// Trickster cast with INT.
Ability? spellAbilityFor(ClassLevel cl, ClassTemplate? t) {
  if (t == null) return null;
  if (t.spellAbility != null) return t.spellAbility;
  if (_casterTypeFor(cl, t) == CasterType.third) return Ability.int_;
  return null;
}

/// Spell model for a class level entry. Third casters know spells.
SpellModel spellModelFor(ClassLevel cl, ClassTemplate? t) {
  if (t == null) return SpellModel.none;
  if (t.spellModel == SpellModel.none &&
      _casterTypeFor(cl, t) == CasterType.third) {
    return SpellModel.known;
  }
  return t.spellModel;
}

int maxHpBase(Character c, int conMod) {
  var hp = 0;
  var first = true;
  for (final cl in c.classes) {
    final die = hitDieByClass[cl.className] ?? 8;
    for (var i = 0; i < cl.level; i++) {
      if (first) {
        hp += die + conMod;
        first = false;
      } else {
        hp += die ~/ 2 + 1 + conMod;
      }
    }
  }
  return hp < 1 ? 1 : hp;
}

CharacterStats resolveStats(Character c) {
  final effects = activeEffects(c);
  final warnings = <String>[];

  // Ability scores.
  final scores = <Ability, int>{};
  final changed = <Ability>{};
  for (final a in Ability.values) {
    final base = c.abilities[a] ?? 10;
    final target = StatTarget.values.firstWhere((t) => t.ability == a);
    final resolved = applyEffects(
      Breakdown([Part('Base', base)]),
      target,
      effects,
    ).total;
    final capped = resolved.clamp(1, 30);
    scores[a] = capped;
    if (capped != base) changed.add(a);
  }
  final mods = {for (final a in Ability.values) a: abilityModOf(scores[a]!)};
  final prof = proficiencyForLevel(c.level);
  int mod(Ability a) => mods[a]!;

  // Max HP.
  final hpBase = c.maxHpOverride ?? maxHpBase(c, mod(Ability.con));
  var maxHp = applyEffects(
    Breakdown([Part('Base', hpBase)]),
    StatTarget.maxHp,
    effects,
  ).total;
  if (c.exhaustion >= 4) maxHp = maxHp ~/ 2;

  // Armor class.
  final armor = c.items
      .where((i) => i.type == ItemType.armor && i.equipped)
      .firstOrNull;
  final shield = c.items
      .where((i) => i.type == ItemType.shield && i.equipped)
      .firstOrNull;
  final candidates = <(String, Breakdown)>[];
  if (armor != null && armor.armor != null) {
    final a = armor.armor!;
    final dexCap = a.dexCap;
    final dex = dexCap == null
        ? mod(Ability.dex)
        : mod(Ability.dex).clamp(-10, dexCap);
    candidates.add((
      armor.name,
      Breakdown([
        Part(armor.name, a.baseAc),
        if (a.category != ArmorCategory.heavy) Part('DEX', dex),
        if (armor.magicBonusActive != 0) Part('Magic', armor.magicBonusActive),
      ]),
    ));
  } else {
    candidates.add((
      'Unarmored',
      Breakdown([const Part('Base', 10), Part('DEX', mod(Ability.dex))]),
    ));
    final cls = c.classes.map((e) => e.className).toSet();
    if (cls.contains('Barbarian')) {
      candidates.add((
        'Unarmored Defense (Barbarian)',
        Breakdown([
          const Part('Base', 10),
          Part('DEX', mod(Ability.dex)),
          Part('CON', mod(Ability.con)),
        ]),
      ));
    }
    if (cls.contains('Monk') && shield == null) {
      candidates.add((
        'Unarmored Defense (Monk)',
        Breakdown([
          const Part('Base', 10),
          Part('DEX', mod(Ability.dex)),
          Part('WIS', mod(Ability.wis)),
        ]),
      ));
    }
    if (c.flags.contains('draconicResilience')) {
      candidates.add((
        'Draconic Resilience',
        Breakdown([const Part('Base', 13), Part('DEX', mod(Ability.dex))]),
      ));
    }
    if (c.flags.contains('mageArmor')) {
      candidates.add((
        'Mage Armor',
        Breakdown([const Part('Base', 13), Part('DEX', mod(Ability.dex))]),
      ));
    }
  }
  candidates.sort((a, b) => b.$2.total.compareTo(a.$2.total));
  final best = candidates.first;
  final acNotes = <String>[
    for (final other in candidates.skip(1))
      '${other.$1}: ${other.$2.total} (not used)',
  ];
  final acParts = [...best.$2.parts];
  if (shield != null) {
    acParts.add(Part(shield.name, 2 + shield.magicBonusActive));
  }
  final ac = applyEffects(Breakdown(acParts), StatTarget.ac, effects);

  // Armor warnings (never blocks).
  if (armor != null && armor.armor != null) {
    final cat = armor.armor!.category.name;
    if (!c.armorProfs.contains(cat)) {
      warnings.add(
        "Not proficient with $cat armor: disadvantage on STR/DEX checks, saves and attacks, and you can't cast spells.",
      );
    }
    if (armor.armor!.strReq > 0 &&
        scores[Ability.str]! < armor.armor!.strReq &&
        !c.variantEncumbrance) {
      warnings.add(
        '${armor.name} needs STR ${armor.armor!.strReq}: speed -10 ft.',
      );
    }
    if (armor.armor!.stealthDisadv) {
      warnings.add('${armor.name}: disadvantage on Stealth.');
    }
  }
  if (shield != null && !c.armorProfs.contains('shields')) {
    warnings.add(
      "Not proficient with shields: disadvantage on STR/DEX checks, saves and attacks, and you can't cast spells.",
    );
  }

  // Initiative.
  final initiative = applyEffects(
    Breakdown([Part('DEX', mod(Ability.dex))]),
    StatTarget.initiative,
    effects,
  );

  // Carrying capacity and speed.
  var carried = c.items.fold<double>(0, (s, i) => s + i.weight * i.quantity);
  if (c.variantEncumbrance) carried += c.wallet.coinCount / 50;
  final capacity = scores[Ability.str]! * 15.0;
  final speedParts = <Part>[Part('Base', c.baseSpeed)];
  if (armor?.armor != null &&
      armor!.armor!.strReq > 0 &&
      scores[Ability.str]! < armor.armor!.strReq &&
      !c.variantEncumbrance) {
    speedParts.add(const Part('Low STR', -10));
  }
  if (c.variantEncumbrance) {
    final str = scores[Ability.str]!;
    if (carried > str * 10) {
      speedParts.add(const Part('Heavily encumbered', -20));
      warnings.add(
        'Heavily encumbered: speed -20 ft., disadvantage on STR/DEX/CON checks, attacks and saves.',
      );
    } else if (carried > str * 5) {
      speedParts.add(const Part('Encumbered', -10));
      warnings.add('Encumbered: speed -10 ft.');
    }
  }
  var speed = applyEffects(Breakdown(speedParts), StatTarget.speed, effects);
  if (c.exhaustion >= 5) {
    speed = const Breakdown([Part('Exhaustion 5', 0)]);
  } else if (c.exhaustion >= 2) {
    speed = Breakdown([Part('Speed (halved by exhaustion)', speed.total ~/ 2)]);
  }
  if (c.conditions.contains('grappled') ||
      c.conditions.contains('restrained')) {
    warnings.add('Speed is 0 while grappled or restrained.');
  }

  // Saves. Effects can hit all saves or one; `set` only applies if higher.
  final saves = <Ability, Breakdown>{};
  for (final a in Ability.values) {
    final base = Breakdown([
      Part(a.abbr, mod(a)),
      if (c.saveProfs.contains(a)) Part('Proficiency', prof),
    ]);
    final relevant = [
      for (final e in effects)
        if (e.target == StatTarget.saves ||
            (e.target == StatTarget.save && e.subject == a.name))
          e.retarget(StatTarget.saves),
    ];
    saves[a] = applyEffects(base, StatTarget.saves, relevant);
  }

  // Skills and passives.
  final skills = <Skill, Breakdown>{};
  final passives = <Skill, int>{};
  for (final s in Skill.values) {
    final p = c.skills[s] ?? Proficiency.none;
    final bonusParts = <Part>[Part(s.ability.abbr, mod(s.ability))];
    if (p == Proficiency.proficient) bonusParts.add(Part('Proficiency', prof));
    if (p == Proficiency.expertise) bonusParts.add(Part('Expertise', prof * 2));
    if (p == Proficiency.none && c.jackOfAllTrades) {
      bonusParts.add(Part('Jack of All Trades', prof ~/ 2));
    }
    skills[s] = applyEffects(Breakdown(bonusParts), StatTarget.skill, [
      for (final e in effects)
        if (e.target == StatTarget.skill && e.subject == s.name) e,
    ]);
    final adv = c.skillAdv[s] ?? AdvState.none;
    passives[s] =
        10 +
        skills[s]!.total +
        (adv == AdvState.advantage
            ? 5
            : adv == AdvState.disadvantage
            ? -5
            : 0);
  }
  if (c.conditions.contains('poisoned')) {
    warnings.add('Poisoned: disadvantage on attack rolls and ability checks.');
  }

  // Spellcasting (one block per casting class).
  final spellcasting = <SpellcastingInfo>[];
  for (final cl in c.classes) {
    final t = templateFor(cl.className);
    final type = _casterTypeFor(cl, t);
    final ab = spellAbilityFor(cl, t);
    if (t == null || type == CasterType.none || ab == null) continue;
    final dc = applyEffects(
      Breakdown([Part('Base', 8 + prof + mod(ab))]),
      StatTarget.spellDc,
      effects,
    ).total;
    final attack = applyEffects(
      Breakdown([Part('Base', prof + mod(ab))]),
      StatTarget.spellAttack,
      effects,
    ).total;
    spellcasting.add(SpellcastingInfo(cl.className, ab, dc, attack));
  }

  // Slots.
  final slotMax = slotTotals(c.classes);
  (int, int)? pact;
  for (final cl in c.classes) {
    if (templateFor(cl.className)?.caster == CasterType.pact) {
      pact = pactMagic(cl.level);
    }
  }

  // Hit dice.
  final hitDice = <int, int>{};
  for (final cl in c.classes) {
    final die = hitDieByClass[cl.className] ?? 8;
    hitDice[die] = (hitDice[die] ?? 0) + cl.level;
  }

  final attuned = c.items.where((i) => i.attuned).length;

  // Attacks.
  final attacks = _attacks(c, mods, prof, effects, spellcasting);

  return CharacterStats(
    scores: scores,
    mods: mods,
    proficiency: prof,
    maxHp: maxHp < 1 ? 1 : maxHp,
    ac: ac,
    acNotes: acNotes,
    initiative: initiative,
    speed: speed,
    saves: saves,
    skills: skills,
    passives: passives,
    spellcasting: spellcasting,
    slotMax: slotMax,
    pactSlots: pact,
    carried: carried,
    capacity: capacity,
    attuned: attuned,
    attacks: attacks,
    warnings: warnings,
    hitDice: hitDice,
    attacksPerAction: c.classes.fold(1, (best, cl) {
      final n = attacksPerActionFor(cl.className, cl.level);
      return n > best ? n : best;
    }),
    traits: [
      for (final e in effects)
        if (e.target == StatTarget.note && e.note.isNotEmpty)
          (e.source, e.note),
    ],
    changedScores: changed,
  );
}

List<AttackInfo> _attacks(
  Character c,
  Map<Ability, int> mods,
  int prof,
  List<Effect> effects,
  List<SpellcastingInfo> casting,
) {
  final list = <AttackInfo>[];
  final atkBonus = effects
      .where((e) => e.target == StatTarget.attackBonus)
      .fold(0, (s, e) => s + e.value);
  final dmgBonus = effects
      .where((e) => e.target == StatTarget.damageBonus)
      .fold(0, (s, e) => s + e.value);
  for (final i in c.items.where(
    (i) => i.type == ItemType.weapon && i.equipped && i.weapon != null,
  )) {
    final w = i.weapon!;
    Ability ability;
    if (w.finesse) {
      ability = mods[Ability.dex]! >= mods[Ability.str]!
          ? Ability.dex
          : Ability.str;
    } else {
      ability = w.ranged ? Ability.dex : Ability.str;
    }
    final proficient = weaponProficient(c, i);
    final mod = mods[ability]!;
    final bonus = mod + (proficient ? prof : 0) + i.magicBonusActive + atkBonus;
    final flat = mod + i.magicBonusActive + dmgBonus;
    String dmg(String dice) =>
        '$dice${flat == 0 ? '' : signed(flat)} ${w.damageType}';
    list.add(
      AttackInfo(
        name: i.name,
        bonus: bonus,
        damage: dmg(w.damageDice),
        versatileDamage: w.versatileDice == null ? null : dmg(w.versatileDice!),
        range: w.ranged ? w.range : (w.reach ? '10 ft.' : '5 ft.'),
        properties: w.properties,
        proficient: proficient,
        itemId: i.id,
      ),
    );
  }

  // Unarmed strike is always present.
  final strMod = mods[Ability.str]!;
  list.add(
    AttackInfo(
      name: 'Unarmed Strike',
      bonus: strMod + prof + atkBonus,
      damage: '${1 + strMod + dmgBonus} bludgeoning',
      range: '5 ft.',
      properties: const [],
      proficient: true,
    ),
  );

  // Spell attacks and save spells.
  if (casting.isNotEmpty) {
    final info = casting.first;
    for (final s in c.spells.where(
      (s) => (s.attackRoll || s.save != null) && (s.isCantrip || s.prepared),
    )) {
      final damage = s.isCantrip ? _scaleCantrip(s.damage, c.level) : s.damage;
      list.add(
        AttackInfo(
          name: s.name,
          bonus: s.attackRoll ? info.attack : null,
          damage: damage,
          range: s.range,
          properties: [s.level == 0 ? 'Cantrip' : 'Level ${s.level}'],
          proficient: true,
          spellId: s.id,
          saveDc: s.save != null ? info.dc : null,
          saveAbility: s.save,
        ),
      );
    }
  }
  return list;
}

/// Cantrip damage scales at levels 5, 11 and 17. Dice text like `1d10 fire`.
String _scaleCantrip(String damage, int level) {
  final m = RegExp(r'^(\d+)d(\d+)(.*)$').firstMatch(damage);
  if (m == null) return damage;
  final mult = level >= 17 ? 4 : (level >= 11 ? 3 : (level >= 5 ? 2 : 1));
  return '${int.parse(m.group(1)!) * mult}d${m.group(2)}${m.group(3)}';
}

/// Concentration save DC: higher of 10 and half the damage taken.
int concentrationDc(int damage) {
  final half = damage ~/ 2;
  return half > 10 ? half : 10;
}

/// Sorcerer prepared/known limits are class tables; prepared casters use
/// casting mod + level (half level for Paladin), minimum 1.
int preparedLimit(Character c, CharacterStats s) {
  final cl = c.primaryClass;
  final t = templateFor(cl.className);
  final ability = spellAbilityFor(cl, t);
  if (t == null || ability == null) return 0;
  final modv = s.mods[ability]!;
  final lvl = cl.className == 'Paladin' ? cl.level ~/ 2 : cl.level;
  final n = modv + lvl;
  return n < 1 ? 1 : n;
}

/// Whether the character is proficient with a weapon item: a manual override
/// wins, then the character's simple/martial/named proficiencies.
bool weaponProficient(Character c, Item i) {
  if (i.proficientOverride != null) return i.proficientOverride!;
  final w = i.weapon;
  if (w == null) return false;
  final category = w.martial ? 'martial' : 'simple';
  return c.weaponProfs.contains(category) ||
      c.weaponProfs.contains(i.name.toLowerCase());
}

/// Who may ritual cast (2014): Wizards from the spellbook, Bards from known
/// spells, Clerics and Druids only prepared rituals. Others need the
/// `ritualCasting` flag (a feature such as Pact of the Tome).
bool canRitualCast(Character c, Spell spell) {
  if (!spell.ritual) return false;
  if (c.flags.contains('ritualCasting')) return true;
  for (final cl in c.classes) {
    switch (cl.className) {
      case 'Wizard':
      case 'Bard':
        return true;
      case 'Cleric':
      case 'Druid':
        if (spell.prepared) return true;
    }
  }
  return false;
}
