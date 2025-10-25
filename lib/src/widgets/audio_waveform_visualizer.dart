import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:math' as math;
import 'painters/waveform_painter.dart';
import 'painters/scrollbar_painter.dart';

/// Large waveform visualization widget for audio player (DAW-style)
class AudioWaveformVisualizer extends StatefulWidget {
  final Float32List? samples;
  final bool isWaveformReady;
  final bool waveformExtractionFailed;
  final double startMs;
  final double endMs;
  final double durationMs;
  final double currentPositionMs;
  final double? touchedPositionMs;
  final bool isPlaying;
  final VoidCallback onTogglePlayPause;
  final Function(double positionMs)? onWaveformTouched;
  final double zoomLevel;
  final double? targetScrollOffsetMs; // Target scroll position from parent (e.g., from Zoom Selection)
  final Function(double scrollOffsetMs)? onScrollChanged; // Callback when user scrolls manually
  final Function(double zoomLevel)? onZoomChanged; // Callback when pinch zoom changes zoom level
  final Color backgroundColor;
  final Color waveformColor;
  final Color playbackLineColor;
  final Color touchLineColor;
  final Color markerBorderColor;
  final Color selectedRegionColor;

  const AudioWaveformVisualizer({
    Key? key,
    required this.samples,
    this.isWaveformReady = true,
    this.waveformExtractionFailed = false,
    required this.startMs,
    required this.endMs,
    required this.durationMs,
    required this.currentPositionMs,
    this.touchedPositionMs,
    required this.isPlaying,
    required this.onTogglePlayPause,
    this.onWaveformTouched,
    this.zoomLevel = 1.0,
    this.targetScrollOffsetMs,
    this.onScrollChanged,
    this.onZoomChanged,
    this.backgroundColor = const Color(0xFF2C3E50),
    this.waveformColor = Colors.yellowAccent,
    this.playbackLineColor = Colors.red,
    this.touchLineColor = Colors.cyan,
    this.markerBorderColor = Colors.blue,
    this.selectedRegionColor = const Color(0x33FFFFFF),
  }) : super(key: key);

  @override
  State<AudioWaveformVisualizer> createState() => _AudioWaveformVisualizerState();
}

class _AudioWaveformVisualizerState extends State<AudioWaveformVisualizer> {
  double _currentZoom = 1.0;
  double _scrollOffset = 0.0; // Horizontal scroll position in milliseconds
  final ScrollController _scrollController = ScrollController();

  // Gesture tracking
  int _pointerCount = 0;
  double _lastPinchScale = 1.0;
  Offset? _lastPinchFocal;

  @override
  void initState() {
    super.initState();
    _currentZoom = widget.zoomLevel;
  }

  @override
  void didUpdateWidget(AudioWaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zoomLevel != widget.zoomLevel) {
      setState(() {
        _currentZoom = widget.zoomLevel;
      });
    }
    // Only update scroll when parent explicitly provides a NEW target (e.g., from Zoom Selection)
    // This prevents overriding user's manual scrollbar adjustments
    if (widget.targetScrollOffsetMs != null &&
        widget.targetScrollOffsetMs != oldWidget.targetScrollOffsetMs) {
      setState(() {
        _scrollOffset = widget.targetScrollOffsetMs!;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Convert screen X position to time in milliseconds
  double _screenXToTimeMs(double screenX, double screenWidth) {
    // Calculate visible time window based on zoom
    final visibleDurationMs = widget.durationMs / _currentZoom;

    // Convert screen position to time
    final relativeX = screenX / screenWidth;
    final timeMs = _scrollOffset + (relativeX * visibleDurationMs);

    return timeMs.clamp(0.0, widget.durationMs);
  }

  // Handle one-finger drag - set position
  void _handleOneFingerDrag(Offset localPosition, Size size) {
    if (widget.onWaveformTouched == null) return;

    final timeMs = _screenXToTimeMs(localPosition.dx, size.width);
    widget.onWaveformTouched!(timeMs);
  }

  // Handle two-finger drag - pan the view
  void _handleTwoFingerPan(Offset delta, Size size) {
    if (_currentZoom <= 1.0) return; // No panning when not zoomed

    setState(() {
      // Calculate how much time is represented by the drag delta
      final visibleDurationMs = widget.durationMs / _currentZoom;
      final pixelsPerMs = size.width / visibleDurationMs;
      final timeDeltaMs = -delta.dx / pixelsPerMs;

      // Update scroll offset
      final maxScrollOffset = widget.durationMs - visibleDurationMs;
      _scrollOffset = (_scrollOffset + timeDeltaMs).clamp(0.0, math.max(0, maxScrollOffset));
    });
  }

  // Handle pinch zoom
  void _handlePinchZoom(double scale, Offset focalPoint, Size size) {
    setState(() {
      // Calculate new zoom level
      final newZoom = (_currentZoom * scale).clamp(1.0, 10.0);

      if (newZoom != _currentZoom) {
        // Adjust scroll offset to zoom toward the focal point
        final oldVisibleDuration = widget.durationMs / _currentZoom;
        final newVisibleDuration = widget.durationMs / newZoom;

        // Time at focal point before zoom
        final focalRelativeX = focalPoint.dx / size.width;
        final focalTimeBeforeZoom = _scrollOffset + (focalRelativeX * oldVisibleDuration);

        // Adjust scroll to keep focal point at same position
        _scrollOffset = focalTimeBeforeZoom - (focalRelativeX * newVisibleDuration);
        _scrollOffset = _scrollOffset.clamp(0.0, math.max(0, widget.durationMs - newVisibleDuration));

        _currentZoom = newZoom;

        // Notify parent of zoom change
        if (widget.onZoomChanged != null) {
          widget.onZoomChanged!(newZoom);
        }
      }
    });
  }

  // Build waveform content based on extraction state
  Widget _buildWaveformContent(Size size) {
    // Always render CustomPaint to show markers, even if waveform extraction failed
    // WaveformPainter handles null samples gracefully (draws markers but not waveform)
    return Stack(
      children: [
        // ALWAYS use CustomPaint - WaveformPainter handles null samples gracefully
        CustomPaint(
          painter: WaveformPainter(
            samples: widget.samples, // Can be null if extraction failed - painter will skip waveform but draw markers
            startMs: widget.startMs,
            endMs: widget.endMs,
            durationMs: widget.durationMs,
            currentPositionMs: widget.currentPositionMs,
            touchedPositionMs: widget.touchedPositionMs,
            waveformColor: widget.waveformColor,
            playbackLineColor: widget.playbackLineColor,
            touchLineColor: widget.touchLineColor,
            markerBorderColor: widget.markerBorderColor,
            selectedRegionColor: widget.selectedRegionColor,
            zoomLevel: _currentZoom,
            scrollOffsetMs: _scrollOffset,
          ),
          size: size,
        ),

        // Show spinner only while loading (hide if failed or succeeded)
        if (!widget.isWaveformReady && !widget.waveformExtractionFailed)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      child: Column(
        children: [
          // Waveform display
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);

                return Listener(
                  onPointerDown: (event) {
                    _pointerCount++;
                  },
                  onPointerUp: (event) {
                    _pointerCount--;
                    if (_pointerCount == 0) {
                      _lastPinchScale = 1.0;
                      _lastPinchFocal = null;
                    }
                  },
                  onPointerCancel: (event) {
                    _pointerCount--;
                  },
                  child: GestureDetector(
                    // Use onScale* for all gestures (1 and 2 fingers)
                    onScaleStart: (details) {
                      _lastPinchScale = 1.0;
                      _lastPinchFocal = details.localFocalPoint;

                      // One finger: Start position selection
                      if (_pointerCount == 1 && widget.onWaveformTouched != null) {
                        final timeMs = _screenXToTimeMs(details.localFocalPoint.dx, size.width);
                        widget.onWaveformTouched!(timeMs);
                      }
                    },
                    onScaleUpdate: (details) {
                      if (_pointerCount == 1) {
                        // One finger: Move cyan marker (position selection)
                        if (widget.onWaveformTouched != null) {
                          final timeMs = _screenXToTimeMs(details.localFocalPoint.dx, size.width);
                          widget.onWaveformTouched!(timeMs);
                        }
                      } else if (_pointerCount == 2) {
                        // Two fingers: Handle pinch zoom only
                        final scaleChange = details.scale / _lastPinchScale;
                        final significantScaleChange = (scaleChange - 1.0).abs() > 0.01;

                        if (significantScaleChange) {
                          _handlePinchZoom(scaleChange, details.localFocalPoint, size);
                          _lastPinchScale = details.scale;
                        }
                        _lastPinchFocal = details.localFocalPoint;
                      }
                    },

                    child: _buildWaveformContent(size),
                  ),
                );
              },
            ),
          ),

          // Horizontal scrollbar for panning (only visible when zoomed)
          if (_currentZoom > 1.0)
            Container(
              height: 20,
              color: widget.backgroundColor.withOpacity(0.8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final visibleDurationMs = widget.durationMs / _currentZoom;
                  final maxScrollOffset = widget.durationMs - visibleDurationMs;

                  return GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        // Calculate scroll position from drag
                        final dragRatio = details.localPosition.dx / constraints.maxWidth;
                        _scrollOffset = (dragRatio * widget.durationMs).clamp(0.0, math.max(0, maxScrollOffset));
                      });
                      // Notify parent of manual scroll change
                      if (widget.onScrollChanged != null) {
                        widget.onScrollChanged!(_scrollOffset);
                      }
                    },
                    child: CustomPaint(
                      painter: AudioScrollbarPainter(
                        scrollOffset: _scrollOffset,
                        visibleDuration: visibleDurationMs,
                        totalDuration: widget.durationMs,
                        backgroundColor: Colors.grey.shade800,
                        thumbColor: Colors.grey.shade400,
                      ),
                      size: Size(constraints.maxWidth, 20),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
