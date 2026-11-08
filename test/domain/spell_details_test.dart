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
}
