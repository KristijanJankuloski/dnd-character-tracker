import 'package:flutter/material.dart';

import 'core/app.dart';
import 'data/database.dart';
import 'data/drift_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  runApp(DnDApp(repository: DriftCharacterRepository(db)));
}
