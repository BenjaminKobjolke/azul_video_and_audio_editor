import 'package:flutter/material.dart';
import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'models/azul_editor_options.dart';

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
  File? videoFile;
  bool isPlaying = false;
  String _status = 'No video selected';

  VideoPlayerController? videoPlayerController;
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
      videoFile = widget.initialVideoFile;
      _initializeVideoPlayer();
    } else if (widget.autoPickVideo) {
      // Auto pick video on init if requested
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickVideo();
      });
    }
  }

  @override
  void dispose() {
    videoPlayerController?.dispose();
    _timelineScrollController.dispose();
    _scrollEndTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowCompression: false,
    );

    if (result != null &&
        result.files.isNotEmpty &&
        result.files.single.path != null) {
      setState(() {
        videoFile = File(result.files.single.path!);
        _status = 'Video selected';
        isPlaying = false;
        thumbnailsData = null;
        isInitialized = false;
      });

      // Clean up previous controller
      if (videoPlayerController != null) {
        videoPlayerController!.removeListener(_updatePlaybackPosition);
        videoPlayerController!.removeListener(_checkVideoEnd);
        await videoPlayerController!.dispose();
        videoPlayerController = null;
      }

      await _initializeVideoPlayer();
    } else {
      // If no video was selected and we're in autoPickVideo mode,
      // we should pop back since there's nothing to edit
      if (widget.autoPickVideo && videoFile == null) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (videoFile == null) return;

    try {
      videoPlayerController = VideoPlayerController.file(videoFile!);
      await videoPlayerController!.initialize();

      videoDurationMs =
          videoPlayerController!.value.duration.inMilliseconds.toDouble();
      endMs = math.min(
        widget.options.maxDurationMs.toDouble(),
        videoDurationMs,
      );

      videoPlayerController!.addListener(_updatePlaybackPosition);
      videoPlayerController!.addListener(_checkVideoEnd);

      _timelineScrollController.addListener(_onTimelineScroll);

      setState(() {
        isInitialized = true;
        _currentPlaybackPositionMs = 0;
      });

      await _generateInMemoryThumbnails();
    } catch (e) {
      setState(() {
        _status = 'Error initializing video: $e';
      });
    }
  }

  void _updatePlaybackPosition() {
    if (videoPlayerController != null &&
        videoPlayerController!.value.isInitialized &&
        mounted) {
      setState(() {
        _currentPlaybackPositionMs =
            videoPlayerController!.value.position.inMilliseconds.toDouble();
      });
    }
  }

  void _checkVideoEnd() {
    if (videoPlayerController != null &&
        videoPlayerController!.value.isInitialized &&
        videoPlayerController!.value.isPlaying &&
        _currentPlaybackPositionMs >= endMs) {
      setState(() {
        isPlaying = false;
        videoPlayerController!.pause();
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
    if (videoPlayerController == null ||
        !videoPlayerController!.value.isInitialized ||
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

      // Seek video to new start position
      videoPlayerController?.seekTo(Duration(milliseconds: startMs.toInt()));
    });
  }

  void _seekToStartMarker() {
    if (videoPlayerController != null &&
        videoPlayerController!.value.isInitialized) {
      videoPlayerController!.seekTo(Duration(milliseconds: startMs.toInt()));
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

  Future<void> _generateInMemoryThumbnails() async {
    if (videoFile == null) return;

    setState(() {
      _status = 'Generating thumbnails...';
      generatingThumbnails = true;
    });

    try {
      // Optimize thumbnail count based on video duration
      // Use fewer thumbnails for shorter videos to save memory
      final int thumbnailCount = math.min(
        80,
        math.max(widget.options.thumbnailSize, (videoDurationMs / 500).round()),
      );
      List<Uint8List> thumbnails = [];

      for (int i = 0; i < thumbnailCount; i++) {
        final positionMs = (videoDurationMs / thumbnailCount) * i;

        final thumbnail = await VideoThumbnail.thumbnailData(
          video: videoFile!.path,
          imageFormat: ImageFormat.JPEG,
          timeMs: positionMs.toInt(),
          quality: 10, // Low quality to save memory
          maxWidth: 100, // Reduce width to save memory
          maxHeight: 80,
        );

        if (thumbnail != null) {
          thumbnails.add(thumbnail);
        }

        // Check if widget is still mounted before continuing
        if (!mounted) return;
      }

      if (mounted) {
        setState(() {
          thumbnailsData = thumbnails;
          _thumbnailTotalWidth = thumbnails.length * 30.0;
          generatingThumbnails = false;
          _status = 'Ready to edit';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          generatingThumbnails = false;
          _status = 'Error generating thumbnails: $e';
        });
      }
    }
  }

  Future<void> _saveVideo() async {
    if (videoFile == null) return;

    setState(() {
      _status = 'Processing video...';
    });

    try {
      final editor = VideoEditorBuilder(
        videoPath: videoFile!.path,
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
        _status = 'Error saving video: $e';
      });

      if (widget.options.showSavedSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save video segment: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _togglePlayPause() {
    if (videoPlayerController == null ||
        !videoPlayerController!.value.isInitialized) {
      return;
    }

    setState(() {
      isPlaying = !isPlaying;
      if (isPlaying) {
        // If current position is at end, seek to start before playing
        if (_currentPlaybackPositionMs >= endMs) {
          _seekToStartMarker();
        }
        videoPlayerController!.play();
      } else {
        videoPlayerController!.pause();
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
          if (videoFile != null && isInitialized)
            widget.options.saveButtonWidget ??
                IconButton(
                  icon: const Icon(Icons.save, color: Colors.white),
                  onPressed: _saveVideo,
                  tooltip: widget.options.saveButtonText,
                ),
        ],
      ),
      body: videoFile == null ? _buildEmptyState() : _buildVideoEditorContent(),
      floatingActionButton:
          videoFile == null && !widget.autoPickVideo
              ? FloatingActionButton.extended(
                onPressed: _pickVideo,
                icon: const Icon(Icons.video_library, color: Colors.white),
                label: const Text(
                  'Select Video',
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: widget.options.primaryColor,
              )
              // : videoFile == null
              // ? FloatingActionButton(
              //   onPressed: _pickVideo,
              //   backgroundColor: widget.options.primaryColor,
              //   child: const Icon(Icons.change_circle, color: Colors.white),
              // )
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
            'No Video Selected',
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
                'Tap "Select Video" to get started',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
        ],
      ),
    );
  }

  Widget _buildVideoEditorContent() {
    return Column(
      children: [
        // Video Player
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: widget.options.videoBackgroundColor,
              borderRadius: BorderRadius.circular(widget.options.videoRadius),
            ),
            margin: EdgeInsets.all(widget.options.videoMargin),
            child:
                isInitialized
                    ? Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio:
                              widget.options.aspectRatio ??
                              videoPlayerController!.value.aspectRatio,
                          child: VideoPlayer(videoPlayerController!),
                        ),
                        GestureDetector(
                          onTap: _togglePlayPause,
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

        // Timeline with Thumbnails and Selection Markers
        Container(
          height: 100,
          margin: widget.options.timelineMargin,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _viewportWidth = constraints.maxWidth;

              return NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification scrollInfo) {
                  if (scrollInfo is ScrollUpdateNotification) {
                    // Recalculate positions when scrolling
                    setState(() {
                      _scrollPosition = _timelineScrollController.offset;
                    });
                  }
                  return true;
                },
                child: Stack(
                  clipBehavior: Clip.none, // Allow overflow
                  children: [
                    // Scrollable Thumbnails
                    SingleChildScrollView(
                      controller: _timelineScrollController,
                      scrollDirection: Axis.horizontal,
                      child:
                          thumbnailsData != null
                              ? SizedBox(
                                width: _thumbnailTotalWidth,
                                height: 80,
                                child: Row(
                                  children: List.generate(
                                    thumbnailsData!.length,
                                    (index) => Container(
                                      width: 30,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        image: DecorationImage(
                                          image: MemoryImage(
                                            thumbnailsData![index],
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              : generatingThumbnails
                              ? Center(
                                child: Text(
                                  widget.options.thumbnailGenerateText,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              )
                              : Container(),
                    ),

                    // Show loading indicator while generating thumbnails
                    if (generatingThumbnails)
                      const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),

                    // Only show the segment UI if thumbnails are ready
                    if (thumbnailsData != null) ...[
                      // Draggable Segment with Adjusted Positioning
                      Positioned(
                        left:
                            ((startMs / videoDurationMs) *
                                _thumbnailTotalWidth) -
                            _scrollPosition,
                        child: GestureDetector(
                          onHorizontalDragUpdate: _updateSegmentPosition,
                          child: Container(
                            width:
                                ((endMs - startMs) / videoDurationMs) *
                                _thumbnailTotalWidth,
                            height: 80,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: widget.options.slideAreaColor,
                                width: 2,
                              ),
                              color: Colors.yellow.withOpacity(0.3),
                            ),
                          ),
                        ),
                      ),

                      // Start Marker [
                      Positioned(
                        left:
                            ((startMs / videoDurationMs) *
                                    _thumbnailTotalWidth -
                                10) -
                            _scrollPosition,
                        child: GestureDetector(
                          onHorizontalDragUpdate: _handleStartMarkerDrag,
                          child: Container(
                            width: 20,
                            height: 80,
                            color: Colors.grey.shade900,
                            child: const Center(
                              child: Text(
                                '[',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // End Marker ]
                      Positioned(
                        left:
                            ((endMs / videoDurationMs) * _thumbnailTotalWidth) -
                            _scrollPosition,
                        child: GestureDetector(
                          onHorizontalDragUpdate: _handleEndMarkerDrag,
                          child: Container(
                            width: 20,
                            height: 80,
                            color: Colors.grey.shade900,
                            child: const Center(
                              child: Text(
                                ']',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Playback Position Indicator
                      Positioned(
                        left:
                            ((_currentPlaybackPositionMs / videoDurationMs) *
                                _thumbnailTotalWidth) -
                            _scrollPosition,
                        child: Container(
                          width: 2,
                          height: 80,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
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
