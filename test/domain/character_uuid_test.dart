import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/domain/character_factory.dart';

void main() {
  test('newUuid produces unique v4 UUIDs', () {
    final re = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    final ids = {for (var i = 0; i < 500; i++) newUuid()};
    expect(ids.length, 500);
    expect(ids.every(re.hasMatch), isTrue);
  });
}
