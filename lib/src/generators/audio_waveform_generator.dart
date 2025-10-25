import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'visual_data_generator.dart';

/// Audio waveform generator implementation using flutter_soloud
class AudioWaveformGenerator implements VisualDataGenerator {
  @override
  Future<List<Uint8List>> generate({
    required File file,
    required double durationMs,
    required int thumbnailSize,
    Function(String)? onStatusUpdate,
  }) async {
    onStatusUpdate?.call('Generating waveforms...');

    try {
      // Read audio file bytes
      final bytes = await file.readAsBytes();

      // Generate one waveform every 10 seconds (like video thumbnails)
      final segmentCount = math.max(1, (durationMs / 10000).round());

      List<Uint8List> waveformImages = [];

      // Samples per segment for visualization
      const samplesPerSegment = 256;

      for (int i = 0; i < segmentCount; i++) {
        onStatusUpdate?.call('Generating waveform ${i + 1}/$segmentCount...');

        // Extract audio samples for this segment
        // Read samples from the middle of the segment for better representation
        final samples = await SoLoud.instance.readSamplesFromMem(
          bytes,
          samplesPerSegment,
          average: true,
        );

        // Generate waveform image from samples
        final image = await _generateWaveformImage(samples, 30, 80);
        waveformImages.add(image);
      }

      return waveformImages;
    } catch (e) {
      throw Exception('Failed to generate waveforms: $e');
    }
  }

  Future<Uint8List> _generateWaveformImage(
    Float32List samples,
    int width,
    int height,
  ) async {
    // Create a picture recorder to draw the waveform
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Background
    final backgroundPaint = Paint()..color = const Color(0xFF2C3E50);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      backgroundPaint,
    );

    // Waveform paint
    final wavePaint = Paint()
      ..color = Colors.yellowAccent
      ..strokeWidth = 1.0;

    // Draw waveform bars
    final barWidth = width / samples.length;

    for (var i = 0; i < samples.length; i++) {
      final barHeight = height * samples[i].abs() * 2;
      final x = barWidth * i;

      // Draw vertical bar representing amplitude
      canvas.drawLine(
        Offset(x, (height - barHeight) / 2),
        Offset(x, (height + barHeight) / 2),
        wavePaint,
      );
    }

    // End recording and convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);

    // Convert to bytes
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  @override
  double get segmentWidth => 30.0;
}
