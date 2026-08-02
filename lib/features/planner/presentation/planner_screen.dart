import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../movies/data/watch_entries_repository.dart';
import '../../movies/domain/movie.dart';
import '../../achievements/presentation/achievement_sync_prompt.dart';
import '../../movies/presentation/log_watch_sheet.dart';
import '../../movies/presentation/story_share_prompt.dart';
import '../data/planner_repository.dart';
import '../domain/planned_session.dart';
import '../domain/watchlist_item.dart';
import 'schedule_session_dialog.dart';

class PlannerScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const PlannerScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final _repository = PlannerRepository();
  late Future<List<WatchlistItem>> _watchlistFuture;
  late Future<List<PlannedSession>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _watchlistFuture = _repository.fetchWatchlist(widget.groupId);
      _sessionsFuture = _repository.fetchSessions(widget.groupId);
    });
  }

  Future<void> _scheduleSession(Movie movie) async {
    final scheduled = await showScheduleSessionDialog(
      context,
      groupId: widget.groupId,
      movie: movie,
    );
    if (scheduled) _reload();
  }

  Future<void> _markAsWatched(PlannedSession session) async {
    final movie = await WatchEntriesRepository().cacheMovieFromTmdb(
      session.movie.tmdbId,
      mediaType: session.movie.mediaType,
    );
    if (!mounted) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LogWatchSheet(groupId: widget.groupId, movie: movie),
    );

    if (saved == true) {
      await _repository.updateSessionStatus(session.id, 'watched');
      _reload();
      if (!mounted) return;
      await syncAndCelebrateAchievements(context);
      if (!mounted) return;
      await maybeOfferStoryShare(
        context,
        groupId: widget.groupId,
        groupName: widget.groupName,
        movie: movie,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planejador')),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Próximas sessões', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            FutureBuilder<List<PlannedSession>>(
              future: _sessionsFuture,
              builder: (context, snapshot) {
                final sessions = snapshot.data ?? [];
                if (sessions.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Nenhuma sessão agendada ainda.',
                      style: TextStyle(color: AppTheme.onSurfaceMuted),
                    ),
                  );
                }
                return Column(
                  children: [for (final session in sessions) _SessionCard(
                    session: session,
                    onRsvp: (status) async {
                      await _repository.setRsvp(session.id, status);
                      _reload();
                    },
                    onMarkWatched: () => _markAsWatched(session),
                  )],
                );
              },
            ),
            const SizedBox(height: 28),
            Text('Assistir Depois', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            FutureBuilder<List<WatchlistItem>>(
              future: _watchlistFuture,
              builder: (context, snapshot) {
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Nada na lista ainda. Adicione filmes pela página de detalhes.',
                      style: TextStyle(color: AppTheme.onSurfaceMuted),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final item in items)
                      Card(
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: item.movie.posterUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: item.movie.posterUrl!,
                                    width: 40,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(Icons.movie),
                          ),
                          title: Text(item.movie.title),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => _scheduleSession(item.movie),
                                child: const Text('Agendar'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () async {
                                  await _repository.removeFromWatchlist(item.id);
                                  _reload();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final PlannedSession session;
  final void Function(String status) onRsvp;
  final VoidCallback onMarkWatched;

  const _SessionCard({
    required this.session,
    required this.onRsvp,
    required this.onMarkWatched,
  });

  @override
  Widget build(BuildContext context) {
    final isPast = session.scheduledAt.isBefore(DateTime.now());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: session.movie.posterUrl != null
                      ? CachedNetworkImage(
                          imageUrl: session.movie.posterUrl!,
                          width: 44,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.movie),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.movie.title,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '${session.scheduledAt.day}/${session.scheduledAt.month} às '
                        '${session.scheduledAt.hour.toString().padLeft(2, '0')}:'
                        '${session.scheduledAt.minute.toString().padLeft(2, '0')} · '
                        '${sessionLocationLabels[session.location] ?? session.location}',
                        style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (session.notes != null && session.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('"${session.notes}"', style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 10),
            Text(
              '✅ ${session.confirmedCount}   🤔 ${session.maybeCount}   ❌ ${session.declinedCount}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Confirmar'),
                  selected: session.myRsvpStatus == 'confirmed',
                  onSelected: (_) => onRsvp('confirmed'),
                ),
                ChoiceChip(
                  label: const Text('Talvez'),
                  selected: session.myRsvpStatus == 'maybe',
                  onSelected: (_) => onRsvp('maybe'),
                ),
                ChoiceChip(
                  label: const Text('Não posso'),
                  selected: session.myRsvpStatus == 'declined',
                  onSelected: (_) => onRsvp('declined'),
                ),
              ],
            ),
            if (isPast) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onMarkWatched,
                  child: const Text('Marcar como assistido'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
