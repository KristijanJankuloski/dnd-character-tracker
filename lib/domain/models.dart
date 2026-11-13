/// Domain entities for the 5e (2014) character tracker. Pure Dart.
///
/// Only base values are stored. Everything derived (modifiers, AC, DCs,
/// slot totals, resource maxima) is computed by the rules engine.
library;

enum Ability {
  str('STR', 'Strength'),
  dex('DEX', 'Dexterity'),
  con('CON', 'Constitution'),
  int_('INT', 'Intelligence'),
  wis('WIS', 'Wisdom'),
  cha('CHA', 'Charisma');

  const Ability(this.abbr, this.label);
  final String abbr;
  final String label;

  static Ability parse(String s) =>
      Ability.values.firstWhere((a) => a.name == s, orElse: () => Ability.str);
}

enum Skill {
  acrobatics('Acrobatics', Ability.dex),
  animalHandling('Animal Handling', Ability.wis),
  arcana('Arcana', Ability.int_),
  athletics('Athletics', Ability.str),
  deception('Deception', Ability.cha),
  history('History', Ability.int_),
  insight('Insight', Ability.wis),
  intimidation('Intimidation', Ability.cha),
  investigation('Investigation', Ability.int_),
  medicine('Medicine', Ability.wis),
  nature('Nature', Ability.int_),
  perception('Perception', Ability.wis),
  performance('Performance', Ability.cha),
  persuasion('Persuasion', Ability.cha),
  religion('Religion', Ability.int_),
  sleightOfHand('Sleight of Hand', Ability.dex),
  stealth('Stealth', Ability.dex),
  survival('Survival', Ability.wis);

  const Skill(this.label, this.ability);
  final String label;
  final Ability ability;

  static Skill parse(String s) => Skill.values.firstWhere(
    (a) => a.name == s,
    orElse: () => Skill.acrobatics,
  );
}

enum Proficiency { none, proficient, expertise }

enum AdvState { none, advantage, disadvantage }

enum CasterType { none, full, half, third, pact }

enum SpellModel { none, known, prepared }

enum RechargeWhen { shortRest, longRest, manual }

enum RechargeAmount { all, half, fixed }

enum CastingTime { action, bonusAction, reaction, other }

enum ItemType {
  armor,
  shield,
  weapon,
  gear,
  tool,
  consumable,
  magic,
  ammo,
  custom,
}

enum ArmorCategory { light, medium, heavy }

enum EffectMode { add, set }

enum StatTarget {
  ac('AC'),
  speed('Speed'),
  initiative('Initiative'),
  spellDc('Spell save DC'),
  spellAttack('Spell attack'),
  attackBonus('Attack bonus'),
  damageBonus('Damage bonus'),
  maxHp('Max HP'),
  saves('All saves'),
  save('One saving throw'),
  skill('One skill'),
  note('Note (resistance, sense)'),
  str('STR'),
  dex('DEX'),
  con('CON'),
  int_('INT'),
  wis('WIS'),
  cha('CHA');

  const StatTarget(this.label);
  final String label;

  Ability? get ability => switch (this) {
    StatTarget.str => Ability.str,
    StatTarget.dex => Ability.dex,
    StatTarget.con => Ability.con,
    StatTarget.int_ => Ability.int_,
    StatTarget.wis => Ability.wis,
    StatTarget.cha => Ability.cha,
    _ => null,
  };
}

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// A modifier to a derived stat. Comes from an item, a spell, a feat, etc.
class Effect {
  const Effect({
    required this.target,
    required this.mode,
    required this.value,
    this.source = '',
    this.active = true,
    this.note = '',
    this.subject = '',
  });

  final StatTarget target;
  final EffectMode mode;
  final int value;
  final String source;
  final bool active;
  final String note;

  /// For `save` and `skill` targets: the ability or skill name.
  final String subject;

  Effect copyWith({bool? active, String? source}) => Effect(
    target: target,
    mode: mode,
    value: value,
    source: source ?? this.source,
    active: active ?? this.active,
    note: note,
    subject: subject,
  );

  Effect retarget(StatTarget t) => Effect(
    target: t,
    mode: mode,
    value: value,
    source: source,
    active: active,
    note: note,
    subject: subject,
  );

  Map<String, Object?> toJson() => {
    'target': target.name,
    'mode': mode.name,
    'value': value,
    'source': source,
    'active': active,
    'note': note,
    'subject': subject,
  };

  factory Effect.fromJson(Map<String, Object?> j) => Effect(
    target: _enum(StatTarget.values, j['target'], StatTarget.ac),
    mode: _enum(EffectMode.values, j['mode'], EffectMode.add),
    value: (j['value'] as num?)?.toInt() ?? 0,
    source: (j['source'] as String?) ?? '',
    active: (j['active'] as bool?) ?? true,
    note: (j['note'] as String?) ?? '',
    subject: (j['subject'] as String?) ?? '',
  );
}

/// How a resource maximum is computed. Data, so templates can be edited.
class MaxFormula {
  const MaxFormula.fixed(this.n)
    : kind = 'fixed',
      ability = null,
      table = const [];
  const MaxFormula.level({this.n = 1})
    : kind = 'level',
      ability = null,
      table = const [];
  const MaxFormula.prof()
    : kind = 'prof',
      n = 1,
      ability = null,
      table = const [];
  const MaxFormula.abilityMod(Ability a, {this.n = 1})
    : kind = 'mod',
      ability = a,
      table = const [];

  /// Table by character level (index 0 = level 1), 20 entries.
  const MaxFormula.table(this.table) : kind = 'table', n = 1, ability = null;

  const MaxFormula._(this.kind, this.n, this.ability, this.table);

  /// `fixed`: value n. `level`: level * n. `prof`: proficiency bonus.
  /// `mod`: max(ability mod, n). `table`: by level.
  final String kind;
  final int n;
  final Ability? ability;
  final List<int> table;

  int resolve({
    required int level,
    required int prof,
    required int Function(Ability) mod,
  }) {
    switch (kind) {
      case 'fixed':
        return n;
      case 'level':
        return level * n;
      case 'prof':
        return prof;
      case 'mod':
        final m = mod(ability!);
        return m < n ? n : m;
      case 'table':
        return table[(level.clamp(1, 20)) - 1];
      default:
        return n;
    }
  }

  Map<String, Object?> toJson() => {
    'kind': kind,
    'n': n,
    'ability': ability?.name,
    'table': table,
  };

  factory MaxFormula.fromJson(Map<String, Object?> j) => MaxFormula._(
    (j['kind'] as String?) ?? 'fixed',
    (j['n'] as num?)?.toInt() ?? 1,
    j['ability'] == null ? null : Ability.parse(j['ability'] as String),
    ((j['table'] as List?) ?? const []).map((e) => (e as num).toInt()).toList(),
  );
}

class RechargeRule {
  const RechargeRule(this.when, this.amount, {this.n = 0, this.minLevel = 1});
  final RechargeWhen when;
  final RechargeAmount amount;
  final int n;
  final int minLevel;

  Map<String, Object?> toJson() => {
    'when': when.name,
    'amount': amount.name,
    'n': n,
    'minLevel': minLevel,
  };

  factory RechargeRule.fromJson(Map<String, Object?> j) => RechargeRule(
    _enum(RechargeWhen.values, j['when'], RechargeWhen.longRest),
    _enum(RechargeAmount.values, j['amount'], RechargeAmount.all),
    n: (j['n'] as num?)?.toInt() ?? 0,
    minLevel: (j['minLevel'] as num?)?.toInt() ?? 1,
  );
}

class Resource {
  const Resource({
    required this.id,
    required this.name,
    required this.maxFormula,
    required this.current,
    this.spendCost = 1,
    this.rules = const [],
    this.minLevel = 1,
    this.pool = false,
    this.toggleable = false,
    this.active = false,
    this.note = '',
    this.className = '',
  });

  final String id;
  final String name;
  final MaxFormula maxFormula;
  final int current;
  final int spendCost;
  final List<RechargeRule> rules;

  /// Hidden until the character reaches this level.
  final int minLevel;

  /// Display as a number (Lay on Hands) instead of pips.
  final bool pool;

  /// Has an on/off state (Rage, Wild Shape).
  final bool toggleable;
  final bool active;
  final String note;

  /// The class this resource scales with. Empty means total character level.
  final String className;

  Resource copyWith({
    int? current,
    bool? active,
    int? spendCost,
    String? name,
  }) => Resource(
    id: id,
    name: name ?? this.name,
    maxFormula: maxFormula,
    current: current ?? this.current,
    spendCost: spendCost ?? this.spendCost,
    rules: rules,
    minLevel: minLevel,
    pool: pool,
    toggleable: toggleable,
    active: active ?? this.active,
    note: note,
    className: className,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'maxFormula': maxFormula.toJson(),
    'current': current,
    'spendCost': spendCost,
    'rules': rules.map((r) => r.toJson()).toList(),
    'minLevel': minLevel,
    'pool': pool,
    'toggleable': toggleable,
    'active': active,
    'note': note,
    'className': className,
  };

  factory Resource.fromJson(Map<String, Object?> j) => Resource(
    id: j['id'] as String,
    name: j['name'] as String,
    maxFormula: MaxFormula.fromJson((j['maxFormula'] as Map).cast()),
    current: (j['current'] as num).toInt(),
    spendCost: (j['spendCost'] as num?)?.toInt() ?? 1,
    rules: ((j['rules'] as List?) ?? const [])
        .map((e) => RechargeRule.fromJson((e as Map).cast()))
        .toList(),
    minLevel: (j['minLevel'] as num?)?.toInt() ?? 1,
    pool: (j['pool'] as bool?) ?? false,
    toggleable: (j['toggleable'] as bool?) ?? false,
    active: (j['active'] as bool?) ?? false,
    note: (j['note'] as String?) ?? '',
    className: (j['className'] as String?) ?? '',
  );
}

/// Shape of a spell's area of effect or targeting.
enum AreaShape {
  none('None'),
  singleTarget('Single target'),
  multipleTargets('Multiple targets'),
  radius('Radius / sphere'),
  cone('Cone'),
  line('Line'),
  cube('Cube'),
  cylinder('Cylinder');

  const AreaShape(this.label);
  final String label;
}

class Spell {
  const Spell({
    required this.id,
    required this.name,
    required this.level,
    this.castingTime = CastingTime.action,
    this.concentration = false,
    this.ritual = false,
    this.prepared = true,
    this.alwaysPrepared = false,
    this.range = '',
    this.damage = '',
    this.save,
    this.attackRoll = false,
    this.text = '',
    this.damageType = '',
    this.areaShape = AreaShape.none,
    this.areaSize = '',
    this.school = '',
    this.components = '',
    this.duration = '',
    this.higherLevels = '',
    this.castingTimeText = '',
  });

  final String id;
  final String name;
  final int level; // 0 = cantrip
  final CastingTime castingTime;
  final bool concentration;
  final bool ritual;
  final bool prepared;
  final bool alwaysPrepared;
  final String range;
  final String damage;
  final Ability? save;
  final bool attackRoll;
  final String text;

  /// Optional detail fields (empty/none for older saves and SRD spells).
  final String damageType;
  final AreaShape areaShape;
  final String areaSize;

  /// Encyclopedia fields (empty for custom spells and older saves).
  final String school;
  final String components;
  final String duration;
  final String higherLevels;

  /// The casting time as written, e.g. `1 minute` (the enum only knows
  /// action / bonus action / reaction / other).
  final String castingTimeText;

  bool get isCantrip => level == 0;

  Spell copyWith({bool? prepared}) => Spell(
    id: id,
    name: name,
    level: level,
    castingTime: castingTime,
    concentration: concentration,
    ritual: ritual,
    prepared: prepared ?? this.prepared,
    alwaysPrepared: alwaysPrepared,
    range: range,
    damage: damage,
    save: save,
    attackRoll: attackRoll,
    text: text,
    damageType: damageType,
    areaShape: areaShape,
    areaSize: areaSize,
    school: school,
    components: components,
    duration: duration,
    higherLevels: higherLevels,
    castingTimeText: castingTimeText,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'level': level,
    'castingTime': castingTime.name,
    'concentration': concentration,
    'ritual': ritual,
    'prepared': prepared,
    'alwaysPrepared': alwaysPrepared,
    'range': range,
    'damage': damage,
    'save': save?.name,
    'attackRoll': attackRoll,
    'text': text,
    'damageType': damageType,
    'areaShape': areaShape.name,
    'areaSize': areaSize,
    'school': school,
    'components': components,
    'duration': duration,
    'higherLevels': higherLevels,
    'castingTimeText': castingTimeText,
  };

  factory Spell.fromJson(Map<String, Object?> j) => Spell(
    id: j['id'] as String,
    name: j['name'] as String,
    level: (j['level'] as num).toInt(),
    castingTime: _enum(
      CastingTime.values,
      j['castingTime'],
      CastingTime.action,
    ),
    concentration: (j['concentration'] as bool?) ?? false,
    ritual: (j['ritual'] as bool?) ?? false,
    prepared: (j['prepared'] as bool?) ?? true,
    alwaysPrepared: (j['alwaysPrepared'] as bool?) ?? false,
    range: (j['range'] as String?) ?? '',
    damage: (j['damage'] as String?) ?? '',
    save: j['save'] == null ? null : Ability.parse(j['save'] as String),
    attackRoll: (j['attackRoll'] as bool?) ?? false,
    text: (j['text'] as String?) ?? '',
    damageType: (j['damageType'] as String?) ?? '',
    areaShape: _enum(AreaShape.values, j['areaShape'], AreaShape.none),
    areaSize: (j['areaSize'] as String?) ?? '',
    school: (j['school'] as String?) ?? '',
    components: (j['components'] as String?) ?? '',
    duration: (j['duration'] as String?) ?? '',
    higherLevels: (j['higherLevels'] as String?) ?? '',
    castingTimeText: (j['castingTimeText'] as String?) ?? '',
  );
}

class ArmorStats {
  const ArmorStats({
    required this.category,
    required this.baseAc,
    this.strReq = 0,
    this.stealthDisadv = false,
  });
  final ArmorCategory category;
  final int baseAc;
  final int strReq;
  final bool stealthDisadv;

  int? get dexCap => switch (category) {
    ArmorCategory.light => null,
    ArmorCategory.medium => 2,
    ArmorCategory.heavy => 0,
  };

  Map<String, Object?> toJson() => {
    'category': category.name,
    'baseAc': baseAc,
    'strReq': strReq,
    'stealthDisadv': stealthDisadv,
  };

  factory ArmorStats.fromJson(Map<String, Object?> j) => ArmorStats(
    category: _enum(ArmorCategory.values, j['category'], ArmorCategory.light),
    baseAc: (j['baseAc'] as num).toInt(),
    strReq: (j['strReq'] as num?)?.toInt() ?? 0,
    stealthDisadv: (j['stealthDisadv'] as bool?) ?? false,
  );
}

class WeaponStats {
  const WeaponStats({
    required this.damageDice,
    required this.damageType,
    this.ranged = false,
    this.finesse = false,
    this.twoHanded = false,
    this.light = false,
    this.versatileDice,
    this.reach = false,
    this.range = '',
    this.martial = false,
    this.ammoItemId,
  });
  final String damageDice;
  final String damageType;
  final bool ranged;
  final bool finesse;
  final bool twoHanded;
  final bool light;
  final String? versatileDice;
  final bool reach;
  final String range;
  final bool martial;
  final String? ammoItemId;

  List<String> get properties => [
    if (finesse) 'Finesse',
    if (light) 'Light',
    if (twoHanded) 'Two-Handed',
    if (versatileDice != null) 'Versatile',
    if (reach) 'Reach',
    if (range.isNotEmpty && ranged) 'Range',
  ];

  Map<String, Object?> toJson() => {
    'damageDice': damageDice,
    'damageType': damageType,
    'ranged': ranged,
    'finesse': finesse,
    'twoHanded': twoHanded,
    'light': light,
    'versatileDice': versatileDice,
    'reach': reach,
    'range': range,
    'martial': martial,
    'ammoItemId': ammoItemId,
  };

  factory WeaponStats.fromJson(Map<String, Object?> j) => WeaponStats(
    damageDice: (j['damageDice'] as String?) ?? '1d4',
    damageType: (j['damageType'] as String?) ?? 'bludgeoning',
    ranged: (j['ranged'] as bool?) ?? false,
    finesse: (j['finesse'] as bool?) ?? false,
    twoHanded: (j['twoHanded'] as bool?) ?? false,
    light: (j['light'] as bool?) ?? false,
    versatileDice: j['versatileDice'] as String?,
    reach: (j['reach'] as bool?) ?? false,
    range: (j['range'] as String?) ?? '',
    martial: (j['martial'] as bool?) ?? false,
    ammoItemId: j['ammoItemId'] as String?,
  );
}

class Item {
  const Item({
    required this.id,
    required this.name,
    required this.type,
    this.quantity = 1,
    this.weight = 0,
    this.valueGp = 0,
    this.description = '',
    this.equipped = false,
    this.attuned = false,
    this.requiresAttunement = false,
    this.cursed = false,
    this.rarity = '',
    this.magicBonus = 0,
    this.armor,
    this.weapon,
    this.effects = const [],
    this.healAmount,
    this.source = 'custom',
    this.proficientOverride,
  });

  final String id;
  final String name;
  final ItemType type;
  final int quantity;
  final double weight;
  final double valueGp;
  final String description;
  final bool equipped;
  final bool attuned;
  final bool requiresAttunement;
  final bool cursed;
  final String rarity;

  /// Magic bonus to armor AC, shield AC, or weapon attack and damage.
  final int magicBonus;
  final ArmorStats? armor;
  final WeaponStats? weapon;
  final List<Effect> effects;

  /// Consumables: HP restored when used (average, entered by the player).
  final int? healAmount;
  final String source;

  /// Weapons: overrides automatic proficiency. Null means automatic.
  final bool? proficientOverride;

  /// Magic bonus counts only while the item is attuned, if it requires that.
  int get magicBonusActive => (!requiresAttunement || attuned) ? magicBonus : 0;

  bool get equippable =>
      type == ItemType.armor ||
      type == ItemType.shield ||
      type == ItemType.weapon ||
      type == ItemType.magic ||
      type == ItemType.gear;

  /// Magic effects only apply while equipped and, when required, attuned.
  bool get effectsActive => equipped && (!requiresAttunement || attuned);

  Item copyWith({
    int? quantity,
    bool? equipped,
    bool? attuned,
    Object? proficientOverride = _unsetItem,
  }) => Item(
    id: id,
    name: name,
    type: type,
    quantity: quantity ?? this.quantity,
    weight: weight,
    valueGp: valueGp,
    description: description,
    equipped: equipped ?? this.equipped,
    attuned: attuned ?? this.attuned,
    requiresAttunement: requiresAttunement,
    cursed: cursed,
    rarity: rarity,
    magicBonus: magicBonus,
    armor: armor,
    weapon: weapon,
    effects: effects,
    healAmount: healAmount,
    source: source,
    proficientOverride: identical(proficientOverride, _unsetItem)
        ? this.proficientOverride
        : proficientOverride as bool?,
  );

  static const Object _unsetItem = Object();

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'quantity': quantity,
    'weight': weight,
    'valueGp': valueGp,
    'description': description,
    'equipped': equipped,
    'attuned': attuned,
    'requiresAttunement': requiresAttunement,
    'cursed': cursed,
    'rarity': rarity,
    'magicBonus': magicBonus,
    'armor': armor?.toJson(),
    'weapon': weapon?.toJson(),
    'effects': effects.map((e) => e.toJson()).toList(),
    'healAmount': healAmount,
    'source': source,
    'proficientOverride': proficientOverride,
  };

  factory Item.fromJson(Map<String, Object?> j) => Item(
    id: j['id'] as String,
    name: j['name'] as String,
    type: _enum(ItemType.values, j['type'], ItemType.gear),
    quantity: (j['quantity'] as num?)?.toInt() ?? 1,
    weight: (j['weight'] as num?)?.toDouble() ?? 0,
    valueGp: (j['valueGp'] as num?)?.toDouble() ?? 0,
    description: (j['description'] as String?) ?? '',
    equipped: (j['equipped'] as bool?) ?? false,
    attuned: (j['attuned'] as bool?) ?? false,
    requiresAttunement: (j['requiresAttunement'] as bool?) ?? false,
    cursed: (j['cursed'] as bool?) ?? false,
    rarity: (j['rarity'] as String?) ?? '',
    magicBonus: (j['magicBonus'] as num?)?.toInt() ?? 0,
    armor: j['armor'] == null
        ? null
        : ArmorStats.fromJson((j['armor'] as Map).cast()),
    weapon: j['weapon'] == null
        ? null
        : WeaponStats.fromJson((j['weapon'] as Map).cast()),
    effects: ((j['effects'] as List?) ?? const [])
        .map((e) => Effect.fromJson((e as Map).cast()))
        .toList(),
    healAmount: (j['healAmount'] as num?)?.toInt(),
    source: (j['source'] as String?) ?? 'custom',
    proficientOverride: j['proficientOverride'] as bool?,
  );
}

class Wallet {
  const Wallet({
    this.cp = 0,
    this.sp = 0,
    this.ep = 0,
    this.gp = 0,
    this.pp = 0,
  });
  final int cp, sp, ep, gp, pp;

  /// Total wealth in gold pieces.
  double get totalGp => cp / 100 + sp / 10 + ep / 2 + gp + pp * 10;
  int get coinCount => cp + sp + ep + gp + pp;

  Wallet copyWith({int? cp, int? sp, int? ep, int? gp, int? pp}) => Wallet(
    cp: cp ?? this.cp,
    sp: sp ?? this.sp,
    ep: ep ?? this.ep,
    gp: gp ?? this.gp,
    pp: pp ?? this.pp,
  );

  Map<String, Object?> toJson() => {
    'cp': cp,
    'sp': sp,
    'ep': ep,
    'gp': gp,
    'pp': pp,
  };
  factory Wallet.fromJson(Map<String, Object?> j) => Wallet(
    cp: (j['cp'] as num?)?.toInt() ?? 0,
    sp: (j['sp'] as num?)?.toInt() ?? 0,
    ep: (j['ep'] as num?)?.toInt() ?? 0,
    gp: (j['gp'] as num?)?.toInt() ?? 0,
    pp: (j['pp'] as num?)?.toInt() ?? 0,
  );
}

class ClassLevel {
  const ClassLevel(this.className, this.level, {this.subclass = ''});
  final String className;
  final int level;
  final String subclass;

  Map<String, Object?> toJson() => {
    'className': className,
    'level': level,
    'subclass': subclass,
  };
  factory ClassLevel.fromJson(Map<String, Object?> j) => ClassLevel(
    j['className'] as String,
    (j['level'] as num).toInt(),
    subclass: (j['subclass'] as String?) ?? '',
  );
}

class TurnState {
  const TurnState({
    this.action = false,
    this.bonusAction = false,
    this.reaction = false,
    this.movementUsed = 0,
    this.leveledActionSpell = false,
    this.bonusActionSpell = false,
    this.attacksMade = 0,
  });

  final bool action;
  final bool bonusAction;
  final bool reaction;
  final int movementUsed;

  /// A non-cantrip spell cast with an action this turn.
  final bool leveledActionSpell;

  /// A spell cast with a bonus action this turn.
  final bool bonusActionSpell;
  final int attacksMade;

  TurnState copyWith({
    bool? action,
    bool? bonusAction,
    bool? reaction,
    int? movementUsed,
    bool? leveledActionSpell,
    bool? bonusActionSpell,
    int? attacksMade,
  }) => TurnState(
    action: action ?? this.action,
    bonusAction: bonusAction ?? this.bonusAction,
    reaction: reaction ?? this.reaction,
    movementUsed: movementUsed ?? this.movementUsed,
    leveledActionSpell: leveledActionSpell ?? this.leveledActionSpell,
    bonusActionSpell: bonusActionSpell ?? this.bonusActionSpell,
    attacksMade: attacksMade ?? this.attacksMade,
  );

  Map<String, Object?> toJson() => {
    'action': action,
    'bonusAction': bonusAction,
    'reaction': reaction,
    'movementUsed': movementUsed,
    'leveledActionSpell': leveledActionSpell,
    'bonusActionSpell': bonusActionSpell,
    'attacksMade': attacksMade,
  };

  factory TurnState.fromJson(Map<String, Object?> j) => TurnState(
    action: (j['action'] as bool?) ?? false,
    bonusAction: (j['bonusAction'] as bool?) ?? false,
    reaction: (j['reaction'] as bool?) ?? false,
    movementUsed: (j['movementUsed'] as num?)?.toInt() ?? 0,
    leveledActionSpell: (j['leveledActionSpell'] as bool?) ?? false,
    bonusActionSpell: (j['bonusActionSpell'] as bool?) ?? false,
    attacksMade: (j['attacksMade'] as num?)?.toInt() ?? 0,
  );
}

/// Where a feature or trait comes from.
enum FeatureSource {
  classFeature('Class'),
  species('Species'),
  background('Background'),
  subclass('Subclass'),
  other('Other');

  const FeatureSource(this.label);
  final String label;
}

class Feature {
  const Feature(
    this.name,
    this.text, {
    this.source = FeatureSource.classFeature,
    this.pinned = '',
  });
  final String name;
  final String text;
  final FeatureSource source;

  /// A short label (e.g. "Fire resistance") shown in the Overview's
  /// "Senses & resistances" panel. Empty means not pinned.
  final String pinned;

  Feature copyWith({
    String? name,
    String? text,
    FeatureSource? source,
    String? pinned,
  }) => Feature(
    name ?? this.name,
    text ?? this.text,
    source: source ?? this.source,
    pinned: pinned ?? this.pinned,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'text': text,
    'source': source.name,
    'pinned': pinned,
  };
  factory Feature.fromJson(Map<String, Object?> j) => Feature(
    j['name'] as String,
    (j['text'] as String?) ?? '',
    source: _enum(
      FeatureSource.values,
      j['source'],
      FeatureSource.classFeature,
    ),
    pinned: (j['pinned'] as String?) ?? '',
  );
}

class Character {
  const Character({
    required this.id,
    required this.name,
    required this.race,
    required this.classes,
    required this.abilities,
    required this.hpCurrent,
    this.background = '',
    this.saveProfs = const {},
    this.saveBonuses = const {},
    this.skills = const {},
    this.skillAdv = const {},
    this.jackOfAllTrades = false,
    this.armorProfs = const {},
    this.tempHp = 0,
    this.maxHpOverride,
    this.hitDiceUsed = const {},
    this.deathSuccesses = 0,
    this.deathFailures = 0,
    this.stable = false,
    this.dead = false,
    this.conditions = const {},
    this.exhaustion = 0,
    this.inspiration = false,
    this.concentration,
    this.slotsUsed = const {},
    this.pactUsed = 0,
    this.resources = const [],
    this.spells = const [],
    this.items = const [],
    this.wallet = const Wallet(),
    this.modifiers = const [],
    this.features = const [],
    this.flags = const {},
    this.notes = '',
    this.turn = const TurnState(),
    this.compactMode = false,
    this.variantEncumbrance = false,
    this.baseSpeed = 30,
    this.weaponProfs = const {},
    this.metamagic = const {},
  });

  final String id;
  final String name;
  final String race;
  final String background;
  final List<ClassLevel> classes;
  final Map<Ability, int> abilities;
  final Set<Ability> saveProfs;

  /// Extra flat bonus per ability's saving throw (can be negative).
  final Map<Ability, int> saveBonuses;
  final Map<Skill, Proficiency> skills;
  final Map<Skill, AdvState> skillAdv;
  final bool jackOfAllTrades;

  /// Any of: light, medium, heavy, shields.
  final Set<String> armorProfs;
  final int hpCurrent;
  final int tempHp;
  final int? maxHpOverride;

  /// Hit dice spent, by die size (6, 8, 10, 12).
  final Map<int, int> hitDiceUsed;
  final int deathSuccesses;
  final int deathFailures;
  final bool stable;
  final bool dead;
  final Set<String> conditions;
  final int exhaustion;
  final bool inspiration;
  final String? concentration;

  /// Spell slots spent, by spell level (1-9).
  final Map<int, int> slotsUsed;
  final int pactUsed;
  final List<Resource> resources;
  final List<Spell> spells;
  final List<Item> items;
  final Wallet wallet;

  /// Manual or temporary modifiers (feats, spells, potions).
  final List<Effect> modifiers;
  final List<Feature> features;

  /// Switches such as `mageArmor`, `draconicResilience`.
  final Set<String> flags;
  final String notes;
  final TurnState turn;
  final bool compactMode;
  final bool variantEncumbrance;
  final int baseSpeed;

  /// `simple`, `martial` and named weapons (lowercase).
  final Set<String> weaponProfs;

  /// Chosen Metamagic option names (Sorcerer).
  final Set<String> metamagic;

  int get level => classes.fold(0, (s, c) => s + c.level);
  ClassLevel get primaryClass => classes.first;
  String get classLine => classes
      .map(
        (c) =>
            '${c.className}${c.subclass.isEmpty ? '' : ' (${c.subclass})'} ${c.level}',
      )
      .join(' / ');

  Character copyWith({
    String? name,
    String? race,
    String? background,
    List<ClassLevel>? classes,
    Map<Ability, int>? abilities,
    Set<Ability>? saveProfs,
    Map<Ability, int>? saveBonuses,
    Map<Skill, Proficiency>? skills,
    Map<Skill, AdvState>? skillAdv,
    bool? jackOfAllTrades,
    Set<String>? armorProfs,
    int? hpCurrent,
    int? tempHp,
    Object? maxHpOverride = _unset,
    Map<int, int>? hitDiceUsed,
    int? deathSuccesses,
    int? deathFailures,
    bool? stable,
    bool? dead,
    Set<String>? conditions,
    int? exhaustion,
    bool? inspiration,
    Object? concentration = _unset,
    Map<int, int>? slotsUsed,
    int? pactUsed,
    List<Resource>? resources,
    List<Spell>? spells,
    List<Item>? items,
    Wallet? wallet,
    List<Effect>? modifiers,
    List<Feature>? features,
    Set<String>? flags,
    String? notes,
    TurnState? turn,
    bool? compactMode,
    bool? variantEncumbrance,
    int? baseSpeed,
    Set<String>? weaponProfs,
    Set<String>? metamagic,
  }) => Character(
    id: id,
    name: name ?? this.name,
    race: race ?? this.race,
    background: background ?? this.background,
    classes: classes ?? this.classes,
    abilities: abilities ?? this.abilities,
    saveProfs: saveProfs ?? this.saveProfs,
    saveBonuses: saveBonuses ?? this.saveBonuses,
    skills: skills ?? this.skills,
    skillAdv: skillAdv ?? this.skillAdv,
    jackOfAllTrades: jackOfAllTrades ?? this.jackOfAllTrades,
    armorProfs: armorProfs ?? this.armorProfs,
    hpCurrent: hpCurrent ?? this.hpCurrent,
    tempHp: tempHp ?? this.tempHp,
    maxHpOverride: identical(maxHpOverride, _unset)
        ? this.maxHpOverride
        : maxHpOverride as int?,
    hitDiceUsed: hitDiceUsed ?? this.hitDiceUsed,
    deathSuccesses: deathSuccesses ?? this.deathSuccesses,
    deathFailures: deathFailures ?? this.deathFailures,
    stable: stable ?? this.stable,
    dead: dead ?? this.dead,
    conditions: conditions ?? this.conditions,
    exhaustion: exhaustion ?? this.exhaustion,
    inspiration: inspiration ?? this.inspiration,
    concentration: identical(concentration, _unset)
        ? this.concentration
        : concentration as String?,
    slotsUsed: slotsUsed ?? this.slotsUsed,
    pactUsed: pactUsed ?? this.pactUsed,
    resources: resources ?? this.resources,
    spells: spells ?? this.spells,
    items: items ?? this.items,
    wallet: wallet ?? this.wallet,
    modifiers: modifiers ?? this.modifiers,
    features: features ?? this.features,
    flags: flags ?? this.flags,
    notes: notes ?? this.notes,
    turn: turn ?? this.turn,
    compactMode: compactMode ?? this.compactMode,
    variantEncumbrance: variantEncumbrance ?? this.variantEncumbrance,
    baseSpeed: baseSpeed ?? this.baseSpeed,
    weaponProfs: weaponProfs ?? this.weaponProfs,
    metamagic: metamagic ?? this.metamagic,
  );

  static const Object _unset = Object();

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'name': name,
    'race': race,
    'background': background,
    'classes': classes.map((c) => c.toJson()).toList(),
    'abilities': {for (final e in abilities.entries) e.key.name: e.value},
    'saveProfs': saveProfs.map((a) => a.name).toList(),
    'saveBonuses': {for (final e in saveBonuses.entries) e.key.name: e.value},
    'skills': {for (final e in skills.entries) e.key.name: e.value.name},
    'skillAdv': {for (final e in skillAdv.entries) e.key.name: e.value.name},
    'jackOfAllTrades': jackOfAllTrades,
    'armorProfs': armorProfs.toList(),
    'hpCurrent': hpCurrent,
    'tempHp': tempHp,
    'maxHpOverride': maxHpOverride,
    'hitDiceUsed': {for (final e in hitDiceUsed.entries) '${e.key}': e.value},
    'deathSuccesses': deathSuccesses,
    'deathFailures': deathFailures,
    'stable': stable,
    'dead': dead,
    'conditions': conditions.toList(),
    'exhaustion': exhaustion,
    'inspiration': inspiration,
    'concentration': concentration,
    'slotsUsed': {for (final e in slotsUsed.entries) '${e.key}': e.value},
    'pactUsed': pactUsed,
    'resources': resources.map((r) => r.toJson()).toList(),
    'spells': spells.map((s) => s.toJson()).toList(),
    'items': items.map((i) => i.toJson()).toList(),
    'wallet': wallet.toJson(),
    'modifiers': modifiers.map((e) => e.toJson()).toList(),
    'features': features.map((f) => f.toJson()).toList(),
    'flags': flags.toList(),
    'notes': notes,
    'turn': turn.toJson(),
    'compactMode': compactMode,
    'variantEncumbrance': variantEncumbrance,
    'baseSpeed': baseSpeed,
    'weaponProfs': weaponProfs.toList(),
    'metamagic': metamagic.toList(),
  };

  factory Character.fromJson(Map<String, Object?> j) {
    List<T> list<T>(String k, T Function(Map<String, Object?>) f) =>
        ((j[k] as List?) ?? const []).map((e) => f((e as Map).cast())).toList();
    Map<K, V> map<K, V>(
      String k,
      K Function(String) kf,
      V Function(Object?) vf,
    ) => {
      for (final e in ((j[k] as Map?) ?? const {}).entries)
        kf(e.key as String): vf(e.value),
    };

    return Character(
      id: j['id'] as String,
      name: j['name'] as String,
      race: (j['race'] as String?) ?? '',
      background: (j['background'] as String?) ?? '',
      classes: list('classes', ClassLevel.fromJson),
      abilities: map('abilities', Ability.parse, (v) => (v as num).toInt()),
      saveProfs: ((j['saveProfs'] as List?) ?? const [])
          .map((e) => Ability.parse(e as String))
          .toSet(),
      saveBonuses: map('saveBonuses', Ability.parse, (v) => (v as num).toInt()),
      skills: map(
        'skills',
        Skill.parse,
        (v) => _enum(Proficiency.values, v, Proficiency.none),
      ),
      skillAdv: map(
        'skillAdv',
        Skill.parse,
        (v) => _enum(AdvState.values, v, AdvState.none),
      ),
      jackOfAllTrades: (j['jackOfAllTrades'] as bool?) ?? false,
      armorProfs: ((j['armorProfs'] as List?) ?? const [])
          .cast<String>()
          .toSet(),
      hpCurrent: (j['hpCurrent'] as num).toInt(),
      tempHp: (j['tempHp'] as num?)?.toInt() ?? 0,
      maxHpOverride: (j['maxHpOverride'] as num?)?.toInt(),
      hitDiceUsed: map('hitDiceUsed', int.parse, (v) => (v as num).toInt()),
      deathSuccesses: (j['deathSuccesses'] as num?)?.toInt() ?? 0,
      deathFailures: (j['deathFailures'] as num?)?.toInt() ?? 0,
      stable: (j['stable'] as bool?) ?? false,
      dead: (j['dead'] as bool?) ?? false,
      conditions: ((j['conditions'] as List?) ?? const [])
          .cast<String>()
          .toSet(),
      exhaustion: (j['exhaustion'] as num?)?.toInt() ?? 0,
      inspiration: (j['inspiration'] as bool?) ?? false,
      concentration: j['concentration'] as String?,
      slotsUsed: map('slotsUsed', int.parse, (v) => (v as num).toInt()),
      pactUsed: (j['pactUsed'] as num?)?.toInt() ?? 0,
      resources: list('resources', Resource.fromJson),
      spells: list('spells', Spell.fromJson),
      items: list('items', Item.fromJson),
      wallet: j['wallet'] == null
          ? const Wallet()
          : Wallet.fromJson((j['wallet'] as Map).cast()),
      modifiers: list('modifiers', Effect.fromJson),
      features: list('features', Feature.fromJson),
      flags: ((j['flags'] as List?) ?? const []).cast<String>().toSet(),
      notes: (j['notes'] as String?) ?? '',
      turn: j['turn'] == null
          ? const TurnState()
          : TurnState.fromJson((j['turn'] as Map).cast()),
      compactMode: (j['compactMode'] as bool?) ?? false,
      variantEncumbrance: (j['variantEncumbrance'] as bool?) ?? false,
      baseSpeed: (j['baseSpeed'] as num?)?.toInt() ?? 30,
      weaponProfs: ((j['weaponProfs'] as List?) ?? const [])
          .cast<String>()
          .toSet(),
      metamagic: ((j['metamagic'] as List?) ?? const []).cast<String>().toSet(),
    );
  }
}
