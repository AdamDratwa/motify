import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/motify_theme.dart';

/// The Motify mark: a neon padlock whose body holds a terminal prompt `>_`.
///
/// This painter is the source for the PNG launcher icons
/// (tool/generate_icons.dart). The Android adaptive icon is a vector copy of
/// the same geometry in android/app/src/main/res/drawable/ic_launcher_*.xml —
/// keep the two in sync.
class MotifyLogo extends StatelessWidget {
  final double size;

  /// Draws the dark tile with its faint grid behind the mark, as on the
  /// launcher icon. Without it the mark sits on whatever is behind it.
  final bool withBackground;

  const MotifyLogo({super.key, this.size = 48, this.withBackground = false});

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: MotifyLogoPainter(withBackground: withBackground)),
      );
}

class MotifyLogoPainter extends CustomPainter {
  final bool withBackground;
  const MotifyLogoPainter({this.withBackground = true});

  /// Designed on Android's 108-unit adaptive-icon canvas, of which the
  /// central 72 units are visible; that visible square is what gets painted.
  static const _canvasUnits = 108.0;
  static const _visibleUnits = 72.0;
  static const _strokeWidth = 4.5;

  /// The mark, in canvas units, before the group transform in [paint].
  static Path markPath() => Path()
    // Shackle
    ..moveTo(39, 47)
    ..lineTo(39, 37)
    ..arcToPoint(const Offset(69, 37), radius: const Radius.circular(15))
    ..lineTo(69, 47)
    // Body
    ..addRRect(RRect.fromLTRBR(30, 47, 78, 83, const Radius.circular(7)))
    // Prompt: >
    ..moveTo(41, 58)
    ..lineTo(48.5, 65)
    ..lineTo(41, 72)
    // Prompt: _
    ..moveTo(54, 72)
    ..lineTo(67, 72);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _visibleUnits;
    canvas
      ..save()
      ..scale(scale)
      ..translate(-(_canvasUnits - _visibleUnits) / 2, -(_canvasUnits - _visibleUnits) / 2);

    if (withBackground) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, _canvasUnits, _canvasUnits),
        Paint()..color = MotifyColors.background,
      );
      final grid = Paint()
        ..color = MotifyColors.neon.withValues(alpha: 0.07)
        ..strokeWidth = 0.6;
      for (var v = 6.0; v < _canvasUnits; v += 12) {
        canvas
          ..drawLine(Offset(v, 0), Offset(v, _canvasUnits), grid)
          ..drawLine(Offset(0, v), Offset(_canvasUnits, v), grid);
      }
    }

    // Same group transform as the vector drawable: shrink the mark to fit
    // Android's circular safe zone, nudged down to centre it optically.
    canvas
      ..translate(54, 54 + 1.2)
      ..scale(0.8)
      ..translate(-54, -54);

    final path = markPath();
    canvas
      // Neon glow underneath, then the crisp stroke.
      ..drawPath(
        path,
        _stroke(MotifyColors.neon.withValues(alpha: 0.55), _strokeWidth * 2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..drawPath(path, _stroke(MotifyColors.neon, _strokeWidth))
      ..restore();
  }

  static Paint _stroke(Color color, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color
    ..strokeWidth = width;

  @override
  bool shouldRepaint(covariant MotifyLogoPainter oldDelegate) =>
      oldDelegate.withBackground != withBackground;
}

/// Renders the logo as PNG bytes, square, [pixels] wide. Used by
/// tool/generate_icons.dart.
Future<List<int>> renderMotifyLogoPng(int pixels) async {
  final recorder = ui.PictureRecorder();
  final size = Size.square(pixels.toDouble());
  const MotifyLogoPainter().paint(Canvas(recorder), size);
  final image = await recorder.endRecording().toImage(pixels, pixels);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}
