import 'dart:io';

import 'package:jjs_character_tracker/domain/spell_catalog.dart';

/// Loads the bundled spell catalog straight from disk (tests run from the
/// project root), so code that reads `srdSpells` works without an AssetBundle.
void loadSrdCatalogForTests() {
  setSpellCatalog(
    parseSpellCatalog(File('assets/data/srd_spells.json').readAsStringSync()),
  );
}
