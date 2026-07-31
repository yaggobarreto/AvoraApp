import '../../../core/network/supabase_config.dart';
import '../domain/movie.dart';
import 'tmdb_repository.dart';

class WatchEntriesRepository {
  final _tmdbRepository = TmdbRepository();

  /// Fetches full details from TMDB and caches them in the local `movies`
  /// table (upsert on tmdb_id + media_type) so later joins/timeline reads
  /// don't need TMDB.
  Future<Movie> cacheMovieFromTmdb(int tmdbId, {String mediaType = 'movie'}) async {
    final details = await _tmdbRepository.movieDetails(tmdbId, mediaType: mediaType);

    final row = await supabase
        .from('movies')
        .upsert({
          'tmdb_id': details.tmdbId,
          'media_type': details.mediaType,
          'title': details.title,
          'year': details.year,
          'poster_url': details.posterUrl,
          'backdrop_url': details.backdropUrl,
          'synopsis': details.synopsis,
          'runtime_minutes': details.runtimeMinutes,
          'genres': details.genres,
          'director': details.director,
          'trailer_url': details.trailerUrl,
        }, onConflict: 'tmdb_id,media_type')
        .select()
        .single();

    return Movie.fromMap(row);
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
}
