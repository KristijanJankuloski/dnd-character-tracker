import 'package:flutter_test/flutter_test.dart';
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
}
