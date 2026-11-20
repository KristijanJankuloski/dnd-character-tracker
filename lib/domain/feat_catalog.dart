/// The feat list the DM imports (see the README for the JSON format). The app
/// ships no feats: the list is parsed and validated here, kept in memory for
/// synchronous reads through [featCatalog], and persisted by `FeatLibrary` in
/// the data layer.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'models.dart';

List<Feat> _catalog = const [];

/// Why a feat file was rejected. [problems] are human-readable lines.
class FeatImportException implements Exception {
  const FeatImportException(this.problems);
  final List<String> problems;

  @override
  String toString() => problems.join('\n');
}

/// Reads `{"source", "license", "feats": [Feat JSON...]}` (a bare list of
/// feats is accepted too). Throws [FeatImportException] listing every problem
/// found, so nothing is half-imported.
List<Feat> parseFeatCatalog(String json, {bool allowEmpty = false}) {
  final Object? root;
  try {
    root = jsonDecode(json);
  } on FormatException catch (e) {
    throw FeatImportException(['This is not valid JSON: ${e.message}']);
  }
  final Object? list = root is Map ? root['feats'] : root;
  if (list is! List) {
    throw const FeatImportException([
      'Expected an object with a "feats" list, like {"feats": [...]}.',
    ]);
  }
  if (list.isEmpty && !allowEmpty) {
    throw const FeatImportException(['The "feats" list is empty.']);
  }
  final problems = <String>[];
  final feats = <Feat>[];
  final ids = <String>{};
  for (var i = 0; i < list.length; i++) {
    final e = list[i];
    final label = 'Feat ${i + 1}';
    if (e is! Map) {
      problems.add('$label is not an object.');
      continue;
    }
    final id = e['id'];
    final name = e['name'];
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
    if (!ids.add(id)) {
      problems.add('$who: duplicate id "$id".');
      continue;
    }
    var wrongType = false;
    for (final k in const ['text', 'prerequisite', 'source']) {
      if (e[k] != null && e[k] is! String) wrongType = true;
    }
    if (wrongType) {
      problems.add('$who: "text", "prerequisite" and "source" must be text.');
      continue;
    }
    feats.add(Feat.fromJson(e.cast()));
  }
  if (problems.isNotEmpty) throw FeatImportException(problems);
  return feats;
}

/// The file text for [feats]: `{"source", "license", "feats": [...]}`, the
/// same shape Import feats reads. [source] and [license] are optional notes.
String encodeFeatCatalog(List<Feat> feats, {String? source, String? license}) =>
    const JsonEncoder.withIndent('  ').convert({
      'source': ?source,
      'license': ?license,
      'feats': [for (final f in feats) f.toJson()],
    });

/// Replaces the in-memory list (and with it the suggestions everywhere).
void setFeatCatalog(List<Feat> feats) {
  _catalog = List.unmodifiable(feats);
}

/// Every imported feat, in file order. Empty until the DM imports a file.
List<Feat> get featCatalog => _catalog;

@visibleForTesting
void resetFeatCatalogForTests() => _catalog = const [];
