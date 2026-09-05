/// Represents a playable audio track (local or remote).
class Track {
  final String id;
  final String title;
  final String artist;
  final String? filePath;
  final String? webUrl;
  final Duration? duration;
  final String? album;
  final String? artworkPath;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    this.filePath,
    this.webUrl,
    this.duration,
    this.album,
    this.artworkPath,
  });

  bool get isLocal => filePath != null && filePath!.trim().isNotEmpty;

  /// Formatted duration string, e.g. "3:45" or "1:02:15"
  String get formattedDuration {
    if (duration == null || duration == Duration.zero) return '--:--';
    final d = duration!;
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60);
    if (d.inHours > 0) {
      final hours = d.inHours;
      final remainingMins = minutes.remainder(60);
      return '$hours:${remainingMins.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  bool get hasArtwork => artworkPath != null && artworkPath!.trim().isNotEmpty;

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? filePath,
    String? webUrl,
    Duration? duration,
    String? album,
    String? artworkPath,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      filePath: filePath ?? this.filePath,
      webUrl: webUrl ?? this.webUrl,
      duration: duration ?? this.duration,
      album: album ?? this.album,
      artworkPath: artworkPath ?? this.artworkPath,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Track &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          filePath == other.filePath &&
          webUrl == other.webUrl;

  @override
  int get hashCode => id.hashCode ^ (filePath?.hashCode ?? 0) ^ (webUrl?.hashCode ?? 0);
}
