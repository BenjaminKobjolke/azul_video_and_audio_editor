import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/media_controller.dart';
import '../controllers/video_media_controller.dart';
import '../controllers/audio_media_controller.dart';
import 'audio_waveform_visualizer.dart';

/// Reusable media player widget that adapts to video or audio
class MediaPlayerWidget extends StatelessWidget {
  final MediaController mediaController;
  final bool isPlaying;
  final VoidCallback onTogglePlayPause;
  final double? aspectRatio;
  final Color backgroundColor;
  final double startMs;
  final double endMs;
  final double currentPositionMs;
  final double? touchedPositionMs;
  final Function(double)? onWaveformTouched;
  final double audioZoomLevel;
  final double? audioTargetScrollOffsetMs;
  final Function(double)? onAudioScrollChanged;
  final Function(double)? onAudioZoomChanged;

  const MediaPlayerWidget({
    Key? key,
    required this.mediaController,
    required this.isPlaying,
    required this.onTogglePlayPause,
    this.aspectRatio,
    required this.backgroundColor,
    this.startMs = 0,
    this.endMs = 0,
    this.currentPositionMs = 0,
    this.touchedPositionMs,
    this.onWaveformTouched,
    this.audioZoomLevel = 1.0,
    this.audioTargetScrollOffsetMs,
    this.onAudioScrollChanged,
    this.onAudioZoomChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!mediaController.isInitialized) {
      return Container(
        color: backgroundColor,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Handle video display
    if (mediaController.mediaType == MediaType.video) {
      return _buildVideoPlayer();
    }

    // Handle audio display
    if (mediaController.mediaType == MediaType.audio) {
      return _buildAudioPlayer();
    }

    // Unknown media type
    return Container(
      color: backgroundColor,
      child: const Center(
        child: Text(
          'Unknown media type',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    final videoController = mediaController as VideoMediaController;
    final controller = videoController.videoController;
    final samples = videoController.fullAudioSamples;
    final durationMs = videoController.durationMs.toDouble();

    if (controller == null) {
      return Container(
        color: backgroundColor,
        child: const Center(
          child: Text(
            'Video player error',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    // Video editing UI: Video player on top, waveform below
    return Column(
      children: [
        // Top: Video player (no play/pause overlay)
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: aspectRatio ?? videoController.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
          ),
        ),

        // Bottom: Audio waveform visualization (reused component)
        Expanded(
          flex: 1,
          child: AudioWaveformVisualizer(
            samples: samples,
            isWaveformReady: videoController.isWaveformReady,
            waveformExtractionFailed: videoController.waveformExtractionFailed,
            startMs: startMs,
            endMs: endMs > 0 ? endMs : durationMs,
            durationMs: durationMs,
            currentPositionMs: currentPositionMs,
            touchedPositionMs: touchedPositionMs,
            isPlaying: isPlaying,
            onTogglePlayPause: onTogglePlayPause,
            onWaveformTouched: onWaveformTouched,
            zoomLevel: audioZoomLevel,
            targetScrollOffsetMs: audioTargetScrollOffsetMs,
            onScrollChanged: onAudioScrollChanged,
            onZoomChanged: onAudioZoomChanged,
            backgroundColor: backgroundColor,
          ),
        ),
      ],
    );
  }

  Widget _buildAudioPlayer() {
    final audioController = mediaController as AudioMediaController;
    final samples = audioController.fullAudioSamples;
    final durationMs = audioController.durationMs.toDouble();

    return AudioWaveformVisualizer(
      samples: samples,
      isWaveformReady: audioController.isWaveformReady,
      waveformExtractionFailed: audioController.waveformExtractionFailed,
      startMs: startMs,
      endMs: endMs > 0 ? endMs : durationMs,
      durationMs: durationMs,
      currentPositionMs: currentPositionMs,
      touchedPositionMs: touchedPositionMs,
      isPlaying: isPlaying,
      onTogglePlayPause: onTogglePlayPause,
      onWaveformTouched: onWaveformTouched,
      zoomLevel: audioZoomLevel,
      targetScrollOffsetMs: audioTargetScrollOffsetMs,
      onScrollChanged: onAudioScrollChanged,
      onZoomChanged: onAudioZoomChanged,
      backgroundColor: backgroundColor,
    );
  }
}
