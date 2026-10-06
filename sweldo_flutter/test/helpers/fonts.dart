import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the app's real typefaces into the test engine, so layout tests
/// measure text the way devices do instead of with the square test font.
Future<void> loadAppFonts() async {
  Future<ByteData> read(String path) async =>
      ByteData.sublistView(await File(path).readAsBytes());

  final archivo = FontLoader('Archivo');
  for (final weight in [400, 500, 600, 700, 800]) {
    archivo.addFont(read('assets/fonts/Archivo-$weight.ttf'));
  }
  await archivo.load();

  final mono = FontLoader('IBMPlexMono');
  for (final weight in [400, 500]) {
    mono.addFont(read('assets/fonts/IBMPlexMono-$weight.ttf'));
  }
  await mono.load();

  // Material Icons ship with the Flutter SDK.
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final icons = File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')..addFont(read(icons.path))).load();
    }
  }
}
