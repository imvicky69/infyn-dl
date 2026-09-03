import 'track.dart';

/// Represents a collection of tracks grouped into a playlist (by folder or metadata).
class MusicPlaylist {
  final String name;
  final List<Track> tracks;
  final String? artworkPath;

  const MusicPlaylist({
    required this.name,
    required this.tracks,
    this.artworkPath,
  });

  int get trackCount => tracks.length;

  Duration get totalDuration {
    var totalMs = 0;
    for (final track in tracks) {
      if (track.duration != null) {
        totalMs += track.duration!.inMilliseconds;
      }
    }
    return Duration(milliseconds: totalMs);
  }

  String get formattedTotalDuration {
    final dur = totalDuration;
    if (dur.inMinutes == 0) return '';
    final hours = dur.inHours;
    final mins = dur.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours hr ${mins > 0 ? '$mins min' : ''}'.trim();
    }
    return '$mins min';
  }

  String get formattedTrackCount =>
      '$trackCount ${trackCount == 1 ? 'song' : 'songs'}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MusicPlaylist &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          tracks.length == other.tracks.length;

  @override
  int get hashCode => name.hashCode ^ tracks.length.hashCode;
}
