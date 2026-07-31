import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../movies/data/watch_entries_repository.dart';
import '../../movies/domain/movie.dart';
import '../../movies/presentation/log_watch_sheet.dart';
import '../data/planner_repository.dart';
import '../domain/planned_session.dart';
import '../domain/watchlist_item.dart';

class PlannerScreen extends StatefulWidget {
  final String groupId;

  const PlannerScreen({super.key, required this.groupId});

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
    var date = DateTime.now().add(const Duration(days: 1));
    var location = sessionLocations.first;
    final notesController = TextEditingController();

    final scheduled = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Agendar "${movie.title}"'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Data e horário'),
                subtitle: Text(
                  '${date.day}/${date.month}/${date.year} às '
                  '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                ),
                trailing: const Icon(Icons.edit_calendar),
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (pickedDate == null) return;
                  if (!context.mounted) return;
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(date),
                  );
                  setDialogState(() {
                    date = DateTime(
                      pickedDate.year,
                      pickedDate.month,
                      pickedDate.day,
                      pickedTime?.hour ?? date.hour,
                      pickedTime?.minute ?? date.minute,
                    );
                  });
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: location,
                decoration: const InputDecoration(labelText: 'Local'),
                items: [
                  for (final loc in sessionLocations)
                    DropdownMenuItem(value: loc, child: Text(sessionLocationLabels[loc]!)),
                ],
                onChanged: (v) => setDialogState(() => location = v!),
              ),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Observações (opcional)'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Agendar'),
            ),
          ],
        ),
      ),
    );

    if (scheduled != true) return;

    await _repository.scheduleSession(
      groupId: widget.groupId,
      movieId: movie.id,
      scheduledAt: date,
      location: location,
      notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
    );
    _reload();
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
