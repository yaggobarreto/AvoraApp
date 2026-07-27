import '../../../core/network/supabase_config.dart';
import '../domain/group.dart';

class GroupsRepository {
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

    final groupRow = await supabase
        .from('groups')
        .insert({'name': name, 'created_by': userId})
        .select()
        .single();

    await supabase.from('group_members').insert({
      'group_id': groupRow['id'],
      'user_id': userId,
      'role': 'owner',
    });

    return Group.fromMap(groupRow);
  }

  Future<Group> joinGroupByInviteCode(String inviteCode) async {
    final groupRow = await supabase.rpc(
      'join_group_by_invite_code',
      params: {'code': inviteCode.trim()},
    );

    return Group.fromMap(groupRow as Map<String, dynamic>);
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
