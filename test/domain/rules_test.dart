import 'package:dnd_tracker/domain/actions.dart';
import 'package:dnd_tracker/domain/character_factory.dart';
import 'package:dnd_tracker/domain/models.dart';
import 'package:dnd_tracker/domain/rules.dart';
import 'package:dnd_tracker/domain/srd_data.dart';
import 'package:dnd_tracker/domain/tables.dart';
import 'package:flutter_test/flutter_test.dart';

Character sorcerer({int level = 5}) => createCharacter(
  name: 'Ruin King',
  race: 'Tiefling',
  className: 'Sorcerer',
  level: level,
  abilities: const {
    Ability.str: 10,
    Ability.dex: 16,
    Ability.con: 14,
    Ability.int_: 12,
    Ability.wis: 13,
    Ability.cha: 18,
  },
);

Item srd(String name) {
  final i = srdItems.firstWhere((i) => i.name == name);
  return Item(
    id: 't-$name',
    name: i.name,
    type: i.type,
    armor: i.armor,
    weapon: i.weapon,
    effects: i.effects,
    requiresAttunement: i.requiresAttunement,
    weight: i.weight,
  );
}

Character withItems(Character c, List<Item> items) => c.copyWith(items: items);

void main() {
  group('derived stats', () {
    test('modifiers and proficiency', () {
      expect(abilityModOf(10), 0);
      expect(abilityModOf(9), -1);
      expect(abilityModOf(18), 4);
      expect(proficiencyForLevel(1), 2);
      expect(proficiencyForLevel(5), 3);
      expect(proficiencyForLevel(17), 6);
    });

    test('sorcerer level 5 numbers', () {
      final s = resolveStats(sorcerer());
      expect(s.proficiency, 3);
      expect(s.initiative.total, 3);
      // 6+2 at level 1, then 4 levels of (4 + 2).
      expect(s.maxHp, 8 + 4 * 6);
      expect(s.spellcasting.single.dc, 8 + 3 + 4);
      expect(s.spellcasting.single.attack, 3 + 4);
      expect(s.slotMax, {1: 4, 2: 3, 3: 2});
    });

    test('skills and jack of all trades', () {
      var c = sorcerer().copyWith(
        skills: {Skill.arcana: Proficiency.expertise},
        jackOfAllTrades: true,
      );
      final s = resolveStats(c);
      expect(s.skills[Skill.arcana]!.total, 1 + 6);
      expect(s.skills[Skill.stealth]!.total, 3 + 1);
      expect(s.passives[Skill.perception], 10 + 1 + 1);
    });
  });

  group('armor class', () {
    test('unarmored is 10 + DEX', () {
      final c = withItems(sorcerer(), []);
      expect(resolveStats(c).ac.total, 13);
    });

    test('mage armor and draconic resilience take the highest', () {
      final c = withItems(
        sorcerer(),
        [],
      ).copyWith(flags: {'mageArmor', 'draconicResilience'});
      final s = resolveStats(c);
      expect(s.ac.total, 16);
      expect(s.acNotes, isNotEmpty);
    });

    test('breastplate caps DEX at +2, shield adds 2', () {
      var c = withItems(sorcerer(), [
        srd('Breastplate').copyWith(equipped: true),
        srd('Shield').copyWith(equipped: true),
      ]);
      expect(resolveStats(c).ac.total, 14 + 2 + 2);
      c = toggleEquipped(c, 't-Shield').character;
      expect(resolveStats(c).ac.total, 16);
    });

    test('heavy armor ignores DEX and warns when not proficient', () {
      final c = withItems(sorcerer(), [srd('Plate').copyWith(equipped: true)]);
      final s = resolveStats(c);
      expect(s.ac.total, 18);
      expect(s.warnings.any((w) => w.contains("can't cast")), isTrue);
      expect(s.warnings.any((w) => w.contains('STR 15')), isTrue);
    });

    test('equipping a second armor swaps and warns', () {
      var c = withItems(sorcerer(), [
        srd('Leather').copyWith(equipped: true),
        srd('Breastplate'),
      ]);
      final r = toggleEquipped(c, 't-Breastplate');
      expect(r.warnings, isNotEmpty);
      expect(r.character.items.where((i) => i.equipped).length, 1);
    });

    test('barbarian unarmored defense', () {
      final c = createCharacter(
        name: 'B',
        race: 'Human',
        className: 'Barbarian',
        level: 1,
        abilities: const {Ability.str: 16, Ability.dex: 14, Ability.con: 16},
        starterGear: false,
      );
      expect(resolveStats(c).ac.total, 10 + 2 + 3);
    });
  });

  group('magic items and attunement', () {
    test('ring of protection needs attunement', () {
      var c = withItems(sorcerer(), [
        srd('Ring of Protection').copyWith(equipped: true),
      ]);
      expect(resolveStats(c).ac.total, 13);
      c = toggleAttunement(c, 't-Ring of Protection').character;
      expect(resolveStats(c).ac.total, 14);
      expect(resolveStats(c).saves[Ability.con]!.total, 2 + 3 + 1);
    });

    test('belt sets strength only if higher', () {
      var c = withItems(sorcerer(), [
        srd('Belt of Hill Giant Strength')
            .copyWith(equipped: true, attuned: true),
      ]);
      expect(resolveStats(c).scores[Ability.str], 21);
      expect(resolveStats(c).changedScores, contains(Ability.str));
      c = c.copyWith(abilities: {...c.abilities, Ability.str: 23});
      expect(resolveStats(c).scores[Ability.str], 23);
    });

    test('fourth attunement is hard-blocked', () {
      Item ring(int n) => Item(
        id: 'r$n',
        name: 'Ring $n',
        type: ItemType.magic,
        requiresAttunement: true,
        attuned: n < 3,
      );
      var c = withItems(sorcerer(), [ring(0), ring(1), ring(2), ring(3)]);
      final r = toggleAttunement(c, 'r3');
      expect(r.blocked, isTrue);
      expect(r.character.items.where((i) => i.attuned).length, 3);
    });

    test('cursed item needs confirmation to unattune', () {
      final c = withItems(sorcerer(), [
        const Item(
          id: 'c',
          name: 'Cursed',
          type: ItemType.magic,
          requiresAttunement: true,
          attuned: true,
          cursed: true,
        ),
      ]);
      expect(toggleAttunement(c, 'c').blocked, isTrue);
      expect(toggleAttunement(c, 'c', confirmCursed: true).blocked, isFalse);
    });
  });

  group('hit points', () {
    test('damage hits temp HP first', () {
      var c = sorcerer().copyWith(tempHp: 5, hpCurrent: 20);
      c = applyDamage(c, 8).character;
      expect(c.tempHp, 0);
      expect(c.hpCurrent, 17);
    });

    test('healing caps at max and clears death saves', () {
      final max = resolveStats(sorcerer()).maxHp;
      var c = sorcerer().copyWith(
        hpCurrent: 0,
        deathFailures: 2,
        conditions: {'unconscious'},
      );
      c = applyHeal(c, 999).character;
      expect(c.hpCurrent, max);
      expect(c.deathFailures, 0);
      expect(c.conditions, isNot(contains('unconscious')));
    });

    test('reaching 0 HP makes unconscious and ends concentration', () {
      var c = sorcerer().copyWith(hpCurrent: 5, concentration: 'Haste');
      final r = applyDamage(c, 6);
      expect(r.character.hpCurrent, 0);
      expect(r.character.conditions, contains('unconscious'));
      expect(r.character.concentration, isNull);
      expect(r.warnings.any((w) => w.contains('concentration')), isTrue);
    });

    test('instant death warning', () {
      final c = sorcerer().copyWith(hpCurrent: 5);
      final r = applyDamage(c, 500);
      expect(r.warnings.any((w) => w.contains('instant death')), isTrue);
    });

    test('damage at 0 HP adds death save failures, crit adds two', () {
      var c = sorcerer().copyWith(hpCurrent: 0);
      c = applyDamage(c, 3).character;
      expect(c.deathFailures, 1);
      c = applyDamage(c, 3, crit: true).character;
      expect(c.dead, isTrue);
    });

    test('death saves: three successes stabilise, nat 20 revives', () {
      var c = sorcerer().copyWith(hpCurrent: 0);
      for (var i = 0; i < 3; i++) {
        c = recordDeathSave(c, 'success').character;
      }
      expect(c.stable, isTrue);
      c = recordDeathSave(c, 'nat20').character;
      expect(c.hpCurrent, 1);
    });

    test('concentration DC is the higher of 10 and half damage', () {
      expect(concentrationDc(7), 10);
      expect(concentrationDc(30), 15);
    });

    test('damage while concentrating warns with DC', () {
      final c = sorcerer().copyWith(hpCurrent: 30, concentration: 'Haste');
      final r = applyDamage(c, 24);
      expect(r.warnings.single, contains('DC 12'));
    });
  });

  group('slots', () {
    test('slot tables', () {
      expect(slotTotals(const [ClassLevel('Wizard', 1)]), {1: 2});
      expect(slotTotals(const [ClassLevel('Wizard', 20)]), {
        1: 4,
        2: 3,
        3: 3,
        4: 3,
        5: 3,
        6: 2,
        7: 2,
        8: 1,
        9: 1,
      });
      expect(slotTotals(const [ClassLevel('Paladin', 1)]), isEmpty);
      expect(slotTotals(const [ClassLevel('Paladin', 5)]), {1: 4, 2: 2});
      expect(slotTotals(const [ClassLevel('Ranger', 2)]), {1: 2});
      expect(
        slotTotals(const [
          ClassLevel('Fighter', 7, subclass: 'Eldritch Knight'),
        ]),
        {1: 4, 2: 2},
      );
      expect(slotTotals(const [ClassLevel('Barbarian', 9)]), isEmpty);
    });

    test('multiclass uses combined caster level', () {
      // Sorcerer 3 + Paladin 4 = 3 + 2 = caster level 5.
      expect(
        slotTotals(const [ClassLevel('Sorcerer', 3), ClassLevel('Paladin', 4)]),
        {1: 4, 2: 3, 3: 2},
      );
    });

    test('pact magic', () {
      expect(pactMagic(1), (1, 1));
      expect(pactMagic(5), (2, 3));
      expect(pactMagic(11), (3, 5));
      expect(pactMagic(17), (4, 5));
    });

    test('spend and restore', () {
      var c = sorcerer();
      c = changeSlot(c, 3, spend: true).character;
      c = changeSlot(c, 3, spend: true).character;
      expect(changeSlot(c, 3, spend: true).blocked, isTrue);
      c = changeSlot(c, 3, spend: false).character;
      expect(c.slotsUsed[3], 1);
    });
  });

  group('casting', () {
    final fireball = srdSpells.firstWhere((s) => s.name == 'Fireball');
    final haste = srdSpells.firstWhere((s) => s.name == 'Haste');
    final healingWord = srdSpells.firstWhere((s) => s.name == 'Healing Word');
    final fireBolt = srdSpells.firstWhere((s) => s.name == 'Fire Bolt');

    test('spends slot, marks action, upcasts', () {
      final r = castSpell(sorcerer(), fireball, slotLevel: 3);
      expect(r.character.slotsUsed[3], 1);
      expect(r.character.turn.action, isTrue);
      final up = castSpell(sorcerer(level: 7), fireball, slotLevel: 4);
      expect(up.character.slotsUsed[4], 1);
      expect(up.description, contains('upcast'));
    });

    test('cantrip costs nothing', () {
      final r = castSpell(sorcerer(), fireBolt);
      expect(r.character.slotsUsed, isEmpty);
      expect(r.character.turn.action, isTrue);
    });

    test('blocks when no slots remain', () {
      var c = sorcerer().copyWith(slotsUsed: {3: 2});
      expect(castSpell(c, fireball, slotLevel: 3).blocked, isTrue);
    });

    test('second concentration spell needs confirmation, then replaces', () {
      final c = castSpell(sorcerer(), haste, slotLevel: 3).character;
      final holdPerson = srdSpells.firstWhere((s) => s.name == 'Hold Person');
      final refused = castSpell(c, holdPerson, slotLevel: 2);
      expect(refused.blocked, isTrue);
      expect(refused.character.concentration, 'Haste');
      expect(refused.character.slotsUsed[2], isNull);
      final r = castSpell(
        c,
        holdPerson,
        slotLevel: 2,
        replaceConcentration: true,
      );
      expect(r.character.concentration, 'Hold Person');
      expect(
        r.warnings.any((w) => w.contains('Ended concentration on Haste')),
        isTrue,
      );
    });

    test(
      'bonus action spell then leveled action spell warns, and the reverse',
      () {
        var c = castSpell(sorcerer(), healingWord, slotLevel: 1).character;
        expect(castSpell(c, fireball, slotLevel: 3).warnings, isNotEmpty);
        expect(castSpell(c, fireBolt).warnings, isEmpty);
        var d = castSpell(sorcerer(), fireball, slotLevel: 3).character;
        expect(castSpell(d, healingWord, slotLevel: 1).warnings, isNotEmpty);
      },
    );

    test('ritual casting spends no slot, and only for ritual casters', () {
      final detect = srdSpells.firstWhere((s) => s.name == 'Detect Magic');
      expect(castSpell(sorcerer(), detect, ritual: true).blocked, isTrue);
      final wizard = createCharacter(
        name: 'W',
        race: 'Elf',
        className: 'Wizard',
        level: 3,
        abilities: standardArray,
      );
      final r = castSpell(wizard, detect, ritual: true);
      expect(r.blocked, isFalse);
      expect(r.character.slotsUsed, isEmpty);
      final withFlag = sorcerer().copyWith(flags: {'ritualCasting'});
      expect(castSpell(withFlag, detect, ritual: true).blocked, isFalse);
    });

    test('cantrip damage scales', () {
      var c = sorcerer(level: 11).copyWith(spells: [fireBolt]);
      expect(
        resolveStats(c).attacks.firstWhere((a) => a.name == 'Fire Bolt').damage,
        '3d10 fire',
      );
    });
  });

  group('resources and rests', () {
    test('sorcerer gets sorcery points equal to level', () {
      final r = sorcerer().resources.firstWhere(
        (r) => r.id == 'sorcery-points',
      );
      expect(r.current, 5);
    });

    test('flexible casting converts both ways', () {
      var c = sorcerer();
      final toSlot = sorceryPointsToSlot(c, 2);
      expect(
        toSlot.character.resources
            .firstWhere((r) => r.id == 'sorcery-points')
            .current,
        2,
      );
      expect(
        slotsRemaining(toSlot.character, resolveStats(toSlot.character), 2),
        4,
      );
      expect(sorceryPointsToSlot(c, 6).blocked, isTrue);
      c = c.copyWith(
        slotsUsed: {3: 1},
        resources: [
          for (final r in c.resources)
            r.id == 'sorcery-points' ? r.copyWith(current: 1) : r,
        ],
      );
      final back = slotToSorceryPoints(c, 3);
      expect(
        back.character.resources
            .firstWhere((r) => r.id == 'sorcery-points')
            .current,
        4,
      );
    });

    test('resource spend, override and floor', () {
      var c = sorcerer();
      c = changeResource(c, 'sorcery-points', -5).character;
      expect(changeResource(c, 'sorcery-points', -1).blocked, isTrue);
      expect(
        changeResource(c, 'sorcery-points', -1, force: true).warnings,
        isNotEmpty,
      );
    });

    test('long rest restores everything', () {
      var c = sorcerer().copyWith(
        hpCurrent: 3,
        tempHp: 4,
        slotsUsed: {1: 4, 2: 3, 3: 2},
        concentration: 'Haste',
        exhaustion: 2,
        hitDiceUsed: {6: 5},
      );
      c = changeResource(c, 'sorcery-points', -5).character;
      final r = takeRest(c, longRest: true).character;
      expect(r.hpCurrent, resolveStats(r).maxHp);
      expect(r.tempHp, 0);
      expect(r.slotsUsed, isEmpty);
      expect(r.concentration, isNull);
      expect(r.exhaustion, 1);
      expect(r.hitDiceUsed[6], 3);
      expect(
        r.resources.firstWhere((x) => x.id == 'sorcery-points').current,
        5,
      );
    });

    test('short rest restores short-rest resources only', () {
      var c = createCharacter(
        name: 'M',
        race: 'Human',
        className: 'Monk',
        level: 5,
        abilities: const {Ability.dex: 16, Ability.wis: 14},
        starterGear: false,
      );
      c = changeResource(c, 'ki', -3).character;
      expect(takeRest(c, longRest: false).character.resources.first.current, 5);

      var s = sorcerer();
      s = changeResource(s, 'sorcery-points', -2).character;
      expect(
        takeRest(s, longRest: false).character.resources
            .firstWhere((r) => r.id == 'sorcery-points')
            .current,
        3,
      );
    });

    test('bard inspiration recharges on short rest from level 5', () {
      Character bard(int lvl) => createCharacter(
        name: 'B',
        race: 'Human',
        className: 'Bard',
        level: lvl,
        abilities: const {Ability.cha: 16},
        starterGear: false,
      );
      var low = changeResource(bard(4), 'bardic-inspiration', -3).character;
      expect(
        takeRest(low, longRest: false).character.resources.first.current,
        0,
      );
      var high = changeResource(bard(5), 'bardic-inspiration', -3).character;
      expect(
        takeRest(high, longRest: false).character.resources.first.current,
        3,
      );
    });

    test('rest preview lists what will be restored', () {
      var c = changeResource(sorcerer(), 'sorcery-points', -2).character;
      final lines = restPreview(c, longRest: true);
      expect(lines.any((l) => l.contains('Sorcery Points')), isTrue);
    });

    test('every class template builds a character', () {
      for (final name in hitDieByClass.keys) {
        final c = createCharacter(
          name: name,
          race: 'Human',
          className: name,
          level: 5,
          abilities: standardArray,
        );
        expect(resolveStats(c).maxHp, greaterThan(0), reason: name);
      }
    });
  });

  group('inventory', () {
    test('coins convert and total in GP', () {
      var c = sorcerer().copyWith(
        wallet: const Wallet(pp: 1, gp: 2, sp: 5, cp: 50),
      );
      expect(c.wallet.totalGp, closeTo(10 + 2 + 0.5 + 0.5, 0.001));
      c = convertCoin(c, 'pp').character;
      expect(c.wallet.gp, 12);
      expect(c.wallet.pp, 0);
    });

    test('carrying capacity is STR x 15', () {
      expect(resolveStats(sorcerer()).capacity, 150);
    });

    test('variant encumbrance slows speed', () {
      var c = sorcerer().copyWith(
        variantEncumbrance: true,
        items: [
          const Item(id: 'x', name: 'Rock', type: ItemType.gear, weight: 60),
        ],
      );
      expect(resolveStats(c).speed.total, 20);
    });

    test('consumables heal and decrement', () {
      var c = sorcerer().copyWith(
        hpCurrent: 10,
        items: [
          const Item(
            id: 'p',
            name: 'Potion',
            type: ItemType.consumable,
            quantity: 1,
            healAmount: 7,
          ),
        ],
      );
      c = useConsumable(c, 'p', healRoll: 9).character;
      expect(c.hpCurrent, 19);
      expect(c.items.first.quantity, 0);
      expect(useConsumable(c, 'p').blocked, isTrue);
    });
  });

  group('attacks', () {
    test(
      'finesse uses the higher of STR and DEX; unarmed is always present',
      () {
        final c = withItems(sorcerer(), [
          srd('Dagger').copyWith(equipped: true),
        ]);
        final a = resolveStats(c).attacks;
        final dagger = a.firstWhere((x) => x.name == 'Dagger');
        expect(dagger.bonus, 3 + 3);
        expect(dagger.damage, '1d4+3 piercing');
        expect(a.any((x) => x.name == 'Unarmed Strike'), isTrue);
      },
    );

    test('extra attack tracks attacks before marking the action', () {
      final c = sorcerer();
      final unarmed = resolveStats(c).attacks.last;
      final r1 = useAttack(c, unarmed, attacksPerAction: 2);
      expect(r1.character.turn.action, isFalse);
      final r2 = useAttack(r1.character, unarmed, attacksPerAction: 2);
      expect(r2.character.turn.action, isTrue);
    });
  });

  group('serialization', () {
    test('character round trips through JSON', () {
      final c = castSpell(
        sorcerer(),
        srdSpells.firstWhere((s) => s.name == 'Haste'),
        slotLevel: 3,
      ).character;
      final copy = Character.fromJson(c.toJson());
      expect(copy.toJson(), c.toJson());
      expect(resolveStats(copy).ac.total, resolveStats(c).ac.total);
    });
  });
}
