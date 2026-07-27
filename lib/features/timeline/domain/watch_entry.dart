import '../../movies/domain/movie.dart';

class WatchEntry {
  final String id;
  final Movie movie;
  final DateTime watchedAt;
  final String watchLocation;
  final int timesWatched;
  final double? rating;
  final String? comment;
  final List<String> emojis;

  WatchEntry({
    required this.id,
    required this.movie,
    required this.watchedAt,
    required this.watchLocation,
    required this.timesWatched,
    this.rating,
    this.comment,
    this.emojis = const [],
  });

  factory WatchEntry.fromMap(Map<String, dynamic> map) {
    return WatchEntry(
      id: map['id'] as String,
      movie: Movie.fromMap(map['movies'] as Map<String, dynamic>),
      watchedAt: DateTime.parse(map['watched_at'] as String),
      watchLocation: map['watch_location'] as String,
      timesWatched: map['times_watched'] as int,
      rating: (map['rating'] as num?)?.toDouble(),
      comment: map['comment'] as String?,
      emojis: (map['emojis'] as List?)?.cast<String>() ?? const [],
    );
  }
}
