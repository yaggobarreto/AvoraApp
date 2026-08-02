import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/network/app_errors.dart';
import '../../../core/network/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../data/groups_repository.dart';
import '../domain/group.dart';
import '../../timeline/presentation/group_timeline_screen.dart';
import 'group_avatar.dart';
import 'group_picker.dart';
import 'group_settings_screen.dart';
import 'invite_screen.dart';

class GroupListScreen extends StatefulWidget {
  const GroupListScreen({super.key});

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  final _repository = GroupsRepository();
  late Future<List<GroupSummary>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _groupsFuture = _repository.fetchMyGroupSummaries();
  }

  void _reload() {
    setState(() => _groupsFuture = _repository.fetchMyGroupSummaries());
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
          decoration: const InputDecoration(hintText: 'Código ou link de convite'),
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

    if (code == null || code.isEmpty) return;
    try {
      await _repository.joinGroupByInviteCode(extractInviteCode(code));
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
    }
  }

  Future<void> _openGroup(Group group) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupTimelineScreen(group: group)),
    );
    _reload();
  }

  Future<void> _openSettings(Group group) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupSettingsScreen(group: group)),
    );
    _reload();
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
      body: FutureBuilder<List<GroupSummary>>(
        future: _groupsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(friendlyErrorMessage(snapshot.error!)));
          }

          final summaries = snapshot.data ?? [];
          if (summaries.isEmpty) return const _EmptyGroupsState();

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: summaries.length,
            itemBuilder: (context, index) {
              final summary = summaries[index];
              return _GroupCard(
                summary: summary,
                onTap: () => _openGroup(summary.group),
                onCustomize: () => _openSettings(summary.group),
                onInvite: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InviteScreen(group: summary.group),
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

class _GroupCard extends StatelessWidget {
  final GroupSummary summary;
  final VoidCallback onTap;
  final VoidCallback onCustomize;
  final VoidCallback onInvite;

  const _GroupCard({
    required this.summary,
    required this.onTap,
    required this.onCustomize,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    final group = summary.group;
    final backdrop = summary.latestBackdropUrl;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: AppTheme.surface,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 172,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (backdrop != null)
                    CachedNetworkImage(
                      imageUrl: backdrop,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 150),
                      errorWidget: (context, url, error) =>
                          const ColoredBox(color: AppTheme.surfaceHigh),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(gradient: AppTheme.posterScrim),
                  ),
                  Positioned(
                    top: 8,
                    right: 4,
                    child: Row(
                      children: [
                        _CardAction(
                          icon: Icons.person_add_alt_1_outlined,
                          tooltip: 'Convidar',
                          onPressed: onInvite,
                        ),
                        _CardAction(
                          icon: Icons.tune,
                          tooltip: 'Personalizar',
                          onPressed: onCustomize,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Row(
                      children: [
                        GroupAvatar(group: group, size: 52),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                group.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _statsLine(summary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _statsLine(GroupSummary summary) {
    final members = '${summary.memberCount} '
        '${summary.memberCount == 1 ? 'membro' : 'membros'}';
    final titles = '${summary.entryCount} '
        '${summary.entryCount == 1 ? 'título' : 'títulos'}';
    return '$members · $titles';
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _CardAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      color: Colors.white,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.35),
      ),
    );
  }
}

class _EmptyGroupsState extends StatelessWidget {
  const _EmptyGroupsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.groups_rounded, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'Nenhum grupo por aqui',
              style: TextStyle(
                color: AppTheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Crie um grupo para começar seu diário de filmes '
              'ou entre em um com o código de convite.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.onSurfaceMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
