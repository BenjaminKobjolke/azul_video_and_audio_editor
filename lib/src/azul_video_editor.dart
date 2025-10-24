import 'package:flutter/material.dart';
import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'models/azul_editor_options.dart';
import 'models/media_controller.dart';
import 'controllers/video_media_controller.dart';
import 'generators/visual_data_generator.dart';
import 'generators/video_thumbnail_generator.dart';
import 'widgets/media_timeline.dart';
import 'widgets/media_player_widget.dart';

/// Main class for the Azul Video Editor
class AzulVideoEditor extends StatefulWidget {
  /// Options for configuring the editor
  final AzulEditorOptions options;

  /// Callback that returns the path of the edited video
  final Function(String path)? onVideoSaved;

  /// File to edit (if null, the editor will prompt to select a file)
  final File? initialVideoFile;

  /// Whether to automatically pick a video when opening the editor
  final bool autoPickVideo;

  const AzulVideoEditor({
    Key? key,
    this.options = const AzulEditorOptions(),
    this.onVideoSaved,
    this.initialVideoFile,
    this.autoPickVideo = false,
  }) : super(key: key);

  /// Static method to open the editor as a page and return the edited video path
  static Future<String?> openEditor(
    BuildContext context, {
    AzulEditorOptions options = const AzulEditorOptions(),
    File? initialVideoFile,
    bool autoPickVideo = true,
  }) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder:
            (context) => AzulVideoEditor(
              options: options,
              initialVideoFile: initialVideoFile,
              autoPickVideo: autoPickVideo,
            ),
      ),
    );

    return result;
  }

  @override
  _AzulVideoEditorState createState() => _AzulVideoEditorState();
}

class _AzulVideoEditorState extends State<AzulVideoEditor> {
  File? mediaFile;
  MediaType? mediaType;
  bool isPlaying = false;
  String _status = 'No media selected';

  MediaController? mediaController;
  VisualDataGenerator? visualGenerator;
  bool isInitialized = false;

  double startMs = 0;
  late double endMs;
  double videoDurationMs = 0;

  List<Uint8List>? thumbnailsData;
  bool generatingThumbnails = false;

  final ScrollController _timelineScrollController = ScrollController();
  double _viewportWidth = 0;
  double _thumbnailTotalWidth = 0;
  double _scrollPosition = 0;
  Timer? _scrollEndTimer;

  double _currentPlaybackPositionMs = 0;

  @override
  void initState() {
    super.initState();
    endMs = widget.options.maxDurationMs.toDouble();

    // Use the initial video file if provided
    if (widget.initialVideoFile != null) {
      mediaFile = widget.initialVideoFile;
      _initializeMediaPlayer();
    } else if (widget.autoPickVideo) {
      // Auto pick media on init if requested
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickMedia();
      });
    }
  }

  @override
  void dispose() {
    mediaController?.dispose();
    _timelineScrollController.dispose();
    _scrollEndTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    // Support both video and audio files
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        // Video formats
        'mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv', 'webm', 'm4v', 'mpeg', 'mpg', '3gp',
        // Audio formats
        'mp3', 'wav', 'aac', 'flac', 'ogg', 'wma', 'm4a', 'opus', 'aiff', 'alac',
      ],
      allowCompression: false,
    );

    if (result != null &&
        result.files.isNotEmpty &&
        result.files.single.path != null) {
      final selectedFile = File(result.files.single.path!);
      final detectedMediaType = MediaTypeDetector.detectFromFile(selectedFile);

      setState(() {
        mediaFile = selectedFile;
        mediaType = detectedMediaType;
        _status = detectedMediaType == MediaType.video
            ? 'Video selected'
            : detectedMediaType == MediaType.audio
                ? 'Audio selected'
                : 'Media selected';
        isPlaying = false;
        thumbnailsData = null;
        isInitialized = false;
      });

      // Clean up previous controller
      if (mediaController != null) {
        mediaController!.removeListener(_updatePlaybackPosition);
        mediaController!.removeListener(_checkMediaEnd);
        await mediaController!.dispose();
        mediaController = null;
      }

      await _initializeMediaPlayer();
    } else {
      // If no media was selected and we're in autoPickVideo mode,
      // we should pop back since there's nothing to edit
      if (widget.autoPickVideo && mediaFile == null) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  Future<void> _initializeMediaPlayer() async {
    if (mediaFile == null || mediaType == null) return;

    try {
      // Create appropriate media controller based on media type
      if (mediaType == MediaType.video) {
        mediaController = VideoMediaController();
        visualGenerator = VideoThumbnailGenerator();
      } else if (mediaType == MediaType.audio) {
        // Audio support coming soon
        setState(() {
          _status = 'Audio editing support coming soon!';
        });
        return;
      } else {
        setState(() {
          _status = 'Unsupported media type';
        });
        return;
      }

      await mediaController!.initialize(mediaFile!);

      videoDurationMs = mediaController!.durationMs.toDouble();
      endMs = math.min(
        widget.options.maxDurationMs.toDouble(),
        videoDurationMs,
      );

      mediaController!.addListener(_updatePlaybackPosition);
      mediaController!.addListener(_checkMediaEnd);

      _timelineScrollController.addListener(_onTimelineScroll);

      setState(() {
        isInitialized = true;
        _currentPlaybackPositionMs = 0;
      });

      await _generateVisualData();
    } catch (e) {
      setState(() {
        _status = 'Error initializing media: $e';
      });
    }
  }

  void _updatePlaybackPosition() {
    if (mediaController != null &&
        mediaController!.isInitialized &&
        mounted) {
      setState(() {
        _currentPlaybackPositionMs = mediaController!.currentPositionMs.toDouble();
      });
    }
  }

  void _checkMediaEnd() {
    if (mediaController != null &&
        mediaController!.isInitialized &&
        mediaController!.isPlaying &&
        _currentPlaybackPositionMs >= endMs) {
      setState(() {
        isPlaying = false;
        mediaController!.pause();
      });
      _seekToStartMarker();
    }
  }

  void _onTimelineScroll() {
    _scrollEndTimer?.cancel();
    setState(() {
      _scrollPosition = _timelineScrollController.offset;
    });
    _scrollEndTimer = Timer(const Duration(milliseconds: 200), _onScrollEnd);
  }

  void _onScrollEnd() {
    if (mediaController == null ||
        !mediaController!.isInitialized ||
        _viewportWidth <= 0 ||
        _thumbnailTotalWidth <= 0) {
      return;
    }

    // Calculate the scroll ratio
    double videoPositionRatio =
        _scrollPosition /
        math.max(1.0, (_thumbnailTotalWidth - _viewportWidth));

    // Calculate the new seek position
    double seekPositionMs =
        videoPositionRatio * (videoDurationMs - (endMs - startMs));

    // Adjust segment position while maintaining segment length
    double segmentLength = endMs - startMs;

    setState(() {
      startMs = math.max(0, seekPositionMs);
      endMs = math.min(startMs + segmentLength, videoDurationMs);

      // Seek media to new start position
      mediaController?.seekTo(startMs.toInt());
    });
  }

  void _seekToStartMarker() {
    if (mediaController != null &&
        mediaController!.isInitialized) {
      mediaController!.seekTo(startMs.toInt());
      setState(() {
        _currentPlaybackPositionMs = startMs;
      });
    }
  }

  void _updateSegmentPosition(DragUpdateDetails details) {
    if (thumbnailsData == null || _thumbnailTotalWidth <= 0) return;

    // Calculate the drag delta in milliseconds
    double dragDeltaMs =
        (details.delta.dx / _thumbnailTotalWidth) * videoDurationMs;

    setState(() {
      // Move both start and end markers together
      double newStartMs = startMs + dragDeltaMs;
      double newEndMs = endMs + dragDeltaMs;

      // Ensure segment stays within video duration
      if (newStartMs >= 0 && newEndMs <= videoDurationMs) {
        startMs = newStartMs;
        endMs = newEndMs;

        // Seek video to new start position
        _seekToStartMarker();
      }
    });
  }

  void _handleStartMarkerDrag(DragUpdateDetails details) {
    if (_thumbnailTotalWidth <= 0) return;

    // Calculate new start position
    double dragDeltaMs =
        (details.delta.dx / _thumbnailTotalWidth) * videoDurationMs;
    double newStartMs = startMs + dragDeltaMs;

    // Ensure start marker doesn't go below 0 or cross end marker
    if (newStartMs >= 0 && newStartMs < endMs) {
      setState(() {
        startMs = newStartMs;
        _seekToStartMarker();
      });
    }
  }

  void _handleEndMarkerDrag(DragUpdateDetails details) {
    if (_thumbnailTotalWidth <= 0) return;

    // Calculate new end position
    double dragDeltaMs =
        (details.delta.dx / _thumbnailTotalWidth) * videoDurationMs;
    double newEndMs = endMs + dragDeltaMs;

    // Ensure end marker doesn't exceed video duration or go below start marker
    if (newEndMs <= videoDurationMs &&
        newEndMs > startMs &&
        newEndMs - startMs <= widget.options.maxDurationMs) {
      setState(() {
        endMs = newEndMs;
      });
    }
  }

  Future<void> _generateVisualData() async {
    if (mediaFile == null || visualGenerator == null) return;

    setState(() {
      _status = mediaType == MediaType.video
          ? 'Generating thumbnails...'
          : 'Generating waveforms...';
      generatingThumbnails = true;
    });

    try {
      final visualData = await visualGenerator!.generate(
        file: mediaFile!,
        durationMs: videoDurationMs,
        thumbnailSize: widget.options.thumbnailSize,
        onStatusUpdate: (status) {
          if (mounted) {
            setState(() {
              _status = status;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          thumbnailsData = visualData;
          _thumbnailTotalWidth = visualData.length * visualGenerator!.segmentWidth;
          generatingThumbnails = false;
          _status = 'Ready to edit';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          generatingThumbnails = false;
          _status = 'Error generating visual data: $e';
        });
      }
    }
  }

  Future<void> _saveMedia() async {
    if (mediaFile == null) return;

    // Currently only video export is supported
    if (mediaType != MediaType.video) {
      setState(() {
        _status = 'Audio export not yet supported';
      });
      if (widget.options.showSavedSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio export support coming soon!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _status = 'Processing video...';
    });

    try {
      final editor = VideoEditorBuilder(
        videoPath: mediaFile!.path,
      ).trim(startTimeMs: startMs.toInt(), endTimeMs: endMs.toInt());

      final result = await editor.export();

      if (!mounted) return;

      setState(() {
        _status = 'Video saved to Local Storage';
      });

      // Show snackbar if enabled
      if (widget.options.showSavedSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video segment saved successfully'),
            backgroundColor: widget.options.primaryColor,
          ),
        );
      }

      // Return the path via the callback if provided
      if (widget.onVideoSaved != null) {
        if (result != null) {
          widget.onVideoSaved!(result);
        }
      }

      // Return the path for the static method
      Navigator.of(context).pop<String>(result);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _status = 'Error saving media: $e';
      });

      if (widget.options.showSavedSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save media: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _togglePlayPause() {
    if (mediaController == null ||
        !mediaController!.isInitialized) {
      return;
    }

    setState(() {
      isPlaying = !isPlaying;
      if (isPlaying) {
        // If current position is at end, seek to start before playing
        if (_currentPlaybackPositionMs >= endMs) {
          _seekToStartMarker();
        }
        mediaController!.play();
      } else {
        mediaController!.pause();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.options.backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.options.title,
          style:
              widget.options.titleStyle ??
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
        ),
        backgroundColor: widget.options.primaryColor,
        elevation: 0,
        leading:
            widget.options.leadingWidget ??
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(
                Icons.arrow_back_ios_new,
                size: 20,
                color: Colors.white,
              ),
            ),
        actions: [
          if (mediaFile != null && isInitialized)
            widget.options.saveButtonWidget ??
                IconButton(
                  icon: const Icon(Icons.save, color: Colors.white),
                  onPressed: _saveMedia,
                  tooltip: widget.options.saveButtonText,
                ),
        ],
      ),
      body: mediaFile == null ? _buildEmptyState() : _buildMediaEditorContent(),
      floatingActionButton:
          mediaFile == null && !widget.autoPickVideo
              ? FloatingActionButton.extended(
                onPressed: _pickMedia,
                icon: const Icon(Icons.video_library, color: Colors.white),
                label: const Text(
                  'Select Media',
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: widget.options.primaryColor,
              )
              : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library,
            size: 100,
            color: widget.options.primaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Media Selected',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          widget.autoPickVideo
              ? const Text(
                'Opening file picker...',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              )
              : const Text(
                'Tap "Select Media" to get started',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
        ],
      ),
    );
  }

  Widget _buildMediaEditorContent() {
    return Column(
      children: [
        // Media Player (Video or Audio)
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: widget.options.videoBackgroundColor,
              borderRadius: BorderRadius.circular(widget.options.videoRadius),
            ),
            margin: EdgeInsets.all(widget.options.videoMargin),
            child: mediaController != null
                ? MediaPlayerWidget(
                    mediaController: mediaController!,
                    isPlaying: isPlaying,
                    onTogglePlayPause: _togglePlayPause,
                    aspectRatio: widget.options.aspectRatio,
                    backgroundColor: widget.options.videoBackgroundColor,
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
        ),

        // Duration Information
        if (widget.options.showDuration) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Start: ${(startMs / 1000).toStringAsFixed(1)}s',
                  style: const TextStyle(color: Colors.white),
                ),
                Text(
                  'Duration: ${((endMs - startMs) / 1000).toStringAsFixed(1)}s',
                  style: const TextStyle(color: Colors.white70),
                ),
                Text(
                  'End: ${(endMs / 1000).toStringAsFixed(1)}s',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
        ],

        // Timeline with Thumbnails/Waveforms and Selection Markers
        MediaTimeline(
          visualData: thumbnailsData,
          isGenerating: generatingThumbnails,
          generatingText: widget.options.thumbnailGenerateText,
          videoDurationMs: videoDurationMs,
          startMs: startMs,
          endMs: endMs,
          currentPlaybackPositionMs: _currentPlaybackPositionMs,
          scrollController: _timelineScrollController,
          scrollPosition: _scrollPosition,
          thumbnailTotalWidth: _thumbnailTotalWidth,
          slideAreaColor: widget.options.slideAreaColor,
          onSegmentDrag: _updateSegmentPosition,
          onStartMarkerDrag: _handleStartMarkerDrag,
          onEndMarkerDrag: _handleEndMarkerDrag,
          margin: widget.options.timelineMargin,
        ),

        // Status Display
        if (_status.startsWith('Error'))
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(_status, style: TextStyle(color: Colors.red)),
          ),
      ],
    );
  }
}
