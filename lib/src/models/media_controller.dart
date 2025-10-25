import 'dart:io';
import 'dart:typed_data';

/// Enum to represent media types
enum MediaType {
  video,
  audio,
  unknown,
}

/// Abstract interface for media playback control
abstract class MediaController {
  /// Initialize the media file
  Future<void> initialize(File file);

  /// Play the media
  Future<void> play();

  /// Pause the media
  Future<void> pause();

  /// Seek to a specific position in milliseconds
  Future<void> seekTo(int milliseconds);

  /// Get the current playback position in milliseconds
  int get currentPositionMs;

  /// Get the total duration in milliseconds
  int get durationMs;

  /// Check if media is playing
  bool get isPlaying;

  /// Check if media is initialized
  bool get isInitialized;

  /// Check if waveform extraction is complete
  bool get isWaveformReady;

  /// Check if waveform extraction failed
  bool get waveformExtractionFailed;

  /// Get the full audio samples for waveform visualization
  Float32List? get fullAudioSamples;

  /// Add a listener for playback position updates
  void addListener(Function() listener);

  /// Remove a listener
  void removeListener(Function() listener);

  /// Dispose resources
  Future<void> dispose();

  /// Get the media type
  MediaType get mediaType;
}

/// Helper class to detect media type from file extension
class MediaTypeDetector {
  static MediaType detectFromFile(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    return detectFromExtension(extension);
  }

  static MediaType detectFromExtension(String extension) {
    // Video extensions
    const videoExtensions = [
      'mp4',
      'mov',
      'avi',
      'mkv',
      'flv',
      'wmv',
      'webm',
      'm4v',
      'mpeg',
      'mpg',
      '3gp',
    ];

    // Audio extensions
    const audioExtensions = [
      'mp3',
      'wav',
      'aac',
      'flac',
      'ogg',
      'wma',
      'm4a',
      'opus',
      'aiff',
      'alac',
    ];

    if (videoExtensions.contains(extension)) {
      return MediaType.video;
    } else if (audioExtensions.contains(extension)) {
      return MediaType.audio;
    } else {
      return MediaType.unknown;
    }
  }
}
