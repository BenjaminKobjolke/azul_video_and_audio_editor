import 'dart:io';
import 'package:video_player/video_player.dart';
import '../models/media_controller.dart';

/// Video implementation of MediaController
class VideoMediaController implements MediaController {
  VideoPlayerController? _controller;

  @override
  Future<void> initialize(File file) async {
    _controller = VideoPlayerController.file(file);
    await _controller!.initialize();
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
  void addListener(Function() listener) {
    _controller?.addListener(listener);
  }

  @override
  void removeListener(Function() listener) {
    _controller?.removeListener(listener);
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
