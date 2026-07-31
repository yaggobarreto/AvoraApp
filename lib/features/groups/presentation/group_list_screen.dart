import 'package:flutter/material.dart';

import '../../../core/network/supabase_config.dart';
import '../data/groups_repository.dart';
import '../domain/group.dart';
import '../../timeline/presentation/group_timeline_screen.dart';
import 'group_picker.dart';

class GroupListScreen extends StatefulWidget {
  const GroupListScreen({super.key});

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  final _repository = GroupsRepository();
  late Future<List<Group>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _groupsFuture = _repository.fetchMyGroups();
  }

  void _reload() {
    setState(() => _groupsFuture = _repository.fetchMyGroups());
  }

  Future<void> _showCreateGroupDialog() async {
    final created = await showCreateGroupDialog(context);
    if (created != null) _reload();
  }

  Future<void> _showJoinGroupDialog() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Entrar em um grupo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Código de convite'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Entrar'),
          ),
        ],
      ),
    );

    if (code != null && code.isNotEmpty) {
      await _repository.joinGroupByInviteCode(code);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus grupos'),
        actions: [
          IconButton(
            onPressed: () => supabase.auth.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
          ),
        ],
      ),
      body: FutureBuilder<List<Group>>(
        future: _groupsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          final groups = snapshot.data ?? [];
          if (groups.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum grupo ainda. Crie um ou entre com um código.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: group.photoUrl != null
                        ? NetworkImage(group.photoUrl!)
                        : null,
                    child: group.photoUrl == null
                        ? Text(group.name.substring(0, 1).toUpperCase())
                        : null,
                  ),
                  title: Text(group.name),
                  subtitle: Text('Convite: ${group.inviteCode}'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroupTimelineScreen(group: group),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'join',
            onPressed: _showJoinGroupDialog,
            label: const Text('Entrar'),
            icon: const Icon(Icons.group_add),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'create',
            onPressed: _showCreateGroupDialog,
            label: const Text('Criar grupo'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
