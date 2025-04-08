import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Generate icons
  await generateIcons();

  exit(0);
}

Future<void> generateIcons() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // Main icon (square)
  await drawIcon(canvas, 1024, 1024, false);
  final picture = recorder.endRecording();
  final img = await picture.toImage(1024, 1024);
  final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);

  // Save the main icon
  await File(
    'assets/icon/app_icon.png',
  ).writeAsBytes(pngBytes!.buffer.asUint8List());

  // Foreground icon (for adaptive icons)
  final recorder2 = ui.PictureRecorder();
  final canvas2 = Canvas(recorder2);
  await drawIcon(canvas2, 1024, 1024, true);
  final picture2 = recorder2.endRecording();
  final img2 = await picture2.toImage(1024, 1024);
  final pngBytes2 = await img2.toByteData(format: ui.ImageByteFormat.png);

  // Save the foreground icon
  await File(
    'assets/icon/app_icon_foreground.png',
  ).writeAsBytes(pngBytes2!.buffer.asUint8List());

  print('Icons generated successfully!');
}

Future<void> drawIcon(
  Canvas canvas,
  double width,
  double height,
  bool foregroundOnly,
) async {
  final size = Size(width, height);

  if (!foregroundOnly) {
    // Background
    final bgPaint =
        Paint()
          ..color = const Color(0xFF6750A4) // Primary color from theme
          ..style = PaintingStyle.fill;

    canvas.drawRect(Offset.zero & size, bgPaint);
  }

  // Microphone icon
  final iconPaint =
      Paint()
        ..color = foregroundOnly ? const Color(0xFF6750A4) : Colors.white
        ..style = PaintingStyle.fill;

  final micPath = Path();

  // Center coordinates
  final centerX = size.width / 2;
  final centerY = size.height / 2;

  // Microphone dimensions
  final micWidth = size.width * 0.35;
  final micHeight = size.height * 0.5;
  final micRadius = micWidth / 2;

  // Draw microphone body
  final micRect = Rect.fromCenter(
    center: Offset(centerX, centerY - micHeight * 0.15),
    width: micWidth,
    height: micHeight,
  );
  micPath.addRRect(
    RRect.fromRectAndRadius(micRect, Radius.circular(micRadius)),
  );

  // Draw stand
  final standWidth = micWidth * 0.6;
  final standHeight = micHeight * 0.25;
  final standTop = micRect.bottom;
  final standPath =
      Path()
        ..moveTo(centerX - standWidth / 2, standTop)
        ..lineTo(centerX + standWidth / 2, standTop)
        ..lineTo(centerX + standWidth / 2, standTop + standHeight)
        ..lineTo(centerX - standWidth / 2, standTop + standHeight)
        ..close();
  micPath.addPath(standPath, Offset.zero);

  // Draw base
  final baseWidth = standWidth * 1.5;
  final baseHeight = standHeight * 0.5;
  final baseTop = standTop + standHeight - baseHeight / 2;
  final baseRect = Rect.fromCenter(
    center: Offset(centerX, baseTop + baseHeight / 2),
    width: baseWidth,
    height: baseHeight,
  );
  micPath.addRRect(
    RRect.fromRectAndRadius(baseRect, Radius.circular(baseHeight / 2)),
  );

  // Draw sound waves if not foreground
  if (!foregroundOnly) {
    final wavePaint =
        Paint()
          ..color = Colors.white.withOpacity(0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.02;

    // Inner wave
    canvas.drawCircle(
      Offset(centerX, centerY - micHeight * 0.1),
      micWidth * 0.9,
      wavePaint,
    );

    // Outer wave
    canvas.drawCircle(
      Offset(centerX, centerY - micHeight * 0.1),
      micWidth * 1.3,
      wavePaint,
    );
  }

  canvas.drawPath(micPath, iconPaint);
}
