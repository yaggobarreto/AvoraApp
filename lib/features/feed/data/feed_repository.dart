import '../../../core/network/supabase_config.dart';
import '../domain/feed_event.dart';

class FeedRepository {
  static const defaultPageSize = 20;

  Future<List<FeedEvent>> fetchGroupActivity(
    String groupId, {
    int limit = defaultPageSize,
    int offset = 0,
  }) async {
    final rows = await supabase.rpc(
      'get_group_activity_feed',
      params: {'p_group_id': groupId, 'p_limit': limit, 'p_offset': offset},
    );

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FeedEvent.fromMap)
        .toList();
  }
}
