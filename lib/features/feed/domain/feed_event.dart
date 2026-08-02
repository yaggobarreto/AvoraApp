enum FeedEventType {
  watchEntry('watch_entry'),
  memberJoined('member_joined'),
  sessionScheduled('session_scheduled'),
  watchlistAdded('watchlist_added');

  final String value;
  const FeedEventType(this.value);

  static FeedEventType fromValue(String value) {
    return FeedEventType.values.firstWhere((t) => t.value == value);
  }
}

class FeedEvent {
  final FeedEventType type;
  final String eventId;
  final String actorName;
  final String? actorAvatarUrl;
  final String? movieTitle;
  final String? moviePosterUrl;
  final double? rating;
  final DateTime createdAt;

  FeedEvent({
    required this.type,
    required this.eventId,
    required this.actorName,
    required this.createdAt,
    this.actorAvatarUrl,
    this.movieTitle,
    this.moviePosterUrl,
    this.rating,
  });

  factory FeedEvent.fromMap(Map<String, dynamic> map) {
    return FeedEvent(
      type: FeedEventType.fromValue(map['event_type'] as String),
      eventId: map['event_id'] as String,
      actorName: map['actor_name'] as String,
      actorAvatarUrl: map['actor_avatar_url'] as String?,
      movieTitle: map['movie_title'] as String?,
      moviePosterUrl: map['movie_poster_url'] as String?,
      rating: (map['rating'] as num?)?.toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// A key unique across the whole feed, not just within one event type —
  /// event_id alone can collide (e.g. a watch_entries.id and a
  /// planned_sessions.id are both independent uuid sequences).
  String get key => '${type.value}:$eventId';
}
