import '../../../core/network/supabase_config.dart';
import '../domain/taste_preferences.dart';

class PreferencesRepository {
  Future<TastePreferences> fetchMyPreferences() async {
    final userId = supabase.auth.currentUser!.id;
    final row = await supabase
        .from('profiles')
        .select('preferred_genres, content_preference, onboarded_at')
        .eq('id', userId)
        .single();

    return TastePreferences.fromMap(row);
  }

  /// Marks onboarding as done in the same write that stores the answers, so a
  /// user can't end up flagged as onboarded with no preferences saved.
  Future<void> savePreferences({
    required List<int> genreIds,
    required ContentPreference contentPreference,
  }) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('profiles').update({
      'preferred_genres': genreIds,
      'content_preference': contentPreference.value,
      'onboarded_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
  }

  /// Used by "pular" — records that the question was asked so it isn't shown
  /// again, without inventing preferences the user never gave.
  Future<void> skipOnboarding() async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('profiles').update({
      'onboarded_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
  }
}
