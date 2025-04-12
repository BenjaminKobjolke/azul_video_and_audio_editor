import 'package:flutter/material.dart';
import 'package:azul_video_editor/azul_video_editor.dart';

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
            if (_editedVideoPath != null) ...[
              const Text('Edited Video Path:'),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _editedVideoPath!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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
        _editedVideoPath = result;
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
        _editedVideoPath = result;
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
        _editedVideoPath = result;
      });
    }
  }
}
