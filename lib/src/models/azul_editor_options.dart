import 'package:flutter/material.dart';
import 'azul_editor_strings.dart';

/// Configuration options for the AzulVideoEditor
class AzulEditorOptions {
  /// Maximum duration in milliseconds for video trimming
  final int maxDurationMs;

  ///Show Duration Video ( Start , Duration , End )
  final bool showDuration;

  /// Video Margin
  final double videoMargin;

  /// Video Radius
  final double videoRadius;

  /// Video Slider Area Color
  final Color slideAreaColor;

  /// Title for the editor page
  final String title;

  /// Title Style Text
  final TextStyle? titleStyle;

  /// Primary color used for UI elements
  final Color primaryColor;

  /// Background color for the editor
  final Color backgroundColor;

  /// Background color for the video player area
  final Color videoBackgroundColor;

  /// Color for the marker borders in the waveform
  final Color markerBorderColor;

  /// Color for the selected region overlay in the waveform
  final Color selectedRegionColor;

  /// Color for the waveform visualization
  final Color waveformColor;

  /// Custom save button widget
  final Widget? saveButtonWidget;

  /// Text for the save button
  final String saveButtonText;

  /// Color of the save button text
  final Color saveButtonTextColor;

  /// Size of the thumbnails in the timeline
  final int thumbnailSize;

  /// Thumbnail Generate Text
  final String thumbnailGenerateText;

  /// Aspect ratio for the video player (null for original aspect ratio)
  final double? aspectRatio;

  /// Leading IconButton Widget
  final Widget? leadingWidget;

  /// Timeline Margin
  final EdgeInsets timelineMargin;

  /// Localized strings for the editor UI
  final AzulEditorStrings strings;

  /// Optional subfolder path for saving files (e.g., "myapp" creates Music/myapp/)
  final String? saveSubfolder;

  const AzulEditorOptions({
    this.maxDurationMs = 15000,
    this.title = 'Media Editor',
    this.primaryColor = Colors.blue,
    this.backgroundColor = const Color(0xFF1E1E1E),
    this.videoBackgroundColor = const Color(0xFF121212),
    this.markerBorderColor = Colors.blue,
    this.selectedRegionColor = const Color(0x33FFFFFF),
    this.waveformColor = Colors.yellowAccent,
    this.saveButtonWidget,
    this.saveButtonText = 'Save',
    this.saveButtonTextColor = Colors.white,
    this.thumbnailSize = 20,
    this.aspectRatio,
    this.showDuration = true,
    this.videoMargin = 16.0,
    this.videoRadius = 12.0,
    this.slideAreaColor = const Color(0x4D2196F3),
    this.leadingWidget,
    this.titleStyle,
    this.thumbnailGenerateText = "Generating thumbnails...",
    this.timelineMargin = const EdgeInsets.symmetric(horizontal: 16),
    this.strings = const AzulEditorStrings(),
    this.saveSubfolder,
  });
}
