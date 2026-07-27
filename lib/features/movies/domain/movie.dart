class TmdbSearchResult {
  final int tmdbId;
  final String title;
  final int? year;
  final String? posterUrl;
  final String? overview;

  TmdbSearchResult({
    required this.tmdbId,
    required this.title,
    this.year,
    this.posterUrl,
    this.overview,
  });

  factory TmdbSearchResult.fromTmdbJson(Map<String, dynamic> json) {
    final releaseDate = json['release_date'] as String?;
    return TmdbSearchResult(
      tmdbId: json['id'] as int,
      title: json['title'] as String? ?? '',
      year: (releaseDate != null && releaseDate.isNotEmpty)
          ? int.tryParse(releaseDate.substring(0, 4))
          : null,
      posterUrl: json['poster_path'] != null
          ? 'https://image.tmdb.org/t/p/w342${json['poster_path']}'
          : null,
      overview: json['overview'] as String?,
    );
  }
}

class Movie {
  final String id;
  final int tmdbId;
  final String title;
  final int? year;
  final String? posterUrl;
  final String? backdropUrl;
  final String? synopsis;
  final int? runtimeMinutes;
  final List<String> genres;
  final String? director;
  final String? trailerUrl;

  Movie({
    required this.id,
    required this.tmdbId,
    required this.title,
    this.year,
    this.posterUrl,
    this.backdropUrl,
    this.synopsis,
    this.runtimeMinutes,
    this.genres = const [],
    this.director,
    this.trailerUrl,
  });

  factory Movie.fromMap(Map<String, dynamic> map) {
    return Movie(
      id: map['id'] as String,
      tmdbId: map['tmdb_id'] as int,
      title: map['title'] as String,
      year: map['year'] as int?,
      posterUrl: map['poster_url'] as String?,
      backdropUrl: map['backdrop_url'] as String?,
      synopsis: map['synopsis'] as String?,
      runtimeMinutes: map['runtime_minutes'] as int?,
      genres: (map['genres'] as List?)?.cast<String>() ?? const [],
      director: map['director'] as String?,
      trailerUrl: map['trailer_url'] as String?,
    );
  }
}

const watchLocations = [
  'cinema',
  'netflix',
  'prime_video',
  'disney_plus',
  'max',
  'apple_tv',
  'youtube',
  'tv_aberta',
  'tv_a_cabo',
  'dvd_blu_ray',
  'outro',
];

const watchLocationLabels = {
  'cinema': 'Cinema',
  'netflix': 'Netflix',
  'prime_video': 'Prime Video',
  'disney_plus': 'Disney+',
  'max': 'Max',
  'apple_tv': 'Apple TV',
  'youtube': 'YouTube',
  'tv_aberta': 'TV Aberta',
  'tv_a_cabo': 'TV a Cabo',
  'dvd_blu_ray': 'DVD/Blu-ray',
  'outro': 'Outro',
};
