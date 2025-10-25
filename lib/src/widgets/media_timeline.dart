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
  final double height;
  final double segmentHeight;

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
    this.height = 100.0,
    this.segmentHeight = 80.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use actual thumbnail width if available, otherwise use viewport width as fallback
    final effectiveWidth = thumbnailTotalWidth > 0 ? thumbnailTotalWidth : 800.0;

    return Container(
      height: height,
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
                          height: segmentHeight,
                          child: Row(
                            children: List.generate(
                              visualData!.length,
                              (index) => Container(
                                width: 30,
                                height: segmentHeight,
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
                          ? // Show grey placeholder bars while generating
                          SizedBox(
                              width: effectiveWidth,
                              height: segmentHeight,
                              child: Container(
                                color: Colors.grey.shade800,
                                child: Center(
                                  child: Text(
                                    generatingText,
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              width: effectiveWidth,
                              height: segmentHeight,
                              color: Colors.grey.shade900,
                            ),
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

                // Show segment UI as soon as we have duration info (don't wait for thumbnails)
                if (videoDurationMs > 0) ...[
                  // Draggable Segment with Adjusted Positioning
                  Positioned(
                    left: ((startMs / videoDurationMs) * effectiveWidth) -
                        scrollPosition,
                    child: GestureDetector(
                      behavior: HitTestBehavior.deferToChild,
                      onHorizontalDragUpdate: onSegmentDrag,
                      child: Container(
                        width: ((endMs - startMs) / videoDurationMs) *
                            effectiveWidth,
                        height: segmentHeight,
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
                    left: ((startMs / videoDurationMs) * effectiveWidth -
                            10) -
                        scrollPosition,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: onStartMarkerDrag,
                      child: Container(
                        width: 30, // Wider hit area
                        height: segmentHeight,
                        color: Colors.grey.shade900,
                        padding: const EdgeInsets.only(left: 5),
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
                    left: ((endMs / videoDurationMs) * effectiveWidth - 10) -
                        scrollPosition,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: onEndMarkerDrag,
                      child: Container(
                        width: 30, // Wider hit area
                        height: segmentHeight,
                        color: Colors.grey.shade900,
                        padding: const EdgeInsets.only(right: 5),
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
                            effectiveWidth) -
                        scrollPosition,
                    child: Container(
                      width: 2,
                      height: segmentHeight,
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
