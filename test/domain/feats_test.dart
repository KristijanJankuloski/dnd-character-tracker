import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/domain/actions.dart';
import 'package:jjs_character_tracker/domain/character_factory.dart';
import 'package:jjs_character_tracker/domain/feat_catalog.dart';
import 'package:jjs_character_tracker/domain/models.dart';
import 'package:jjs_character_tracker/domain/sync.dart';

import '../helpers/srd_catalog.dart';

Character make() => createCharacter(
  name: 'F',
  race: 'Human',
  className: 'Fighter',
  level: 4,
  abilities: standardArray,
  starterGear: false,
);

const _alert = Feat(id: 'alert', name: 'Alert', text: '+5 to initiative.');

void main() {
  loadTestSpellCatalog();

  group('Feat data', () {
    test('JSON round trip keeps every field', () {
      const f = Feat(
        id: 'x',
        name: 'Tough',
        text: 'More HP.',
        prerequisite: 'None',
        source: 'PHB',
      );
      final back = Feat.fromJson(f.toJson());
      expect(back.id, 'x');
      expect(back.name, 'Tough');
      expect(back.text, 'More HP.');
      expect(back.prerequisite, 'None');
      expect(back.source, 'PHB');
    });

    test('a character saved before feats existed loads with none', () {
      final json = make().toJson()..remove('feats');
      expect(Character.fromJson(json).feats, isEmpty);
    });

    test('a character keeps its feats through JSON', () {
      final c = make().copyWith(feats: [_alert]);
      final back = Character.fromJson(
        jsonDecode(jsonEncode(c.toJson())) as Map<String, Object?>,
      );
      expect(back.feats.single.name, 'Alert');
    });

    test('feats change the synced format, so sync needs version 3', () {
      expect(syncSchemaVersion, greaterThanOrEqualTo(3));
    });
  });

  group('feat actions', () {
    test('add appends a trimmed copy and logs it', () {
      final r = addFeat(
        make(),
        const Feat(id: 'a', name: '  Alert  ', text: 't'),
      );
      expect(r.character.feats.single.name, 'Alert');
      expect(r.description, 'Added feat: Alert');
    });

    test('add refuses a nameless feat and a duplicate name', () {
      final c = make();
      final nameless = addFeat(c, const Feat(id: 'n', name: '  '));
      expect(nameless.character.feats, isEmpty);
      expect(nameless.blocked, isTrue);
      final once = addFeat(c, _alert).character;
      final twice = addFeat(once, const Feat(id: 'z', name: 'ALERT'));
      expect(twice.character.feats, hasLength(1));
      expect(twice.blocked, isTrue);
    });

    test('edit keeps the id and refuses a name another feat has', () {
      var c = addFeat(make(), _alert).character;
      c = addFeat(c, const Feat(id: 'tough', name: 'Tough')).character;
      final ok = editFeat(c, 'alert', const Feat(id: 'ignored', name: 'Wary'));
      expect(ok.character.feats.map((f) => f.id), ['alert', 'tough']);
      expect(ok.character.feats.first.name, 'Wary');
      final dup = editFeat(c, 'alert', const Feat(id: 'alert', name: 'tough'));
      expect(dup.blocked, isTrue);
      expect(editFeat(c, 'nope', _alert).blocked, isTrue);
    });

    test('remove deletes by id', () {
      final c = addFeat(make(), _alert).character;
      expect(removeFeat(c, 'alert').character.feats, isEmpty);
      expect(removeFeat(c, 'nope').blocked, isTrue);
    });
  });

  group('feat catalogue file', () {
    test('parses an object with a feats list and a bare list', () {
      const feat = '{"id":"a","name":"Alert","text":"t"}';
      expect(parseFeatCatalog('{"feats":[$feat]}').single.name, 'Alert');
      expect(parseFeatCatalog('[$feat]').single.id, 'a');
    });

    test('reports every problem and imports nothing', () {
      try {
        parseFeatCatalog(
          '{"feats":[{"name":"No id"},{"id":"b","name":""},'
          '{"id":"c","name":"C","text":5},"x",'
          '{"id":"d","name":"D"},{"id":"d","name":"D2"}]}',
        );
        fail('should throw');
      } on FeatImportException catch (e) {
        expect(e.problems, hasLength(5));
      }
    });

    test('rejects bad JSON, a wrong shape and an empty list', () {
      expect(
        () => parseFeatCatalog('nope'),
        throwsA(isA<FeatImportException>()),
      );
      expect(
        () => parseFeatCatalog('{"spells":[]}'),
        throwsA(isA<FeatImportException>()),
      );
      expect(
        () => parseFeatCatalog('{"feats":[]}'),
        throwsA(isA<FeatImportException>()),
      );
      expect(parseFeatCatalog('{"feats":[]}', allowEmpty: true), isEmpty);
    });

    test('encode produces what parse reads', () {
      final text = encodeFeatCatalog([
        _alert.copyWith(prerequisite: 'None', source: 'PHB'),
      ], source: 'Mine');
      expect((jsonDecode(text) as Map)['source'], 'Mine');
      final back = parseFeatCatalog(text).single;
      expect(back.prerequisite, 'None');
      expect(back.source, 'PHB');
    });
  });
}
