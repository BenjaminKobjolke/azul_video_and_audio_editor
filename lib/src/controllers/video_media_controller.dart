import 'dart:io';
import 'dart:typed_data';
import 'package:video_player/video_player.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import '../models/media_controller.dart';

/// Video implementation of MediaController
class VideoMediaController implements MediaController {
  VideoPlayerController? _controller;
  Float32List? _fullAudioSamples;
  final SoLoud _soloud = SoLoud.instance;
  bool _isWaveformReady = false;
  bool _waveformExtractionFailed = false;
  File? _videoFile;
  final List<Function()> _listeners = [];

  @override
  Future<void> initialize(File file) async {
    _videoFile = file;
    _controller = VideoPlayerController.file(file);
    await _controller!.initialize();

    // Start waveform extraction asynchronously without blocking
    _extractWaveformAsync();
  }

  /// Extract audio waveform asynchronously in the background
  Future<void> _extractWaveformAsync() async {
    if (_videoFile == null) return;

    try {
      // Initialize SoLoud if not already initialized
      if (!_soloud.isInitialized) {
        await _soloud.init();
      }

      // Extract audio from video to temp WAV file using FFmpeg
      final tempDir = await getTemporaryDirectory();
      final tempAudioPath = path.join(tempDir.path, 'video_audio_extract.wav');
      final command = '-y -i "${_videoFile!.path}" -vn -acodec pcm_s16le -ar 44100 -ac 2 "$tempAudioPath"';

      print('[VideoMediaController] Extracting audio to: $tempAudioPath');
      await FFmpegKit.execute(command);

      // Read temp audio file as bytes (same approach as audio files)
      final tempAudioFile = File(tempAudioPath);
      if (await tempAudioFile.exists()) {
        final audioBytes = await tempAudioFile.readAsBytes();

        // Use same SoLoud method as audio files
        _fullAudioSamples = await _soloud.readSamplesFromMem(
          audioBytes,
          1024, // Same sample count as audio files for consistency
          average: true,
        );

        // Clean up temp file
        await tempAudioFile.delete();
        print('[VideoMediaController] Audio waveform extracted successfully');
        _isWaveformReady = true;
        _notifyListeners();
      } else {
        print('[VideoMediaController] Temp audio file not created');
        _waveformExtractionFailed = true;
        _notifyListeners();
      }
    } catch (e) {
      print('[VideoMediaController] Error extracting audio waveform: $e');
      _waveformExtractionFailed = true;
      _notifyListeners();
      // Continue without waveform - video will still work
    }
  }

  @override
  Future<void> play() async {
    await _controller?.play();
  }

  @override
  Future<void> pause() async {
    await _controller?.pause();
  }

  @override
  Future<void> seekTo(int milliseconds) async {
    await _controller?.seekTo(Duration(milliseconds: milliseconds));
  }

  @override
  int get currentPositionMs {
    return _controller?.value.position.inMilliseconds ?? 0;
  }

  @override
  int get durationMs {
    return _controller?.value.duration.inMilliseconds ?? 0;
  }

  @override
  bool get isPlaying {
    return _controller?.value.isPlaying ?? false;
  }

  @override
  bool get isInitialized {
    return _controller?.value.isInitialized ?? false;
  }

  @override
  bool get isWaveformReady => _isWaveformReady;

  @override
  bool get waveformExtractionFailed => _waveformExtractionFailed;

  @override
  Float32List? get fullAudioSamples => _fullAudioSamples;

  @override
  void addListener(Function() listener) {
    _listeners.add(listener);
    _controller?.addListener(listener);
  }

  @override
  void removeListener(Function() listener) {
    _listeners.remove(listener);
    _controller?.removeListener(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  @override
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }

  @override
  MediaType get mediaType => MediaType.video;

  /// Get the underlying video player controller for video-specific features
  VideoPlayerController? get videoController => _controller;

  /// Get aspect ratio for video display
  double get aspectRatio => _controller?.value.aspectRatio ?? 16 / 9;
}
