class TmdbSearchResult {
  final int tmdbId;
  final String mediaType;
  final String title;
  final int? year;
  final String? posterUrl;
  final String? overview;

  TmdbSearchResult({
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    this.year,
    this.posterUrl,
    this.overview,
  });

  factory TmdbSearchResult.fromTmdbJson(Map<String, dynamic> json) {
    final mediaType = json['media_type'] as String? ?? 'movie';
    final isTv = mediaType == 'tv';
    final date = (isTv ? json['first_air_date'] : json['release_date']) as String?;

    return TmdbSearchResult(
      tmdbId: json['id'] as int,
      mediaType: mediaType,
      title: (isTv ? json['name'] : json['title']) as String? ?? '',
      year: (date != null && date.isNotEmpty) ? int.tryParse(date.substring(0, 4)) : null,
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
  final String mediaType;
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
    this.mediaType = 'movie',
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

  bool get isSeries => mediaType == 'tv';

  factory Movie.fromMap(Map<String, dynamic> map) {
    return Movie(
      id: map['id'] as String,
      tmdbId: map['tmdb_id'] as int,
      mediaType: map['media_type'] as String? ?? 'movie',
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

class CastMember {
  final String name;
  final String character;
  final String? profileUrl;

  CastMember({required this.name, required this.character, this.profileUrl});

  factory CastMember.fromTmdbJson(Map<String, dynamic> json) {
    return CastMember(
      name: json['name'] as String? ?? '',
      character: json['character'] as String? ?? '',
      profileUrl: json['profile_path'] != null
          ? 'https://image.tmdb.org/t/p/w185${json['profile_path']}'
          : null,
    );
  }
}

class WatchProvider {
  final String name;
  final String logoUrl;

  WatchProvider({required this.name, required this.logoUrl});

  factory WatchProvider.fromTmdbJson(Map<String, dynamic> json) {
    return WatchProvider(
      name: json['provider_name'] as String? ?? '',
      logoUrl: 'https://image.tmdb.org/t/p/w92${json['logo_path']}',
    );
  }
}

/// Full title details fetched fresh from TMDB for the movie detail page —
/// not persisted, since cast/trailer rarely change but streaming
/// availability does, so this is always re-fetched rather than cached.
class MovieDetails {
  final int tmdbId;
  final String mediaType;
  final String title;
  final int? year;
  final String? posterUrl;
  final String? backdropUrl;
  final String? synopsis;
  final int? runtimeMinutes;
  final List<String> genres;
  final String? director;
  final String? trailerUrl;
  final List<CastMember> cast;
  final List<WatchProvider> watchProviders;

  MovieDetails({
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    this.year,
    this.posterUrl,
    this.backdropUrl,
    this.synopsis,
    this.runtimeMinutes,
    this.genres = const [],
    this.director,
    this.trailerUrl,
    this.cast = const [],
    this.watchProviders = const [],
  });

  bool get isSeries => mediaType == 'tv';

  factory MovieDetails.fromTmdbJson(Map<String, dynamic> json) {
    final mediaType = json['media_type'] as String? ?? 'movie';
    final isTv = mediaType == 'tv';
    final date = (isTv ? json['first_air_date'] : json['release_date']) as String?;

    final crew = (json['credits']?['crew'] as List?) ?? [];
    String? director;
    if (isTv) {
      final creators = (json['created_by'] as List?) ?? [];
      if (creators.isNotEmpty) {
        director = creators.map((c) => c['name'] as String).join(', ');
      }
    } else {
      director = crew.cast<Map<String, dynamic>>().firstWhere(
            (member) => member['job'] == 'Director',
            orElse: () => const {},
          )['name'] as String?;
    }

    final videos = (json['videos']?['results'] as List?) ?? [];
    final trailer = videos.cast<Map<String, dynamic>>().firstWhere(
          (video) => video['type'] == 'Trailer' && video['site'] == 'YouTube',
          orElse: () => const {},
        )['key'] as String?;

    final cast = ((json['credits']?['cast'] as List?) ?? [])
        .cast<Map<String, dynamic>>()
        .take(12)
        .map(CastMember.fromTmdbJson)
        .toList();

    final providersBr = json['watch/providers']?['results']?['BR'] as Map<String, dynamic>?;
    final providerLists = [
      ...(providersBr?['flatrate'] as List? ?? []),
      ...(providersBr?['ads'] as List? ?? []),
      ...(providersBr?['free'] as List? ?? []),
    ];
    final seenProviders = <String>{};
    final watchProviders = <WatchProvider>[];
    for (final p in providerLists.cast<Map<String, dynamic>>()) {
      final provider = WatchProvider.fromTmdbJson(p);
      if (seenProviders.add(provider.name)) watchProviders.add(provider);
    }

    int? runtimeMinutes;
    if (isTv) {
      final episodeRunTimes = (json['episode_run_time'] as List?)?.cast<int>() ?? [];
      runtimeMinutes = episodeRunTimes.isNotEmpty ? episodeRunTimes.first : null;
    } else {
      runtimeMinutes = json['runtime'] as int?;
    }

    return MovieDetails(
      tmdbId: json['id'] as int,
      mediaType: mediaType,
      title: (isTv ? json['name'] : json['title']) as String? ?? '',
      year: (date != null && date.isNotEmpty) ? int.tryParse(date.substring(0, 4)) : null,
      posterUrl: json['poster_path'] != null
          ? 'https://image.tmdb.org/t/p/w342${json['poster_path']}'
          : null,
      backdropUrl: json['backdrop_path'] != null
          ? 'https://image.tmdb.org/t/p/w780${json['backdrop_path']}'
          : null,
      synopsis: json['overview'] as String?,
      runtimeMinutes: runtimeMinutes,
      genres: ((json['genres'] as List?) ?? [])
          .map((g) => g['name'] as String)
          .toList(),
      director: director,
      trailerUrl: trailer != null ? 'https://www.youtube.com/watch?v=$trailer' : null,
      cast: cast,
      watchProviders: watchProviders,
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
