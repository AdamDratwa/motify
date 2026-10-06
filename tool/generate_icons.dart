// Regenerates the PNG launcher icons from MotifyLogoPainter
// (lib/core/widgets/motify_logo.dart). Run from the project root after
// changing the logo:
//
//   flutter test tool/generate_icons.dart
//
// Android 8+ (all devices Motify supports) actually uses the adaptive vector
// icon in res/mipmap-anydpi-v26; the PNGs are the legacy fallback. iOS uses
// the PNGs directly, which must be opaque, hence the dark background.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:motify/core/widgets/motify_logo.dart';

const _androidRes = 'android/app/src/main/res';
const _androidSizes = {
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
};
const _iosIconSet = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

void main() {
  testWidgets('generate launcher icons', (tester) async {
    await tester.runAsync(() async {
      for (final MapEntry(key: folder, value: pixels) in _androidSizes.entries) {
        await _write('$_androidRes/$folder/ic_launcher.png', pixels);
      }

      // Icon-App-<points>x<points>@<scale>x.png, e.g. Icon-App-83.5x83.5@2x.png
      final iosName = RegExp(r'^Icon-App-([\d.]+)x[\d.]+@(\d)x\.png$');
      for (final file in Directory(_iosIconSet).listSync().whereType<File>()) {
        final match = iosName.firstMatch(file.uri.pathSegments.last);
        if (match == null) continue;
        final pixels = (double.parse(match[1]!) * int.parse(match[2]!)).round();
        await _write(file.path, pixels);
      }
    });
  });
}

Future<void> _write(String path, int pixels) async {
  await File(path).writeAsBytes(await renderMotifyLogoPng(pixels));
  // ignore: avoid_print
  print('wrote $path (${pixels}px)');
}
