import 'package:flutter/material.dart';

import '../../../core/widgets/movie_rail.dart';
import '../../../core/widgets/poster_card.dart';
import '../../groups/domain/group.dart';
import '../../groups/presentation/invite_screen.dart';
import '../../movies/data/tmdb_repository.dart';
import '../../movies/data/watch_entries_repository.dart';
import '../../movies/domain/movie.dart';
import '../../movies/presentation/log_watch_sheet.dart';
import '../../movies/presentation/movie_detail_screen.dart';
import '../../movies/presentation/movie_search_screen.dart';
import '../../movies/presentation/my_movies_screen.dart';
import '../../planner/presentation/planner_screen.dart';
import '../data/ranking_repository.dart';
import '../data/timeline_repository.dart';
import '../domain/top_movie.dart';
import '../domain/watch_entry.dart';

class GroupTimelineScreen extends StatefulWidget {
  final Group group;

  const GroupTimelineScreen({super.key, required this.group});

  @override
  State<GroupTimelineScreen> createState() => _GroupTimelineScreenState();
}

class _GroupTimelineScreenState extends State<GroupTimelineScreen> {
  final _repository = TimelineRepository();
  final _rankingRepository = RankingRepository();
  final _tmdbRepository = TmdbRepository();
  late Future<List<WatchEntry>> _timelineFuture;
  late Future<List<TopMovie>> _topMoviesFuture;
  late Future<List<TmdbSearchResult>?> _recommendationsFuture;

  @override
  void initState() {
    super.initState();
    _timelineFuture = _repository.fetchTimeline(widget.group.id);
    _topMoviesFuture = _rankingRepository.fetchTopMovies(widget.group.id);
    _recommendationsFuture = _loadRecommendations();
  }

  Future<List<TmdbSearchResult>?> _loadRecommendations() async {
    final topMovies = await _topMoviesFuture;
    if (topMovies.isEmpty) return null;
    final seed = topMovies.first;
    final items = await _tmdbRepository.recommendationsFor(seed.tmdbId, seed.mediaType);
    return items.isEmpty ? null : items;
  }

  void _reload() {
    setState(() {
      _timelineFuture = _repository.fetchTimeline(widget.group.id);
      _topMoviesFuture = _rankingRepository.fetchTopMovies(widget.group.id);
      _recommendationsFuture = _loadRecommendations();
    });
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

  void _openMovieDetail(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieDetailScreen.forGroup(movie: movie, groupId: widget.group.id),
      ),
    );
  }

  Future<void> _selectRecommendation(TmdbSearchResult result) async {
    final movie = await WatchEntriesRepository().cacheMovieFromTmdb(
      result.tmdbId,
      mediaType: result.mediaType,
    );
    if (!mounted) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LogWatchSheet(groupId: widget.group.id, movie: movie),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: 'Convidar',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InviteScreen(group: widget.group),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.event_available_outlined),
            tooltip: 'Planejador',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlannerScreen(groupId: widget.group.id),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.grid_view_rounded),
            tooltip: 'Meus filmes',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MyMoviesScreen(groupId: widget.group.id),
              ),
            ),
          ),
        ],
      ),
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
              FutureBuilder<List<TopMovie>>(
                future: _topMoviesFuture,
                builder: (context, rankingSnapshot) {
                  final topMovies = rankingSnapshot.data ?? [];
                  if (topMovies.isEmpty) return const SizedBox.shrink();
                  return MovieRail(
                    title: '🏆 Top do grupo',
                    itemCount: topMovies.length,
                    posterUrlBuilder: (i) => topMovies[i].posterUrl,
                    titleBuilder: (i) => topMovies[i].title,
                    subtitleBuilder: (i) => '★ ${topMovies[i].avgRating.toStringAsFixed(1)}',
                    onTap: (i) => _openMovieDetail(topMovies[i].toMovie()),
                  );
                },
              ),
              FutureBuilder<List<TmdbSearchResult>?>(
                future: _recommendationsFuture,
                builder: (context, recSnapshot) {
                  final recommendations = recSnapshot.data ?? [];
                  if (recommendations.isEmpty) return const SizedBox.shrink();
                  return MovieRail(
                    title: 'Recomendado pro grupo',
                    itemCount: recommendations.length,
                    posterUrlBuilder: (i) => recommendations[i].posterUrl,
                    titleBuilder: (i) => recommendations[i].title,
                    subtitleBuilder: (i) =>
                        recommendations[i].mediaType == 'tv' ? 'Série' : 'Filme',
                    onTap: (i) => _selectRecommendation(recommendations[i]),
                  );
                },
              ),
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
                      onTap: () => _openMovieDetail(entry.movie),
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
