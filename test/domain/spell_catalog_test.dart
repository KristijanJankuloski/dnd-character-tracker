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
