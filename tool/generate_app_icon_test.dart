// Draws the app icon art from the logo in assets/icon/logo_source.png.
//
// It's named like a test only so it can run with Flutter's drawing tools:
//
//   flutter test tool/generate_app_icon_test.dart
//
// It writes the PNG layers into assets/icon/, which the launcher icon tool
// then turns into the Android icon files (see pubspec.yaml). It does not run
// as part of the normal `flutter test`, which only looks in test/.
//
// Edit the colors and wave shapes below and run it again to change the icon.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const double _size = 1024; // every image is 1024 x 1024

// ---- Colors ----------------------------------------------------------------

const Color _skyTop = Color(0xFF3AA6F2); // light blue at the top
const Color _deepBottom = Color(0xFF0A2F73); // deep blue at the bottom

/// The waves, from the back (top, lighter) to the front (bottom, darker).
/// Each is [height as a fraction of the icon, wave height, wavelength, phase].
const List<({double base, double amp, double length, double phase, Color color})> _waves = [
  (base: 0.40, amp: 34, length: 760, phase: 0.6, color: Color(0x992A8BE6)),
  (base: 0.52, amp: 42, length: 600, phase: 2.2, color: Color(0xB32079D8)),
  (base: 0.65, amp: 48, length: 680, phase: 4.1, color: Color(0xCC0F5FB8)),
  (base: 0.79, amp: 40, length: 500, phase: 1.3, color: Color(0xE60B3F8C)),
];

// ---- Logo ------------------------------------------------------------------

/// How tall the logo is on the icon. Android crops the icon to a circle or
/// rounded square and only guarantees the middle ~60% is visible, so this
/// keeps the logo inside that.
const double _logoHeight = 440;

/// Loads the logo and returns it as a white shape with a transparent
/// background, cropped tight to the symbol.
Future<ui.Image> _loadLogo() async {
  final bytes = await File('assets/icon/logo_source.png').readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final source = (await codec.getNextFrame()).image;
  final data = (await source.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final w = source.width;
  final h = source.height;

  // "Ink" is how dark and how opaque a pixel is, 0 to 255. The source is a
  // black symbol on white (or on transparent), so ink is the shape.
  final ink = Uint8List(w * h);
  var minX = w, minY = h, maxX = 0, maxY = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final luminance =
          (0.299 * data.getUint8(i) + 0.587 * data.getUint8(i + 1) + 0.114 * data.getUint8(i + 2));
      final alpha = data.getUint8(i + 3) / 255;
      final value = ((255 - luminance) * alpha).round().clamp(0, 255);
      ink[y * w + x] = value;
      if (value > 24) {
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
      }
    }
  }

  final cropW = maxX - minX + 1;
  final cropH = maxY - minY + 1;
  final out = Uint8List(cropW * cropH * 4);
  for (var y = 0; y < cropH; y++) {
    for (var x = 0; x < cropW; x++) {
      final o = (y * cropW + x) * 4;
      out[o] = 255; // white
      out[o + 1] = 255;
      out[o + 2] = 255;
      out[o + 3] = ink[(y + minY) * w + (x + minX)];
    }
  }

  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(out, cropW, cropH, ui.PixelFormat.rgba8888, completer.complete);
  return completer.future;
}

/// Draws the logo centered on the icon, optionally with a soft shadow so it
/// stays readable over the lighter parts of the waves.
void _paintLogo(Canvas canvas, ui.Image logo, {required bool shadow, Color color = Colors.white}) {
  final aspect = logo.width / logo.height;
  final height = _logoHeight;
  final width = height * aspect;
  final dest = Rect.fromCenter(
    center: const Offset(_size / 2, _size / 2),
    width: width,
    height: height,
  );
  final src = Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble());

  if (shadow) {
    canvas.saveLayer(
      null,
      Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
    );
    canvas.drawImageRect(
      logo,
      src,
      dest.shift(const Offset(0, 14)),
      Paint()
        ..filterQuality = FilterQuality.high
        ..colorFilter = const ColorFilter.mode(Color(0x66041A40), BlendMode.srcIn),
    );
    canvas.restore();
  }

  canvas.drawImageRect(
    logo,
    src,
    dest,
    Paint()
      ..filterQuality = FilterQuality.high
      ..colorFilter = ColorFilter.mode(color, BlendMode.srcIn),
  );
}

// ---- Waves -----------------------------------------------------------------

void _paintWaves(Canvas canvas) {
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, _size, _size),
    Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(0, _size),
        [_skyTop, _deepBottom],
      ),
  );

  for (var i = 0; i < _waves.length; i++) {
    final wave = _waves[i];
    final top = Path();
    for (var x = -10.0; x <= _size + 10; x += 8) {
      final y = wave.base * _size +
          wave.amp * math.sin(x / wave.length * 2 * math.pi + wave.phase) +
          // A second, smaller ripple so the waves aren't perfect sine curves.
          wave.amp * 0.25 * math.sin(x / (wave.length * 0.37) * 2 * math.pi + wave.phase * 2);
      if (x == -10.0) {
        top.moveTo(x, y);
      } else {
        top.lineTo(x, y);
      }
    }

    final fill = Path.from(top)
      ..lineTo(_size + 10, _size + 10)
      ..lineTo(-10, _size + 10)
      ..close();
    canvas.drawPath(fill, Paint()..color = wave.color..style = PaintingStyle.fill);

    // A pale line along the crest of the two back waves, like sea foam.
    if (i < 2) {
      canvas.drawPath(
        top,
        Paint()
          ..color = const Color(0x55FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }
}

// ---- Output ----------------------------------------------------------------

Future<void> _savePng(String path, void Function(Canvas) draw, {int size = 1024}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (size != _size.toInt()) canvas.scale(size / _size);
  draw(canvas);
  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(data!.buffer.asUint8List());
}

/// A picture of how the icon looks once Android crops it: a circle, a rounded
/// square, and small sizes. Written to build/ (not part of the project).
Future<void> _savePreview(ui.Image icon) async {
  const tile = 300.0;
  const gap = 24.0;
  const width = gap + 3 * (tile + gap);
  const height = gap + tile + gap + 96 + gap;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), Paint()..color = const Color(0xFFE8ECF1));

  // Android shows the middle two thirds of the 108dp icon (the 72dp window).
  void drawMasked(Offset at, double sizePx, Path Function(Rect) mask) {
    final rect = Rect.fromLTWH(at.dx, at.dy, sizePx, sizePx);
    canvas.save();
    canvas.clipPath(mask(rect));
    final full = sizePx / (72 / 108);
    canvas.drawImageRect(
      icon,
      const Rect.fromLTWH(0, 0, _size, _size),
      Rect.fromCenter(center: rect.center, width: full, height: full),
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
  }

  Path circle(Rect r) => Path()..addOval(r);
  Path squircle(Rect r) => Path()..addRRect(RRect.fromRectXY(r, r.width * 0.30, r.width * 0.30));
  Path square(Rect r) => Path()..addRRect(RRect.fromRectXY(r, r.width * 0.10, r.width * 0.10));

  var x = gap;
  drawMasked(Offset(x, gap), tile, circle);
  x += tile + gap;
  drawMasked(Offset(x, gap), tile, squircle);
  x += tile + gap;
  drawMasked(Offset(x, gap), tile, square);

  // Small sizes, as on a home screen and in lists.
  var sx = gap;
  for (final px in [96.0, 72.0, 48.0, 36.0]) {
    drawMasked(Offset(sx, gap + tile + gap), px, circle);
    sx += px + gap;
  }

  final image = await recorder.endRecording().toImage(width.toInt(), height.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  await Directory('build').create(recursive: true);
  await File('build/icon_preview.png').writeAsBytes(data!.buffer.asUint8List());
}

void main() {
  testWidgets('generate the app icon art', (tester) async {
    await tester.runAsync(() async {
      final logo = await _loadLogo();

      // The waves only: the background layer of the Android adaptive icon.
      await _savePng('assets/icon/app_icon_background.png', _paintWaves);

      // The logo only, on a transparent layer: the foreground layer.
      await _savePng('assets/icon/app_icon_foreground.png', (c) => _paintLogo(c, logo, shadow: true));

      // The logo as a single flat shape, which Android 13+ can tint to match
      // the user's wallpaper ("themed icons").
      await _savePng('assets/icon/app_icon_monochrome.png', (c) => _paintLogo(c, logo, shadow: false));

      // Everything together, for older phones that don't layer icons.
      void both(Canvas c) {
        _paintWaves(c);
        _paintLogo(c, logo, shadow: true);
      }

      await _savePng('assets/icon/app_icon.png', both);

      // For checking the result by eye.
      final recorder = ui.PictureRecorder();
      both(Canvas(recorder));
      await _savePreview(await recorder.endRecording().toImage(1024, 1024));

      // The logo alone, for the splash screen.
      await _savePng('assets/icon/splash_logo.png', (c) => _paintLogo(c, logo, shadow: false));
    });
  });
}
