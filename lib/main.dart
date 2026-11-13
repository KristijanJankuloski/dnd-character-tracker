import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'core/app.dart';
import 'data/database.dart';
import 'data/drift_repository.dart';
import 'data/drift_sync_store.dart';
import 'domain/spell_catalog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSpellCatalog(rootBundle);
  LicenseRegistry.addLicense(() async* {
    for (final font in const ['Cinzel', 'Alegreya']) {
      yield LicenseEntryWithLineBreaks([
        font,
      ], await rootBundle.loadString('assets/fonts/$font-OFL.txt'));
    }
  });
  final db = AppDatabase();
  runApp(
    DnDApp(
      repository: DriftCharacterRepository(db),
      syncStore: DriftSyncStore(db, defaultName: _deviceName),
    ),
  );
}

/// A name other devices can tell this one apart by until the user picks one.
String _deviceName() {
  final os = switch (Platform.operatingSystem) {
    'android' => 'Android',
    'ios' => 'iPhone/iPad',
    final other => other,
  };
  final suffix = (DateTime.now().microsecondsSinceEpoch % 9000 + 1000);
  return '$os $suffix';
}
