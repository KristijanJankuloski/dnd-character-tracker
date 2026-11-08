/// State-changing operations as pure functions. Each returns the new character,
/// a log description and any warnings. The app warns and never blocks, except
/// for the fourth attunement.
library;

import 'class_templates.dart';
import 'models.dart';
import 'rules.dart';
import 'tables.dart';

class ActionResult {
  const ActionResult(
    this.character,
    this.description, {
    this.warnings = const [],
    this.blocked = false,
  });

  /// A refused action: the character is unchanged and [description] says why.
  const ActionResult.blocked(this.character, this.description)
    : warnings = const [],
      blocked = true;

  final Character character;
  final String description;
  final List<String> warnings;
  final bool blocked;
}

// ---------------------------------------------------------------- HP

ActionResult applyDamage(Character c, int amount, {bool crit = false}) {
  if (amount <= 0) {
    return ActionResult.blocked(c, 'Enter a damage amount above 0.');
  }
  final stats = resolveStats(c);
  final warnings = <String>[];
  var temp = c.tempHp;
  var remaining = amount;
  final absorbed = remaining < temp ? remaining : temp;
  temp -= absorbed;
  remaining -= absorbed;

  var hp = c.hpCurrent;
  var successes = c.deathSuccesses;
  var failures = c.deathFailures;
  var conditions = c.conditions;
  var concentration = c.concentration;
  var stable = c.stable;
  var dead = c.dead;

  if (hp == 0) {
    // Damage at 0 HP is a death save failure (two on a crit).
    if (remaining > 0 || absorbed == 0) {
      failures += crit ? 2 : 1;
      stable = false;
      if (remaining >= stats.maxHp) {
        warnings.add(
          'Damage at 0 HP equals or exceeds max HP: instant death by the rules. Use "Mark as dead" if your DM confirms.',
        );
      }
      if (failures >= 3) dead = true;
    }
  } else {
    final newHp = hp - remaining;
    if (newHp <= 0) {
      final overflow = -newHp;
      hp = 0;
      conditions = {...conditions, 'unconscious'};
      successes = 0;
      failures = 0;
      if (overflow >= stats.maxHp) {
        warnings.add(
          'Remaining damage ($overflow) equals or exceeds max HP: instant death by the rules. Use "Mark as dead" if your DM confirms.',
        );
      }
      if (concentration != null) {
        warnings.add('Dropped to 0 HP: concentration on $concentration ended.');
        concentration = null;
      }
    } else {
      hp = newHp;
    }
    // Damage that only hit temp HP still calls for a concentration check.
    if (hp > 0 && concentration != null) {
      warnings.add(
        'Concentration check: CON save DC ${concentrationDc(amount)} to keep $concentration.',
      );
    }
  }
  if (dead && !c.dead) warnings.add('${c.name} is dead.');

  final out = c.copyWith(
    hpCurrent: hp,
    tempHp: temp,
    deathSuccesses: successes,
    deathFailures: failures,
    conditions: conditions,
    concentration: concentration,
    stable: stable,
    dead: dead,
  );
  return ActionResult(
    out,
    'Took $amount damage${crit ? ' (crit)' : ''}: HP ${c.hpCurrent} to $hp',
    warnings: warnings,
  );
}

ActionResult applyHeal(Character c, int amount) {
  if (amount <= 0) {
    return ActionResult.blocked(c, 'Enter a healing amount above 0.');
  }
  if (c.dead) {
    return ActionResult.blocked(
      c,
      '${c.name} is marked dead. Dismiss that first if it was a mistake.',
    );
  }
  final max = resolveStats(c).maxHp;
  final hp = (c.hpCurrent + amount).clamp(0, max);
  final out = c.copyWith(
    hpCurrent: hp,
    deathSuccesses: 0,
    deathFailures: 0,
    stable: false,
    dead: false,
    conditions: {...c.conditions}..remove('unconscious'),
  );
  return ActionResult(out, 'Healed $amount: HP ${c.hpCurrent} to $hp');
}

/// The player decides death (for example after massive damage).
ActionResult markDead(Character c) => ActionResult(
  c.copyWith(dead: true, stable: false),
  '${c.name} marked dead',
);

/// Clears a death banner and the death saves. The character stays at 0 HP.
ActionResult dismissDeath(Character c) => ActionResult(
  c.copyWith(dead: false, deathSuccesses: 0, deathFailures: 0, stable: false),
  'Dismissed death for ${c.name}',
);

ActionResult setTempHp(Character c, int value) {
  final v = value < 0 ? 0 : value;
  return ActionResult(c.copyWith(tempHp: v), 'Temp HP ${c.tempHp} to $v');
}

ActionResult recordDeathSave(Character c, String kind) {
  var s = c.deathSuccesses, f = c.deathFailures;
  var hp = c.hpCurrent;
  var stable = c.stable, dead = c.dead;
  var conditions = c.conditions;
  final warnings = <String>[];
  switch (kind) {
    case 'success':
      s++;
    case 'failure':
      f++;
    case 'nat20':
      hp = 1;
      s = 0;
      f = 0;
      conditions = {...conditions}..remove('unconscious');
    case 'nat1':
      f += 2;
  }
  if (s >= 3) {
    stable = true;
    warnings.add('Three successes: stable.');
  }
  if (f >= 3) {
    dead = true;
    warnings.add('Three failures: ${c.name} is dead.');
  }
  return ActionResult(
    c.copyWith(
      deathSuccesses: s.clamp(0, 3),
      deathFailures: f.clamp(0, 3),
      hpCurrent: hp,
      stable: stable,
      dead: dead,
      conditions: conditions,
    ),
    kind == 'nat20'
        ? 'Natural 20 death save: regained 1 HP'
        : 'Death save: $kind',
    warnings: warnings,
  );
}

/// Spend one hit die. [roll] is the die roll entered by the player.
ActionResult spendHitDie(Character c, int die, int roll) {
  final stats = resolveStats(c);
  final max = stats.hitDice[die] ?? 0;
  final used = c.hitDiceUsed[die] ?? 0;
  if (used >= max) return ActionResult.blocked(c, 'No d$die hit dice left.');
  final healing = (roll + stats.mods[Ability.con]!).clamp(0, 999);
  var out = c;
  if (healing > 0) {
    final healed = applyHeal(c, healing);
    if (healed.blocked) return healed;
    out = healed.character;
  }
  return ActionResult(
    out.copyWith(hitDiceUsed: {...c.hitDiceUsed, die: used + 1}),
    'Spent a d$die hit die (rolled $roll): healed $healing',
  );
}

// ---------------------------------------------------------------- Slots

int slotsRemaining(Character c, CharacterStats s, int level) =>
    (s.slotMax[level] ?? 0) - (c.slotsUsed[level] ?? 0);

int pactRemaining(Character c, CharacterStats s) =>
    (s.pactSlots?.$1 ?? 0) - c.pactUsed;

/// Toggle one pip: spend when [spend] is true, otherwise restore.
ActionResult changeSlot(
  Character c,
  int level, {
  required bool spend,
  bool force = false,
}) {
  final s = resolveStats(c);
  final used = c.slotsUsed[level] ?? 0;
  final max = s.slotMax[level] ?? 0;
  if (spend) {
    if (used >= max && !force) {
      return ActionResult.blocked(c, 'No level $level slots left.');
    }
    return ActionResult(
      c.copyWith(slotsUsed: {...c.slotsUsed, level: used + 1}),
      'Spent a level $level slot',
    );
  }
  if (used <= 0) {
    return ActionResult.blocked(c, 'No spent level $level slots to restore.');
  }
  return ActionResult(
    c.copyWith(slotsUsed: {...c.slotsUsed, level: used - 1}),
    'Restored a level $level slot',
  );
}

ActionResult changePactSlot(Character c, {required bool spend}) {
  final s = resolveStats(c);
  final max = s.pactSlots?.$1 ?? 0;
  if (spend) {
    if (c.pactUsed >= max) {
      return ActionResult.blocked(c, 'No pact slots left.');
    }
    return ActionResult(
      c.copyWith(pactUsed: c.pactUsed + 1),
      'Spent a pact slot',
    );
  }
  if (c.pactUsed <= 0) return ActionResult.blocked(c, 'No spent pact slots.');
  return ActionResult(
    c.copyWith(pactUsed: c.pactUsed - 1),
    'Restored a pact slot',
  );
}

// ---------------------------------------------------------------- Spells

/// Cast [spell] at [slotLevel] (ignored for cantrips and rituals). Marks the
/// turn toggle, sets concentration and returns rule warnings.
ActionResult castSpell(
  Character c,
  Spell spell, {
  int? slotLevel,
  bool ritual = false,
  bool pact = false,
  bool replaceConcentration = false,
}) {
  final s = resolveStats(c);
  final warnings = <String>[];
  var out = c;

  if (ritual && !canRitualCast(c, spell)) {
    return ActionResult.blocked(
      c,
      '${spell.name} cannot be cast as a ritual by this character.',
    );
  }
  if (spell.concentration &&
      c.concentration != null &&
      c.concentration != spell.name &&
      !replaceConcentration) {
    return ActionResult.blocked(
      c,
      'You are concentrating on ${c.concentration}. Casting ${spell.name} would end it.',
    );
  }

  if (s.warnings.any((w) => w.contains("can't cast"))) {
    warnings.add(
      "Armor proficiency: you can't cast spells in armor or with a shield you aren't proficient with.",
    );
  }

  var label = spell.name;
  if (ritual) {
    label = '${spell.name} (ritual, +10 min)';
  } else if (!spell.isCantrip) {
    if (pact) {
      if (pactRemaining(c, s) <= 0) {
        return ActionResult.blocked(c, 'No pact slots left.');
      }
      out = out.copyWith(pactUsed: out.pactUsed + 1);
      label = '${spell.name} (pact slot)';
    } else {
      final lvl = slotLevel ?? spell.level;
      if (lvl < spell.level) {
        return ActionResult.blocked(
          c,
          '${spell.name} needs a level ${spell.level} slot or higher.',
        );
      }
      if (slotsRemaining(c, s, lvl) <= 0) {
        return ActionResult.blocked(c, 'No level $lvl slots left.');
      }
      out = out.copyWith(
        slotsUsed: {...out.slotsUsed, lvl: (out.slotsUsed[lvl] ?? 0) + 1},
      );
      label = lvl > spell.level ? '${spell.name} (upcast at $lvl)' : spell.name;
    }
  }

  // Turn economy.
  var turn = out.turn;
  switch (spell.castingTime) {
    case CastingTime.action:
      turn = turn.copyWith(
        action: true,
        leveledActionSpell: turn.leveledActionSpell || !spell.isCantrip,
      );
      if (!spell.isCantrip && turn.bonusActionSpell) {
        warnings.add(
          'Rule: if you cast a spell as a bonus action, you can only cast a cantrip with a 1-action casting time on the same turn.',
        );
      }
    case CastingTime.bonusAction:
      turn = turn.copyWith(bonusAction: true, bonusActionSpell: true);
      if (c.turn.leveledActionSpell) {
        warnings.add(
          'Rule: you already cast a leveled spell this turn. A bonus-action spell means only a cantrip with a 1-action casting time is allowed alongside it.',
        );
      }
    case CastingTime.reaction:
      turn = turn.copyWith(reaction: true);
    case CastingTime.other:
      break;
  }
  out = out.copyWith(turn: turn);

  // Concentration.
  if (spell.concentration) {
    if (out.concentration != null && out.concentration != spell.name) {
      warnings.add('Ended concentration on ${out.concentration}.');
    }
    out = out.copyWith(concentration: spell.name);
  }
  return ActionResult(out, 'Cast $label', warnings: warnings);
}

ActionResult endConcentration(Character c) {
  if (c.concentration == null) {
    return ActionResult.blocked(c, 'Not concentrating.');
  }
  return ActionResult(
    c.copyWith(concentration: null),
    'Ended concentration on ${c.concentration}',
  );
}

ActionResult togglePrepared(Character c, String spellId) {
  final spells = [
    for (final s in c.spells)
      s.id == spellId && !s.alwaysPrepared
          ? s.copyWith(prepared: !s.prepared)
          : s,
  ];
  final spell = c.spells.firstWhere((s) => s.id == spellId);
  final stats = resolveStats(c);
  final warnings = <String>[];
  if (!spell.prepared && !spell.isCantrip) {
    final limit = preparedLimit(c, stats);
    final count = spells
        .where((s) => s.prepared && !s.isCantrip && !s.alwaysPrepared)
        .length;
    if (count > limit) warnings.add('$count prepared; your limit is $limit.');
  }
  return ActionResult(
    c.copyWith(spells: spells),
    '${spell.prepared ? 'Unprepared' : 'Prepared'} ${spell.name}',
    warnings: warnings,
  );
}

ActionResult addSpell(Character c, Spell spell) {
  if (c.spells.any((s) => s.name == spell.name)) {
    return ActionResult.blocked(c, '${spell.name} is already on the list.');
  }
  final cl = c.primaryClass;
  final t = templateFor(cl.className);
  final model = spellModelFor(cl, t);
  // Prepared casters add to their list unprepared; cantrips are always ready.
  final added = model == SpellModel.prepared && !spell.isCantrip
      ? spell.copyWith(prepared: false)
      : spell;
  final warnings = <String>[];
  final limits = knownLimits(cl.className, cl.level);
  if (limits != null) {
    final all = [...c.spells, added];
    final cantrips = all.where((s) => s.isCantrip).length;
    if (cantrips > limits.cantrips) {
      warnings.add('$cantrips cantrips; your class knows ${limits.cantrips}.');
    }
    final known = all.where((s) => !s.isCantrip).length;
    if (limits.spells != null && known > limits.spells!) {
      warnings.add(
        '$known spells known; your class limit is ${limits.spells}.',
      );
    }
  }
  return ActionResult(
    c.copyWith(spells: [...c.spells, added]),
    'Added spell ${spell.name}',
    warnings: warnings,
  );
}

ActionResult removeSpell(Character c, String id) {
  final s = c.spells.firstWhere((s) => s.id == id);
  return ActionResult(
    c.copyWith(spells: c.spells.where((x) => x.id != id).toList()),
    'Removed spell ${s.name}',
  );
}

// ---------------------------------------------------------------- Resources

int resourceMax(Character c, Resource r) {
  final s = resolveStats(c);
  return maxResource(c, r, (a) => s.mods[a]!);
}

ActionResult changeResource(
  Character c,
  String id,
  int delta, {
  bool force = false,
}) {
  final r = c.resources.firstWhere((r) => r.id == id);
  final max = resourceMax(c, r);
  final next = r.current + delta;
  final warnings = <String>[];
  if (next < 0) {
    if (!force) return ActionResult.blocked(c, 'Not enough ${r.name}.');
    warnings.add('${r.name} went below 0.');
  }
  final clamped = next > max ? max : next;
  return ActionResult(
    c.copyWith(
      resources: [
        for (final x in c.resources)
          x.id == id ? x.copyWith(current: clamped) : x,
      ],
    ),
    '${r.name} ${r.current} to $clamped',
    warnings: warnings,
  );
}

ActionResult setResource(Character c, String id, int value) {
  final r = c.resources.firstWhere((r) => r.id == id);
  final max = resourceMax(c, r);
  final v = value.clamp(0, max);
  return ActionResult(
    c.copyWith(
      resources: [
        for (final x in c.resources) x.id == id ? x.copyWith(current: v) : x,
      ],
    ),
    '${r.name} set to $v',
  );
}

ActionResult toggleResourceActive(Character c, String id) {
  final r = c.resources.firstWhere((r) => r.id == id);
  return ActionResult(
    c.copyWith(
      resources: [
        for (final x in c.resources)
          x.id == id ? x.copyWith(active: !x.active) : x,
      ],
    ),
    '${r.name} ${r.active ? 'ended' : 'active'}',
  );
}

/// Flexible Casting: convert Sorcery Points to a slot of [level] (1-5).
ActionResult sorceryPointsToSlot(Character c, int level) {
  final cost = sorceryPointSlotCost[level];
  if (cost == null) {
    return ActionResult.blocked(
      c,
      'Flexible Casting can only make slots of level 1-5.',
    );
  }
  final sp = c.resources.where((r) => r.id == 'sorcery-points').firstOrNull;
  if (sp == null) return ActionResult.blocked(c, 'No Sorcery Points resource.');
  if (sp.current < cost) {
    return ActionResult.blocked(
      c,
      'Level $level slot costs $cost Sorcery Points; you have ${sp.current}.',
    );
  }
  final stats = resolveStats(c);
  final used = c.slotsUsed[level] ?? 0;
  final warnings = <String>[];
  // A created slot beyond the maximum is modelled as a negative used count.
  final slots = {...c.slotsUsed, level: used - 1};
  if (used <= 0) {
    warnings.add(
      'Created an extra level $level slot above your normal maximum (${stats.slotMax[level] ?? 0}). It vanishes at a long rest.',
    );
  }
  return ActionResult(
    c.copyWith(
      slotsUsed: slots,
      resources: [
        for (final x in c.resources)
          x.id == sp.id ? x.copyWith(current: sp.current - cost) : x,
      ],
    ),
    'Converted $cost Sorcery Points into a level $level slot',
    warnings: warnings,
  );
}

/// Flexible Casting: burn a slot for Sorcery Points equal to its level.
ActionResult slotToSorceryPoints(Character c, int level) {
  final sp = c.resources.where((r) => r.id == 'sorcery-points').firstOrNull;
  if (sp == null) return ActionResult.blocked(c, 'No Sorcery Points resource.');
  final stats = resolveStats(c);
  if (slotsRemaining(c, stats, level) <= 0) {
    return ActionResult.blocked(c, 'No level $level slots left.');
  }
  final max = resourceMax(c, sp);
  final gained = (sp.current + level) > max ? max - sp.current : level;
  return ActionResult(
    c.copyWith(
      slotsUsed: {...c.slotsUsed, level: (c.slotsUsed[level] ?? 0) + 1},
      resources: [
        for (final x in c.resources)
          x.id == sp.id ? x.copyWith(current: sp.current + gained) : x,
      ],
    ),
    'Converted a level $level slot into $gained Sorcery Points',
    warnings: gained < level ? ['Sorcery Points capped at $max.'] : const [],
  );
}

// ---------------------------------------------------------------- Turn

ActionResult toggleTurn(Character c, String kind) {
  final t = c.turn;
  final next = switch (kind) {
    'action' => t.copyWith(action: !t.action),
    'bonus' => t.copyWith(bonusAction: !t.bonusAction),
    'reaction' => t.copyWith(reaction: !t.reaction),
    _ => t,
  };
  return ActionResult(c.copyWith(turn: next), 'Toggled $kind');
}

ActionResult newTurn(Character c) =>
    ActionResult(c.copyWith(turn: const TurnState()), 'New turn');

ActionResult addMovement(Character c, int feet) {
  final speed = resolveStats(c).speed.total;
  final used = c.turn.movementUsed + feet < 0 ? 0 : c.turn.movementUsed + feet;
  return ActionResult(
    c.copyWith(turn: c.turn.copyWith(movementUsed: used)),
    'Moved $feet ft.',
    warnings: [
      if (used > speed) 'Over your speed by ${used - speed} ft. (Dash?)',
    ],
  );
}

/// Use an attack card: first attack marks the Action; Extra Attack is tracked
/// by [attacksPerAction].
ActionResult useAttack(
  Character c,
  AttackInfo a, {
  int attacksPerAction = 1,
  bool offHand = false,
}) {
  var out = c;
  final warnings = <String>[];
  var turn = c.turn;
  if (offHand) {
    // Two-Weapon Fighting: the Light-weapon attack uses the bonus action.
    final item = c.items.where((i) => i.id == a.itemId).firstOrNull;
    if (item?.weapon?.light != true) {
      warnings.add('Two-Weapon Fighting needs a Light melee weapon.');
    }
    if (!c.turn.action && c.turn.attacksMade == 0) {
      warnings.add(
        'Two-Weapon Fighting: take the Attack action with a Light weapon first.',
      );
    }
    warnings.add(
      "Off-hand damage doesn't add your ability modifier unless it is negative.",
    );
    turn = turn.copyWith(bonusAction: true);
  } else {
    final made = c.turn.attacksMade + 1;
    if (made >= attacksPerAction) {
      turn = turn.copyWith(action: true, attacksMade: 0);
    } else {
      turn = turn.copyWith(attacksMade: made);
    }
  }
  out = out.copyWith(turn: turn);

  if (a.itemId != null) {
    final item = c.items.firstWhere((i) => i.id == a.itemId);
    final ammoId = item.weapon?.ammoItemId;
    if (ammoId != null) {
      final ammo = c.items.where((i) => i.id == ammoId).firstOrNull;
      if (ammo == null || ammo.quantity <= 0) {
        warnings.add('Out of ammo.');
      } else {
        out = out.copyWith(
          items: [
            for (final i in out.items)
              i.id == ammoId ? i.copyWith(quantity: i.quantity - 1) : i,
          ],
        );
      }
    }
  }
  return ActionResult(out, 'Used ${a.name}', warnings: warnings);
}

// ---------------------------------------------------------------- Conditions

ActionResult toggleCondition(Character c, String id) {
  final set = {...c.conditions};
  final removed = set.remove(id);
  if (!removed) set.add(id);
  // Incapacitating conditions end concentration.
  const breaksConcentration = {
    'incapacitated',
    'stunned',
    'paralyzed',
    'unconscious',
    'petrified',
  };
  final ends =
      !removed && breaksConcentration.contains(id) && c.concentration != null;
  return ActionResult(
    c.copyWith(conditions: set, concentration: ends ? null : c.concentration),
    '${removed ? 'Removed' : 'Added'} condition $id',
    warnings: [if (ends) 'Concentration on ${c.concentration} ended ($id).'],
  );
}

ActionResult setExhaustion(Character c, int level) {
  final l = level.clamp(0, 6);
  final warnings = <String>[
    if (l > 0) 'Exhaustion $l: ${exhaustionRules[l]}',
    if (l == 6) 'Exhaustion 6 means death.',
  ];
  return ActionResult(
    c.copyWith(exhaustion: l),
    'Exhaustion $l',
    warnings: warnings,
  );
}

ActionResult toggleInspiration(Character c) => ActionResult(
  c.copyWith(inspiration: !c.inspiration),
  c.inspiration ? 'Used Inspiration' : 'Gained Inspiration',
);

// ---------------------------------------------------------------- Rest

/// Preview what a rest will restore, as plain lines.
List<String> restPreview(Character c, {required bool longRest}) {
  final lines = <String>[];
  final s = resolveStats(c);
  if (longRest) {
    lines.add('HP back to ${s.maxHp}');
    lines.add('Temp HP cleared');
    final used = s.hitDice.entries.fold(
      0,
      (sum, e) => sum + (c.hitDiceUsed[e.key] ?? 0),
    );
    if (used > 0) lines.add('Hit dice: regain up to half your total (min 1)');
    if (c.slotsUsed.values.any((v) => v != 0)) lines.add('All spell slots');
    if (c.pactUsed > 0) lines.add('Pact slots');
    if (c.exhaustion > 0) lines.add('Exhaustion -1');
    if (c.concentration != null) lines.add('Concentration ends');
  } else {
    lines.add('Spend hit dice on the Character tab to heal');
    if (c.pactUsed > 0) lines.add('Pact slots');
  }
  for (final r in c.resources.where((r) => resourceLevel(c, r) >= r.minLevel)) {
    final gain = _rechargeAmount(c, r, longRest);
    if (gain > 0 && r.current < resourceMax(c, r)) {
      lines.add(
        '${r.name}: +$gain (${r.current} to ${(r.current + gain).clamp(0, resourceMax(c, r))})',
      );
    }
  }
  final timed = c.modifiers
      .where(
        (m) =>
            m.active &&
            (m.note == 'timer:short' || (longRest && m.note == 'timer:long')),
      )
      .length;
  if (timed > 0) lines.add('$timed timed modifier(s) end');
  return lines;
}

int _rechargeAmount(Character c, Resource r, bool longRest) {
  final max = resourceMax(c, r);
  var best = 0;
  for (final rule in r.rules) {
    if (resourceLevel(c, r) < rule.minLevel) continue;
    final applies =
        rule.when == RechargeWhen.shortRest ||
        (rule.when == RechargeWhen.longRest && longRest);
    if (!applies) continue;
    final amount = switch (rule.amount) {
      RechargeAmount.all => max,
      RechargeAmount.half => max ~/ 2 < 1 ? 1 : max ~/ 2,
      RechargeAmount.fixed => rule.n,
    };
    if (amount > best) best = amount;
  }
  return best;
}

ActionResult takeRest(Character c, {required bool longRest}) {
  if (c.dead) {
    return ActionResult.blocked(
      c,
      '${c.name} is marked dead. Dismiss that first if it was a mistake.',
    );
  }
  final s = resolveStats(c);
  var out = c;
  final resources = [
    for (final r in c.resources)
      () {
        if (resourceLevel(c, r) < r.minLevel) return r;
        final gain = _rechargeAmount(c, r, longRest);
        // Active states (Rage, Wild Shape) end on any rest.
        if (gain == 0) return r.active ? r.copyWith(active: false) : r;
        final max = resourceMax(c, r);
        final next = (r.current + gain).clamp(0, max);
        return r.copyWith(current: next, active: false);
      }(),
  ];
  out = out.copyWith(
    resources: resources,
    pactUsed: 0,
    modifiers: [
      for (final m in c.modifiers)
        if (!(m.note == 'timer:short') && !(longRest && m.note == 'timer:long'))
          m,
    ],
  );
  if (longRest) {
    final dice = <int, int>{};
    for (final e in s.hitDice.entries) {
      final used = c.hitDiceUsed[e.key] ?? 0;
      final regain = e.value ~/ 2 < 1 ? 1 : e.value ~/ 2;
      dice[e.key] = (used - regain) < 0 ? 0 : used - regain;
    }
    out = out.copyWith(
      hpCurrent: s.maxHp,
      tempHp: 0,
      slotsUsed: const {},
      hitDiceUsed: dice,
      deathSuccesses: 0,
      deathFailures: 0,
      stable: false,
      dead: false,
      conditions: {...out.conditions}..remove('unconscious'),
      exhaustion: c.exhaustion > 0 ? c.exhaustion - 1 : 0,
      concentration: null,
      turn: const TurnState(),
    );
  }
  return ActionResult(out, longRest ? 'Long rest' : 'Short rest');
}

// ---------------------------------------------------------------- Items

ActionResult toggleEquipped(Character c, String itemId) {
  final item = c.items.firstWhere((i) => i.id == itemId);
  final warnings = <String>[];
  var items = c.items;
  if (!item.equipped) {
    // One armor and one shield at a time.
    if (item.type == ItemType.armor || item.type == ItemType.shield) {
      final other = items
          .where((i) => i.type == item.type && i.equipped && i.id != itemId)
          .firstOrNull;
      if (other != null) {
        warnings.add('Swapped ${other.name} out for ${item.name}.');
        items = [
          for (final i in items)
            i.id == other.id
                ? i.copyWith(equipped: false, attuned: other.attuned)
                : i,
        ];
      }
    }
    if (item.type == ItemType.weapon) {
      final hands = items
          .where(
            (i) => i.type == ItemType.weapon && i.equipped && i.weapon != null,
          )
          .fold<int>(0, (s, i) => s + (i.weapon!.twoHanded ? 2 : 1));
      final shieldHand =
          items.any((i) => i.type == ItemType.shield && i.equipped) ? 1 : 0;
      final add = item.weapon?.twoHanded == true ? 2 : 1;
      if (hands + shieldHand + add > 2) {
        warnings.add('More than two hands of weapons and shield equipped.');
      }
    }
    if (item.requiresAttunement && !item.attuned) {
      warnings.add('${item.name} needs attunement for its magic effects.');
    }
  }
  items = [
    for (final i in items)
      i.id == itemId ? i.copyWith(equipped: !item.equipped) : i,
  ];
  return ActionResult(
    c.copyWith(items: items),
    '${item.equipped ? 'Unequipped' : 'Equipped'} ${item.name}',
    warnings: warnings,
  );
}

/// Attunement. The fourth attunement is hard-blocked (SRD). Ending attunement
/// on a cursed item needs [confirmCursed].
ActionResult toggleAttunement(
  Character c,
  String itemId, {
  bool confirmCursed = false,
}) {
  final item = c.items.firstWhere((i) => i.id == itemId);
  if (item.attuned) {
    if (item.cursed && !confirmCursed) {
      return ActionResult.blocked(
        c,
        '${item.name} is cursed. Confirm to end attunement.',
      );
    }
    return ActionResult(
      c.copyWith(
        items: [
          for (final i in c.items)
            i.id == itemId ? i.copyWith(attuned: false) : i,
        ],
      ),
      'Ended attunement to ${item.name}',
    );
  }
  if (!item.requiresAttunement) {
    return ActionResult.blocked(c, '${item.name} does not require attunement.');
  }
  final count = c.items.where((i) => i.attuned).length;
  if (count >= 3) {
    return ActionResult.blocked(
      c,
      'You can be attuned to at most three items. End another attunement first.',
    );
  }
  final warnings = <String>[
    if (c.items.any((i) => i.attuned && i.name == item.name))
      'Already attuned to another ${item.name}.',
  ];
  return ActionResult(
    c.copyWith(
      items: [
        for (final i in c.items) i.id == itemId ? i.copyWith(attuned: true) : i,
      ],
    ),
    'Attuned to ${item.name}',
    warnings: warnings,
  );
}

ActionResult useConsumable(Character c, String itemId, {int? healRoll}) {
  final item = c.items.firstWhere((i) => i.id == itemId);
  if (item.quantity <= 0) {
    return ActionResult.blocked(c, '${item.name} is used up.');
  }
  var out = c.copyWith(
    items: [
      for (final i in c.items)
        i.id == itemId ? i.copyWith(quantity: i.quantity - 1) : i,
    ],
  );
  var desc = 'Used ${item.name}';
  final heal = healRoll ?? item.healAmount;
  if (heal != null && heal > 0) {
    out = applyHeal(out, heal).character;
    desc += ', healed $heal';
  }
  return ActionResult(out, desc);
}

ActionResult addItem(Character c, Item item) =>
    ActionResult(c.copyWith(items: [...c.items, item]), 'Added ${item.name}');

ActionResult removeItem(Character c, String id) {
  final item = c.items.firstWhere((i) => i.id == id);
  return ActionResult(
    c.copyWith(items: c.items.where((i) => i.id != id).toList()),
    'Removed ${item.name}',
  );
}

ActionResult changeQuantity(Character c, String id, int delta) {
  final item = c.items.firstWhere((i) => i.id == id);
  final q = (item.quantity + delta).clamp(0, 9999);
  return ActionResult(
    c.copyWith(
      items: [
        for (final i in c.items) i.id == id ? i.copyWith(quantity: q) : i,
      ],
    ),
    '${item.name} quantity $q',
  );
}

// ---------------------------------------------------------------- Currency

ActionResult setCoins(
  Character c, {
  int? cp,
  int? sp,
  int? ep,
  int? gp,
  int? pp,
}) {
  final w = c.wallet.copyWith(
    cp: cp == null ? null : (cp < 0 ? 0 : cp),
    sp: sp == null ? null : (sp < 0 ? 0 : sp),
    ep: ep == null ? null : (ep < 0 ? 0 : ep),
    gp: gp == null ? null : (gp < 0 ? 0 : gp),
    pp: pp == null ? null : (pp < 0 ? 0 : pp),
  );
  return ActionResult(c.copyWith(wallet: w), 'Updated coins');
}

/// Make change: break one coin of [from] into the next lower denomination.
ActionResult convertCoin(Character c, String from) {
  final w = c.wallet;
  switch (from) {
    case 'pp':
      if (w.pp < 1) return ActionResult.blocked(c, 'No platinum to convert.');
      return ActionResult(
        c.copyWith(
          wallet: w.copyWith(pp: w.pp - 1, gp: w.gp + 10),
        ),
        '1 PP into 10 GP',
      );
    case 'gp':
      if (w.gp < 1) return ActionResult.blocked(c, 'No gold to convert.');
      return ActionResult(
        c.copyWith(
          wallet: w.copyWith(gp: w.gp - 1, sp: w.sp + 10),
        ),
        '1 GP into 10 SP',
      );
    case 'sp':
      if (w.sp < 1) return ActionResult.blocked(c, 'No silver to convert.');
      return ActionResult(
        c.copyWith(
          wallet: w.copyWith(sp: w.sp - 1, cp: w.cp + 10),
        ),
        '1 SP into 10 CP',
      );
  }
  return ActionResult.blocked(c, 'Cannot convert $from.');
}

// ---------------------------------------------------------------- Misc

ActionResult setAbilityScore(Character c, Ability a, int score) {
  final v = score.clamp(1, 30);
  return ActionResult(
    c.copyWith(abilities: {...c.abilities, a: v}),
    '${a.abbr} ${c.abilities[a]} to $v',
  );
}

ActionResult setNotes(Character c, String notes) =>
    ActionResult(c.copyWith(notes: notes), 'Edited notes');

ActionResult setCompact(Character c, bool on) => ActionResult(
  c.copyWith(compactMode: on),
  on ? 'Compact combat mode on' : 'Compact combat mode off',
);

ActionResult setFlag(Character c, String flag, bool on) {
  if (flag == 'variantEncumbrance') {
    return ActionResult(
      c.copyWith(variantEncumbrance: on),
      'Variant encumbrance ${on ? 'on' : 'off'}',
    );
  }
  final flags = {...c.flags};
  on ? flags.add(flag) : flags.remove(flag);
  return ActionResult(
    c.copyWith(flags: flags),
    '${on ? 'Enabled' : 'Disabled'} $flag',
  );
}

ActionResult setSkill(Character c, Skill skill) {
  final cur = c.skills[skill] ?? Proficiency.none;
  final next = Proficiency.values[(cur.index + 1) % Proficiency.values.length];
  return ActionResult(
    c.copyWith(skills: {...c.skills, skill: next}),
    '${skill.label} proficiency ${next.name}',
  );
}

ActionResult cycleAdvantage(Character c, Skill skill) {
  final cur = c.skillAdv[skill] ?? AdvState.none;
  final next = AdvState.values[(cur.index + 1) % AdvState.values.length];
  return ActionResult(
    c.copyWith(skillAdv: {...c.skillAdv, skill: next}),
    '${skill.label} ${next.name}',
  );
}

// ---------------------------------------------------------------- Level up

/// Adds a level in [className] (taking the class if the character doesn't have
/// it yet). Max HP, slots and hit dice are derived, so they follow on their
/// own. New class resources are added, and resource pools that grew gain the
/// difference in current value.
ActionResult levelUp(Character c, String className, {String subclass = ''}) {
  final template = classTemplates[className];
  if (template == null) {
    return ActionResult.blocked(c, 'Unknown class $className.');
  }
  if (c.level >= 20) {
    return ActionResult.blocked(c, 'Characters top out at level 20.');
  }
  final before = resolveStats(c);
  final warnings = <String>[];

  var classes = <ClassLevel>[];
  final existing = c.classes
      .where((cl) => cl.className == className)
      .firstOrNull;
  if (existing != null) {
    classes = [
      for (final cl in c.classes)
        cl.className == className
            ? ClassLevel(
                cl.className,
                cl.level + 1,
                subclass: subclass.isNotEmpty ? subclass : cl.subclass,
              )
            : cl,
    ];
  } else {
    classes = [...c.classes, ClassLevel(className, 1, subclass: subclass)];
    warnings.add(
      "Multiclassing: extra proficiencies aren't added automatically. Edit them on the character if you gain any.",
    );
  }
  final newClassLevel = classes
      .firstWhere((cl) => cl.className == className)
      .level;

  var out = c.copyWith(classes: classes);
  final after = resolveStats(out);

  // Resources: grow existing pools, add the class's new ones.
  int maxOf(Character ch, Resource r) {
    final st = resolveStats(ch);
    return maxResource(ch, r, (a) => st.mods[a]!);
  }

  final resources = <Resource>[];
  for (final r in c.resources) {
    final delta = maxOf(out, r) - maxOf(c, r);
    resources.add(delta > 0 ? r.copyWith(current: r.current + delta) : r);
  }
  for (final rt in template.resources) {
    if (resources.any((r) => r.id == rt.id)) continue;
    resources.add(rt.build(className, (r) => maxOf(out, r)));
  }
  final features = [...c.features];
  for (final f in template.features) {
    if (!features.any((x) => x.name == f.name)) features.add(f);
  }
  out = out.copyWith(resources: resources, features: features);

  // HP: the new maximum, and the same amount of current HP, unless down.
  final gain = after.maxHp - before.maxHp;
  if (gain > 0 && out.hpCurrent > 0) {
    out = out.copyWith(hpCurrent: out.hpCurrent + gain);
  }

  final asiLevels = {
    4,
    8,
    12,
    16,
    19,
    if (className == 'Fighter') ...{6, 14},
    if (className == 'Rogue') 10,
  };
  if (asiLevels.contains(newClassLevel)) {
    warnings.add(
      'Ability Score Improvement or a feat is available. Edit your ability scores on the Sheet tab.',
    );
  }
  return ActionResult(
    out,
    'Leveled up: $className $newClassLevel (character level ${out.level}), max HP ${before.maxHp} to ${after.maxHp}',
    warnings: warnings,
  );
}

/// Weapon proficiency override: automatic, then proficient, then not.
ActionResult cycleWeaponProficiency(Character c, String itemId) {
  final item = c.items.firstWhere((i) => i.id == itemId);
  final Object? next = switch (item.proficientOverride) {
    null => true,
    true => false,
    false => null,
  };
  return ActionResult(
    c.copyWith(
      items: [
        for (final i in c.items)
          i.id == itemId ? i.copyWith(proficientOverride: next) : i,
      ],
    ),
    '${item.name} proficiency: ${next == null ? 'automatic' : (next == true ? 'proficient' : 'not proficient')}',
  );
}
