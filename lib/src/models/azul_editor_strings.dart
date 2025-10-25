/// Localized strings for the Azul Video Editor
///
/// All UI text can be customized by providing a custom AzulEditorStrings instance
/// to AzulEditorOptions. This enables full internationalization (i18n) support.
///
/// Example:
/// ```dart
/// AzulEditorOptions(
///   strings: AzulEditorStrings(
///     title: 'Editor de Video',
///     playAll: 'Todo',
///     // ... other strings
///   ),
/// )
/// ```
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
  final String markerStartAt; // "Start @ " (time will be appended)
  final String markerEndAt;   // "End @ " (time will be appended)

  // Actions menu items
  final String actionsSave;
  final String actionsSaveFrame;

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

  // Empty state
  final String emptyStateTitle;
  final String emptyStateOpeningPicker;
  final String emptyStateTapToSelect;
  final String emptyStateSelectButton;

  // Saving overlay
  final String exportingMedia;

  // Error messages (internal use by library)
  final String errorInvalidDuration;
  final String errorNoLogs;
  final String errorOutputEmpty;
  final String errorFFmpegFailed;
  final String errorAV1NotSupported;

  // Unsaved changes dialog
  final String discardChangesTitle;
  final String discardChangesMessage;
  final String discardChangesCancel;
  final String discardChangesDiscard;

  const AzulEditorStrings({
    // Default English strings
    this.title = 'Video Editor',
    this.saveButtonText = 'Save',

    this.playMenuLabel = 'play',
    this.zoomMenuLabel = 'zoom',
    this.markerMenuLabel = 'marker',
    this.actionsMenuLabel = 'actions',

    this.playAll = 'All',
    this.playSelection = 'Selection',
    this.playFromHere = 'From Here',
    this.playPause = 'Pause',
    this.playResume = 'Resume',
    this.playStop = 'Stop',

    this.zoomSelection = 'Selection',
    this.zoomAll = 'All',

    this.markerStartToBeginning = 'Start → 0:00',
    this.markerEndToMax = 'End → Max',
    this.markerStartAt = 'Start @ ',
    this.markerEndAt = 'End @ ',

    this.actionsSave = 'Save Selection',
    this.actionsSaveFrame = 'Save Frame',

    this.durationStart = 'Start:',
    this.durationLabel = 'Duration:',
    this.durationEnd = 'End:',

    this.statusNoMediaSelected = 'No media selected',
    this.statusVideoSelected = 'Video selected',
    this.statusAudioSelected = 'Audio selected',
    this.statusMediaSelected = 'Media selected',
    this.statusUnsupportedMedia = 'Unsupported media type',
    this.statusErrorInitializing = 'Error initializing media:',
    this.statusGeneratingThumbnails = 'Generating thumbnails...',
    this.statusGeneratingWaveforms = 'Generating waveforms...',
    this.statusReadyToEdit = 'Ready to edit',
    this.statusErrorGenerating = 'Error generating visual data:',
    this.statusProcessingAudio = 'Processing audio...',
    this.statusProcessingVideo = 'Processing video...',
    this.statusAudioSaved = 'Audio saved to:',
    this.statusVideoSaved = 'Video saved to:',
    this.statusErrorSavingAudio = 'Error saving audio:',
    this.statusErrorSavingMedia = 'Error saving media:',

    this.emptyStateTitle = 'No Media Selected',
    this.emptyStateOpeningPicker = 'Opening file picker...',
    this.emptyStateTapToSelect = 'Tap "Select Media" to get started',
    this.emptyStateSelectButton = 'Select Media',

    this.exportingMedia = 'Exporting media...',

    this.errorInvalidDuration = 'Invalid duration:',
    this.errorNoLogs = 'No logs available',
    this.errorOutputEmpty = 'Output file is empty (0 bytes). Check logs for FFmpeg errors.',
    this.errorFFmpegFailed = 'FFmpeg failed with return code:',
    this.errorAV1NotSupported = 'Frame extraction failed. AV1 videos may not be supported on this device.',

    this.discardChangesTitle = 'Discard changes?',
    this.discardChangesMessage = 'You have unsaved changes. Do you want to discard them?',
    this.discardChangesCancel = 'Cancel',
    this.discardChangesDiscard = 'Discard',
  });
}
