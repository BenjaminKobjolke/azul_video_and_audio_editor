# Azul Video Editor

A Flutter package for seamless video editing with powerful trimming capabilities. Azul Video Editor provides an intuitive interface for trimming videos, previewing edits in real-time, and customizing the editing experience.

## Features

- **Video Trimming**: Easily trim videos to your desired length.
- **Auto File Picking**: Automatically open a file picker to select videos.
- **Real-Time Preview**: Preview edits instantly as you adjust the timeline.
- **Timeline with Thumbnails**: Navigate videos with a thumbnail-based timeline.
- **Customizable UI**: Tailor colors, text, and aspect ratios to match your app.
- **Easy Integration**: Simple API for quick setup in any Flutter project.

## Screenshots

![Video Editor Demo](https://github.com/azulmouad/azul_video_editor/raw/main/screenshots/screenshot.gif)


## Installation

Add the package to your project by including it in your `pubspec.yaml`:

```yaml
dependencies:
  azul_video_editor: ^0.0.1
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
<string>This app requires access to the photo library for video editing.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>This app requires access to the photo library to save edited videos.</string>
```

Ensure your `Podfile` (in `ios/Podfile`) specifies at least iOS 13.0:

```ruby
platform :ios, '13.0'
```

Run `pod install` in the `ios/` directory to update dependencies:

```bash
cd ios && pod install
```

## Usage

Azul Video Editor offers a flexible API for integrating video editing into your Flutter app. Below are examples of common use cases.

### Basic Usage (Auto Pick Video)

Open the editor with a single line of code. The file picker opens automatically, and the result is the path to the edited video:

```dart
import 'package:flutter/material.dart';
import 'package:azul_video_editor/azul_video_editor.dart';

void openEditor(BuildContext context) async {
  // Open the editor and get the result
  final String? result = await AzulVideoEditor.openEditor(context);

  if (result != null) {
    print('Edited video path: $result');
  }
}
```

### Manual Video Selection

Disable auto-pick to show a video selection button:

```dart
final String? result = await AzulVideoEditor.openEditor(
  context,
  autoPickVideo: false,
);

if (result != null) {
  print('Edited video path: $result');
}
```

### With Customization

Customize the editor’s appearance and behavior using `AzulEditorOptions`:

```dart
final options = AzulEditorOptions(
  maxDurationMs: 30000, // 30 seconds max duration
  title: 'My Video Editor',
  primaryColor: Colors.purple,
  backgroundColor: Colors.black,
  videoBackgroundColor: Colors.grey[900]!,
  saveButtonText: 'Export Video',
  thumbnailSize: 30,
  aspectRatio: 16 / 9, // Force 16:9 aspect ratio
  showDuration: true,
  videoMargin: 20.0,
  videoRadius: 10.0,
  slideAreaColor: Colors.yellow,
);

final String? result = await AzulVideoEditor.openEditor(
  context,
  options: options,
);

if (result != null) {
  print('Edited video path: $result');
}
```

### With an Initial Video File

If you already have a video file, pass it directly to the editor:

```dart
import 'dart:io';

File videoFile = File('/path/to/video.mp4');

final String? result = await AzulVideoEditor.openEditor(
  context,
  initialVideoFile: videoFile,
);

if (result != null) {
  print('Edited video path: $result');
}
```

### Advanced Usage (Widget Integration)

For full control, embed the `AzulVideoEditor` widget in your navigation stack:

```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => AzulVideoEditor(
      options: AzulEditorOptions(
        maxDurationMs: 10000,
        title: 'Custom Editor',
        primaryColor: Colors.blue,
        showDuration: true,
        videoMargin: 16.0,
        videoRadius: 12.0,
        slideAreaColor: Colors.yellow,
      ),
      onVideoSaved: (path) {
        print('Video saved to: $path');
      },
      autoPickVideo: true,
    ),
  ),
);
```

## Configuration Options

Customize the editor with `AzulEditorOptions`:

| Option                     | Description                                                                 | Default Value                     |
|----------------------------|-----------------------------------------------------------------------------|-----------------------------------|
| `maxDurationMs`            | Maximum video duration in milliseconds                                      | `15000` (15 seconds)              |
| `showDuration`             | Show video duration (start, duration, end) in the UI                        | `true`                            |
| `videoMargin`              | Margin around the video player                                              | `16.0`                            |
| `videoRadius`              | Border radius for the video player                                          | `12.0`                            |
| `slideAreaColor`           | Color of the slider area in the timeline                                    | `Colors.yellow`                   |
| `title`                    | Title displayed on the editor page                                          | `'Video Editor'`                  |
| `titleStyle`               | Text style for the title                                                    | `null` (uses default style)       |
| `primaryColor`             | Primary color for UI elements (buttons, sliders, etc.)                      | `Color(0xFF6A11CB)`               |
| `backgroundColor`          | Background color of the editor screen                                       | `Color(0xFF2C3E50)`               |
| `videoBackgroundColor`     | Background color behind the video player                                    | `Color(0xFF1E2430)`               |
| `saveButtonWidget`         | Custom widget for the save button                                           | `null` (uses default button)      |
| `saveButtonText`           | Text for the save button                                                    | `'Save'`                          |
| `saveButtonTextColor`      | Color of the save button’s text                                             | `Colors.white`                    |
| `showSavedSnackbar`        | Show a snackbar after saving the video                                      | `true`                            |
| `thumbnailSize`            | Base size (in pixels) for timeline thumbnails                               | `20`                              |
| `thumbnailGenerateText`    | Text shown while generating thumbnails                                      | `'Generating thumbnails...'`      |
| `aspectRatio`              | Force a specific aspect ratio for the video player                          | `null` (original video ratio)     |
| `leadingWidget`            | Custom leading widget (e.g., back button)                                   | `null` (uses default)             |
| `timelineMargin`           | Margin around the timeline                                                  | `EdgeInsets.symmetric(horizontal: 16)` |

## Example

Check the `example/` folder for a sample Flutter app demonstrating how to integrate Azul Video Editor. To run the example:

```bash
cd example
flutter run
```

## Contributing

Contributions are welcome! Please submit issues or pull requests to the [GitHub repository](https://github.com/azulmouad/azul_video_editor).

## License

This package is licensed under the [MIT License](https://github.com/azulmouad/azul_video_editor/blob/main/LICENSE).

---

## 📧 Author

Created by [Mouad Zizi](https://github.com/azulmouad).

## ⭐ Show Your Support

If you find Azul Video Editor helpful, please give it a ⭐ on [GitHub](https://github.com/azulmouad/azul_video_editor)! Your support helps others discover the package and encourages ongoing development.

## Acknowledgments

A special thanks to the creator of [easy_video_editor](https://pub.dev/packages/easy_video_editor) for their foundational work. Azul Video Editor was built upon the inspiration and capabilities of this package, and it wouldn't have been possible without it!