import '../../../core/network/supabase_config.dart';
import '../domain/watch_entry.dart';

class TimelineRepository {
  Future<List<WatchEntry>> fetchTimeline(String groupId) async {
    final rows = await supabase
        .from('watch_entries')
        .select('*, movies(*)')
        .eq('group_id', groupId)
        .order('watched_at', ascending: false);

    return (rows as List)
        .map((row) => WatchEntry.fromMap(row as Map<String, dynamic>))
        .toList();
  }
}
