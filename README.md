# Azul Video Editor

A Flutter package for seamless video and audio editing with powerful trimming capabilities. Azul Video Editor provides an intuitive interface for trimming media files, previewing edits in real-time with waveform visualization, and customizing the editing experience.

## Features

- **Video & Audio Editing**: Trim both video and audio files with a unified interface
- **Waveform Visualization**: Visual audio waveform for precise editing
- **Real-Time Preview**: Preview edits instantly as you adjust markers
- **Interactive Controls**: Play, zoom, and marker controls for efficient editing
- **Internationalization (i18n)**: Full support for custom UI strings in any language
- **Customizable UI**: Tailor colors, text, and aspect ratios to match your app
- **Auto-Normalized Waveforms**: Audio waveforms automatically scale for optimal visibility
- **Subfolder Organization**: Organize saved files into custom subfolders
- **Comprehensive Logging**: FFmpeg logs for debugging export issues
- **Easy Integration**: Simple API for quick setup in any Flutter project

## Screenshots

<img src="https://github.com/BenjaminKobjolke/azul_video_and_audio_editor/raw/main/screenshots/screenshot.png" alt="Video Editor Demo" width="300" />

## Supported Formats

### Video Formats
MP4, MOV, AVI, MKV, FLV, WMV, WebM, M4V, MPEG, MPG, 3GP

### Audio Formats
MP3, WAV, AAC, FLAC, OGG, WMA, M4A, Opus, AIFF, ALAC

## Installation

Add the package to your project by including it in your `pubspec.yaml`:

```yaml
dependencies:
  azul_video_editor: ^0.0.1
  file_picker: ^8.1.6  # For picking media files
```

Run the following command to fetch the package:

```bash
flutter pub get
```

## Platform-Specific Setup

### Android

Add the following permissions to your `AndroidManifest.xml` (located in `android/app/src/main/AndroidManifest.xml`):

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

For Android 13 (API 33) and above, you may need to use granular media permissions:

```xml
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
```

**Note**: If targeting Android 11 (API 30) or higher, ensure your app handles [scoped storage](https://developer.android.com/training/data-storage) requirements. You may need to add `requestLegacyExternalStorage="true"` in the `<application>` tag for older apps:

```xml
<application
    android:requestLegacyExternalStorage="true"
    ... >
```

Update your `android/app/build.gradle` to set the minimum SDK version to at least 21:

```gradle
android {
    defaultConfig {
        minSdkVersion 21
    }
}
```

### iOS

Azul Video Editor requires **iOS 13.0** or later. Add the following keys to your `Info.plist` (located in `ios/Runner/Info.plist`):

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>This app requires access to the photo library for media editing.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>This app requires access to the photo library to save edited media.</string>
```

Ensure your `Podfile` (in `ios/Podfile`) specifies at least iOS 13.0:

```ruby
platform :ios, '13.0'
```

Run `pod install` in the `ios/` directory to update dependencies:

```bash
cd ios && pod install
```

## Known Issues

### flutter_soloud Dependency

**Issue**: The published `flutter_soloud` package on pub.dev (version 3.3.9) is incomplete and missing required header files (`opus/opus.h`, `vorbis/codec.h`), causing build failures.

**Current Workaround**: This package uses `flutter_soloud` from the GitHub repository instead of pub.dev. The working version is commit `28435a2bda6c0685b98d1fb5846471bd071ac925`.

**Important**: Due to Windows path length limitations during CMake compilation, we cannot pin the exact commit hash using `ref:` in `pubspec.yaml`. The full commit hash in the cache directory path causes build failures for release builds.

**Recommended Configuration**:

Option 1 - Use GitHub without pinning (current approach):
```yaml
flutter_soloud:
  git:
    url: https://github.com/alnitak/flutter_soloud.git
    # Using commit 28435a2 (cannot pin due to Windows path length issues)
```

Option 2 - Use local path (for Windows users experiencing path issues):
```yaml
flutter_soloud:
  path: path/to/local/flutter_soloud
  # Local copy of commit 28435a2bda6c0685b98d1fb5846471bd071ac925
```

If you encounter build errors mentioning missing header files or path length issues, use Option 2 with a local clone of the flutter_soloud repository.

## Usage

### Basic Usage

The library requires you to provide a `File` object. Here's a complete example with file picking:

```dart
import 'package:flutter/material.dart';
import 'package:azul_video_editor/azul_video_editor.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

Future<void> openEditor(BuildContext context) async {
  // Pick a media file
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: [
      'mp4', 'mov', 'avi', 'mkv',  // Video formats
      'mp3', 'wav', 'aac', 'flac',  // Audio formats
    ],
  );

  if (result != null && result.files.single.path != null) {
    File mediaFile = File(result.files.single.path!);

    // Open the editor
    final editorResult = await AzulVideoEditor.openEditor(context, mediaFile);

    if (editorResult != null && editorResult['success'] == 'true') {
      final tempFilePath = editorResult['path'];
      print('Media edited successfully: $tempFilePath');

      // Handle the temp file (rename, move, etc.)
      // The library returns a temp file - you decide what to do with it
    } else {
      // Handle error
      print('Error: ${editorResult?['error']}');
    }
  }
}
```

### Return Value Structure

The editor returns a `Map<String, String>?` with the following keys:

| Key | Description |
|-----|-------------|
| `success` | `'true'` if export succeeded, `'false'` otherwise |
| `path` | Path to the temp exported file (only if success is true) |
| `error` | Error message (only if success is false) |
| `logFilePath` | Path to FFmpeg log file for debugging |

### Handling the Result

```dart
final result = await AzulVideoEditor.openEditor(context, mediaFile);

if (result == null) {
  // User cancelled editing
  return;
}

if (result['success'] == 'true') {
  final tempFilePath = result['path']!;

  // The library saved to a temp file with format: yyyyMMdd_temp.ext
  // Now you can:
  // 1. Show a dialog to get final filename from user
  // 2. Rename/move the file
  // 3. Upload it
  // 4. etc.

  final finalPath = await _showSaveDialog(tempFilePath);
  if (finalPath != null) {
    // Rename temp file to final name
    await File(tempFilePath).rename(finalPath);
  }
} else {
  // Export failed
  print('Export failed: ${result['error']}');

  // Check logs for debugging
  if (result['logFilePath']?.isNotEmpty ?? false) {
    final logs = await File(result['logFilePath']!).readAsString();
    print('FFmpeg logs: $logs');
  }
}
```

### With Customization

Customize the editor's appearance and behavior using `AzulEditorOptions`:

```dart
final options = AzulEditorOptions(
  maxDurationMs: 30000, // 30 seconds max duration
  title: 'My Media Editor',
  // Color customization (all colors are fully customizable)
  primaryColor: Colors.purple,
  backgroundColor: Colors.black,
  videoBackgroundColor: Colors.grey[900]!,
  markerBorderColor: Colors.green, // Color of selection marker borders
  slideAreaColor: Colors.yellow.withOpacity(0.3),
  // Layout customization
  thumbnailSize: 30,
  aspectRatio: 16 / 9, // Force 16:9 aspect ratio for videos
  showDuration: true,
  videoMargin: 20.0,
  videoRadius: 10.0,
  saveSubfolder: 'myapp', // Save to Music/myapp or Movies/myapp
);

final result = await AzulVideoEditor.openEditor(
  context,
  mediaFile,
  options: options,
);
```

### Subfolder Organization

Use the `saveSubfolder` option to organize exported files:

```dart
final options = AzulEditorOptions(
  saveSubfolder: 'myapp',
);

final result = await AzulVideoEditor.openEditor(context, mediaFile, options: options);

// Files will be saved to:
// - Audio: Music/myapp/20251025_temp.mp3
// - Video: Movies/myapp/20251025_temp.mp4
// - iOS: Documents/myapp/20251025_temp.mp4
```

## Internationalization (i18n)

Azul Video Editor supports full customization of all UI strings through the `AzulEditorStrings` class. This allows you to translate the interface into any language.

### Available Strings

All UI text can be customized through `AzulEditorStrings`:

```dart
class AzulEditorStrings {
  // App/Editor
  final String title;
  final String saveButtonText;

  // Menu buttons
  final String playMenuLabel;
  final String zoomMenuLabel;
  final String markerMenuLabel;
  final String actionsMenuLabel;

  // Play menu items
  final String playAll;
  final String playSelection;
  final String playFromHere;
  final String playPause;
  final String playResume;
  final String playStop;

  // Zoom menu items
  final String zoomSelection;
  final String zoomAll;

  // Marker menu items
  final String markerStartToBeginning;
  final String markerEndToMax;
  final String markerStartAt;
  final String markerEndAt;

  // Actions menu items
  final String actionsSave;

  // Duration display
  final String durationStart;
  final String durationLabel;
  final String durationEnd;

  // Status messages
  final String statusNoMediaSelected;
  final String statusVideoSelected;
  final String statusAudioSelected;
  final String statusMediaSelected;
  final String statusUnsupportedMedia;
  final String statusErrorInitializing;
  final String statusGeneratingThumbnails;
  final String statusGeneratingWaveforms;
  final String statusReadyToEdit;
  final String statusErrorGenerating;
  final String statusProcessingAudio;
  final String statusProcessingVideo;
  final String statusAudioSaved;
  final String statusVideoSaved;
  final String statusErrorSavingAudio;
  final String statusErrorSavingMedia;

  // Saving overlay
  final String savingAudio;
  final String savingVideo;

  // Error messages
  final String errorInvalidDuration;
  final String errorNoLogs;
  final String errorOutputEmpty;
  final String errorFFmpegFailed;
}
```

### Spanish Translation Example

```dart
final spanishStrings = AzulEditorStrings(
  title: 'Editor de Medios',
  saveButtonText: 'Guardar',

  playMenuLabel: 'reproducir',
  zoomMenuLabel: 'zoom',
  markerMenuLabel: 'marcador',
  actionsMenuLabel: 'acciones',

  playAll: 'Todo',
  playSelection: 'Selección',
  playFromHere: 'Desde Aquí',
  playPause: 'Pausar',
  playResume: 'Reanudar',
  playStop: 'Detener',

  zoomSelection: 'Selección',
  zoomAll: 'Todo',

  markerStartToBeginning: 'Inicio → 0:00',
  markerEndToMax: 'Fin → Máx',
  markerStartAt: 'Inicio @ ',
  markerEndAt: 'Fin @ ',

  actionsSave: 'Guardar Selección',

  durationStart: 'Inicio:',
  durationLabel: 'Duración:',
  durationEnd: 'Fin:',

  savingAudio: 'Guardando audio...',
  savingVideo: 'Guardando video...',
);

final options = AzulEditorOptions(
  strings: spanishStrings,
  title: 'Editor de Medios', // Also set in options for consistency
);

final result = await AzulVideoEditor.openEditor(context, mediaFile, options: options);
```

### French Translation Example

```dart
final frenchStrings = AzulEditorStrings(
  title: 'Éditeur de Médias',
  playMenuLabel: 'lecture',
  zoomMenuLabel: 'zoom',
  markerMenuLabel: 'marqueur',
  actionsMenuLabel: 'actions',

  playAll: 'Tout',
  playSelection: 'Sélection',
  playFromHere: 'Depuis Ici',
  playPause: 'Pause',
  playResume: 'Reprendre',
  playStop: 'Arrêter',

  actionsSave: 'Enregistrer Sélection',

  savingAudio: 'Enregistrement audio...',
  savingVideo: 'Enregistrement vidéo...',
);
```

## Configuration Options

Customize the editor with `AzulEditorOptions`:

| Option | Type | Description | Default Value |
|--------|------|-------------|---------------|
| `maxDurationMs` | `int` | Maximum media duration in milliseconds | `15000` (15 seconds) |
| `showDuration` | `bool` | Show duration info (start, duration, end) | `true` |
| `videoMargin` | `double` | Margin around the media player | `16.0` |
| `videoRadius` | `double` | Border radius for the media player | `12.0` |
| `slideAreaColor` | `Color` | Color of the slider area in timeline | `Color(0x4D2196F3)` (blue with transparency) |
| `title` | `String` | Title displayed on the editor page | `'Video Editor'` |
| `titleStyle` | `TextStyle?` | Text style for the title | `null` |
| `primaryColor` | `Color` | Primary color for UI elements | `Colors.blue` |
| `backgroundColor` | `Color` | Background color of the editor | `Color(0xFF1E1E1E)` |
| `videoBackgroundColor` | `Color` | Background behind the media player | `Color(0xFF121212)` |
| `markerBorderColor` | `Color` | Color of the selection marker borders | `Colors.blue` |
| `saveButtonWidget` | `Widget?` | Custom save button widget | `null` |
| `saveButtonText` | `String` | Text for the save button | `'Save'` |
| `saveButtonTextColor` | `Color` | Color of save button text | `Colors.white` |
| `thumbnailSize` | `int` | Base size for timeline thumbnails | `20` |
| `thumbnailGenerateText` | `String` | Text shown while generating thumbnails | `'Generating thumbnails...'` |
| `aspectRatio` | `double?` | Force specific aspect ratio for video | `null` (original ratio) |
| `leadingWidget` | `Widget?` | Custom leading widget (back button) | `null` |
| `timelineMargin` | `EdgeInsets` | Margin around the timeline | `EdgeInsets.symmetric(horizontal: 16)` |
| `strings` | `AzulEditorStrings` | Localized UI strings (i18n) | `AzulEditorStrings()` (English) |
| `saveSubfolder` | `String?` | Subfolder for organizing saved files | `null` |

## Save Workflow

The library uses a temp file workflow for maximum flexibility:

1. **User edits media** in the editor
2. **Library exports** to temp file with format: `yyyyMMdd_temp.ext`
   - Audio: Saved to `Music/` (or `Music/subfolder` if specified)
   - Video: Saved to `Movies/` (or `Movies/subfolder` if specified)
   - iOS: Saved to `Documents/` (or `Documents/subfolder` if specified)
3. **Library returns** the temp file path in the result Map
4. **Your app decides** what to do:
   - Show save dialog to get filename from user
   - Rename the temp file
   - Move it to a different location
   - Upload it
   - Delete it if user cancels

### Example Save Dialog Implementation

```dart
Future<String?> _showSaveDialog(String tempFilePath) async {
  final extension = path.extension(tempFilePath);
  final filename = await showDialog<String>(
    context: context,
    builder: (context) => SaveFilenameDialog(
      suggestedFilename: 'my_media',
      fileExtension: extension,
    ),
  );

  if (filename == null) {
    // User cancelled - delete temp file
    await File(tempFilePath).delete();
    return null;
  }

  // Rename temp file to user's chosen name
  final directory = path.dirname(tempFilePath);
  final finalPath = path.join(directory, '$filename$extension');

  return finalPath;
}
```

## Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:azul_video_editor/azul_video_editor.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class MediaEditorScreen extends StatefulWidget {
  @override
  _MediaEditorScreenState createState() => _MediaEditorScreenState();
}

class _MediaEditorScreenState extends State<MediaEditorScreen> {
  String? _editedMediaPath;
  String? _errorMessage;

  Future<void> _openEditor() async {
    // Pick media file
    final pickedFile = await _pickMediaFile();
    if (pickedFile == null) return;

    // Configure editor
    final options = AzulEditorOptions(
      maxDurationMs: 30000,
      title: 'Media Editor',
      primaryColor: Colors.purple,
      saveSubfolder: 'myapp',
      strings: AzulEditorStrings(
        playMenuLabel: 'play',
        actionsSave: 'Save Selection',
      ),
    );

    // Open editor
    final result = await AzulVideoEditor.openEditor(
      context,
      pickedFile,
      options: options,
    );

    // Handle result
    if (result != null) {
      await _handleEditorResult(result, pickedFile);
    }
  }

  Future<File?> _pickMediaFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp4', 'mov', 'avi', 'mkv',
        'mp3', 'wav', 'aac', 'flac',
      ],
    );

    if (result != null && result.files.single.path != null) {
      return File(result.files.single.path!);
    }
    return null;
  }

  Future<void> _handleEditorResult(
    Map<String, String> result,
    File originalFile,
  ) async {
    if (result['success'] == 'true') {
      final tempFilePath = result['path']!;
      final originalName = path.basenameWithoutExtension(originalFile.path);

      // Show save dialog
      final finalPath = await _showSaveDialog(tempFilePath, originalName);

      if (finalPath != null) {
        setState(() {
          _editedMediaPath = finalPath;
          _errorMessage = null;
        });
      } else {
        // User cancelled - delete temp file
        await File(tempFilePath).delete();
      }
    } else {
      setState(() {
        _errorMessage = result['error'];
        _editedMediaPath = null;
      });
    }
  }

  Future<String?> _showSaveDialog(String tempFilePath, String suggestedName) async {
    final extension = path.extension(tempFilePath);
    // Show your custom dialog here
    // Return final path or null if cancelled
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Media Editor Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _openEditor,
              child: Text('Open Media Editor'),
            ),
            if (_errorMessage != null) ...[
              SizedBox(height: 20),
              Text('Error: $_errorMessage', style: TextStyle(color: Colors.red)),
            ],
            if (_editedMediaPath != null) ...[
              SizedBox(height: 20),
              Text('Saved to: $_editedMediaPath'),
            ],
          ],
        ),
      ),
    );
  }
}
```

## Example

Check the `example/` folder for a complete Flutter app demonstrating how to integrate Azul Video Editor with save dialogs, error handling, and file management. To run the example:

```bash
cd example
flutter run
```

## Contributing

Contributions are welcome! Please submit issues or pull requests to the [GitHub repository](https://github.com/BenjaminKobjolke/azul_video_and_audio_editor).

## License

This package is licensed under the [MIT License](https://github.com/BenjaminKobjolke/azul_video_and_audio_editor/blob/main/LICENSE).

---

## 📧 Authors

- Fork maintained by [Benjamin Kobjolke](https://github.com/BenjaminKobjolke)
- Originally created by [Mouad Zizi](https://github.com/azulmouad)

## ⭐ Show Your Support

If you find Azul Video Editor helpful, please give it a ⭐ on [GitHub](https://github.com/BenjaminKobjolke/azul_video_and_audio_editor)! Your support helps others discover the package and encourages ongoing development.

## Acknowledgments

A special thanks to the creator of [easy_video_editor](https://pub.dev/packages/easy_video_editor) for their foundational work. Azul Video Editor was built upon the inspiration and capabilities of this package, and it wouldn't have been possible without it!
