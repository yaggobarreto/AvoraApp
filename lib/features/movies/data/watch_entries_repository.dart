import '../../../core/network/supabase_config.dart';
import '../domain/movie.dart';
import 'tmdb_repository.dart';

class WatchEntriesRepository {
  final _tmdbRepository = TmdbRepository();

  /// Fetches full details from TMDB and caches them in the local `movies`
  /// table (upsert on tmdb_id) so later joins/timeline reads don't need TMDB.
  Future<Movie> cacheMovieFromTmdb(int tmdbId) async {
    final details = await _tmdbRepository.movieDetails(tmdbId);

    final crew = (details['credits']?['crew'] as List?) ?? [];
    final director = crew.cast<Map<String, dynamic>>().firstWhere(
          (member) => member['job'] == 'Director',
          orElse: () => const {},
        )['name'] as String?;

    final videos = (details['videos']?['results'] as List?) ?? [];
    final trailer = videos.cast<Map<String, dynamic>>().firstWhere(
          (video) => video['type'] == 'Trailer' && video['site'] == 'YouTube',
          orElse: () => const {},
        )['key'] as String?;

    final releaseDate = details['release_date'] as String?;

    final row = await supabase
        .from('movies')
        .upsert({
          'tmdb_id': details['id'],
          'title': details['title'],
          'year': (releaseDate != null && releaseDate.isNotEmpty)
              ? int.tryParse(releaseDate.substring(0, 4))
              : null,
          'poster_url': details['poster_path'] != null
              ? 'https://image.tmdb.org/t/p/w342${details['poster_path']}'
              : null,
          'backdrop_url': details['backdrop_path'] != null
              ? 'https://image.tmdb.org/t/p/w780${details['backdrop_path']}'
              : null,
          'synopsis': details['overview'],
          'runtime_minutes': details['runtime'],
          'genres': ((details['genres'] as List?) ?? [])
              .map((g) => g['name'] as String)
              .toList(),
          'director': director,
          'trailer_url': trailer != null
              ? 'https://www.youtube.com/watch?v=$trailer'
              : null,
        }, onConflict: 'tmdb_id')
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
}
