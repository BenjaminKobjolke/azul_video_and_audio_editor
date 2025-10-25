import 'package:flutter/material.dart';
import 'package:easy_video_editor/easy_video_editor.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'models/azul_editor_options.dart';
import 'models/media_controller.dart';
import 'controllers/video_media_controller.dart';
import 'controllers/audio_media_controller.dart';
import 'generators/visual_data_generator.dart';
import 'generators/video_thumbnail_generator.dart';
import 'generators/audio_waveform_generator.dart';
import 'widgets/media_timeline.dart';
import 'widgets/media_player_widget.dart';
import 'services/metadata_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';

/// Main class for the Azul Video Editor
class AzulVideoEditor extends StatefulWidget {
  /// Options for configuring the editor
  final AzulEditorOptions options;

  /// Callback that returns the path of the edited video
  final Function(String path)? onVideoSaved;

  /// File to edit (required)
  final File initialVideoFile;

  const AzulVideoEditor({
    Key? key,
    this.options = const AzulEditorOptions(),
    this.onVideoSaved,
    required this.initialVideoFile,
  }) : super(key: key);

  /// Static method to open the editor as a page and return the edited video path and logs
  static Future<Map<String, String>?> openEditor(
    BuildContext context,
    File file, {
    AzulEditorOptions options = const AzulEditorOptions(),
  }) async {
    final result = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        builder:
            (context) => AzulVideoEditor(
              options: options,
              initialVideoFile: file,
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
  late String _status;
  bool _isSaving = false;

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
  Timer? _playbackPositionTimer; // Timer to update playback position

  double _currentPlaybackPositionMs = 0;
  double? _touchedPositionMs; // Position where user tapped on waveform
  double _audioZoomLevel = 1.0; // Zoom level for audio waveform
  double? _audioTargetScrollOffsetMs; // Target scroll position for audio waveform (set by Zoom Selection/All)
  bool _isLoopingSelection = false; // Whether selection is playing in loop mode
  bool _bypassEndMarkerCheck = false; // Bypass end marker check when playing from position beyond end marker

  // Helper to get effective timeline width (with fallback before thumbnails load)
  double get _effectiveTimelineWidth {
    return _thumbnailTotalWidth > 0 ? _thumbnailTotalWidth : 800.0;
  }

  @override
  void initState() {
    super.initState();
    _status = widget.options.strings.statusNoMediaSelected;
    endMs = widget.options.maxDurationMs.toDouble();

    // Initialize with the provided file
    mediaFile = widget.initialVideoFile;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMediaPlayer();
    });
  }

  @override
  void dispose() {
    mediaController?.dispose();
    _timelineScrollController.dispose();
    _scrollEndTimer?.cancel();
    _playbackPositionTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeMediaPlayer() async {
    if (mediaFile == null) return;

    // Detect media type from file
    mediaType = MediaTypeDetector.detectFromFile(mediaFile!);

    setState(() {
      _status = mediaType == MediaType.video
          ? widget.options.strings.statusVideoSelected
          : mediaType == MediaType.audio
              ? widget.options.strings.statusAudioSelected
              : widget.options.strings.statusMediaSelected;
    });

    try {
      // Create appropriate media controller based on media type
      if (mediaType == MediaType.video) {
        mediaController = VideoMediaController();
        visualGenerator = VideoThumbnailGenerator();
      } else if (mediaType == MediaType.audio) {
        // Initialize audio controller and waveform generator
        mediaController = AudioMediaController();
        visualGenerator = AudioWaveformGenerator();
      } else {
        setState(() {
          _status = widget.options.strings.statusUnsupportedMedia;
        });
        return;
      }

      await mediaController!.initialize(mediaFile!);

      videoDurationMs = mediaController!.durationMs.toDouble();

      // Start with entire file selected
      startMs = 0;
      endMs = videoDurationMs;

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
        _status = '${widget.options.strings.statusErrorInitializing} $e';
      });
    }
  }

  void _startPlaybackPositionTimer() {
    _playbackPositionTimer?.cancel();
    _playbackPositionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updatePlaybackPosition();
      _checkMediaEnd();
    });
  }

  void _stopPlaybackPositionTimer() {
    _playbackPositionTimer?.cancel();
    _playbackPositionTimer = null;
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
        mediaController!.isPlaying) {

      // Use end marker or file duration depending on bypass flag
      final effectiveEndMs = _bypassEndMarkerCheck ? videoDurationMs : endMs;

      if (_currentPlaybackPositionMs >= effectiveEndMs) {
        if (_isLoopingSelection) {
          // Loop back to start and continue playing
          mediaController!.seekTo(startMs.toInt());
          setState(() {
            _currentPlaybackPositionMs = startMs;
          });
        } else {
          // Stop playback and seek to start
          setState(() {
            isPlaying = false;
            _bypassEndMarkerCheck = false; // Reset bypass flag
            mediaController!.pause();
          });
          _stopPlaybackPositionTimer();
          _seekToStartMarker();
        }
      }
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
    // Allow dragging even before thumbnails load
    // Calculate the drag delta in milliseconds
    double dragDeltaMs =
        (details.delta.dx / _effectiveTimelineWidth) * videoDurationMs;

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
    // Allow dragging even before thumbnails load
    // Calculate new start position
    double dragDeltaMs =
        (details.delta.dx / _effectiveTimelineWidth) * videoDurationMs;
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
    // Allow dragging even before thumbnails load
    // Calculate new end position
    double dragDeltaMs =
        (details.delta.dx / _effectiveTimelineWidth) * videoDurationMs;
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

  // Timeline control button methods
  void _moveStartToBeginning() {
    setState(() {
      startMs = 0;
    });
  }

  void _moveEndToFinish() {
    setState(() {
      endMs = videoDurationMs;
    });
  }

  void _onWaveformTouched(double positionMs) {
    setState(() {
      _touchedPositionMs = positionMs.clamp(0.0, videoDurationMs);
    });
  }

  void _setStartToTouchedPosition() {
    if (_touchedPositionMs != null && _touchedPositionMs! < endMs) {
      setState(() {
        startMs = _touchedPositionMs!;
      });
    }
  }

  void _setEndToTouchedPosition() {
    if (_touchedPositionMs != null && _touchedPositionMs! > startMs) {
      setState(() {
        endMs = _touchedPositionMs!;
      });
    }
  }

  void _setZoomDuration(double targetDurationMs) {
    if (videoDurationMs <= 0) return;

    setState(() {
      // For audio: zoom the waveform view
      if (mediaType == MediaType.audio) {
        // Calculate zoom level based on target duration
        // Full file = 1.0x zoom, smaller durations = higher zoom
        if (targetDurationMs >= videoDurationMs) {
          _audioZoomLevel = 1.0;
        } else {
          _audioZoomLevel = (videoDurationMs / targetDurationMs).clamp(1.0, 10.0);
        }
      } else {
        // For video: set selection range (existing behavior)
        if (targetDurationMs >= videoDurationMs) {
          startMs = 0;
          endMs = videoDurationMs;
        } else {
          // Center the selection around current midpoint
          final midpoint = (startMs + endMs) / 2;
          double newStartMs = midpoint - (targetDurationMs / 2);
          double newEndMs = midpoint + (targetDurationMs / 2);

          // Adjust if we go out of bounds
          if (newStartMs < 0) {
            newStartMs = 0;
            newEndMs = math.min(targetDurationMs, videoDurationMs);
          } else if (newEndMs > videoDurationMs) {
            endMs = videoDurationMs;
            newStartMs = math.max(0, videoDurationMs - targetDurationMs);
          }

          startMs = newStartMs;
          endMs = newEndMs;
        }
        _seekToStartMarker();
      }
    });
  }

  void _zoomToSelection() {
    if (videoDurationMs <= 0 || endMs <= startMs) return;
    setState(() {
      // Zoom to fit the selected region
      final selectionDuration = endMs - startMs;
      _audioZoomLevel = (videoDurationMs / selectionDuration).clamp(1.0, 10.0);

      // Calculate scroll offset to show the selected region
      // Center the selection in the viewport
      final selectionMidpoint = (startMs + endMs) / 2;
      final visibleDuration = videoDurationMs / _audioZoomLevel;
      final targetScrollOffset = selectionMidpoint - (visibleDuration / 2);

      // Clamp to valid range
      final maxScrollOffset = videoDurationMs - visibleDuration;
      _audioTargetScrollOffsetMs = targetScrollOffset.clamp(0.0, math.max(0, maxScrollOffset));
    });
  }

  void _zoomToAll() {
    setState(() {
      _audioZoomLevel = 1.0; // Show entire audio file
      _audioTargetScrollOffsetMs = 0.0; // Reset scroll to beginning
    });
  }

  void _onAudioZoomChanged(double newZoom) {
    setState(() {
      _audioZoomLevel = newZoom;
    });
  }

  void _setStartMarkerToBeginning() {
    setState(() {
      startMs = 0;
    });
  }

  void _setEndMarkerToEnd() {
    setState(() {
      endMs = videoDurationMs;
    });
  }

  Future<void> _generateVisualData() async {
    if (mediaFile == null || visualGenerator == null) return;

    setState(() {
      _status = mediaType == MediaType.video
          ? widget.options.strings.statusGeneratingThumbnails
          : widget.options.strings.statusGeneratingWaveforms;
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
          _status = widget.options.strings.statusReadyToEdit;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          generatingThumbnails = false;
          _status = '${widget.options.strings.statusErrorGenerating} $e';
        });
      }
    }
  }

  Future<void> _saveMedia() async {
    if (mediaFile == null) return;

    // Pause audio playback before saving
    if (mediaController?.isPlaying == true) {
      await mediaController?.pause();
      setState(() {
        isPlaying = false;
      });
    }

    // Get file extension
    final extension = path.extension(mediaFile!.path);

    // Get appropriate save directory
    // On Android, use external storage directory (Music for audio, Movies for video, Downloads as fallback)
    // On iOS, use documents directory
    Directory? saveDirectory;
    if (Platform.isAndroid) {
      // Try to get external storage directory, fall back to app directory
      saveDirectory = await getExternalStorageDirectory();
      if (saveDirectory != null) {
        // Navigate to a more user-accessible location
        final pathSegments = saveDirectory.path.split('/');
        final baseIndex = pathSegments.indexOf('Android');
        if (baseIndex > 0) {
          final basePath = pathSegments.sublist(0, baseIndex).join('/');

          if (mediaType == MediaType.audio) {
            // For audio files, try Music directory first
            final musicDir = Directory('$basePath/Music');
            if (await musicDir.exists()) {
              saveDirectory = musicDir;
            } else {
              // Fall back to Downloads
              final downloadsDir = Directory('$basePath/Download');
              if (await downloadsDir.exists()) {
                saveDirectory = downloadsDir;
              }
            }
          } else {
            // For video files, try Movies directory first
            final moviesDir = Directory('$basePath/Movies');
            if (await moviesDir.exists()) {
              saveDirectory = moviesDir;
            } else {
              // Fall back to Downloads
              final downloadsDir = Directory('$basePath/Download');
              if (await downloadsDir.exists()) {
                saveDirectory = downloadsDir;
              }
            }
          }
        }
      }
    } else {
      // For iOS, use documents directory
      saveDirectory = await getApplicationDocumentsDirectory();
    }

    // Fall back to original directory if we couldn't get a save directory
    final targetDirectory = saveDirectory?.path ?? path.dirname(mediaFile!.path);

    // Generate temp filename: yyyyMMdd_temp.ext
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final tempFilename = '${dateStr}_temp$extension';

    // Set saving state to disable UI
    setState(() {
      _isSaving = true;
    });

    // Handle audio export with FFmpeg
    if (mediaType == MediaType.audio) {
      try {
        // Build output path with temp filename
        final outputPath = path.join(targetDirectory, tempFilename);

        // Convert milliseconds to seconds for FFmpeg
        // Round to 2 decimal places to avoid precision issues
        final startSeconds = (startMs / 1000.0).toStringAsFixed(2);
        final duration = ((endMs - startMs) / 1000.0).toStringAsFixed(2);

        // Validate parameters
        print('[Audio Export] Input: ${mediaFile!.path}');
        print('[Audio Export] Output: $outputPath');
        print('[Audio Export] Start: ${startSeconds}s, Duration: ${duration}s');
        print('[Audio Export] Start marker: ${startMs}ms, End marker: ${endMs}ms');

        if (double.parse(duration) <= 0) {
          throw Exception('${widget.options.strings.errorInvalidDuration} $duration seconds');
        }

        // Detect appropriate codec based on input file extension
        String getAudioCodec(String filePath) {
          final ext = path.extension(filePath).toLowerCase();
          switch (ext) {
            case '.mp3':
              return 'libmp3lame';
            case '.aac':
            case '.m4a':
              return 'aac';
            case '.wav':
              return 'pcm_s16le';
            case '.ogg':
              return 'libvorbis';
            case '.flac':
              return 'flac';
            default:
              return 'aac'; // Fallback to AAC (most compatible)
          }
        }

        final codec = getAudioCodec(mediaFile!.path);
        print('[Audio Export] Detected codec: $codec for file: ${path.extension(mediaFile!.path)}');

        // Build FFmpeg command with -y flag to force overwrite
        // Use appropriate codec based on input file format
        // -vn flag disables video streams (audio-only export)
        final command = '-y -ss $startSeconds -i "${mediaFile!.path}" -t $duration -vn -c:a $codec -b:a 128k "$outputPath"';
        print('[Audio Export] FFmpeg command: $command');

        // Execute FFmpeg command
        final session = await FFmpegKit.execute(command);
        final returnCode = await session.getReturnCode();

        // Get detailed logs for debugging - try multiple methods
        final output = await session.getOutput();
        final failStackTrace = await session.getFailStackTrace();

        // Try to get logs using getLogs() method
        final logs = await session.getLogs();
        String allLogs = '';
        if (logs != null && logs.isNotEmpty) {
          // Format log entries
          allLogs = logs.map((log) => log.getMessage()).join('\n');
        } else if (output != null && output.isNotEmpty) {
          // Fallback to output
          allLogs = output;
        } else {
          allLogs = widget.options.strings.errorNoLogs;
        }

        print('[Audio Export] Return code: $returnCode');
        print('[Audio Export] Output: $output');
        if (failStackTrace != null) {
          print('[Audio Export] Error: $failStackTrace');
        }
        print('[Audio Export] Log entries count: ${logs?.length ?? 0}');
        print('[Audio Export] Complete logs (first 500 chars):\n${allLogs.length > 500 ? allLogs.substring(0, 500) : allLogs}');

        // Write logs to file for debugging
        final documentsDir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final logFile = File(path.join(documentsDir.path, 'ffmpeg_log_$timestamp.txt'));
        await logFile.writeAsString(allLogs);
        print('[Audio Export] Logs written to: ${logFile.path}');

        if (!mounted) return;

        // Check if output file was created and has content
        final outputFile = File(outputPath);
        final fileExists = await outputFile.exists();
        final fileSize = fileExists ? await outputFile.length() : 0;
        print('[Audio Export] File exists: $fileExists, Size: $fileSize bytes');

        final isSuccess = ReturnCode.isSuccess(returnCode) && fileExists && fileSize > 0;

        if (isSuccess) {
          // Copy metadata from original file to saved file
          try {
            print('[Audio Export] Copying metadata from original to saved file...');
            final metadataCopied = await MetadataService.copyMetadata(
              mediaFile!,
              outputFile,
            );
            if (metadataCopied) {
              print('[Audio Export] Metadata copied successfully');
            } else {
              print('[Audio Export] Metadata copy failed or not applicable');
            }
          } catch (e) {
            print('[Audio Export] Error copying metadata: $e');
            // Continue even if metadata copy fails
          }

          // Call callback with temp file path
          if (widget.onVideoSaved != null) {
            widget.onVideoSaved!(outputPath);
          }
        } else {
          // Failed - delete empty file if it exists
          if (fileExists && fileSize == 0) {
            await outputFile.delete();
          }
        }

        // Reset saving state before returning
        setState(() {
          _isSaving = false;
        });

        // Return to caller with standardized result
        final errorMsg = !isSuccess
            ? (fileSize == 0
                ? widget.options.strings.errorOutputEmpty
                : '${widget.options.strings.errorFFmpegFailed} $returnCode')
            : '';

        Navigator.of(context).pop<Map<String, String>>({
          'success': isSuccess ? 'true' : 'false',
          'path': isSuccess ? outputPath : '',
          'error': errorMsg,
          'logFilePath': logFile.path,
        });
        return;
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _isSaving = false;
        });

        // Return error to caller
        Navigator.of(context).pop<Map<String, String>>({
          'success': 'false',
          'path': '',
          'error': '${widget.options.strings.statusErrorSavingAudio} $e',
          'logFilePath': '',
        });
        return;
      }
    }

    // Handle video export
    try {
      final editor = VideoEditorBuilder(
        videoPath: mediaFile!.path,
      ).trim(startTimeMs: startMs.toInt(), endTimeMs: endMs.toInt());

      final result = await editor.export();

      if (!mounted) return;

      // Move exported file to target directory with temp filename
      String? outputPath;
      if (result != null) {
        final exportedFile = File(result);
        // Use target directory (Movies/Downloads on Android, Documents on iOS)
        outputPath = path.join(targetDirectory, tempFilename);

        await exportedFile.copy(outputPath);
        await exportedFile.delete(); // Delete the original temp file from easy_video_editor
      }

      // Copy metadata from original file to saved file (for MP4 videos)
      if (outputPath != null) {
        try {
          print('[Video Export] Copying metadata from original to saved file...');
          final savedFile = File(outputPath);
          final metadataCopied = await MetadataService.copyMetadata(
            mediaFile!,
            savedFile,
          );
          if (metadataCopied) {
            print('[Video Export] Metadata copied successfully');
          } else {
            print('[Video Export] Metadata copy failed or not applicable');
          }
        } catch (e) {
          print('[Video Export] Error copying metadata: $e');
          // Continue even if metadata copy fails
        }

        // Call callback with temp file path
        if (widget.onVideoSaved != null) {
          widget.onVideoSaved!(outputPath);
        }
      }

      // Reset saving state before returning
      setState(() {
        _isSaving = false;
      });

      // Return standardized result to caller
      Navigator.of(context).pop<Map<String, String>>({
        'success': outputPath != null ? 'true' : 'false',
        'path': outputPath ?? '',
        'error': outputPath == null ? 'Video export failed' : '',
        'logFilePath': '', // Video export doesn't use FFmpeg, so no logs
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      // Return error to caller
      Navigator.of(context).pop<Map<String, String>>({
        'success': 'false',
        'path': '',
        'error': '${widget.options.strings.statusErrorSavingMedia} $e',
        'logFilePath': '',
      });
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
        _startPlaybackPositionTimer();
      } else {
        mediaController!.pause();
        _stopPlaybackPositionTimer();
        _isLoopingSelection = false; // Disable loop mode when manually pausing
      }
    });
  }

  // Audio playback controls
  void _playEntireFile() async {
    if (mediaController == null || !mediaController!.isInitialized) return;

    await mediaController!.seekTo(0);
    setState(() {
      _currentPlaybackPositionMs = 0;
      isPlaying = true;
      _isLoopingSelection = false; // Disable loop mode
    });
    await mediaController!.play();
    _startPlaybackPositionTimer();
  }

  void _playSelection() async {
    if (mediaController == null || !mediaController!.isInitialized) return;

    await mediaController!.seekTo(startMs.toInt());
    setState(() {
      _currentPlaybackPositionMs = startMs;
      isPlaying = true;
      _isLoopingSelection = true; // Enable loop mode
    });
    await mediaController!.play();
    _startPlaybackPositionTimer();
  }

  void _playFromPosition() async {
    if (mediaController == null || !mediaController!.isInitialized) return;

    // Play from touched position, or current playback position
    // If current position is 0 (never played), fall back to start marker
    final playPosition = _touchedPositionMs ??
        (_currentPlaybackPositionMs > 0 ? _currentPlaybackPositionMs : startMs);
    await mediaController!.seekTo(playPosition.toInt());
    setState(() {
      _currentPlaybackPositionMs = playPosition;
      isPlaying = true;
      _isLoopingSelection = false; // Disable loop mode
      _bypassEndMarkerCheck = playPosition > endMs; // Bypass end marker check if playing beyond it
    });
    await mediaController!.play();
    _startPlaybackPositionTimer();
  }

  void _stopPlayback() async {
    if (mediaController == null || !mediaController!.isInitialized) return;

    await mediaController!.pause();
    await mediaController!.seekTo(startMs.toInt());

    setState(() {
      isPlaying = false;
      _currentPlaybackPositionMs = startMs;
      _touchedPositionMs = null; // Clear touch marker
      _isLoopingSelection = false;
    });

    _stopPlaybackPositionTimer();
  }

  Widget _buildZoomButton(String label, double durationMs) {
    final isActive = mediaType == MediaType.audio
        ? (_audioZoomLevel - (videoDurationMs / durationMs)).abs() < 0.1
        : (endMs - startMs - durationMs).abs() < 100; // Within 100ms tolerance

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ElevatedButton(
        onPressed: () => _setZoomDuration(durationMs),
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive
              ? widget.options.slideAreaColor
              : widget.options.primaryColor.withOpacity(0.7),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          minimumSize: const Size(0, 42),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTextControl(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPipeSeparator() {
    return Text(
      '|',
      style: TextStyle(
        color: widget.options.primaryColor.withOpacity(0.4),
        fontSize: 16,
      ),
    );
  }

  Widget _buildPlayMenuButton() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'all':
            _playEntireFile();
            break;
          case 'selection':
            _playSelection();
            break;
          case 'from_here':
            _playFromPosition();
            break;
          case 'stop':
            _stopPlayback();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'all', child: Text(widget.options.strings.playAll)),
        PopupMenuItem(value: 'selection', child: Text(widget.options.strings.playSelection)),
        PopupMenuItem(value: 'from_here', child: Text(widget.options.strings.playFromHere)),
        PopupMenuItem(value: 'stop', child: Text(widget.options.strings.playStop)),
      ],
      child: ElevatedButton.icon(
        onPressed: null, // PopupMenuButton handles tap
        icon: const Icon(Icons.play_circle_outline, size: 20),
        label: Text(widget.options.strings.playMenuLabel),
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.options.primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: widget.options.primaryColor,
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildZoomMenuButton() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'selection':
            _zoomToSelection();
            break;
          case 'all':
            _zoomToAll();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'selection', child: Text(widget.options.strings.zoomSelection)),
        PopupMenuItem(value: 'all', child: Text(widget.options.strings.zoomAll)),
      ],
      child: ElevatedButton.icon(
        onPressed: null, // PopupMenuButton handles tap
        icon: const Icon(Icons.zoom_in, size: 20),
        label: Text(widget.options.strings.zoomMenuLabel),
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.options.primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: widget.options.primaryColor,
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildMarkerMenuButton() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'start_begin':
            _setStartMarkerToBeginning();
            break;
          case 'end_max':
            _setEndMarkerToEnd();
            break;
          case 'start_touch':
            _setStartToTouchedPosition();
            break;
          case 'end_touch':
            _setEndToTouchedPosition();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'start_begin', child: Text(widget.options.strings.markerStartToBeginning)),
        PopupMenuItem(value: 'end_max', child: Text(widget.options.strings.markerEndToMax)),
        if (_touchedPositionMs != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'start_touch',
            child: Text('${widget.options.strings.markerStartAt}${(_touchedPositionMs! / 1000).toStringAsFixed(1)}s'),
          ),
          PopupMenuItem(
            value: 'end_touch',
            child: Text('${widget.options.strings.markerEndAt}${(_touchedPositionMs! / 1000).toStringAsFixed(1)}s'),
          ),
        ],
      ],
      child: ElevatedButton.icon(
        onPressed: null, // PopupMenuButton handles tap
        icon: const Icon(Icons.location_on, size: 20),
        label: Text(widget.options.strings.markerMenuLabel),
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.options.primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: widget.options.primaryColor,
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
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
          if (mediaFile != null && isInitialized && !_isSaving)
            widget.options.saveButtonWidget ??
                IconButton(
                  icon: const Icon(Icons.save, color: Colors.white),
                  onPressed: _saveMedia,
                  tooltip: widget.options.saveButtonText,
                ),
        ],
      ),
      body: Stack(
        children: [
          // Main editor content
          _buildMediaEditorContent(),

          // Fullscreen blocking overlay when saving
          if (_isSaving)
            IgnorePointer(
              ignoring: true,
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        mediaType == MediaType.audio
                            ? widget.options.strings.savingAudio
                            : widget.options.strings.savingVideo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaEditorContent() {
    return SafeArea(
      child: Column(
        children: [
        // Media Player (Video or Audio)
        Expanded(
          flex: 2,
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
                    startMs: startMs,
                    endMs: endMs,
                    currentPositionMs: _currentPlaybackPositionMs,
                    touchedPositionMs: _touchedPositionMs,
                    onWaveformTouched: _onWaveformTouched,
                    audioZoomLevel: _audioZoomLevel,
                    audioTargetScrollOffsetMs: _audioTargetScrollOffsetMs,
                    onAudioScrollChanged: (scrollOffset) {
                      // Optional: Track user's manual scroll position if needed
                      // For now, we don't need to do anything here
                    },
                    onAudioZoomChanged: _onAudioZoomChanged,
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
                  '${widget.options.strings.durationStart} ${(startMs / 1000).toStringAsFixed(1)}s',
                  style: const TextStyle(color: Colors.white),
                ),
                Text(
                  '${widget.options.strings.durationLabel} ${((endMs - startMs) / 1000).toStringAsFixed(1)}s',
                  style: const TextStyle(color: Colors.white70),
                ),
                Text(
                  '${widget.options.strings.durationEnd} ${(endMs / 1000).toStringAsFixed(1)}s',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
        ],

        // Audio Controls - Menu Button Style
        if (mediaType == MediaType.audio && isInitialized) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(child: _buildPlayMenuButton()),
                const SizedBox(width: 8),
                Expanded(child: _buildZoomMenuButton()),
                const SizedBox(width: 8),
                Expanded(child: _buildMarkerMenuButton()),
              ],
            ),
          ),
        ],

        // Timeline Control Buttons (hide for audio files)
        if (isInitialized && mediaType != MediaType.audio) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Position controls
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _moveStartToBeginning,
                    icon: const Icon(Icons.skip_previous, size: 24),
                    label: const Text('Start', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.options.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size(0, 52),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _moveEndToFinish,
                    icon: const Icon(Icons.skip_next, size: 24),
                    label: const Text('End', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.options.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size(0, 52),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Text(
                  'Zoom:',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(width: 8),
                Expanded(child: _buildZoomButton('1s', 1000)),
                Expanded(child: _buildZoomButton('10s', 10000)),
                Expanded(child: _buildZoomButton('60s', 60000)),
                Expanded(child: _buildZoomButton('Full', videoDurationMs)),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Timeline with Thumbnails/Waveforms and Selection Markers (hide for audio)
        if (mediaType != MediaType.audio)
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
          height: mediaType == MediaType.audio ? 150.0 : 100.0,
          segmentHeight: mediaType == MediaType.audio ? 130.0 : 80.0,
        ),

        // Status Display
        if (_status.startsWith('Error'))
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(_status, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
