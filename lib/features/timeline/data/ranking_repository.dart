import '../../../core/network/supabase_config.dart';
import '../domain/top_movie.dart';

class RankingRepository {
  Future<List<TopMovie>> fetchTopMovies(String groupId, {int limit = 10}) async {
    final rows = await supabase.rpc(
      'get_group_top_movies',
      params: {'p_group_id': groupId, 'p_limit': limit},
    );

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(TopMovie.fromMap)
        .toList();
  }
}
