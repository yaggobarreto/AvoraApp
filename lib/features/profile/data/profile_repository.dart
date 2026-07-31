import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_config.dart';

class RecentRating {
  final String movieTitle;
  final String? posterUrl;
  final double? rating;

  RecentRating({required this.movieTitle, this.posterUrl, this.rating});
}

class ProfileStats {
  final String name;
  final String? avatarUrl;
  final int moviesWatched;
  final int seriesWatched;
  final int totalWatchedMinutes;
  final double? avgRating;
  final String? favoriteGenre;
  final String? favoriteStreamer;
  final int currentStreakDays;
  final List<RecentRating> recentRatings;

  ProfileStats({
    required this.name,
    this.avatarUrl,
    required this.moviesWatched,
    required this.seriesWatched,
    required this.totalWatchedMinutes,
    this.avgRating,
    this.favoriteGenre,
    this.favoriteStreamer,
    required this.currentStreakDays,
    this.recentRatings = const [],
  });
}

class ProfileRepository {
  Future<ProfileStats> fetchMyProfile() async {
    final userId = supabase.auth.currentUser!.id;

    final profileRow = await supabase.from('profiles').select().eq('id', userId).single();

    final entries = await supabase
        .from('watch_entries')
        .select('rating, times_watched, watch_location, created_at, movies(title, poster_url, genres, runtime_minutes, media_type)')
        .eq('logged_by', userId)
        .order('created_at', ascending: false);

    final entryList = (entries as List).cast<Map<String, dynamic>>();

    var moviesWatched = 0;
    var seriesWatched = 0;
    var totalMinutes = 0;
    final ratings = <double>[];
    final genreCounts = <String, int>{};
    final locationCounts = <String, int>{};
    final loggedDates = <DateTime>{};

    for (final entry in entryList) {
      final movie = entry['movies'] as Map<String, dynamic>?;
      if (movie == null) continue;

      final timesWatched = (entry['times_watched'] as num?)?.toInt() ?? 1;
      if (movie['media_type'] == 'tv') {
        seriesWatched++;
      } else {
        moviesWatched++;
      }

      final runtime = (movie['runtime_minutes'] as num?)?.toInt();
      if (runtime != null) totalMinutes += runtime * timesWatched;

      final rating = (entry['rating'] as num?)?.toDouble();
      if (rating != null) ratings.add(rating);

      for (final genre in (movie['genres'] as List? ?? [])) {
        genreCounts[genre as String] = (genreCounts[genre] ?? 0) + 1;
      }

      final location = entry['watch_location'] as String?;
      if (location != null) locationCounts[location] = (locationCounts[location] ?? 0) + 1;

      final createdAt = DateTime.tryParse(entry['created_at'] as String? ?? '');
      if (createdAt != null) {
        loggedDates.add(DateTime(createdAt.year, createdAt.month, createdAt.day));
      }
    }

    String? topKey(Map<String, int> counts) {
      if (counts.isEmpty) return null;
      return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }

    final recentRatings = entryList.take(5).map((entry) {
      final movie = entry['movies'] as Map<String, dynamic>?;
      return RecentRating(
        movieTitle: movie?['title'] as String? ?? '',
        posterUrl: movie?['poster_url'] as String?,
        rating: (entry['rating'] as num?)?.toDouble(),
      );
    }).toList();

    return ProfileStats(
      name: profileRow['name'] as String,
      avatarUrl: profileRow['avatar_url'] as String?,
      moviesWatched: moviesWatched,
      seriesWatched: seriesWatched,
      totalWatchedMinutes: totalMinutes,
      avgRating: ratings.isEmpty ? null : ratings.reduce((a, b) => a + b) / ratings.length,
      favoriteGenre: topKey(genreCounts),
      favoriteStreamer: topKey(locationCounts),
      currentStreakDays: _computeStreak(loggedDates),
      recentRatings: recentRatings,
    );
  }

  int _computeStreak(Set<DateTime> loggedDates) {
    if (loggedDates.isEmpty) return 0;

    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);

    // The streak counts backward from today; if nothing was logged today,
    // it can still count from yesterday (streak isn't broken until a full
    // day is skipped).
    if (!loggedDates.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!loggedDates.contains(cursor)) return 0;
    }

    var streak = 0;
    while (loggedDates.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<String> uploadAvatar(Uint8List bytes, String fileExtension) async {
    final userId = supabase.auth.currentUser!.id;
    final path = '$userId/avatar.$fileExtension';

    await supabase.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: 'image/$fileExtension'),
        );

    final publicUrl = supabase.storage.from('avatars').getPublicUrl(path);
    // Cache-bust so the new photo shows immediately instead of a cached old one.
    final avatarUrl = '$publicUrl?updated=${DateTime.now().millisecondsSinceEpoch}';

    await supabase
        .from('profiles')
        .update({'avatar_url': avatarUrl}).eq('id', userId);

    return avatarUrl;
  }
}
