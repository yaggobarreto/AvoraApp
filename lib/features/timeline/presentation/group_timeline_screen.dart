import 'package:flutter/material.dart';

import '../../../core/network/app_errors.dart';
import '../../../core/widgets/movie_rail.dart';
import '../../achievements/presentation/achievement_sync_prompt.dart';
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
import '../../movies/presentation/story_share_prompt.dart';
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
  static const _pageSize = TimelineRepository.defaultPageSize;
  // How close to the bottom (in pixels) before the next page is fetched —
  // far enough that the fetch finishes before the user actually hits the end.
  static const _loadMoreThreshold = 400.0;

  final _repository = TimelineRepository();
  final _rankingRepository = RankingRepository();
  final _tmdbRepository = TmdbRepository();
  final _scrollController = ScrollController();

  late Future<List<TopMovie>> _topMoviesFuture;
  late Future<List<TmdbSearchResult>?> _recommendationsFuture;

  final List<WatchEntry> _entries = [];
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _topMoviesFuture = _rankingRepository.fetchTopMovies(widget.group.id);
    _recommendationsFuture = _loadRecommendations();
    _loadInitialEntries();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore || _isLoadingInitial) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      _loadMoreEntries();
    }
  }

  Future<void> _loadInitialEntries() async {
    setState(() {
      _isLoadingInitial = true;
      _loadError = null;
    });
    try {
      final page = await _repository.fetchTimeline(widget.group.id, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _entries
          ..clear()
          ..addAll(page);
        _hasMore = page.length == _pageSize;
        _isLoadingInitial = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _isLoadingInitial = false;
      });
    }
  }

  Future<void> _loadMoreEntries() async {
    setState(() => _isLoadingMore = true);
    try {
      final page = await _repository.fetchTimeline(
        widget.group.id,
        limit: _pageSize,
        offset: _entries.length,
      );
      if (!mounted) return;
      setState(() {
        _entries.addAll(page);
        _hasMore = page.length == _pageSize;
      });
    } catch (e) {
      // A failed "load more" shouldn't replace the list already on screen —
      // hasMore stays true so scrolling near the bottom again just retries.
      debugPrint('Failed to load more timeline entries: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
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
      _topMoviesFuture = _rankingRepository.fetchTopMovies(widget.group.id);
      _recommendationsFuture = _loadRecommendations();
    });
    _loadInitialEntries();
  }

  Future<void> _openMovieSearch() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieSearchScreen(
          groupId: widget.group.id,
          groupName: widget.group.name,
        ),
      ),
    );
    _reload();
  }

  void _openMovieDetail(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieDetailScreen.forGroup(
          movie: movie,
          groupId: widget.group.id,
          groupName: widget.group.name,
        ),
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
    if (saved == true) {
      _reload();
      if (!mounted) return;
      await syncAndCelebrateAchievements(context);
      if (!mounted) return;
      await maybeOfferStoryShare(
        context,
        groupId: widget.group.id,
        groupName: widget.group.name,
        movie: movie,
      );
    }
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
                builder: (_) => PlannerScreen(
                  groupId: widget.group.id,
                  groupName: widget.group.name,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.grid_view_rounded),
            tooltip: 'Meus filmes',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MyMoviesScreen(
                  groupId: widget.group.id,
                  groupName: widget.group.name,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_isLoadingInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_loadError != null) {
            return Center(child: Text(friendlyErrorMessage(_loadError!)));
          }
          if (_entries.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum filme registrado ainda neste grupo.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final entriesByYear = <int, List<WatchEntry>>{};
          for (final entry in _entries) {
            entriesByYear.putIfAbsent(entry.watchedAt.year, () => []).add(entry);
          }
          final years = entriesByYear.keys.toList()..sort((a, b) => b.compareTo(a));

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              controller: _scrollController,
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
                      subtitleBuilder: (i) =>
                          '★ ${topMovies[i].avgRating.toStringAsFixed(1)}',
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
                if (_isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
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
