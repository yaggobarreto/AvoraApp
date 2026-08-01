/// A TMDB genre offered during onboarding. The ids are TMDB's own, so they
/// can be passed straight to the discover endpoint.
class GenreChoice {
  final int id;
  final String label;
  final String emoji;

  const GenreChoice(this.id, this.label, this.emoji);
}

/// Deliberately a short list. Onboarding competes with the user's patience —
/// a wall of thirty genres gets skipped, and the long tail adds little to a
/// first recommendation.
const genreChoices = <GenreChoice>[
  GenreChoice(28, 'Ação', '💥'),
  GenreChoice(35, 'Comédia', '😂'),
  GenreChoice(18, 'Drama', '🎭'),
  GenreChoice(27, 'Terror', '👻'),
  GenreChoice(10749, 'Romance', '❤️'),
  GenreChoice(878, 'Ficção científica', '🚀'),
  GenreChoice(53, 'Suspense', '🔪'),
  GenreChoice(16, 'Animação', '🎨'),
  GenreChoice(80, 'Crime', '🕵️'),
  GenreChoice(12, 'Aventura', '🗺️'),
  GenreChoice(14, 'Fantasia', '🐉'),
  GenreChoice(99, 'Documentário', '🎥'),
];

enum ContentPreference {
  movie('movie', 'Filmes'),
  tv('tv', 'Séries'),
  both('both', 'Os dois');

  final String value;
  final String label;

  const ContentPreference(this.value, this.label);

  static ContentPreference fromValue(String? value) {
    return ContentPreference.values.firstWhere(
      (preference) => preference.value == value,
      orElse: () => ContentPreference.both,
    );
  }
}

class TastePreferences {
  final List<int> genreIds;
  final ContentPreference contentPreference;
  final bool hasOnboarded;

  const TastePreferences({
    this.genreIds = const [],
    this.contentPreference = ContentPreference.both,
    this.hasOnboarded = false,
  });

  /// The discover endpoint takes a single media type, so "both" has to pick
  /// one; movies are the larger and better-rated catalogue on TMDB.
  String get discoverMediaType =>
      contentPreference == ContentPreference.tv ? 'tv' : 'movie';

  factory TastePreferences.fromMap(Map<String, dynamic> map) {
    return TastePreferences(
      genreIds: ((map['preferred_genres'] as List?) ?? const [])
          .map((id) => (id as num).toInt())
          .toList(),
      contentPreference:
          ContentPreference.fromValue(map['content_preference'] as String?),
      hasOnboarded: map['onboarded_at'] != null,
    );
  }
}
