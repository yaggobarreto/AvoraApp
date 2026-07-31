import 'package:flutter/material.dart';

import '../../../core/widgets/poster_card.dart';
import '../../groups/domain/group.dart';
import '../../movies/domain/movie.dart';
import '../../movies/presentation/movie_search_screen.dart';
import '../data/timeline_repository.dart';
import '../domain/watch_entry.dart';

class GroupTimelineScreen extends StatefulWidget {
  final Group group;

  const GroupTimelineScreen({super.key, required this.group});

  @override
  State<GroupTimelineScreen> createState() => _GroupTimelineScreenState();
}

class _GroupTimelineScreenState extends State<GroupTimelineScreen> {
  final _repository = TimelineRepository();
  late Future<List<WatchEntry>> _timelineFuture;

  @override
  void initState() {
    super.initState();
    _timelineFuture = _repository.fetchTimeline(widget.group.id);
  }

  void _reload() {
    setState(() => _timelineFuture = _repository.fetchTimeline(widget.group.id));
  }

  Future<void> _openMovieSearch() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieSearchScreen(groupId: widget.group.id),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.group.name)),
      body: FutureBuilder<List<WatchEntry>>(
        future: _timelineFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }

          final entries = snapshot.data ?? [];
          if (entries.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum filme registrado ainda neste grupo.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final entriesByYear = <int, List<WatchEntry>>{};
          for (final entry in entries) {
            entriesByYear.putIfAbsent(entry.watchedAt.year, () => []).add(entry);
          }
          final years = entriesByYear.keys.toList()..sort((a, b) => b.compareTo(a));

          return ListView(
            padding: const EdgeInsets.only(bottom: 8),
            children: [
              for (final year in years) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    '$year',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: Colors.white),
                  ),
                ),
                for (final entry in entriesByYear[year]!)
                  Builder(builder: (context) {
                    final stars = (entry.rating ?? 0).round().clamp(0, 5);
                    return PosterCard(
                      imageUrl: entry.movie.backdropUrl ?? entry.movie.posterUrl,
                      title: entry.movie.title,
                      subtitle: '${'★' * stars}${'☆' * (5 - stars)} '
                          '· ${watchLocationLabels[entry.watchLocation]}'
                          '${entry.timesWatched > 1 ? ' · Assistido ${entry.timesWatched}x' : ''}',
                      trailing: entry.emojis.isNotEmpty
                          ? Text(entry.emojis.join(), style: const TextStyle(fontSize: 20))
                          : null,
                    );
                  }),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openMovieSearch,
        icon: const Icon(Icons.add),
        label: const Text('Registrar filme'),
      ),
    );
  }
}
