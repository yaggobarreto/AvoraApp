import 'package:flutter/material.dart';

import '../../features/groups/data/groups_repository.dart';
import '../../features/groups/presentation/group_list_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/timeline/presentation/group_timeline_screen.dart';
import '../pending_invite.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  static const _tabs = [
    HomeScreen(),
    GroupListScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    final code = PendingInvite.consume();
    if (code != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _joinPendingInvite(code));
    }
  }

  Future<void> _joinPendingInvite(String code) async {
    try {
      final group = await GroupsRepository().joinGroupByInviteCode(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Você entrou no grupo "${group.name}"!')),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GroupTimelineScreen(group: group)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível entrar no grupo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.group), label: 'Grupos'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
