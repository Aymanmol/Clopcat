import 'package:flutter/material.dart';
import '../models/timeline_models.dart';

class MultiTrackTimeline extends StatefulWidget {
  final List<TimelineTrack> tracks;
  final int currentPositionMs;
  final Function(int) onPositionChanged;

  const MultiTrackTimeline({
    Key? key,
    required this.tracks,
    required this.currentPositionMs,
    required this.onPositionChanged,
  }) : super(key: key);

  @override
  _MultiTrackTimelineState createState() => _MultiTrackTimelineState();
}

class _MultiTrackTimelineState extends State<MultiTrackTimeline> {
  final double timeToPixelScale = 0.05; 

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      height: 250, 
      child: Stack(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Padding(
                padding: const EdgeInsets.only(top: 30.0, left: 150.0), 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.tracks.map((track) => _buildTrackRow(track)).toList(),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            left: 150, 
            child: Container(
              width: 2,
              color: Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackRow(TimelineTrack track) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      height: 45,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: track.items.map((item) => _buildTrackItem(item)).toList(),
      ),
    );
  }

  Widget _buildTrackItem(TimelineItem item) {
    double leftPosition = item.startMs * timeToPixelScale;
    double itemWidth = item.durationMs * timeToPixelScale;

    return Positioned(
      left: leftPosition,
      width: itemWidth,
      height: 45,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          setState(() {
            int deltaMs = (details.delta.dx / timeToPixelScale).round();
            item.startMs += deltaMs;
            if (item.startMs < 0) item.startMs = 0;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: _getTrackColor(item.type),
            border: Border.all(color: Colors.white30, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          overflow: TextOverflow.ellipsis,
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              item.sourcePath.split('/').last,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Color _getTrackColor(TrackType type) {
    switch (type) {
      case TrackType.video: return Colors.indigo[700]!;
      case TrackType.audio: return Colors.teal[700]!;
      case TrackType.text: return Colors.amber[800]!;
      case TrackType.sticker: return Colors.purple[700]!;
    }
  }
}
