import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'core/app.dart';
import 'data/database.dart';
import 'data/drift_repository.dart';
import 'data/drift_sync_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
