import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/domain/character_factory.dart';
import 'package:jjs_character_tracker/domain/models.dart';
import 'package:uuid/uuid.dart';

void main() {
  test('new characters get unique UUID v4 ids', () {
    Character make() => createCharacter(
      name: 'A',
      race: 'Human',
      className: 'Fighter',
      level: 1,
      abilities: standardArray,
    );
    final a = make(), b = make();
    expect(Uuid.isValidUUID(fromString: a.id), isTrue);
    expect(a.id[14], '4');
    expect(a.id, isNot(b.id));
  });
}
