import '../../../core/network/supabase_config.dart';
import '../domain/watch_entry.dart';

class TimelineRepository {
  static const defaultPageSize = 30;

  /// watched_at is a plain date, so many entries commonly share the same
  /// value — ordering by it alone would let range() return unstable pages
  /// (an entry could be skipped or repeated across pages). created_at breaks
  /// the tie deterministically.
  Future<List<WatchEntry>> fetchTimeline(
    String groupId, {
    int limit = defaultPageSize,
    int offset = 0,
  }) async {
    final rows = await supabase
        .from('watch_entries')
        .select('*, movies(*)')
        .eq('group_id', groupId)
        .order('watched_at', ascending: false)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (rows as List)
        .map((row) => WatchEntry.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<WatchEntry>> fetchMyEntries(
    String groupId, {
    int limit = defaultPageSize,
    int offset = 0,
  }) async {
    final userId = supabase.auth.currentUser!.id;
    final rows = await supabase
        .from('watch_entries')
        .select('*, movies(*)')
        .eq('group_id', groupId)
        .eq('logged_by', userId)
        .order('watched_at', ascending: false)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (rows as List)
        .map((row) => WatchEntry.fromMap(row as Map<String, dynamic>))
        .toList();
  }
}
