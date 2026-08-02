import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_config.dart';
import '../../../core/storage/image_upload.dart';
import '../domain/group.dart';

class GroupsRepository {
  Future<List<GroupSummary>> fetchMyGroupSummaries() async {
    final rows = await supabase.rpc('get_my_groups_with_stats');
    return (rows as List)
        .map((row) => GroupSummary.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<Group>> fetchMyGroups() async {
    final userId = supabase.auth.currentUser!.id;
    final rows = await supabase
        .from('group_members')
        .select('groups(*)')
        .eq('user_id', userId);

    return (rows as List)
        .map((row) => Group.fromMap(row['groups'] as Map<String, dynamic>))
        .toList();
  }

  Future<Group> createGroup(String name) async {
    final userId = supabase.auth.currentUser!.id;

    // The `on_group_created` trigger adds the creator to group_members as
    // owner automatically, so no separate membership insert is needed here.
    final groupRow = await supabase
        .from('groups')
        .insert({'name': name, 'created_by': userId})
        .select()
        .single();

    return Group.fromMap(groupRow);
  }

  Future<Group> joinGroupByInviteCode(String inviteCode) async {
    final groupRow = await supabase.rpc(
      'join_group_by_invite_code',
      params: {'code': inviteCode.trim()},
    );

    return Group.fromMap(groupRow as Map<String, dynamic>);
  }

  Future<Group> renameGroup(String groupId, String name) =>
      _updateGroup(groupId, {'name': name});

  /// A group is represented by either an emoji or a photo, never both, so
  /// setting one clears the other.
  Future<Group> setGroupIcon(String groupId, String icon) =>
      _updateGroup(groupId, {'icon': icon, 'photo_url': null});

  Future<Group> setGroupPhoto(String groupId, String photoUrl) =>
      _updateGroup(groupId, {'photo_url': photoUrl, 'icon': null});

  Future<Group> _updateGroup(String groupId, Map<String, dynamic> values) async {
    final row = await supabase
        .from('groups')
        .update(values)
        .eq('id', groupId)
        .select()
        .single();

    return Group.fromMap(row);
  }

  Future<String> uploadGroupPhoto(
    String groupId,
    Uint8List bytes,
    String fileExtension,
  ) async {
    verifyImageBytes(bytes, fileExtension);

    final path = '$groupId/photo.$fileExtension';

    await supabase.storage.from('group-photos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: 'image/$fileExtension'),
        );

    final publicUrl = supabase.storage.from('group-photos').getPublicUrl(path);
    // Cache-bust so the new photo shows immediately instead of a cached old one.
    return '$publicUrl?updated=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<List<Map<String, dynamic>>> fetchMembers(String groupId) async {
    final rows = await supabase
        .from('group_members')
        .select('user_id, profiles(name, avatar_url)')
        .eq('group_id', groupId);

    return (rows as List)
        .map((row) => {
              'user_id': row['user_id'],
              'name': row['profiles']['name'],
            })
        .toList();
  }
}
