import '../../movies/domain/movie.dart';

class TopMovie {
  final String movieId;
  final int tmdbId;
  final String title;
  final String? posterUrl;
  final String? backdropUrl;
  final String mediaType;
  final int entryCount;
  final double avgRating;
  final double weightedScore;

  TopMovie({
    required this.movieId,
    required this.tmdbId,
    required this.title,
    this.posterUrl,
    this.backdropUrl,
    required this.mediaType,
    required this.entryCount,
    required this.avgRating,
    required this.weightedScore,
  });

  factory TopMovie.fromMap(Map<String, dynamic> map) {
    return TopMovie(
      movieId: map['movie_id'] as String,
      tmdbId: map['tmdb_id'] as int,
      title: map['title'] as String,
      posterUrl: map['poster_url'] as String?,
      backdropUrl: map['backdrop_url'] as String?,
      mediaType: map['media_type'] as String? ?? 'movie',
      entryCount: (map['entry_count'] as num).toInt(),
      avgRating: (map['avg_rating'] as num).toDouble(),
      weightedScore: (map['weighted_score'] as num).toDouble(),
    );
  }

  Movie toMovie() {
    return Movie(
      id: movieId,
      tmdbId: tmdbId,
      mediaType: mediaType,
      title: title,
      posterUrl: posterUrl,
      backdropUrl: backdropUrl,
    );
  }
}
