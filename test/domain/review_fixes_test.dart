import 'package:jjs_character_tracker/data/database.dart';
import 'package:jjs_character_tracker/data/drift_repository.dart';
import 'package:jjs_character_tracker/domain/actions.dart';
import 'package:jjs_character_tracker/domain/character_factory.dart';
import 'package:jjs_character_tracker/domain/models.dart';
import 'package:jjs_character_tracker/domain/rules.dart';
import 'package:jjs_character_tracker/domain/srd_data.dart';
import 'package:jjs_character_tracker/domain/tables.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/srd_catalog.dart';

Character make(
  String cls, {
  int level = 5,
  String subclass = '',
  Map<Ability, int>? abilities,
  bool gear = false,
}) => createCharacter(
  name: 'T',
  race: 'Human',
  className: cls,
  level: level,
  subclass: subclass,
  abilities: abilities ?? standardArray,
  starterGear: gear,
);

Item weapon(String name, {bool equipped = true}) {
  final i = srdItems.firstWhere((i) => i.name == name);
  return Item(
    id: 'w-$name',
    name: i.name,
    type: ItemType.weapon,
    weapon: i.weapon,
    equipped: equipped,
  );
}

void main() {
  loadSrdCatalogForTests();
  group('death and healing', () {
    test('massive damage warns but does not decide death', () {
      final c = make('Sorcerer').copyWith(hpCurrent: 5);
      final r = applyDamage(c, 500);
      expect(r.character.dead, isFalse);
      expect(r.warnings.any((w) => w.contains('instant death')), isTrue);
      expect(markDead(r.character).character.dead, isTrue);
    });

    test('a dead character is not healed or rested until dismissed', () {
      final dead = make('Sorcerer').copyWith(hpCurrent: 0, dead: true);
      expect(applyHeal(dead, 10).blocked, isTrue);
      expect(takeRest(dead, longRest: true).blocked, isTrue);
      expect(spendHitDie(dead, 6, 4).blocked, isTrue);
      final alive = dismissDeath(dead).character;
      expect(alive.dead, isFalse);
      expect(applyHeal(alive, 10).blocked, isFalse);
    });

    test('three failures still mark dead automatically', () {
      var c = make('Sorcerer').copyWith(hpCurrent: 0);
      c = recordDeathSave(c, 'nat1').character;
      c = recordDeathSave(c, 'failure').character;
      expect(c.dead, isTrue);
    });

    test('hit die log matches the healing', () {
      final c = make('Sorcerer').copyWith(hpCurrent: 5);
      final r = spendHitDie(c, 6, 1); // 1 + CON 1 = 2
      expect(r.description, contains('healed 2'));
      expect(r.character.hpCurrent, 7);
      final zero = make(
        'Sorcerer',
        abilities: {...standardArray, Ability.con: 6},
      ).copyWith(hpCurrent: 3);
      final z = spendHitDie(zero, 6, 1); // 1 - 2 => 0
      expect(z.character.hpCurrent, 3);
      expect(z.description, contains('healed 0'));
    });
  });

  group('concentration', () {
    test('damage absorbed by temp HP still prompts a concentration check', () {
      final c = make('Sorcerer')
          .copyWith(hpCurrent: 20, tempHp: 30, concentration: 'Haste');
      final r = applyDamage(c, 22);
      expect(r.character.hpCurrent, 20);
      expect(r.warnings.single, contains('DC 11'));
    });

    test('incapacitating conditions end concentration', () {
      for (final cond in ['incapacitated', 'stunned', 'paralyzed']) {
        final c = make('Sorcerer').copyWith(concentration: 'Haste');
        final r = toggleCondition(c, cond);
        expect(r.character.concentration, isNull, reason: cond);
        expect(r.warnings, isNotEmpty);
      }
      final c = make('Sorcerer').copyWith(concentration: 'Haste');
      expect(toggleCondition(c, 'poisoned').character.concentration, 'Haste');
    });
  });

  group('multiclass resources use the owning class level', () {
    test('Sorcerer 4 / Fighter 1 has 4 Sorcery Points', () {
      final base = make('Sorcerer', level: 4);
      final c = levelUp(base, 'Fighter').character;
      expect(c.classes.map((e) => '${e.className}${e.level}'), [
        'Sorcerer4',
        'Fighter1',
      ]);
      final sp = c.resources.firstWhere((r) => r.id == 'sorcery-points');
      expect(resourceMax(c, sp), 4);
      // Second Wind is a level 1 Fighter resource; Action Surge needs Fighter 2.
      expect(c.resources.any((r) => r.id == 'second-wind'), isTrue);
      final surge = c.resources.firstWhere((r) => r.id == 'action-surge');
      expect(resourceLevel(c, surge) >= surge.minLevel, isFalse);
    });

    test('Bard 1 / Fighter 4 does not get Font of Inspiration', () {
      var c = make(
        'Bard',
        level: 1,
        abilities: {...standardArray, Ability.cha: 16},
      );
      for (var i = 0; i < 4; i++) {
        c = levelUp(c, 'Fighter').character;
      }
      expect(c.level, 5);
      c = changeResource(c, 'bardic-inspiration', -3).character;
      // Total level 5, but Bard level 1: a short rest restores nothing.
      expect(takeRest(c, longRest: false).character.resources.first.current, 0);
    });
  });

  group('level up', () {
    test('adds HP, resources and warns about ASIs', () {
      final c = make('Sorcerer', level: 3);
      final before = resolveStats(c).maxHp;
      final r = levelUp(c, 'Sorcerer');
      expect(r.character.level, 4);
      expect(resolveStats(r.character).maxHp, greaterThan(before));
      expect(r.character.hpCurrent, resolveStats(r.character).maxHp);
      expect(r.warnings.any((w) => w.contains('Ability Score')), isTrue);
      final sp = r.character.resources.firstWhere(
        (x) => x.id == 'sorcery-points',
      );
      expect(sp.current, 4);
    });

    test('caps at level 20 and rejects unknown classes', () {
      expect(levelUp(make('Sorcerer', level: 20), 'Sorcerer').blocked, isTrue);
      expect(levelUp(make('Sorcerer'), 'Artificer').blocked, isTrue);
    });

    test('multiclass slots follow the combined table', () {
      final c = levelUp(make('Sorcerer', level: 3), 'Paladin').character;
      // Sorcerer 3 + Paladin 1 (half, rounded down to 0) = caster level 3.
      expect(resolveStats(c).slotMax, {1: 4, 2: 2});
    });
  });

  group('third casters', () {
    test('Eldritch Knight casts with INT', () {
      final c = make(
        'Fighter',
        level: 7,
        subclass: 'Eldritch Knight',
        abilities: {...standardArray, Ability.int_: 16},
      );
      final s = resolveStats(c);
      expect(s.spellcasting.single.ability, Ability.int_);
      expect(s.spellcasting.single.dc, 8 + 3 + 3);
      expect(s.slotMax, {1: 4, 2: 2});
    });

    test('Arcane Trickster casts with INT', () {
      final c = make('Rogue', level: 3, subclass: 'Arcane Trickster');
      expect(resolveStats(c).spellcasting.single.ability, Ability.int_);
    });
  });

  group('weapon proficiency', () {
    test(
      'rogue and bard are proficient with rapier, wizard is not with a mace',
      () {
        final rogue = make('Rogue').copyWith(items: [weapon('Rapier')]);
        expect(
          resolveStats(rogue).attacks
              .firstWhere((a) => a.name == 'Rapier')
              .proficient,
          isTrue,
        );
        final bard = make('Bard').copyWith(items: [weapon('Rapier')]);
        expect(
          resolveStats(bard).attacks
              .firstWhere((a) => a.name == 'Rapier')
              .proficient,
          isTrue,
        );
        final monk = make('Monk').copyWith(items: [weapon('Shortsword')]);
        expect(
          resolveStats(monk).attacks
              .firstWhere((a) => a.name == 'Shortsword')
              .proficient,
          isTrue,
        );
        final wizard = make('Wizard')
            .copyWith(items: [weapon('Mace'), weapon('Dagger')]);
        final attacks = resolveStats(wizard).attacks;
        expect(attacks.firstWhere((a) => a.name == 'Mace').proficient, isFalse);
        expect(
          attacks.firstWhere((a) => a.name == 'Dagger').proficient,
          isTrue,
        );
        final fighter = make('Fighter').copyWith(items: [weapon('Greatsword')]);
        expect(
          resolveStats(fighter).attacks
              .firstWhere((a) => a.name == 'Greatsword')
              .proficient,
          isTrue,
        );
      },
    );

    test('per-attack override wins', () {
      var c = make('Wizard').copyWith(items: [weapon('Mace')]);
      c = cycleWeaponProficiency(c, 'w-Mace').character; // proficient
      expect(
        resolveStats(c).attacks.firstWhere((a) => a.name == 'Mace').proficient,
        isTrue,
      );
      c = cycleWeaponProficiency(c, 'w-Mace').character; // not
      c = c.copyWith(weaponProfs: {'simple'});
      expect(
        resolveStats(c).attacks.firstWhere((a) => a.name == 'Mace').proficient,
        isFalse,
      );
      c = cycleWeaponProficiency(c, 'w-Mace').character; // automatic
      expect(
        resolveStats(c).attacks.firstWhere((a) => a.name == 'Mace').proficient,
        isTrue,
      );
    });
  });

  group('small fixes', () {
    test('short rest preview only counts short-rest timers', () {
      final c = make('Sorcerer').copyWith(
        modifiers: [
          const Effect(
            target: StatTarget.ac,
            mode: EffectMode.add,
            value: 1,
            note: 'timer:long',
          ),
          const Effect(
            target: StatTarget.ac,
            mode: EffectMode.add,
            value: 1,
            note: 'timer:short',
          ),
        ],
      );
      expect(
        restPreview(
          c,
          longRest: false,
        ).where((l) => l.contains('timed')).single,
        startsWith('1 '),
      );
      expect(
        restPreview(c, longRest: true).where((l) => l.contains('timed')).single,
        startsWith('2 '),
      );
    });

    test('Rage ends on a short rest even if nothing is restored', () {
      var c = make('Barbarian');
      c = toggleResourceActive(c, 'rage').character;
      expect(c.resources.first.active, isTrue);
      expect(
        takeRest(c, longRest: false).character.resources.first.active,
        isFalse,
      );
    });

    test('movement can exceed speed with a warning', () {
      var c = make('Sorcerer');
      c = addMovement(c, 30).character;
      final r = addMovement(c, 30);
      expect(r.blocked, isFalse);
      expect(r.character.turn.movementUsed, 60);
      expect(r.warnings.single, contains('Dash'));
    });

    test('magic bonus needs attunement when the item requires it', () {
      Item sword({required bool attuned}) => Item(
        id: 's',
        name: '+1 Longsword',
        type: ItemType.weapon,
        equipped: true,
        requiresAttunement: true,
        attuned: attuned,
        magicBonus: 1,
        weapon: srdItems.firstWhere((i) => i.name == 'Longsword').weapon,
      );
      final f = make('Fighter');
      final off = resolveStats(f.copyWith(items: [sword(attuned: false)]))
          .attacks
          .first;
      final on = resolveStats(f.copyWith(items: [sword(attuned: true)]))
          .attacks
          .first;
      expect(on.bonus! - off.bonus!, 1);
      Item armor({required bool attuned}) => Item(
        id: 'a',
        name: '+1 Breastplate',
        type: ItemType.armor,
        equipped: true,
        requiresAttunement: true,
        attuned: attuned,
        magicBonus: 1,
        armor: srdItems.firstWhere((i) => i.name == 'Breastplate').armor,
      );
      expect(
        resolveStats(f.copyWith(items: [armor(attuned: true)])).ac.total -
            resolveStats(f.copyWith(items: [armor(attuned: false)])).ac.total,
        1,
      );
    });

    test('Flexible Casting slots above the normal maximum can be cast', () {
      var c = make('Sorcerer', level: 6);
      c = sorceryPointsToSlot(
        c,
        4,
      ).character; // lv 4 slot, not a normal slot at lvl 6
      final s = resolveStats(c);
      expect(slotsRemaining(c, s, 4), 1);
      final r = castSpell(
        c,
        srdSpells.firstWhere((x) => x.name == 'Polymorph'),
        slotLevel: 4,
      );
      expect(r.blocked, isFalse);
    });

    test('Monk does not get an arcane focus', () {
      final c = createCharacter(
        name: 'M',
        race: 'Human',
        className: 'Monk',
        level: 1,
        abilities: standardArray,
      );
      expect(c.items.any((i) => i.name == 'Arcane Focus'), isFalse);
      final s = createCharacter(
        name: 'S',
        race: 'Human',
        className: 'Sorcerer',
        level: 1,
        abilities: standardArray,
      );
      expect(s.items.any((i) => i.name == 'Arcane Focus'), isTrue);
    });
  });

  group('speed', () {
    test('base speed comes from the character', () {
      final c = createCharacter(
        name: 'D',
        race: 'Dwarf',
        className: 'Fighter',
        level: 1,
        abilities: standardArray,
        baseSpeed: 25,
        starterGear: false,
      );
      expect(resolveStats(c).speed.total, 25);
    });
  });

  group('effects on one save or skill', () {
    test('a single save and a single skill', () {
      final c = make('Sorcerer').copyWith(
        modifiers: [
          const Effect(
            target: StatTarget.save,
            mode: EffectMode.add,
            value: 2,
            subject: 'dex',
            source: 'Boon',
          ),
          const Effect(
            target: StatTarget.skill,
            mode: EffectMode.add,
            value: 5,
            subject: 'stealth',
            source: 'Cloak',
          ),
        ],
      );
      final base = resolveStats(make('Sorcerer'));
      final s = resolveStats(c);
      expect(s.saves[Ability.dex]!.total - base.saves[Ability.dex]!.total, 2);
      expect(s.saves[Ability.str]!.total, base.saves[Ability.str]!.total);
      expect(
        s.skills[Skill.stealth]!.total - base.skills[Skill.stealth]!.total,
        5,
      );
      expect(s.skills[Skill.arcana]!.total, base.skills[Skill.arcana]!.total);
    });

    test('set effects apply only if higher for spell DC and saves', () {
      final base = resolveStats(make('Sorcerer'));
      final dc = base.spellcasting.single.dc;
      final c = make('Sorcerer').copyWith(
        modifiers: [
          Effect(
            target: StatTarget.spellDc,
            mode: EffectMode.set,
            value: dc + 3,
          ),
          const Effect(
            target: StatTarget.spellAttack,
            mode: EffectMode.set,
            value: 0,
          ),
        ],
      );
      final s = resolveStats(c);
      expect(s.spellcasting.single.dc, dc + 3);
      expect(s.spellcasting.single.attack, base.spellcasting.single.attack);
    });

    test('note effects show as traits only while active', () {
      Item cloak({required bool attuned}) => Item(
        id: 'c',
        name: 'Cloak of Fire',
        type: ItemType.magic,
        equipped: true,
        requiresAttunement: true,
        attuned: attuned,
        effects: const [
          Effect(
            target: StatTarget.note,
            mode: EffectMode.add,
            value: 0,
            note: 'Resistance to fire',
          ),
        ],
      );
      final c = make('Sorcerer');
      expect(
        resolveStats(c.copyWith(items: [cloak(attuned: false)])).traits,
        isEmpty,
      );
      expect(
        resolveStats(c.copyWith(items: [cloak(attuned: true)])).traits.single,
        ('Cloak of Fire', 'Resistance to fire'),
      );
    });

    test('effects survive a JSON round trip', () {
      final c = make('Sorcerer').copyWith(
        modifiers: [
          const Effect(
            target: StatTarget.save,
            mode: EffectMode.add,
            value: 1,
            subject: 'wis',
          ),
        ],
      );
      expect(Character.fromJson(c.toJson()).modifiers.single.subject, 'wis');
    });
  });

  group('extra attack and two-weapon fighting', () {
    test('attacks per action by class', () {
      expect(attacksPerActionFor('Fighter', 4), 1);
      expect(attacksPerActionFor('Fighter', 5), 2);
      expect(attacksPerActionFor('Fighter', 11), 3);
      expect(attacksPerActionFor('Fighter', 20), 4);
      expect(attacksPerActionFor('Barbarian', 5), 2);
      expect(attacksPerActionFor('Sorcerer', 20), 1);
      expect(resolveStats(make('Fighter')).attacksPerAction, 2);
      expect(resolveStats(make('Sorcerer')).attacksPerAction, 1);
    });

    test('off-hand attack uses the bonus action', () {
      var c = make('Fighter')
          .copyWith(items: [weapon('Shortsword'), weapon('Dagger')]);
      final attack = resolveStats(c).attacks
          .firstWhere((a) => a.name == 'Dagger');
      final first = useAttack(c, attack, attacksPerAction: 2, offHand: true);
      // No Attack action taken yet: warn.
      expect(first.character.turn.bonusAction, isTrue);
      expect(first.warnings.any((w) => w.contains('Attack action')), isTrue);
      c = useAttack(c, attack, attacksPerAction: 2).character;
      final second = useAttack(c, attack, attacksPerAction: 2, offHand: true);
      expect(second.warnings.any((w) => w.contains('Attack action')), isFalse);
      expect(
        second.warnings.any((w) => w.contains('ability modifier')),
        isTrue,
      );
    });
  });

  group('spell lists', () {
    test('known limits come from the class tables', () {
      expect(knownLimits('Sorcerer', 1), (cantrips: 4, spells: 2));
      expect(knownLimits('Sorcerer', 5), (cantrips: 5, spells: 6));
      expect(knownLimits('Bard', 10), (cantrips: 4, spells: 14));
      expect(knownLimits('Warlock', 11), (cantrips: 4, spells: 11));
      expect(knownLimits('Ranger', 2), (cantrips: 0, spells: 2));
      expect(knownLimits('Wizard', 1), (cantrips: 3, spells: null));
      expect(knownLimits('Fighter', 5), isNull);
    });

    test('adding beyond the known limit warns', () {
      var c = make('Sorcerer', level: 1);
      final names = ['Magic Missile', 'Shield', 'Burning Hands'];
      ActionResult? last;
      for (final n in names) {
        last = addSpell(c, srdSpells.firstWhere((s) => s.name == n));
        c = last.character;
      }
      expect(last!.warnings.single, contains('3 spells known'));
    });

    test('prepared casters add leveled spells unprepared, cantrips ready', () {
      var c = make('Wizard');
      c = addSpell(
        c,
        srdSpells.firstWhere((s) => s.name == 'Fireball'),
      ).character;
      c = addSpell(
        c,
        srdSpells.firstWhere((s) => s.name == 'Fire Bolt'),
      ).character;
      expect(
        c.spells.firstWhere((s) => s.name == 'Fireball').prepared,
        isFalse,
      );
      expect(
        c.spells.firstWhere((s) => s.name == 'Fire Bolt').prepared,
        isTrue,
      );
      // Known casters keep spells ready.
      var s = make('Sorcerer');
      s = addSpell(
        s,
        srdSpells.firstWhere((x) => x.name == 'Fireball'),
      ).character;
      expect(s.spells.first.prepared, isTrue);
    });

    test('ritual rules per class', () {
      final detect = srdSpells.firstWhere((s) => s.name == 'Detect Magic');
      expect(
        canRitualCast(make('Wizard'), detect.copyWith(prepared: false)),
        isTrue,
      );
      expect(canRitualCast(make('Bard'), detect), isTrue);
      expect(
        canRitualCast(make('Cleric'), detect.copyWith(prepared: false)),
        isFalse,
      );
      expect(canRitualCast(make('Cleric'), detect), isTrue);
      expect(canRitualCast(make('Sorcerer'), detect), isFalse);
      expect(
        canRitualCast(
          make('Wizard'),
          srdSpells.firstWhere((s) => s.name == 'Fireball'),
        ),
        isFalse,
      );
    });
  });

  group('undo keeps unlogged edits', () {
    late AppDatabase db;
    late DriftCharacterRepository repo;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = DriftCharacterRepository(db);
    });
    tearDown(() => db.close());

    test('notes and compact mode survive an undo', () async {
      final c = make('Sorcerer');
      await repo.create(c);
      final r = applyDamage(c, 4);
      await repo.apply(
        before: c,
        after: r.character,
        type: 'x',
        description: 'damage',
      );
      // Typed after the logged action, saved without a log entry.
      await repo.save(
        r.character.copyWith(notes: 'new notes', compactMode: true),
      );
      await repo.undoLast(c.id);
      final back = (await repo.get(c.id))!;
      expect(back.hpCurrent, c.hpCurrent);
      expect(back.notes, 'new notes');
      expect(back.compactMode, isTrue);
    });
  });
}
