import '../../movies/domain/movie.dart';

class WatchlistItem {
  final String id;
  final Movie movie;
  final String addedBy;
  final DateTime createdAt;

  WatchlistItem({
    required this.id,
    required this.movie,
    required this.addedBy,
    required this.createdAt,
  });

  factory WatchlistItem.fromMap(Map<String, dynamic> map) {
    return WatchlistItem(
      id: map['id'] as String,
      movie: Movie.fromMap(map['movies'] as Map<String, dynamic>),
      addedBy: map['added_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
