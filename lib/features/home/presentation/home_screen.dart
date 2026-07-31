import 'package:flutter/material.dart';

import '../../../core/widgets/movie_rail.dart';
import '../../groups/data/groups_repository.dart';
import '../../groups/domain/group.dart';
import '../../movies/data/tmdb_repository.dart';
import '../../movies/data/watch_entries_repository.dart';
import '../../movies/domain/movie.dart';
import '../../movies/presentation/log_watch_sheet.dart';
import '../../timeline/data/ranking_repository.dart';
import '../../timeline/domain/top_movie.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _rankingRepository = RankingRepository();
  final _tmdbRepository = TmdbRepository();
  final _groupsRepository = GroupsRepository();
  final _watchEntriesRepository = WatchEntriesRepository();

  late Future<List<TopMovie>> _topMoviesFuture;
  late Future<List<TmdbSearchResult>> _trendingFuture;
  bool _isLoggingMovie = false;

  @override
  void initState() {
    super.initState();
    _topMoviesFuture = _rankingRepository.fetchGlobalTopMovies();
    _trendingFuture = _tmdbRepository.trending();
  }

  /// Every Home-tab discovery card (global Top Filmes or Lançamentos) leads
  /// here: pick which of your groups to log it in, then open the same
  /// rating sheet the search flow uses.
  Future<void> _registerDiscoveryItem({
    required int tmdbId,
    required String mediaType,
    required String title,
  }) async {
    final groups = await _groupsRepository.fetchMyGroups();
    if (!mounted) return;

    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crie ou entre em um grupo primeiro.')),
      );
      return;
    }

    final selectedGroup = await showModalBottomSheet<Group>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Registrar "$title" em qual grupo?'),
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
    if (selectedGroup == null || !mounted) return;

    setState(() => _isLoggingMovie = true);
    try {
      final movie = await _watchEntriesRepository.cacheMovieFromTmdb(
        tmdbId,
        mediaType: mediaType,
      );
      if (!mounted) return;

      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => LogWatchSheet(groupId: selectedGroup.id, movie: movie),
      );
    } finally {
      if (mounted) setState(() => _isLoggingMovie = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avora')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              FutureBuilder<List<TopMovie>>(
                future: _topMoviesFuture,
                builder: (context, snapshot) {
                  final topMovies = snapshot.data ?? [];
                  if (topMovies.isEmpty) return const SizedBox.shrink();
                  return MovieRail(
                    title: '🏆 Top Filmes do Avora',
                    itemCount: topMovies.length,
                    posterUrlBuilder: (i) => topMovies[i].posterUrl,
                    titleBuilder: (i) => topMovies[i].title,
                    subtitleBuilder: (i) => '★ ${topMovies[i].avgRating.toStringAsFixed(1)}',
                    onTap: (i) => _registerDiscoveryItem(
                      tmdbId: topMovies[i].tmdbId,
                      mediaType: topMovies[i].mediaType,
                      title: topMovies[i].title,
                    ),
                  );
                },
              ),
              FutureBuilder<List<TmdbSearchResult>>(
                future: _trendingFuture,
                builder: (context, snapshot) {
                  final trending = snapshot.data ?? [];
                  if (trending.isEmpty) return const SizedBox.shrink();
                  return MovieRail(
                    title: '🆕 Lançamentos e tendências',
                    itemCount: trending.length,
                    posterUrlBuilder: (i) => trending[i].posterUrl,
                    titleBuilder: (i) => trending[i].title,
                    subtitleBuilder: (i) => trending[i].mediaType == 'tv' ? 'Série' : 'Filme',
                    onTap: (i) => _registerDiscoveryItem(
                      tmdbId: trending[i].tmdbId,
                      mediaType: trending[i].mediaType,
                      title: trending[i].title,
                    ),
                  );
                },
              ),
            ],
          ),
          if (_isLoggingMovie)
            const ColoredBox(
              color: Colors.black45,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
