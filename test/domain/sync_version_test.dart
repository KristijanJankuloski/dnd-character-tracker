import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/domain/sync.dart';

void main() {
  test(
    'traits changed the synced character format, so sync needs version 2',
    () {
      // Feature gained `source` and `pinned`. An app that doesn't know them
      // would strip them and win the next sync, so older apps must refuse.
      expect(syncSchemaVersion, greaterThanOrEqualTo(2));
    },
  );
}
