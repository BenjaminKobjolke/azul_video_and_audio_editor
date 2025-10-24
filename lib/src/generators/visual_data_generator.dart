import 'dart:io';
import 'dart:typed_data';

/// Abstract interface for generating visual data (thumbnails or waveforms)
abstract class VisualDataGenerator {
  /// Generate visual data for the given media file
  /// Returns a list of image data (thumbnails or waveform segments)
  Future<List<Uint8List>> generate({
    required File file,
    required double durationMs,
    required int thumbnailSize,
    Function(String)? onStatusUpdate,
  });

  /// Get the width of each visual segment
  double get segmentWidth => 30.0;
}
