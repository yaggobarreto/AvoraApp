import '../../../core/network/supabase_config.dart';
import '../domain/achievement.dart';

class AchievementsRepository {
  /// Calls the server-side check and returns every achievement the user has
  /// unlocked (old and new). Safe to call anytime — with nothing new to
  /// unlock it just returns the existing set with isNew: false on all of
  /// them, so screens can call it on open without worrying about
  /// re-triggering celebrations.
  Future<List<UnlockedAchievement>> syncAndFetch() async {
    final rows = await supabase.rpc('sync_and_fetch_achievements');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(UnlockedAchievement.fromMap)
        .toList();
  }
}
