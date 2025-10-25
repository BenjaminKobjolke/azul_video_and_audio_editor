import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:azul_video_editor/azul_video_editor.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'widgets/save_dialog.dart';
import 'widgets/overwrite_dialog.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Azul Video Editor Example',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _editedVideoPath;
  String? _ffmpegLogs;
  String? _logFilePath;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Azul Video Editor Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _openDefaultEditor(context),
              child: const Text('Open Default Video Editor'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _openCustomEditor(context),
              child: const Text('Open Customized Video Editor'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _openManualPickEditor(context),
              child: const Text('Open Editor (Manual Pick)'),
            ),
            const SizedBox(height: 32),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(16.0),
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 32),
                    const SizedBox(height: 8),
                    const Text(
                      'Export Failed',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_editedVideoPath != null && _editedVideoPath!.isNotEmpty) ...[
              const Text('Edited Video Path:'),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _editedVideoPath!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_logFilePath != null) ...[
              ElevatedButton.icon(
                onPressed: () => _showLogFileDialog(context),
                icon: const Icon(Icons.description),
                label: const Text('View FFmpeg Log File'),
              ),
              const SizedBox(height: 8),
              Text(
                'Log file: ${_logFilePath!.split('/').last}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openDefaultEditor(BuildContext context) async {
    // Pick media file first
    final pickedFile = await _pickMediaFile();
    if (pickedFile == null) return; // User cancelled

    // Open editor with the picked file
    final result = await AzulVideoEditor.openEditor(context, pickedFile);

    if (result != null) {
      // Get original filename for save dialog suggestion
      final originalName = path.basenameWithoutExtension(pickedFile.path);
      await _handleEditorResult(context, result, originalName);
    }
  }

  Future<void> _openCustomEditor(BuildContext context) async {
    // Pick media file first
    final pickedFile = await _pickMediaFile();
    if (pickedFile == null) return; // User cancelled

    // Custom options
    final options = AzulEditorOptions(
      maxDurationMs: 30000, // 30 seconds
      title: 'My Custom Editor',
      primaryColor: Colors.purple,
      backgroundColor: Colors.black,
      videoBackgroundColor: Colors.grey[900]!,
      saveButtonText: 'Export Video',
      thumbnailSize: 30,
      aspectRatio: 16 / 9, // Force 16:9 aspect ratio
    );

    final result = await AzulVideoEditor.openEditor(context, pickedFile, options: options);

    if (result != null) {
      // Get original filename for save dialog suggestion
      final originalName = path.basenameWithoutExtension(pickedFile.path);
      await _handleEditorResult(context, result, originalName);
    }
  }

  Future<void> _openManualPickEditor(BuildContext context) async {
    // Pick media file first
    final pickedFile = await _pickMediaFile();
    if (pickedFile == null) return; // User cancelled

    final result = await AzulVideoEditor.openEditor(context, pickedFile);

    if (result != null) {
      // Get original filename for save dialog suggestion
      final originalName = path.basenameWithoutExtension(pickedFile.path);
      await _handleEditorResult(context, result, originalName);
    }
  }

  /// Shows file picker and returns selected file
  Future<File?> _pickMediaFile() async {
    try {
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
        return File(result.files.single.path!);
      }
      return null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
      return null;
    }
  }

  /// Handles the result from the editor - processes temp file and shows save dialog
  Future<void> _handleEditorResult(
    BuildContext context,
    Map<String, String> result,
    String originalFilename,
  ) async {
    // Store log file path regardless of success/failure
    setState(() {
      _logFilePath = result['logFilePath'];
    });

    // Check if export was successful
    final success = result['success'] == 'true';
    if (!success) {
      // Export failed - show error
      setState(() {
        _errorMessage = result['error'] ?? 'Unknown error occurred';
        _editedVideoPath = null;
      });
      return;
    }

    // Export succeeded - get temp file path
    final tempFilePath = result['path'];
    if (tempFilePath == null || tempFilePath.isEmpty) {
      setState(() {
        _errorMessage = 'No file path returned from editor';
        _editedVideoPath = null;
      });
      return;
    }

    final tempFile = File(tempFilePath);
    if (!await tempFile.exists()) {
      setState(() {
        _errorMessage = 'Temp file does not exist: $tempFilePath';
        _editedVideoPath = null;
      });
      return;
    }

    final extension = path.extension(tempFilePath);

    // Show save dialog to get filename from user (using original filename as suggestion)
    final finalPath = await _showSaveDialogAndRename(
      context,
      tempFile,
      originalFilename,
      extension,
    );

    if (finalPath != null) {
      // Success! File has been renamed to user's choice
      setState(() {
        _editedVideoPath = finalPath;
        _errorMessage = null;
      });
    } else {
      // User cancelled - delete temp file
      try {
        await tempFile.delete();
        print('Temp file deleted: $tempFilePath');
      } catch (e) {
        print('Error deleting temp file: $e');
      }

      setState(() {
        _editedVideoPath = null;
        _errorMessage = null;
      });
    }
  }

  /// Shows save dialog and handles file renaming/overwrite logic
  Future<String?> _showSaveDialogAndRename(
    BuildContext context,
    File tempFile,
    String suggestedName,
    String extension,
  ) async {
    final tempDir = tempFile.parent.path;

    while (true) {
      // Show filename dialog
      final filename = await showDialog<String>(
        context: context,
        builder: (context) => SaveFilenameDialog(
          suggestedFilename: suggestedName,
          fileExtension: extension,
        ),
      );

      if (filename == null || filename.isEmpty) {
        // User cancelled
        return null;
      }

      // Add extension if missing
      final filenameWithExt = filename.endsWith(extension) ? filename : '$filename$extension';

      // Check if file exists
      final targetPath = path.join(tempDir, filenameWithExt);
      final targetFile = File(targetPath);

      if (await targetFile.exists()) {
        // File exists - show overwrite dialog
        if (!mounted) return null;

        final action = await showDialog<OverwriteAction>(
          context: context,
          builder: (context) => OverwriteDialog(
            filename: filenameWithExt,
          ),
        );

        if (action == OverwriteAction.cancel) {
          // User cancelled
          return null;
        } else if (action == OverwriteAction.rename) {
          // User wants to rename - loop back to filename dialog
          continue;
        } else if (action == OverwriteAction.overwrite) {
          // User wants to overwrite - delete existing file
          try {
            await targetFile.delete();
          } catch (e) {
            if (!mounted) return null;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error deleting existing file: $e')),
            );
            return null;
          }
        }
      }

      // Rename temp file to final filename
      try {
        await tempFile.rename(targetPath);
        return targetPath;
      } catch (e) {
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error renaming file: $e')),
        );
        return null;
      }
    }
  }

  void _showLogsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('FFmpeg Export Logs'),
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _ffmpegLogs ?? ''));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logs copied to clipboard')),
                );
              },
              tooltip: 'Copy to clipboard',
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              _ffmpegLogs ?? 'No logs available',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogFileDialog(BuildContext context) async {
    if (_logFilePath == null) return;

    try {
      final file = File(_logFilePath!);
      final contents = await file.readAsString();

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Expanded(
                child: Text('FFmpeg Log File'),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: contents));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logs copied to clipboard')),
                  );
                },
                tooltip: 'Copy to clipboard',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.share, size: 20),
                onPressed: () async {
                  final box = context.findRenderObject() as RenderBox?;
                  await Share.shareXFiles(
                    [XFile(_logFilePath!)],
                    subject: 'FFmpeg Log File',
                    sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
                  );
                },
                tooltip: 'Share log file',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: SelectableText(
                contents,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reading log file: $e')),
      );
    }
  }
}
