import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:azul_video_editor/azul_video_editor.dart';
import 'dart:io';

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
    // Default is now auto-pick = true
    final result = await AzulVideoEditor.openEditor(context);

    if (result != null) {
      setState(() {
        _editedVideoPath = result['path'];
        _ffmpegLogs = result['logs'];
        _logFilePath = result['logFilePath'];
        _errorMessage = result['error']?.isNotEmpty == true ? result['error'] : null;
      });
    }
  }

  Future<void> _openCustomEditor(BuildContext context) async {
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

    // Still auto-picks
    final result = await AzulVideoEditor.openEditor(context, options: options);

    if (result != null) {
      setState(() {
        _editedVideoPath = result['path'];
        _ffmpegLogs = result['logs'];
        _logFilePath = result['logFilePath'];
        _errorMessage = result['error']?.isNotEmpty == true ? result['error'] : null;
      });
    }
  }

  Future<void> _openManualPickEditor(BuildContext context) async {
    // Set autoPickVideo to false for manual selection
    final result = await AzulVideoEditor.openEditor(
      context,
      autoPickVideo: false,
    );

    if (result != null) {
      setState(() {
        _editedVideoPath = result['path'];
        _ffmpegLogs = result['logs'];
        _logFilePath = result['logFilePath'];
        _errorMessage = result['error']?.isNotEmpty == true ? result['error'] : null;
      });
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('FFmpeg Log File'),
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: contents));
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
