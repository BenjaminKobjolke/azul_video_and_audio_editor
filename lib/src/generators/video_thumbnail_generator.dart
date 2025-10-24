import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter_video_thumbnail_plus/flutter_video_thumbnail_plus.dart';
import 'visual_data_generator.dart';

/// Video thumbnail generator implementation
class VideoThumbnailGenerator implements VisualDataGenerator {
  @override
  Future<List<Uint8List>> generate({
    required File file,
    required double durationMs,
    required int thumbnailSize,
    Function(String)? onStatusUpdate,
  }) async {
    onStatusUpdate?.call('Generating thumbnails...');

    // Optimize thumbnail count based on video duration
    final int thumbnailCount = math.min(
      80,
      math.max(thumbnailSize, (durationMs / 500).round()),
    );

    List<Uint8List> thumbnails = [];

    for (int i = 0; i < thumbnailCount; i++) {
      final positionMs = (durationMs / thumbnailCount) * i;

      final thumbnail = await FlutterVideoThumbnailPlus.thumbnailData(
        video: file.path,
        imageFormat: ImageFormat.jpeg,
        timeMs: positionMs.toInt(),
        quality: 10, // Low quality to save memory
        maxWidth: 100, // Reduce width to save memory
        maxHeight: 80,
      );

      if (thumbnail != null) {
        thumbnails.add(thumbnail);
      }
    }

    return thumbnails;
  }

  @override
  double get segmentWidth => 30.0;
}
