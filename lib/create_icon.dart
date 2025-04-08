import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// This is a helper application to create the app icon
// Run this with: flutter run -d windows lib/create_icon.dart
void main() {
  runApp(const AppIconGenerator());
}

class AppIconGenerator extends StatefulWidget {
  const AppIconGenerator({Key? key}) : super(key: key);

  @override
  State<AppIconGenerator> createState() => _AppIconGeneratorState();
}

class _AppIconGeneratorState extends State<AppIconGenerator> {
  final GlobalKey _iconKey = GlobalKey();
  bool _generated = false;
  String _status = '';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('VoiceGPT Icon Generator')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RepaintBoundary(
                key: _iconKey,
                child: Container(
                  width: 512,
                  height: 512,
                  decoration: const BoxDecoration(
                    color: Color(0xFF6750A4),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.record_voice_over,
                      size: 300,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _generateIcon,
                child: const Text('Generate Icon'),
              ),
              if (_status.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_status),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateIcon() async {
    try {
      setState(() {
        _status = 'Generating icons...';
      });

      // Create directories if they don't exist
      final directory = Directory('assets/icon');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Capture the widget as an image
      final RenderRepaintBoundary boundary =
          _iconKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Save the image
      final file = await File(
        'assets/icon/app_icon.png',
      ).writeAsBytes(pngBytes);

      setState(() {
        _generated = true;
        _status = 'Icon generated successfully at: ${file.path}';
      });
    } catch (e) {
      setState(() {
        _status = 'Error generating icon: $e';
      });
    }
  }
}
