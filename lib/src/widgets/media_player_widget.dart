import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/media_controller.dart';
import '../controllers/video_media_controller.dart';

/// Reusable media player widget that adapts to video or audio
class MediaPlayerWidget extends StatelessWidget {
  final MediaController mediaController;
  final bool isPlaying;
  final VoidCallback onTogglePlayPause;
  final double? aspectRatio;
  final Color backgroundColor;

  const MediaPlayerWidget({
    Key? key,
    required this.mediaController,
    required this.isPlaying,
    required this.onTogglePlayPause,
    this.aspectRatio,
    required this.backgroundColor,
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

    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: aspectRatio ?? videoController.aspectRatio,
          child: VideoPlayer(controller),
        ),
        GestureDetector(
          onTap: onTogglePlayPause,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(16),
            child: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 50,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioPlayer() {
    // TODO: Implement audio player UI
    // For now, show a placeholder with play/pause control
    return Container(
      color: backgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.audiotrack,
              size: 100,
              color: Colors.white54,
            ),
            const SizedBox(height: 20),
            const Text(
              'Audio Player',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Audio playback UI coming soon',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 30),
            GestureDetector(
              onTap: onTogglePlayPause,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(16),
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
