/// The bundled SRD spell catalog (assets/data/srd_spells.json), loaded once
/// at app start and then read synchronously through [srdSpells].
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show AssetBundle;

import 'models.dart';

const spellCatalogAsset = 'assets/data/srd_spells.json';

List<Spell>? _catalog;

/// Reads the asset format `{"source", "license", "spells": [Spell JSON...]}`.
List<Spell> parseSpellCatalog(String json) {
  final root = jsonDecode(json) as Map<String, Object?>;
  return [
    for (final e in root['spells'] as List) Spell.fromJson((e as Map).cast()),
  ];
}

Future<void> loadSpellCatalog(AssetBundle bundle) async {
  setSpellCatalog(
    parseSpellCatalog(await bundle.loadString(spellCatalogAsset)),
  );
}

void setSpellCatalog(List<Spell> spells) {
  _catalog = List.unmodifiable(spells);
}

/// Every SRD spell. Throws if the catalog was never loaded, so a missing load
/// fails loudly instead of showing an empty spell list.
List<Spell> get srdSpells =>
    _catalog ?? (throw StateError('Spell catalog not loaded'));

@visibleForTesting
void resetSpellCatalogForTests() => _catalog = null;
