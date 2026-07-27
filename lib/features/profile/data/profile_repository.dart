import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<String> uploadAvatar(Uint8List bytes, String fileExtension) async {
    final userId = supabase.auth.currentUser!.id;
    final path = '$userId/avatar.$fileExtension';

    await supabase.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: 'image/$fileExtension'),
        );

    final publicUrl = supabase.storage.from('avatars').getPublicUrl(path);
    // Cache-bust so the new photo shows immediately instead of a cached old one.
    final avatarUrl = '$publicUrl?updated=${DateTime.now().millisecondsSinceEpoch}';

    await supabase
        .from('profiles')
        .update({'avatar_url': avatarUrl}).eq('id', userId);

    return avatarUrl;
  }
}
