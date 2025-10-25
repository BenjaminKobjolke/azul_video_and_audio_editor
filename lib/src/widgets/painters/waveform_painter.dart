import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:math' as math;

/// Custom painter for waveform visualization (DAW-style)
class WaveformPainter extends CustomPainter {
  final Float32List? samples;
  final double startMs;
  final double endMs;
  final double durationMs;
  final double currentPositionMs;
  final double? touchedPositionMs;
  final Color waveformColor;
  final Color selectedRegionColor;
  final Color playbackLineColor;
  final Color touchLineColor;
  final double zoomLevel;
  final double scrollOffsetMs;

  WaveformPainter({
    required this.samples,
    required this.startMs,
    required this.endMs,
    required this.durationMs,
    required this.currentPositionMs,
    this.touchedPositionMs,
    required this.waveformColor,
    required this.selectedRegionColor,
    required this.playbackLineColor,
    required this.touchLineColor,
    required this.zoomLevel,
    required this.scrollOffsetMs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (durationMs <= 0) return;

    // Calculate visible time window (needed for both waveform and markers)
    final visibleDurationMs = durationMs / zoomLevel;
    final visibleStartMs = scrollOffsetMs;
    final visibleEndMs = math.min(scrollOffsetMs + visibleDurationMs, durationMs);

    // Only draw waveform if samples exist
    if (samples != null && samples!.isNotEmpty) {
      final centerY = size.height / 2;

    // Calculate which samples to draw
    final totalSamples = samples!.length;
    final samplesPerMs = totalSamples / durationMs;

    final startSampleIndex = (visibleStartMs * samplesPerMs).floor();
    final endSampleIndex = (visibleEndMs * samplesPerMs).ceil().clamp(0, totalSamples);

    if (startSampleIndex >= endSampleIndex) return;

    // Find maximum amplitude in visible samples for normalization
    double maxAmplitude = 0.0;
    for (var i = startSampleIndex; i < endSampleIndex; i++) {
      final sampleIndex = i.clamp(0, totalSamples - 1);
      final amplitude = samples![sampleIndex].abs();
      if (amplitude > maxAmplitude) {
        maxAmplitude = amplitude;
      }
    }

    // Normalization factor (avoid division by zero)
    final normalizationFactor = maxAmplitude > 0.0 ? 1.0 / maxAmplitude : 1.0;

    // Calculate how many pixels per sample
    final visibleSampleCount = endSampleIndex - startSampleIndex;
    final pixelsPerSample = size.width / visibleSampleCount;

    // Decide if we should draw bars or use optimized line drawing
    final shouldDrawBars = pixelsPerSample >= 2.0;

    // Paint for unselected waveform (dimmed)
    final dimWavePaint = Paint()
      ..color = waveformColor.withOpacity(0.3)
      ..strokeWidth = pixelsPerSample.clamp(1.0, 3.0)
      ..strokeCap = StrokeCap.round;

    // Paint for selected waveform (bright)
    final brightWavePaint = Paint()
      ..color = waveformColor
      ..strokeWidth = pixelsPerSample.clamp(1.0, 3.0)
      ..strokeCap = StrokeCap.round;

    // Draw waveform
    if (shouldDrawBars) {
      // Draw individual bars
      for (var i = startSampleIndex; i < endSampleIndex; i++) {
        final sampleIndex = i.clamp(0, totalSamples - 1);
        final amplitude = (samples![sampleIndex].abs() * normalizationFactor).clamp(0.0, 1.0);
        final barHeight = size.height * amplitude; // Use full height

        // Calculate X position in screen space
        final x = (i - startSampleIndex) * pixelsPerSample + (pixelsPerSample / 2);

        // Calculate time for this sample
        final sampleTimeMs = (i / samplesPerMs);

        // Choose paint based on whether this sample is in selected region
        final paint = (sampleTimeMs >= startMs && sampleTimeMs <= endMs) ? brightWavePaint : dimWavePaint;

        // Draw vertical bar representing amplitude
        canvas.drawLine(
          Offset(x, centerY - barHeight / 2),
          Offset(x, centerY + barHeight / 2),
          paint,
        );
      }
    } else {
      // Optimized drawing for zoomed out view
      // Draw as continuous path
      final dimPath = Path();
      final brightPath = Path();
      Path? lastPath; // Track which path we're currently drawing to

      for (var i = startSampleIndex; i < endSampleIndex; i++) {
        final sampleIndex = i.clamp(0, totalSamples - 1);
        final amplitude = (samples![sampleIndex].abs() * normalizationFactor).clamp(0.0, 1.0);
        final barHeight = size.height * amplitude;

        final x = (i - startSampleIndex) * pixelsPerSample;
        final sampleTimeMs = (i / samplesPerMs);

        final path = (sampleTimeMs >= startMs && sampleTimeMs <= endMs) ? brightPath : dimPath;

        // If switching to a different path, start a new subpath
        if (path != lastPath) {
          path.moveTo(x, centerY - barHeight / 2);
          lastPath = path;
        }

        path.lineTo(x, centerY - barHeight / 2);
        path.lineTo(x, centerY + barHeight / 2);
      }

      canvas.drawPath(dimPath, dimWavePaint..style = PaintingStyle.stroke);
      canvas.drawPath(brightPath, brightWavePaint..style = PaintingStyle.stroke);
    }
    } // End waveform drawing block

    // Convert time to screen X position (helper function for marker drawing)
    double timeToScreenX(double timeMs) {
      return ((timeMs - visibleStartMs) / visibleDurationMs) * size.width;
    }

    // Draw selected region overlay
    if (endMs >= visibleStartMs && startMs <= visibleEndMs) {
      final startX = timeToScreenX(startMs);
      final endX = timeToScreenX(endMs);

      // Only draw if at least part of the rectangle is visible
      final visibleStartX = startX.clamp(0.0, size.width);
      final visibleEndX = endX.clamp(0.0, size.width);

      if (visibleStartX < visibleEndX && visibleEndX > 0 && visibleStartX < size.width) {
        final selectedRegionPaint = Paint()
          ..color = selectedRegionColor
          ..style = PaintingStyle.fill;

        canvas.drawRect(
          Rect.fromLTRB(visibleStartX, 0, visibleEndX, size.height),
          selectedRegionPaint,
        );

        // Draw selected region borders (only if visible in viewport)
        final borderPaint = Paint()
          ..color = Colors.green
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;

        // Only draw start border if it's within visible range
        if (startMs >= visibleStartMs && startMs <= visibleEndMs) {
          canvas.drawLine(Offset(startX, 0), Offset(startX, size.height), borderPaint);
        }

        // Only draw end border if it's within visible range
        if (endMs >= visibleStartMs && endMs <= visibleEndMs) {
          canvas.drawLine(Offset(endX, 0), Offset(endX, size.height), borderPaint);
        }
      }
    }

    // Draw playback position indicator
    if (currentPositionMs >= visibleStartMs && currentPositionMs <= visibleEndMs) {
      final playbackX = timeToScreenX(currentPositionMs);
      final playbackPaint = Paint()
        ..color = playbackLineColor
        ..strokeWidth = 3.0;

      canvas.drawLine(
        Offset(playbackX, 0),
        Offset(playbackX, size.height),
        playbackPaint,
      );
    }

    // Draw touched position indicator (cyan line)
    if (touchedPositionMs != null && touchedPositionMs! >= visibleStartMs && touchedPositionMs! <= visibleEndMs) {
      final touchedX = timeToScreenX(touchedPositionMs!);
      final touchPaint = Paint()
        ..color = touchLineColor
        ..strokeWidth = 4.0;

      canvas.drawLine(
        Offset(touchedX, 0),
        Offset(touchedX, size.height),
        touchPaint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.currentPositionMs != currentPositionMs ||
        oldDelegate.startMs != startMs ||
        oldDelegate.endMs != endMs ||
        oldDelegate.touchedPositionMs != touchedPositionMs ||
        oldDelegate.samples != samples ||
        oldDelegate.zoomLevel != zoomLevel ||
        oldDelegate.scrollOffsetMs != scrollOffsetMs;
  }
}
