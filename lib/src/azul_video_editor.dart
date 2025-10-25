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
import 'generators/audio_waveform_generator.dart';
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
    // Validate file type before opening editor
    final mediaType = MediaTypeDetector.detectFromFile(file);

    if (mediaType == MediaType.unknown) {
      // Return error for unsupported file types
      return {
        'success': 'false',
        'path': '',
        'error': 'Unsupported file format. Please select a video or audio file.',
        'logFilePath': '',
      };
    }

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

  Timer? _playbackPositionTimer; // Timer to update playback position

  double _currentPlaybackPositionMs = 0;
  double? _touchedPositionMs; // Position where user tapped on waveform
  double _mediaZoomLevel = 1.0; // Zoom level for waveform visualization
  double? _mediaTargetScrollOffsetMs; // Target scroll position for waveform (set by Zoom Selection/All)
  bool _isLoopingSelection = false; // Whether selection is playing in loop mode
  bool _bypassEndMarkerCheck = false; // Bypass end marker check when playing from position beyond end marker


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
        // Video waveform is extracted in controller, no generator needed
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
      mediaController!.addListener(_onWaveformStateChanged);

      setState(() {
        isInitialized = true;
        _currentPlaybackPositionMs = 0;
        _status = widget.options.strings.statusReadyToEdit;
      });
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

  void _onWaveformStateChanged() {
    // Rebuild UI when waveform extraction state changes
    if (mounted) {
      setState(() {
        // Just trigger a rebuild to update the waveform visualizer
      });
    }
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

  void _onWaveformTouched(double positionMs) {
    setState(() {
      _touchedPositionMs = positionMs.clamp(0.0, videoDurationMs);
    });

    // Seek video/audio to touched position for preview
    if (mediaController != null && mediaController!.isInitialized) {
      mediaController!.seekTo(_touchedPositionMs!.toInt());
      setState(() {
        _currentPlaybackPositionMs = _touchedPositionMs!;
      });
    }
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
      // Zoom the waveform view for both video and audio
      // Full file = 1.0x zoom, smaller durations = higher zoom
      if (targetDurationMs >= videoDurationMs) {
        _mediaZoomLevel = 1.0;
      } else {
        _mediaZoomLevel = (videoDurationMs / targetDurationMs).clamp(1.0, 10.0);
      }
    });
  }

  void _zoomToSelection() {
    if (videoDurationMs <= 0 || endMs <= startMs) return;
    setState(() {
      // Zoom to fit the selected region
      final selectionDuration = endMs - startMs;
      _mediaZoomLevel = (videoDurationMs / selectionDuration).clamp(1.0, 10.0);

      // Calculate scroll offset to show the selected region
      // Center the selection in the viewport
      final selectionMidpoint = (startMs + endMs) / 2;
      final visibleDuration = videoDurationMs / _mediaZoomLevel;
      final targetScrollOffset = selectionMidpoint - (visibleDuration / 2);

      // Clamp to valid range
      final maxScrollOffset = videoDurationMs - visibleDuration;
      _mediaTargetScrollOffsetMs = targetScrollOffset.clamp(0.0, math.max(0, maxScrollOffset));
    });
  }

  void _zoomToAll() {
    setState(() {
      _mediaZoomLevel = 1.0; // Show entire file
      _mediaTargetScrollOffsetMs = 0.0; // Reset scroll to beginning
    });
  }

  void _onMediaZoomChanged(double newZoom) {
    setState(() {
      _mediaZoomLevel = newZoom;
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
    // Only used for audio files now (video waveform extracted in controller)
    if (mediaFile == null || visualGenerator == null) return;

    setState(() {
      _status = widget.options.strings.statusGeneratingWaveforms;
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
          _status = widget.options.strings.statusReadyToEdit;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
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

              // Apply subfolder if specified
              if (widget.options.saveSubfolder != null && widget.options.saveSubfolder!.isNotEmpty) {
                saveDirectory = Directory(path.join(saveDirectory.path, widget.options.saveSubfolder!));

                // Create subfolder if it doesn't exist
                if (!await saveDirectory.exists()) {
                  await saveDirectory.create(recursive: true);
                }
              }
            } else {
              // Fall back to Downloads
              final downloadsDir = Directory('$basePath/Download');
              if (await downloadsDir.exists()) {
                saveDirectory = downloadsDir;

                // Apply subfolder if specified
                if (widget.options.saveSubfolder != null && widget.options.saveSubfolder!.isNotEmpty) {
                  saveDirectory = Directory(path.join(saveDirectory.path, widget.options.saveSubfolder!));

                  // Create subfolder if it doesn't exist
                  if (!await saveDirectory.exists()) {
                    await saveDirectory.create(recursive: true);
                  }
                }
              }
            }
          } else {
            // For video files, try Movies directory first
            final moviesDir = Directory('$basePath/Movies');
            if (await moviesDir.exists()) {
              saveDirectory = moviesDir;

              // Apply subfolder if specified
              if (widget.options.saveSubfolder != null && widget.options.saveSubfolder!.isNotEmpty) {
                saveDirectory = Directory(path.join(saveDirectory.path, widget.options.saveSubfolder!));

                // Create subfolder if it doesn't exist
                if (!await saveDirectory.exists()) {
                  await saveDirectory.create(recursive: true);
                }
              }
            } else {
              // Fall back to Downloads
              final downloadsDir = Directory('$basePath/Download');
              if (await downloadsDir.exists()) {
                saveDirectory = downloadsDir;

                // Apply subfolder if specified
                if (widget.options.saveSubfolder != null && widget.options.saveSubfolder!.isNotEmpty) {
                  saveDirectory = Directory(path.join(saveDirectory.path, widget.options.saveSubfolder!));

                  // Create subfolder if it doesn't exist
                  if (!await saveDirectory.exists()) {
                    await saveDirectory.create(recursive: true);
                  }
                }
              }
            }
          }
        }
      }
    } else {
      // For iOS, use documents directory
      saveDirectory = await getApplicationDocumentsDirectory();

      // Apply subfolder if specified
      if (widget.options.saveSubfolder != null && widget.options.saveSubfolder!.isNotEmpty) {
        saveDirectory = Directory(path.join(saveDirectory.path, widget.options.saveSubfolder!));

        // Create subfolder if it doesn't exist
        if (!await saveDirectory.exists()) {
          await saveDirectory.create(recursive: true);
        }
      }
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

  Future<void> _saveCurrentFrame() async {
    // Only works for video files
    if (mediaType != MediaType.video || mediaFile == null) return;

    // Pause playback if playing
    if (mediaController?.isPlaying == true) {
      await mediaController?.pause();
      setState(() {
        isPlaying = false;
      });
    }

    // Get save directory (use Pictures for images on Android)
    Directory? saveDirectory;
    if (Platform.isAndroid) {
      saveDirectory = await getExternalStorageDirectory();
      if (saveDirectory != null) {
        final pathSegments = saveDirectory.path.split('/');
        final baseIndex = pathSegments.indexOf('Android');
        if (baseIndex > 0) {
          final basePath = pathSegments.sublist(0, baseIndex).join('/');
          final picturesDir = Directory('$basePath/Pictures');
          if (await picturesDir.exists()) {
            saveDirectory = picturesDir;

            // Apply subfolder if specified
            if (widget.options.saveSubfolder != null && widget.options.saveSubfolder!.isNotEmpty) {
              saveDirectory = Directory(path.join(saveDirectory.path, widget.options.saveSubfolder!));
              if (!await saveDirectory.exists()) {
                await saveDirectory.create(recursive: true);
              }
            }
          }
        }
      }
    } else {
      // iOS
      saveDirectory = await getApplicationDocumentsDirectory();
      if (widget.options.saveSubfolder != null && widget.options.saveSubfolder!.isNotEmpty) {
        saveDirectory = Directory(path.join(saveDirectory.path, widget.options.saveSubfolder!));
        if (!await saveDirectory.exists()) {
          await saveDirectory.create(recursive: true);
        }
      }
    }

    final targetDirectory = saveDirectory?.path ?? path.dirname(mediaFile!.path);

    // Generate temp filename: yyyyMMdd_frame_temp.jpg
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final tempFilename = '${dateStr}_frame_temp.jpg';
    final outputPath = path.join(targetDirectory, tempFilename);

    // Set saving state
    setState(() {
      _isSaving = true;
    });

    try {
      // Convert current position to seconds
      final currentSeconds = (_currentPlaybackPositionMs / 1000.0).toStringAsFixed(3);

      final documentsDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final logFile = File(path.join(documentsDir.path, 'ffmpeg_frame_log_$timestamp.txt'));

      String allLogs = '';
      bool success = false;

      // TIER 1: Try with hardware decoding (default)
      print('[Frame Export] Attempt 1: Hardware decoding');
      final hardwareCommand = '-y -ss $currentSeconds -i "${mediaFile!.path}" -vframes 1 -q:v 2 "$outputPath"';
      print('[Frame Export] Command: $hardwareCommand');

      var session = await FFmpegKit.execute(hardwareCommand);
      var returnCode = await session.getReturnCode();

      // Get logs
      var logs = await session.getLogs();
      if (logs != null && logs.isNotEmpty) {
        allLogs = logs.map((log) => log.getMessage()).join('\n');
      }

      // Check success
      var outputFile = File(outputPath);
      var fileExists = await outputFile.exists();
      var fileSize = fileExists ? await outputFile.length() : 0;
      success = ReturnCode.isSuccess(returnCode) && fileExists && fileSize > 0;

      // TIER 2: If hardware failed, try software decoding
      if (!success) {
        print('[Frame Export] Hardware decoding failed, attempting software decoding...');

        // Delete any partial output file from first attempt
        if (await outputFile.exists()) {
          await outputFile.delete();
        }

        final softwareCommand = '-hwaccel none -y -ss $currentSeconds -i "${mediaFile!.path}" -vframes 1 -q:v 2 "$outputPath"';
        print('[Frame Export] Command: $softwareCommand');

        session = await FFmpegKit.execute(softwareCommand);
        returnCode = await session.getReturnCode();

        // Get logs from second attempt
        logs = await session.getLogs();
        String softwareLogs = '';
        if (logs != null && logs.isNotEmpty) {
          softwareLogs = logs.map((log) => log.getMessage()).join('\n');
        }

        // Append to all logs
        allLogs += '\n\n=== SOFTWARE DECODER ATTEMPT ===\n' + softwareLogs;

        // Check success
        outputFile = File(outputPath);
        fileExists = await outputFile.exists();
        fileSize = fileExists ? await outputFile.length() : 0;
        success = ReturnCode.isSuccess(returnCode) && fileExists && fileSize > 0;
      }

      // Write all logs to file
      await logFile.writeAsString(allLogs);

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      // TIER 3: If both failed, provide helpful error message
      String errorMessage = 'Failed to extract frame';
      if (!success) {
        // Detect AV1-specific errors
        if (allLogs.contains('av1') &&
            (allLogs.contains('Failed to get pixel format') ||
             allLogs.contains('not support') ||
             allLogs.contains('Function not implemented'))) {
          errorMessage = widget.options.strings.errorAV1NotSupported;
        } else if (!ReturnCode.isSuccess(returnCode)) {
          errorMessage = '${widget.options.strings.errorFFmpegFailed} $returnCode';
        } else if (!fileExists) {
          errorMessage = 'Output file was not created';
        } else if (fileSize == 0) {
          errorMessage = widget.options.strings.errorOutputEmpty;
        }
      }

      // Return result
      Navigator.of(context).pop<Map<String, String>>({
        'success': success ? 'true' : 'false',
        'path': success ? outputPath : '',
        'error': success ? '' : errorMessage,
        'logFilePath': logFile.path,
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      Navigator.of(context).pop<Map<String, String>>({
        'success': 'false',
        'path': '',
        'error': 'Error saving frame: $e',
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

  void _togglePlayPauseFromMenu() async {
    if (mediaController == null || !mediaController!.isInitialized) return;

    if (isPlaying) {
      // Currently playing - pause it
      await mediaController!.pause();
      setState(() {
        isPlaying = false;
        _isLoopingSelection = false;
      });
      _stopPlaybackPositionTimer();
    } else {
      // Currently paused - resume from current position
      await mediaController!.play();
      setState(() {
        isPlaying = true;
      });
      _startPlaybackPositionTimer();
    }
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
          case 'toggle_play_pause':
            _togglePlayPauseFromMenu();
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
        PopupMenuItem(
          value: 'toggle_play_pause',
          child: Text(isPlaying ? widget.options.strings.playPause : widget.options.strings.playResume),
        ),
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

  Widget _buildActionsMenuButton() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'save':
            _saveMedia();
            break;
          case 'save_frame':
            _saveCurrentFrame();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'save', child: Text(widget.options.strings.actionsSave)),
        // Save Frame temporarily disabled (AV1 compatibility issues)
        // if (mediaType == MediaType.video)
        //   PopupMenuItem(value: 'save_frame', child: Text(widget.options.strings.actionsSaveFrame)),
      ],
      child: ElevatedButton.icon(
        onPressed: null, // PopupMenuButton handles tap
        icon: const Icon(Icons.more_horiz, size: 20),
        label: Text(widget.options.strings.actionsMenuLabel),
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

  /// Check if user has made any edits to the media (moved markers from default positions)
  bool _hasUnsavedChanges() {
    if (!isInitialized || videoDurationMs == 0) return false;

    // Check if markers have been moved from default positions
    final markersChanged = startMs != 0 || endMs != videoDurationMs;

    return markersChanged;
  }

  /// Show confirmation dialog for unsaved changes
  Future<bool> _showDiscardChangesDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Do you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Stay
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), // Discard
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return result ?? false; // Default to false (stay) if dialog dismissed
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving && !_hasUnsavedChanges(), // Block back if saving or has unsaved changes
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        // If blocked due to save, do nothing (save must complete)
        if (_isSaving) {
          return;
        }

        // If blocked due to unsaved changes, show confirmation dialog
        if (_hasUnsavedChanges()) {
          final shouldDiscard = await _showDiscardChangesDialog(context);
          if (shouldDiscard && context.mounted) {
            Navigator.of(context).pop();
          }
          return;
        }
      },
      child: Scaffold(
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
      ),
      body: Stack(
        children: [
          // Main editor content
          _buildMediaEditorContent(),

          // Fullscreen blocking overlay when saving
          if (_isSaving)
            AbsorbPointer(
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
                        widget.options.strings.exportingMedia,
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
      ), // Scaffold
    ); // PopScope
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
                    audioZoomLevel: _mediaZoomLevel,
                    audioTargetScrollOffsetMs: _mediaTargetScrollOffsetMs,
                    onAudioScrollChanged: (scrollOffset) {
                      // Optional: Track user's manual scroll position if needed
                      // For now, we don't need to do anything here
                    },
                    onAudioZoomChanged: _onMediaZoomChanged,
                    markerBorderColor: widget.options.markerBorderColor,
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

        // Unified Controls - Menu Button Style (for both video and audio)
        if (isInitialized) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    SizedBox(width: 120, child: _buildPlayMenuButton()),
                    const SizedBox(width: 8),
                    SizedBox(width: 120, child: _buildZoomMenuButton()),
                    const SizedBox(width: 8),
                    SizedBox(width: 120, child: _buildMarkerMenuButton()),
                    const SizedBox(width: 8),
                    SizedBox(width: 120, child: _buildActionsMenuButton()),
                  ],
                ),
              ),
            ),
          ),
        ],

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
