import 'dart:async';

import '../helpers/app_fonts.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) =>
    withAppFonts(testMain);
