import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/domain/models.dart';
import 'package:jjs_character_tracker/domain/spell_catalog.dart';

void main() {
  Spell spell({List<String> classes = const []}) =>
      Spell(id: 's', name: 'S', level: 1, classes: classes);

  group('availableTo', () {
    test('a spell with no classes is open to every class', () {
      expect(spell().availableTo(['Fighter']), isTrue);
      expect(spell().availableTo(const []), isTrue);
    });

    test('a spell with classes is open only to those classes', () {
      final s = spell(classes: ['Wizard', 'Sorcerer']);
      expect(s.availableTo(['Wizard']), isTrue);
      expect(s.availableTo(['Fighter']), isFalse);
    });

    test('a multiclass character qualifies through any of its classes', () {
      final s = spell(classes: ['Cleric']);
      expect(s.availableTo(['Fighter', 'Cleric']), isTrue);
      expect(s.availableTo(['Fighter', 'Rogue']), isFalse);
    });

    test('matching ignores case and spaces', () {
      expect(spell(classes: [' wizard ']).availableTo(['Wizard']), isTrue);
    });
  });

  group('JSON', () {
    test('classes round-trip', () {
      final s = Spell.fromJson(spell(classes: ['Bard', 'Wizard']).toJson());
      expect(s.classes, ['Bard', 'Wizard']);
    });

    test('missing classes means all classes and is not written out', () {
      final json = spell().toJson();
      expect(json.containsKey('classes'), isFalse);
      expect(Spell.fromJson(json).classes, isEmpty);
    });

    test('an empty classes list means all classes', () {
      final s = Spell.fromJson({'id': 'a', 'name': 'A', 'level': 1, 'classes': []});
      expect(s.classes, isEmpty);
      expect(s.availableTo(['Fighter']), isTrue);
    });

    test('import accepts old files and files with classes', () {
      final spells = parseSpellCatalog('''
{"spells": [
  {"id": "a", "name": "A", "level": 1},
  {"id": "b", "name": "B", "level": 1, "classes": ["Wizard"]}
]}''');
      expect(spells[0].classes, isEmpty);
      expect(spells[1].classes, ['Wizard']);
      final again = parseSpellCatalog(encodeSpellCatalog(spells));
      expect(again[1].classes, ['Wizard']);
      expect(again[0].classes, isEmpty);
    });

    test('import rejects a classes value that is not a list of text', () {
      expect(
        () => parseSpellCatalog(
          '{"spells": [{"id": "a", "name": "A", "level": 1, "classes": "Wizard"}]}',
        ),
        throwsA(isA<SpellImportException>()),
      );
    });
  });

  test('copyWith(prepared) keeps classes', () {
    expect(spell(classes: ['Bard']).copyWith(prepared: false).classes, ['Bard']);
  });
}
