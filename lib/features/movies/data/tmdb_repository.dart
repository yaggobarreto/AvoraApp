import '../../../core/network/supabase_config.dart';
import '../domain/movie.dart';

/// Calls the tmdb-search / tmdb-movie-details Edge Functions instead of the
/// TMDB API directly, so the TMDB key never ships inside the app.
class TmdbRepository {
  Future<List<TmdbSearchResult>> search(String query) async {
    final response = await supabase.functions.invoke(
      'tmdb-search',
      queryParameters: {'query': query},
    );

    final results = (response.data['results'] as List?) ?? [];
    return results
        .cast<Map<String, dynamic>>()
        .map(TmdbSearchResult.fromTmdbJson)
        .toList();
  }

  Future<MovieDetails> movieDetails(int tmdbId, {String mediaType = 'movie'}) async {
    final response = await supabase.functions.invoke(
      'tmdb-movie-details',
      queryParameters: {'tmdb_id': '$tmdbId', 'media_type': mediaType},
    );
    return MovieDetails.fromTmdbJson(response.data as Map<String, dynamic>);
  }

  Future<List<TmdbSearchResult>> trending() async {
    final response = await supabase.functions.invoke('tmdb-trending');

    final results = (response.data['results'] as List?) ?? [];
    return results
        .cast<Map<String, dynamic>>()
        .map(TmdbSearchResult.fromTmdbJson)
        .toList();
  }

  /// Titles by genre, used to fill the Home before the app has any ratings
  /// of its own and to seed recommendations from onboarding answers.
  Future<List<TmdbSearchResult>> discover({
    List<int> genreIds = const [],
    String mediaType = 'movie',
    bool topRated = false,
  }) async {
    final response = await supabase.functions.invoke(
      'tmdb-discover',
      queryParameters: {
        'genres': genreIds.join(','),
        'media_type': mediaType,
        'sort_by': topRated ? 'top_rated' : 'popular',
      },
    );

    final results = (response.data['results'] as List?) ?? [];
    return results
        .cast<Map<String, dynamic>>()
        .map(TmdbSearchResult.fromTmdbJson)
        .toList();
  }

  Future<List<TmdbSearchResult>> recommendationsFor(int tmdbId, String mediaType) async {
    final response = await supabase.functions.invoke(
      'tmdb-recommendations',
      queryParameters: {'tmdb_id': '$tmdbId', 'media_type': mediaType},
    );

    final results = (response.data['results'] as List?) ?? [];
    return results
        .cast<Map<String, dynamic>>()
        .map(TmdbSearchResult.fromTmdbJson)
        .toList();
  }
}
