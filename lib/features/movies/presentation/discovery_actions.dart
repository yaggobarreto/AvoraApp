import 'package:flutter/material.dart';

import '../../groups/presentation/group_picker.dart';
import '../data/watch_entries_repository.dart';
import 'log_watch_sheet.dart';

/// Shared "register this title" flow for anywhere a movie/série is being
/// discovered without an existing group context yet (Home rails, the movie
/// detail page opened from Home) — pick or create a group, cache the TMDB
/// details, then open the same rating sheet the search screen uses.
Future<void> registerDiscoveryItem(
  BuildContext context, {
  required int tmdbId,
  required String mediaType,
  required String title,
}) async {
  final selectedGroup = await pickOrCreateGroup(
    context,
    purposeMessage: 'Crie um grupo para registrar "$title".',
  );
  if (selectedGroup == null || !context.mounted) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final movie = await WatchEntriesRepository().cacheMovieFromTmdb(tmdbId, mediaType: mediaType);
    if (!context.mounted) return;
    Navigator.of(context).pop();

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LogWatchSheet(groupId: selectedGroup.id, movie: movie),
    );
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
  }
}
