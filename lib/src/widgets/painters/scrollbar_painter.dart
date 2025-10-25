import 'package:flutter/material.dart';

/// Custom painter for horizontal scrollbar
class AudioScrollbarPainter extends CustomPainter {
  final double scrollOffset;
  final double visibleDuration;
  final double totalDuration;
  final Color backgroundColor;
  final Color thumbColor;

  AudioScrollbarPainter({
    required this.scrollOffset,
    required this.visibleDuration,
    required this.totalDuration,
    required this.backgroundColor,
    required this.thumbColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Calculate thumb position and width
    final thumbWidth = (visibleDuration / totalDuration) * size.width;
    final thumbX = (scrollOffset / totalDuration) * size.width;

    // Draw thumb
    final thumbPaint = Paint()
      ..color = thumbColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(thumbX, 2, thumbWidth, size.height - 4),
        const Radius.circular(8),
      ),
      thumbPaint,
    );
  }

  @override
  bool shouldRepaint(AudioScrollbarPainter oldDelegate) {
    return oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.visibleDuration != visibleDuration;
  }
}
