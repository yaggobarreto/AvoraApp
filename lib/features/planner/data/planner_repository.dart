import '../../../core/network/supabase_config.dart';
import '../domain/planned_session.dart';
import '../domain/watchlist_item.dart';

class PlannerRepository {
  Future<List<WatchlistItem>> fetchWatchlist(String groupId) async {
    final rows = await supabase
        .from('watchlist_items')
        .select('*, movies(*)')
        .eq('group_id', groupId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => WatchlistItem.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> addToWatchlist(String groupId, String movieId) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('watchlist_items').insert({
      'group_id': groupId,
      'movie_id': movieId,
      'added_by': userId,
    });
  }

  Future<void> removeFromWatchlist(String watchlistItemId) async {
    await supabase.from('watchlist_items').delete().eq('id', watchlistItemId);
  }

  Future<List<PlannedSession>> fetchSessions(
    String groupId, {
    String status = 'scheduled',
  }) async {
    final userId = supabase.auth.currentUser?.id;
    final rows = await supabase
        .from('planned_sessions')
        .select('*, movies(*), session_rsvps(status, user_id)')
        .eq('group_id', groupId)
        .eq('status', status)
        .order('scheduled_at', ascending: true);

    return (rows as List)
        .map((row) => PlannedSession.fromMap(row as Map<String, dynamic>, currentUserId: userId))
        .toList();
  }

  Future<void> scheduleSession({
    required String groupId,
    required String movieId,
    required DateTime scheduledAt,
    required String location,
    String? notes,
  }) async {
    final userId = supabase.auth.currentUser!.id;
    final row = await supabase
        .from('planned_sessions')
        .insert({
          'group_id': groupId,
          'movie_id': movieId,
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'location': location,
          'notes': notes,
          'created_by': userId,
        })
        .select()
        .single();

    // The creator automatically confirms their own presence.
    await supabase.from('session_rsvps').insert({
      'session_id': row['id'],
      'user_id': userId,
      'status': 'confirmed',
    });
  }

  Future<void> setRsvp(String sessionId, String status) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('session_rsvps').upsert({
      'session_id': sessionId,
      'user_id': userId,
      'status': status,
    }, onConflict: 'session_id,user_id');
  }

  Future<void> updateSessionStatus(String sessionId, String status) async {
    await supabase.from('planned_sessions').update({'status': status}).eq('id', sessionId);
  }
}
