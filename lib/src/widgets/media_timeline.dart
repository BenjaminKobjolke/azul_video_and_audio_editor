import 'package:flutter/material.dart';
import 'dart:typed_data';

/// Reusable timeline widget for both video thumbnails and audio waveforms
class MediaTimeline extends StatelessWidget {
  final List<Uint8List>? visualData;
  final bool isGenerating;
  final String generatingText;
  final double videoDurationMs;
  final double startMs;
  final double endMs;
  final double currentPlaybackPositionMs;
  final ScrollController scrollController;
  final double scrollPosition;
  final double thumbnailTotalWidth;
  final Color slideAreaColor;
  final Function(DragUpdateDetails) onSegmentDrag;
  final Function(DragUpdateDetails) onStartMarkerDrag;
  final Function(DragUpdateDetails) onEndMarkerDrag;
  final EdgeInsets margin;

  const MediaTimeline({
    Key? key,
    required this.visualData,
    required this.isGenerating,
    required this.generatingText,
    required this.videoDurationMs,
    required this.startMs,
    required this.endMs,
    required this.currentPlaybackPositionMs,
    required this.scrollController,
    required this.scrollPosition,
    required this.thumbnailTotalWidth,
    required this.slideAreaColor,
    required this.onSegmentDrag,
    required this.onStartMarkerDrag,
    required this.onEndMarkerDrag,
    required this.margin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      margin: margin,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Note: viewportWidth calculation moved to parent widget
          return NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              return true;
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Scrollable Visual Data (Thumbnails or Waveforms)
                SingleChildScrollView(
                  controller: scrollController,
                  scrollDirection: Axis.horizontal,
                  child: visualData != null
                      ? SizedBox(
                          width: thumbnailTotalWidth,
                          height: 80,
                          child: Row(
                            children: List.generate(
                              visualData!.length,
                              (index) => Container(
                                width: 30,
                                height: 80,
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: MemoryImage(visualData![index]),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : isGenerating
                          ? Center(
                              child: Text(
                                generatingText,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            )
                          : Container(),
                ),

                // Show loading indicator while generating
                if (isGenerating)
                  const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),

                // Only show the segment UI if visual data is ready
                if (visualData != null) ...[
                  // Draggable Segment with Adjusted Positioning
                  Positioned(
                    left: ((startMs / videoDurationMs) * thumbnailTotalWidth) -
                        scrollPosition,
                    child: GestureDetector(
                      onHorizontalDragUpdate: onSegmentDrag,
                      child: Container(
                        width: ((endMs - startMs) / videoDurationMs) *
                            thumbnailTotalWidth,
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: slideAreaColor,
                            width: 2,
                          ),
                          color: Colors.yellow.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),

                  // Start Marker [
                  Positioned(
                    left: ((startMs / videoDurationMs) * thumbnailTotalWidth -
                            10) -
                        scrollPosition,
                    child: GestureDetector(
                      onHorizontalDragUpdate: onStartMarkerDrag,
                      child: Container(
                        width: 20,
                        height: 80,
                        color: Colors.grey.shade900,
                        child: const Center(
                          child: Text(
                            '[',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // End Marker ]
                  Positioned(
                    left: ((endMs / videoDurationMs) * thumbnailTotalWidth) -
                        scrollPosition,
                    child: GestureDetector(
                      onHorizontalDragUpdate: onEndMarkerDrag,
                      child: Container(
                        width: 20,
                        height: 80,
                        color: Colors.grey.shade900,
                        child: const Center(
                          child: Text(
                            ']',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Playback Position Indicator
                  Positioned(
                    left: ((currentPlaybackPositionMs / videoDurationMs) *
                            thumbnailTotalWidth) -
                        scrollPosition,
                    child: Container(
                      width: 2,
                      height: 80,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
