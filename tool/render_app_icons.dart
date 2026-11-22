// Renders the McMap logo (lib/widgets/mcmap_logo.dart) into every app icon
// PNG: web favicon + PWA icons, Android launcher icons and the iOS app icon
// set. Each existing file is overwritten at its own pixel size.
//
// Run from the repo root (it's a Flutter test so it can use the engine):
//   flutter test tool/render_app_icons.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mcmap/theme/app_theme.dart';
import 'package:mcmap/widgets/mcmap_logo.dart';

enum _Style {
  /// Logo only, transparent (browser tab favicon).
  bare,

  /// Rounded McGill-red tile (PWA icon, Android launcher).
  tile,

  /// Full-bleed red with extra padding (PWA maskable: the OS crops it).
  maskable,

  /// Full-bleed opaque red square (iOS rounds the corners itself and
  /// rejects transparency).
  opaque,
}

int _pngSize(File file) {
  final bytes = file.readAsBytesSync();
  // PNG IHDR: width is big-endian at byte 16.
  return ByteData.sublistView(bytes, 16, 20).getUint32(0);
}

Future<Uint8List> _render(int size, _Style style) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final s = size.toDouble();
  final bg = Paint()..color = McMapColors.red;
  switch (style) {
    case _Style.bare:
      break;
    case _Style.tile:
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, s, s),
          Radius.circular(s * 0.22),
        ),
        bg,
      );
    case _Style.maskable || _Style.opaque:
      canvas.drawRect(Rect.fromLTWH(0, 0, s, s), bg);
  }
  final logoScale = switch (style) {
    _Style.bare => 1.0,
    _Style.tile || _Style.opaque => 0.8,
    _Style.maskable => 0.66,
  };
  final logo = s * logoScale;
  canvas.translate((s - logo) / 2, (s - logo) / 2);
  const McMapLogoPainter().paint(canvas, Size.square(logo));

  final image = await recorder.endRecording().toImage(size, size);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}

void main() {
  testWidgets('render app icons', (tester) async {
    final targets = <(String, _Style)>[
      ('web/favicon.png', _Style.bare),
      ('web/icons/Icon-192.png', _Style.tile),
      ('web/icons/Icon-512.png', _Style.tile),
      ('web/icons/Icon-maskable-192.png', _Style.maskable),
      ('web/icons/Icon-maskable-512.png', _Style.maskable),
      for (final dir in Directory(
        'android/app/src/main/res',
      ).listSync().whereType<Directory>())
        if (File('${dir.path}/ic_launcher.png').existsSync())
          ('${dir.path}/ic_launcher.png', _Style.tile),
      for (final file in Directory(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset',
      ).listSync().whereType<File>())
        if (file.path.endsWith('.png')) (file.path, _Style.opaque),
    ];

    await tester.runAsync(() async {
      for (final (path, style) in targets) {
        final file = File(path);
        final size = _pngSize(file);
        file.writeAsBytesSync(await _render(size, style));
        // ignore: avoid_print
        print('$path  ${size}px  ${style.name}');
      }
    });
  });
}
