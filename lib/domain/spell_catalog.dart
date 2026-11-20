/// The spell list the DM imports (see the README for the JSON format). The
/// app ships no spells: the list is parsed and validated here, kept in memory
/// for synchronous reads through [spellCatalog], and persisted by
/// `SpellLibrary` in the data layer.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'models.dart';

List<Spell> _catalog = const [];

/// Why a spell file was rejected. [problems] are human-readable lines.
class SpellImportException implements Exception {
  const SpellImportException(this.problems);
  final List<String> problems;

  @override
  String toString() => problems.join('\n');
}

/// Reads `{"source", "license", "spells": [Spell JSON...]}` (a bare list of
/// spells is accepted too). Throws [SpellImportException] listing every
/// problem found, so nothing is half-imported.
List<Spell> parseSpellCatalog(String json, {bool allowEmpty = false}) {
  final Object? root;
  try {
    root = jsonDecode(json);
  } on FormatException catch (e) {
    throw SpellImportException(['This is not valid JSON: ${e.message}']);
  }
  final Object? list = root is Map ? root['spells'] : root;
  if (list is! List) {
    throw const SpellImportException([
      'Expected an object with a "spells" list, like {"spells": [...]}.',
    ]);
  }
  if (list.isEmpty && !allowEmpty) {
    throw const SpellImportException(['The "spells" list is empty.']);
  }
  final problems = <String>[];
  final spells = <Spell>[];
  final ids = <String>{};
  for (var i = 0; i < list.length; i++) {
    final e = list[i];
    final label = 'Spell ${i + 1}';
    if (e is! Map) {
      problems.add('$label is not an object.');
      continue;
    }
    final id = e['id'];
    final name = e['name'];
    final level = e['level'];
    final who = name is String && name.trim().isNotEmpty
        ? '$label ($name)'
        : label;
    if (id is! String || id.trim().isEmpty) {
      problems.add('$who: "id" must be non-empty text.');
      continue;
    }
    if (name is! String || name.trim().isEmpty) {
      problems.add('$who: "name" must be non-empty text.');
      continue;
    }
    if (level is! num || level != level.toInt() || level < 0 || level > 9) {
      problems.add('$who: "level" must be a whole number from 0 to 9.');
      continue;
    }
    if (!ids.add(id)) {
      problems.add('$who: duplicate id "$id".');
      continue;
    }
    try {
      spells.add(Spell.fromJson(e.cast()));
    } catch (_) {
      problems.add(
        '$who: a field has the wrong type or an unknown value '
        '(check "save" and the true/false fields).',
      );
    }
  }
  if (problems.isNotEmpty) throw SpellImportException(problems);
  return spells;
}

/// The file text for [spells]: `{"source", "license", "spells": [...]}`, the
/// same shape Import spells reads. [source] and [license] are optional notes.
String encodeSpellCatalog(
  List<Spell> spells, {
  String? source,
  String? license,
}) => const JsonEncoder.withIndent('  ').convert({
  'source': ?source,
  'license': ?license,
  'spells': [for (final s in spells) s.toJson()],
});

/// Replaces the in-memory list (and with it the suggestions everywhere).
void setSpellCatalog(List<Spell> spells) {
  _catalog = List.unmodifiable(spells);
}

/// Every imported spell, in file order. Empty until the DM imports a file.
List<Spell> get spellCatalog => _catalog;

@visibleForTesting
void resetSpellCatalogForTests() => _catalog = const [];
