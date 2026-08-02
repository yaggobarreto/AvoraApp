import '../../movies/domain/movie.dart';

const sessionLocations = ['casa', 'cinema', 'com_pizza', 'discord', 'online', 'outro'];

const sessionLocationLabels = {
  'casa': '🏠 Casa',
  'cinema': '🎥 Cinema',
  'com_pizza': '🍕 Com Pizza',
  'discord': '🎮 No Discord',
  'online': '💻 Online',
  'outro': 'Outro',
};

class PlannedSession {
  final String id;
  final Movie movie;
  final DateTime scheduledAt;
  final String location;
  final String? notes;
  final String status;
  final String createdBy;
  final int confirmedCount;
  final int declinedCount;
  final int maybeCount;
  final String? myRsvpStatus;

  PlannedSession({
    required this.id,
    required this.movie,
    required this.scheduledAt,
    required this.location,
    this.notes,
    required this.status,
    required this.createdBy,
    this.confirmedCount = 0,
    this.declinedCount = 0,
    this.maybeCount = 0,
    this.myRsvpStatus,
  });

  factory PlannedSession.fromMap(Map<String, dynamic> map, {String? currentUserId}) {
    final rsvps = (map['session_rsvps'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

    String? myStatus;
    var confirmed = 0, declined = 0, maybe = 0;
    for (final rsvp in rsvps) {
      final status = rsvp['status'] as String;
      switch (status) {
        case 'confirmed':
          confirmed++;
        case 'declined':
          declined++;
        case 'maybe':
          maybe++;
      }
      if (rsvp['user_id'] == currentUserId) myStatus = status;
    }

    return PlannedSession(
      id: map['id'] as String,
      movie: Movie.fromMap(map['movies'] as Map<String, dynamic>),
      scheduledAt: DateTime.parse(map['scheduled_at'] as String).toLocal(),
      location: map['location'] as String,
      notes: map['notes'] as String?,
      status: map['status'] as String,
      createdBy: map['created_by'] as String,
      confirmedCount: confirmed,
      declinedCount: declined,
      maybeCount: maybe,
      myRsvpStatus: myStatus,
    );
  }
}
