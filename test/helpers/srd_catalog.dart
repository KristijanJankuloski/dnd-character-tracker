import 'dart:io';

import 'package:jjs_character_tracker/domain/spell_catalog.dart';

/// Loads a small spell list from test/fixtures (tests run from the project
/// root) so code that reads `spellCatalog` has spells to work with.
void loadTestSpellCatalog() {
  setSpellCatalog(
    parseSpellCatalog(File('test/fixtures/spells.json').readAsStringSync()),
  );
}
