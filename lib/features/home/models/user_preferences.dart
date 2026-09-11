/// Model representing a user's completely local music preferences.
class UserPreferences {
  final List<String> languages;
  final List<String> genres;
  final List<String> moods;
  final bool isOnboarded;

  const UserPreferences({
    this.languages = const [],
    this.genres = const [],
    this.moods = const [],
    this.isOnboarded = false,
  });

  bool get isEmpty => languages.isEmpty && genres.isEmpty && moods.isEmpty;

  UserPreferences copyWith({
    List<String>? languages,
    List<String>? genres,
    List<String>? moods,
    bool? isOnboarded,
  }) {
    return UserPreferences(
      languages: languages ?? this.languages,
      genres: genres ?? this.genres,
      moods: moods ?? this.moods,
      isOnboarded: isOnboarded ?? this.isOnboarded,
    );
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw is List) {
        return raw
            .map((e) => e?.toString().trim() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return const [];
    }

    return UserPreferences(
      languages: parseList(json['languages']),
      genres: parseList(json['genres']),
      moods: parseList(json['moods']),
      isOnboarded: json['isOnboarded'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'languages': languages,
      'genres': genres,
      'moods': moods,
      'isOnboarded': isOnboarded,
    };
  }

  /// Available options for user onboarding and preference selection.
  static const List<String> availableLanguages = [
    'English',
    'Hindi',
    'Punjabi',
    'Spanish',
    'Korean',
    'Japanese',
    'Instrumental',
    'Arabic',
    'French',
    'German',
    'Tamil',
    'Telugu',
  ];

  static const List<String> availableGenres = [
    'Pop',
    'Lo-Fi',
    'Hip-Hop',
    'Rock',
    'Electronic',
    'Classical',
    'Bollywood',
    'Acoustic',
    'Indie',
    'R&B',
    'Jazz',
    'Latin',
    'K-Pop',
    'Punjabi',
    'Ambient',
    'Synthwave',
  ];

  static const List<String> availableMoods = [
    'Chill',
    'Focus',
    'Workout',
    'Party',
    'Energy',
    'Relax',
    'Sleep',
    'Commute',
    'Romantic',
  ];
}
