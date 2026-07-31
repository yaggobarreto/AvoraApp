import 'package:flutter/material.dart';

import '../data/groups_repository.dart';
import '../domain/group.dart';

/// Shared "new group" dialog used both by the Grupos tab and by any
/// discovery flow (Home rails, movie detail) that needs to create a group
/// on the spot.
Future<Group?> showCreateGroupDialog(BuildContext context, {String? message}) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Novo grupo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message != null) ...[
            Text(message),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Ex: Eu ❤️ Minha Namorada'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Criar'),
        ),
      ],
    ),
  );

  if (name == null || name.isEmpty) return null;
  return GroupsRepository().createGroup(name);
}

/// Used whenever an action (registering a movie/série from Home, etc.) needs
/// "which group is this for?" — if the user has no group yet, this offers to
/// create one right away instead of dead-ending with a message telling them
/// to go do it elsewhere first.
Future<Group?> pickOrCreateGroup(BuildContext context, {String? purposeMessage}) async {
  final groups = await GroupsRepository().fetchMyGroups();
  if (!context.mounted) return null;

  if (groups.isEmpty) {
    return showCreateGroupDialog(
      context,
      message: purposeMessage ?? 'Você ainda não tem um grupo — crie um para continuar.',
    );
  }

  if (groups.length == 1) return groups.first;

  if (!context.mounted) return null;
  return showModalBottomSheet<Group>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Escolha um grupo'),
          ),
          for (final group in groups)
            ListTile(
              title: Text(group.name),
              onTap: () => Navigator.pop(context, group),
            ),
        ],
      ),
    ),
  );
}
