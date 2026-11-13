import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled typefaces before the tests in a file run, so widgets are
/// laid out with the glyph widths the app really has rather than the square
/// placeholder glyphs of the default test font.
///
/// Used from the `flutter_test_config.dart` of the widget test folders only:
/// it needs the widget test binding, which blocks the real sockets the sync
/// tests under `test/data` rely on.
Future<void> withAppFonts(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const families = {
    'Cinzel': ['Cinzel-Bold'],
    'Alegreya': [
      'Alegreya-Regular',
      'Alegreya-Italic',
      'Alegreya-Bold',
      'Alegreya-ExtraBold',
    ],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = await File('assets/fonts/$file.ttf').readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
  await testMain();
}
