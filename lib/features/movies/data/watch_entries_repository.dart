import '../../../core/network/supabase_config.dart';
import '../domain/movie.dart';

class WatchEntriesRepository {
  /// Caches a title's metadata in the local `movies` table so later
  /// joins/timeline reads don't need TMDB.
  ///
  /// The write happens in the `cache-movie` Edge Function rather than here:
  /// `movies` is readable by every user, so letting clients write it directly
  /// allowed poisoning the shared cache, and re-caching a title someone else
  /// had already saved failed RLS.
  Future<Movie> cacheMovieFromTmdb(int tmdbId, {String mediaType = 'movie'}) async {
    final response = await supabase.functions.invoke(
      'cache-movie',
      body: {'tmdb_id': tmdbId, 'media_type': mediaType},
    );

    return Movie.fromMap(response.data as Map<String, dynamic>);
  }

  Future<void> logWatch({
    required String groupId,
    required String movieId,
    required DateTime watchedAt,
    required String watchLocation,
    required int timesWatched,
    double? rating,
    String? comment,
    List<String> emojis = const [],
    List<String> participantUserIds = const [],
  }) async {
    final userId = supabase.auth.currentUser!.id;

    final entryRow = await supabase
        .from('watch_entries')
        .insert({
          'group_id': groupId,
          'movie_id': movieId,
          'logged_by': userId,
          'watched_at': watchedAt.toIso8601String().substring(0, 10),
          'watch_location': watchLocation,
          'times_watched': timesWatched,
          'rating': rating,
          'comment': comment,
          'emojis': emojis,
        })
        .select()
        .single();

    if (participantUserIds.isNotEmpty) {
      await supabase.from('watch_entry_participants').insert([
        for (final participantId in participantUserIds)
          {'watch_entry_id': entryRow['id'], 'user_id': participantId},
      ]);
    }
  }

  /// All watch entries logged for this movie within this group, newest
  /// first, with the logger's name — used to show "sua nota", the group's
  /// average, and friends' individual ratings on the movie detail page.
  Future<List<Map<String, dynamic>>> fetchEntriesForMovieInGroup(
    String groupId,
    String movieId,
  ) async {
    final rows = await supabase
        .from('watch_entries')
        .select('*, profiles!watch_entries_logged_by_fkey(name)')
        .eq('group_id', groupId)
        .eq('movie_id', movieId)
        .order('watched_at', ascending: false);

    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// The current user's single highest-rated title across every group they
  /// belong to — used as the "seed" for TMDB-powered recommendations
  /// ("porque você gostou de X") when there's no group context yet.
  Future<Movie?> fetchMyFavoriteMovie() async {
    final userId = supabase.auth.currentUser!.id;
    final rows = await supabase
        .from('watch_entries')
        .select('rating, movies(*)')
        .eq('logged_by', userId)
        .not('rating', 'is', null)
        .order('rating', ascending: false)
        .limit(1);

    final list = rows as List;
    if (list.isEmpty) return null;
    return Movie.fromMap(list.first['movies'] as Map<String, dynamic>);
  }
}
