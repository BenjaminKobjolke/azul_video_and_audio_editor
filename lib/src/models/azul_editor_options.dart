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

  const AzulEditorOptions({
    this.maxDurationMs = 15000,
    this.title = 'Video Editor',
    this.primaryColor = const Color(0xFF6A11CB),
    this.backgroundColor = const Color(0xFF2C3E50),
    this.videoBackgroundColor = const Color(0xFF1E2430),
    this.saveButtonWidget,
    this.saveButtonText = 'Save',
    this.saveButtonTextColor = Colors.white,
    this.thumbnailSize = 20,
    this.aspectRatio,
    this.showDuration = true,
    this.videoMargin = 16.0,
    this.videoRadius = 12.0,
    this.slideAreaColor = Colors.yellow,
    this.leadingWidget,
    this.titleStyle,
    this.thumbnailGenerateText = "Generating thumbnails...",
    this.timelineMargin = const EdgeInsets.symmetric(horizontal: 16),
    this.strings = const AzulEditorStrings(),
  });
}
