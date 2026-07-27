import '../../../core/network/supabase_config.dart';

class ProfileStats {
  final String name;
  final String? avatarUrl;
  final int moviesWatched;

  ProfileStats({required this.name, this.avatarUrl, required this.moviesWatched});
}

class ProfileRepository {
  Future<ProfileStats> fetchMyProfile() async {
    final userId = supabase.auth.currentUser!.id;

    final profileRow = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();

    final watchEntries = await supabase
        .from('watch_entries')
        .select('id')
        .eq('logged_by', userId);

    return ProfileStats(
      name: profileRow['name'] as String,
      avatarUrl: profileRow['avatar_url'] as String?,
      moviesWatched: (watchEntries as List).length,
    );
  }
}
