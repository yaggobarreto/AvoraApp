class Group {
  final String id;
  final String name;
  final String? photoUrl;
  final String? icon;
  final String inviteCode;

  Group({
    required this.id,
    required this.name,
    required this.inviteCode,
    this.photoUrl,
    this.icon,
  });

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['id'] as String,
      name: map['name'] as String,
      photoUrl: map['photo_url'] as String?,
      icon: map['icon'] as String?,
      inviteCode: map['invite_code'] as String,
    );
  }
}

/// A group plus the counters shown on its card in the list.
class GroupSummary {
  final Group group;
  final int memberCount;
  final int entryCount;
  final DateTime? lastWatchedAt;

  /// Backdrop of the most recently watched title, used as the card's
  /// background so each group looks like what the group has been watching.
  final String? latestBackdropUrl;

  GroupSummary({
    required this.group,
    required this.memberCount,
    required this.entryCount,
    this.lastWatchedAt,
    this.latestBackdropUrl,
  });

  factory GroupSummary.fromMap(Map<String, dynamic> map) {
    final lastWatched = map['last_watched_at'] as String?;
    return GroupSummary(
      group: Group.fromMap(map),
      memberCount: (map['member_count'] as num?)?.toInt() ?? 0,
      entryCount: (map['entry_count'] as num?)?.toInt() ?? 0,
      lastWatchedAt: lastWatched == null ? null : DateTime.parse(lastWatched),
      latestBackdropUrl: map['latest_backdrop_url'] as String?,
    );
  }
}
