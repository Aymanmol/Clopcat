enum TrackType { video, audio, text, sticker }

class TimelineTrack {
  final String id;
  final TrackType type;
  final List<TimelineItem> items;

  TimelineTrack({required this.id, required this.type, required this.items});
}

class TimelineItem {
  final String id;
  final String sourcePath; 
  final TrackType type;
  int startMs; 
  int durationMs;
  double scale;
  double offsetX;
  double offsetY;

  int get endMs => startMs + durationMs;

  TimelineItem({
    required this.id,
    required this.sourcePath,
    required this.type,
    required this.startMs,
    required this.durationMs,
    this.scale = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
  });
}
