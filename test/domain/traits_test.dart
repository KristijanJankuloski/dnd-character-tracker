import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/domain/actions.dart';
import 'package:jjs_character_tracker/domain/character_factory.dart';
import 'package:jjs_character_tracker/domain/class_templates.dart';
import 'package:jjs_character_tracker/domain/models.dart';
import 'package:jjs_character_tracker/domain/rules.dart';

import '../helpers/srd_catalog.dart';

Character make({List<Feature> traits = const []}) => createCharacter(
  name: 'T',
  race: 'Tiefling',
  className: 'Sorcerer',
  level: 5,
  abilities: standardArray,
  starterGear: false,
  traits: traits,
);

void main() {
  loadSrdCatalogForTests();

  group('Feature data', () {
    test('feature JSON round trip keeps source and pinned', () {
      const f = Feature(
        'Hellish Resistance',
        'Fire resistance',
        source: FeatureSource.species,
        pinned: 'Fire resistance',
      );
      final back = Feature.fromJson(f.toJson());
      expect(back.source, FeatureSource.species);
      expect(back.pinned, 'Fire resistance');
    });

    test('a feature saved before sources existed loads as an unpinned '
        'class feature', () {
      final f = Feature.fromJson({'name': 'Old', 'text': 't'});
      expect(f.source, FeatureSource.classFeature);
      expect(f.pinned, '');
    });

    test('an unknown source loads as a class feature', () {
      final f = Feature.fromJson({
        'name': 'x',
        'text': '',
        'source': 'wizardTower',
      });
      expect(f.source, FeatureSource.classFeature);
    });
  });

  group('pinned labels', () {
    test('pinned labels follow effect notes in stats.traits', () {
      final base = make();
      final c = base.copyWith(
        modifiers: [
          const Effect(
            target: StatTarget.note,
            mode: EffectMode.add,
            value: 0,
            source: 'Ring',
            note: 'Resist cold',
          ),
        ],
        features: [
          ...base.features,
          const Feature('Hellish Resistance', '', pinned: 'Fire resistance'),
          const Feature('No pin', 't'),
        ],
      );
      expect(resolveStats(c).traits, [
        ('Ring', 'Resist cold'),
        ('Hellish Resistance', 'Fire resistance'),
      ]);
    });

    test('a whitespace-only pinned label adds no chip', () {
      final base = make();
      final c = base.copyWith(
        features: [
          ...base.features,
          const Feature('Blank', '', pinned: '   '),
        ],
      );
      expect(resolveStats(c).traits, isEmpty);
    });
  });

  test('createCharacter appends traits after the class features', () {
    final c = make(
      traits: [
        const Feature('Darkvision', '60 ft', source: FeatureSource.species),
      ],
    );
    expect(c.features.length, classTemplates['Sorcerer']!.features.length + 1);
    expect(c.features.last.name, 'Darkvision');
  });

  group('feature actions', () {
    const hellish = Feature(
      'Hellish Resistance',
      'Fire resistance',
      source: FeatureSource.species,
      pinned: 'Fire resistance',
    );
    const metamagicMessage =
        'Metamagic is a built-in feature; use its Choose button.';
    int metamagicIndex(Character c) =>
        c.features.indexWhere((f) => f.name == 'Metamagic');

    group('addFeature', () {
      test('appends a trimmed trait', () {
        final c = make();
        final r = addFeature(
          c,
          const Feature(
            '  Eyes of the Dark ',
            'Darkvision 120 ft',
            source: FeatureSource.subclass,
            pinned: ' Darkvision 120 ft ',
          ),
        );
        expect(r.blocked, isFalse);
        expect(r.character.features.last.name, 'Eyes of the Dark');
        expect(r.character.features.last.pinned, 'Darkvision 120 ft');
        expect(r.description, 'Added trait: Eyes of the Dark');
      });

      test('blocks a blank name and changes nothing', () {
        final c = make();
        for (final name in ['', '   ']) {
          final r = addFeature(c, Feature(name, 'x'));
          expect(r.blocked, isTrue);
          expect(r.description, 'Give the trait a name.');
          expect(identical(r.character, c), isTrue);
        }
      });

      test('blocks the reserved name Metamagic', () {
        final c = make();
        final r = addFeature(c, const Feature(' metamagic ', ''));
        expect(r.blocked, isTrue);
        expect(r.description, metamagicMessage);
        expect(identical(r.character, c), isTrue);
      });

      test('a whitespace-only pinned label is stored as empty', () {
        final r = addFeature(make(), const Feature('Blank', '', pinned: '   '));
        expect(r.character.features.last.pinned, '');
      });
    });

    group('editFeature', () {
      test('replaces in place and keeps order', () {
        final c = addFeature(make(), hellish).character;
        final last = c.features.length - 1;
        final r = editFeature(
          c,
          last,
          hellish.copyWith(text: 'Resist fire damage', pinned: 'Fire resist'),
        );
        expect(r.blocked, isFalse);
        expect(r.character.features.length, c.features.length);
        expect(r.character.features[last].text, 'Resist fire damage');
        expect(r.character.features[last].pinned, 'Fire resist');
        expect(r.description, 'Edited trait: Hellish Resistance');
      });

      test('blocks a bad index', () {
        final c = make();
        for (final i in [-1, c.features.length]) {
          final r = editFeature(c, i, hellish);
          expect(r.blocked, isTrue);
          expect(r.description, 'That trait no longer exists.');
          expect(identical(r.character, c), isTrue);
        }
      });

      test('blocks the Metamagic entry', () {
        final c = make();
        final r = editFeature(c, metamagicIndex(c), hellish);
        expect(r.blocked, isTrue);
        expect(r.description, metamagicMessage);
      });

      test('blocks renaming a trait to Metamagic', () {
        final c = addFeature(make(), hellish).character;
        final r = editFeature(
          c,
          c.features.length - 1,
          hellish.copyWith(name: 'Metamagic'),
        );
        expect(r.blocked, isTrue);
        expect(r.description, metamagicMessage);
      });

      test('blocks a blank name', () {
        final c = addFeature(make(), hellish).character;
        final r = editFeature(
          c,
          c.features.length - 1,
          hellish.copyWith(name: ' '),
        );
        expect(r.blocked, isTrue);
        expect(r.description, 'Give the trait a name.');
      });
    });

    group('removeFeature', () {
      test('removes the trait', () {
        final c = addFeature(make(), hellish).character;
        final r = removeFeature(c, c.features.length - 1);
        expect(r.blocked, isFalse);
        expect(r.character.features.length, c.features.length - 1);
        expect(
          r.character.features.any((f) => f.name == hellish.name),
          isFalse,
        );
        expect(r.description, 'Removed trait: Hellish Resistance');
      });

      test('blocks a bad index', () {
        final c = make();
        for (final i in [-1, c.features.length]) {
          final r = removeFeature(c, i);
          expect(r.blocked, isTrue);
          expect(r.description, 'That trait no longer exists.');
        }
      });

      test('blocks the Metamagic entry', () {
        final c = make();
        final r = removeFeature(c, metamagicIndex(c));
        expect(r.blocked, isTrue);
        expect(r.description, metamagicMessage);
        expect(identical(r.character, c), isTrue);
      });
    });
  });
}
