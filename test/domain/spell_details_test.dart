import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/domain/models.dart';

void main() {
  group('Spell detail fields', () {
    test('round-trip through JSON', () {
      const s = Spell(
        id: 's1',
        name: 'Frost Ray',
        level: 2,
        range: '60 ft',
        damageType: 'cold',
        areaShape: AreaShape.cone,
        areaSize: '15 ft',
        text: 'A freezing blast.',
      );
      final back = Spell.fromJson(s.toJson());
      expect(back.range, '60 ft');
      expect(back.damageType, 'cold');
      expect(back.areaShape, AreaShape.cone);
      expect(back.areaSize, '15 ft');
      expect(back.text, 'A freezing blast.');
    });

    test('older saves without new fields still load', () {
      final s = Spell.fromJson({'id': 'x', 'name': 'Old', 'level': 1});
      expect(s.damageType, '');
      expect(s.areaShape, AreaShape.none);
      expect(s.areaSize, '');
    });

    test('unknown shape falls back to none; copyWith keeps fields', () {
      final s = Spell.fromJson({
        'id': 'x',
        'name': 'N',
        'level': 0,
        'areaShape': 'bogus',
        'damageType': 'fire',
      });
      expect(s.areaShape, AreaShape.none);
      expect(s.copyWith(prepared: false).damageType, 'fire');
    });
  });

  group('Spell encyclopedia fields', () {
    test('round-trip through JSON', () {
      const s = Spell(
        id: 'srd-fireball',
        name: 'Fireball',
        level: 3,
        school: 'Evocation',
        components: 'V, S, M (a tiny ball of bat guano and sulfur)',
        duration: 'Instantaneous',
        higherLevels: 'The damage increases by 1d6.',
        castingTimeText: '1 action',
      );
      final back = Spell.fromJson(s.toJson());
      expect(back.school, 'Evocation');
      expect(back.components, 'V, S, M (a tiny ball of bat guano and sulfur)');
      expect(back.duration, 'Instantaneous');
      expect(back.higherLevels, 'The damage increases by 1d6.');
      expect(back.castingTimeText, '1 action');
    });

    test('older saves without the fields load with empty strings', () {
      final s = Spell.fromJson({'id': 'x', 'name': 'Old', 'level': 1});
      expect(s.school, '');
      expect(s.components, '');
      expect(s.duration, '');
      expect(s.higherLevels, '');
      expect(s.castingTimeText, '');
    });

    test('copyWith keeps the fields', () {
      const s = Spell(
        id: 'x',
        name: 'N',
        level: 1,
        school: 'Abjuration',
        components: 'V',
        duration: '1 round',
        higherLevels: 'More.',
        castingTimeText: '1 reaction',
      );
      final c = s.copyWith(prepared: false);
      expect(c.school, 'Abjuration');
      expect(c.components, 'V');
      expect(c.duration, '1 round');
      expect(c.higherLevels, 'More.');
      expect(c.castingTimeText, '1 reaction');
    });
  });
}
