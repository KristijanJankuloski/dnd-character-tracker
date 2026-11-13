import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/domain/models.dart';
import 'package:jjs_character_tracker/domain/spell_catalog.dart';

import '../helpers/srd_catalog.dart';

// Names offered by the create-character screen's starter spell lists.
const _starterNames = [
  'Fire Bolt', 'Light', 'Mage Hand', 'Minor Illusion', 'Magic Missile',
  'Shield', 'Mage Armor', 'Misty Step', 'Fireball', 'Detect Magic',
  'Sacred Flame', 'Guidance', 'Cure Wounds', 'Healing Word', 'Bless',
  'Hold Person', 'Druidcraft', 'Thunderwave', 'Vicious Mockery',
  'Charm Person', 'Eldritch Blast',
];

void main() {
  test('reading srdSpells before the catalog is loaded throws', () {
    resetSpellCatalogForTests();
    expect(() => srdSpells, throwsStateError);
  });

  test('parseSpellCatalog reads the asset format', () {
    final list = parseSpellCatalog(
      '{"source":"x","license":"y","spells":'
      '[{"id":"a","name":"A","level":1,"school":"Evocation"}]}',
    );
    expect(list, hasLength(1));
    expect(list.single.school, 'Evocation');
  });

  testWidgets('the app startup path loads the registered asset', (
    tester,
  ) async {
    resetSpellCatalogForTests();
    await tester.runAsync(() => loadSpellCatalog(rootBundle));
    expect(srdSpells, hasLength(319));
  });

  group('bundled catalog', () {
    setUpAll(loadSrdCatalogForTests);

    test('holds every SRD spell with unique ids', () {
      expect(srdSpells, hasLength(319));
      expect(srdSpells.map((s) => s.id).toSet(), hasLength(319));
    });

    test('keeps the ids earlier saves already use', () {
      expect(
        srdSpells.firstWhere((s) => s.name == 'Fireball').id,
        'srd-fireball',
      );
    });

    test('odd names get clean ids', () {
      String idOf(String n) => srdSpells.firstWhere((s) => s.name == n).id;
      expect(idOf('Antipathy/Sympathy'), 'srd-antipathy-sympathy');
      expect(idOf("Arcanist's Magic Aura"), 'srd-arcanists-magic-aura');
      expect(idOf("Heroes' Feast"), 'srd-heroes-feast');
    });

    test('combat fields feed the attack list', () {
      final fireBolt = srdSpells.firstWhere((s) => s.name == 'Fire Bolt');
      expect(fireBolt.damage, '1d10 fire');
      expect(fireBolt.attackRoll, isTrue);
      expect(
        srdSpells.firstWhere((s) => s.name == 'Feeblemind').save,
        Ability.int_,
      );
    });

    test('splits out At Higher Levels and keeps normal spaces', () {
      final nbsp = String.fromCharCode(0xA0);
      Spell named(String n) => srdSpells.firstWhere((s) => s.name == n);
      for (final n in ['Counterspell', 'Hellish Rebuke', "Hunter's Mark"]) {
        expect(named(n).higherLevels, isNotEmpty, reason: n);
        expect(named(n).text, isNot(contains('At Higher Levels')), reason: n);
      }
      for (final s in srdSpells) {
        expect(s.text + s.higherLevels, isNot(contains(nbsp)), reason: s.name);
      }
    });

    test('attack-list fields do not mislead', () {
      Spell named(String n) => srdSpells.firstWhere((s) => s.name == n);
      expect(named('Light').save, isNull);
      expect(named('Contact Other Plane').save, isNull);
      expect(named('Contact Other Plane').damage, isEmpty);
      expect(named('Web').damage, isEmpty);
      expect(named('Web').save, Ability.dex);
      expect(
        named('Spirit Guardians').damage,
        '3d8 radiant or 3d8 necrotic',
      );
      expect(named('Ice Storm').damage, '2d8 bludgeoning + 4d6 cold');
    });

    test('every starter spell exists', () {
      final names = srdSpells.map((s) => s.name).toSet();
      for (final n in _starterNames) {
        expect(names, contains(n));
      }
    });

    test('every spell has the fields the picker and sheet show', () {
      for (final s in srdSpells) {
        expect(s.school, isNotEmpty, reason: s.name);
        expect(s.castingTimeText, isNotEmpty, reason: s.name);
        expect(s.range, isNotEmpty, reason: s.name);
        expect(s.duration, isNotEmpty, reason: s.name);
        expect(s.text, isNotEmpty, reason: s.name);
        expect(s.level, inInclusiveRange(0, 9), reason: s.name);
      }
    });
  });
}
