import 'package:flutter/material.dart';

import '../../../core/widgets/movie_rail.dart';
import '../../../core/widgets/rail_states.dart';
import '../../movies/data/tmdb_repository.dart';
import '../../movies/data/watch_entries_repository.dart';
import '../../movies/domain/movie.dart';
import '../../movies/presentation/movie_detail_screen.dart';
import '../../onboarding/data/preferences_repository.dart';
import '../../timeline/data/ranking_repository.dart';
import '../../timeline/domain/top_movie.dart';

/// A rail's worth of titles plus the heading that explains where they came
/// from — the heading changes depending on whether the data is the
/// community's or a TMDB fallback, so the user is never misled about which
/// they're looking at.
class _Rail {
  final String title;
  final List<TmdbSearchResult> items;

  _Rail(this.title, this.items);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _rankingRepository = RankingRepository();
  final _tmdbRepository = TmdbRepository();
  final _watchEntriesRepository = WatchEntriesRepository();
  final _preferencesRepository = PreferencesRepository();

  late Future<List<TopMovie>> _topMoviesFuture;
  late Future<_Rail> _highlightsFuture;
  late Future<_Rail> _recommendationsFuture;
  late Future<List<TmdbSearchResult>> _trendingFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _topMoviesFuture = _rankingRepository.fetchGlobalTopMovies();
    _highlightsFuture = _loadHighlights();
    _recommendationsFuture = _loadRecommendations();
    _trendingFuture = _tmdbRepository.trending();
  }

  void _reload() => setState(_load);

  /// The community ranking is empty until users have rated things, which on a
  /// new install is always. Rather than hide the rail, fall back to TMDB's
  /// best-rated titles so there is something to browse from minute one.
  Future<_Rail> _loadHighlights() async {
    final topMovies = await _topMoviesFuture;
    if (topMovies.isNotEmpty) return _Rail('', const []);

    final items = await _tmdbRepository.discover(topRated: true);
    return _Rail('⭐ Aclamados pela crítica', items);
  }

  /// Recommendations are normally seeded from a title the user rated highly.
  /// Before they have rated anything, fall back to the genres they picked
  /// during onboarding.
  Future<_Rail> _loadRecommendations() async {
    final seed = await _watchEntriesRepository.fetchMyFavoriteMovie();
    if (seed != null) {
      final items =
          await _tmdbRepository.recommendationsFor(seed.tmdbId, seed.mediaType);
      if (items.isNotEmpty) {
        return _Rail('Porque você gostou de ${seed.title}', items);
      }
    }

    final preferences = await _preferencesRepository.fetchMyPreferences();
    if (preferences.genreIds.isEmpty) return _Rail('', const []);

    final items = await _tmdbRepository.discover(
      genreIds: preferences.genreIds,
      mediaType: preferences.discoverMediaType,
    );
    return _Rail('Escolhido para você', items);
  }

  void _openDetail(TmdbSearchResult item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieDetailScreen(
          tmdbId: item.tmdbId,
          mediaType: item.mediaType,
          title: item.title,
          posterUrl: item.posterUrl,
        ),
      ),
    );
  }

  Widget _buildTmdbRail(Future<_Rail> future, String skeletonTitle) {
    return FutureBuilder<_Rail>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return RailSkeleton(title: skeletonTitle);
        }
        if (snapshot.hasError) {
          return RailError(title: skeletonTitle, onRetry: _reload);
        }

        final rail = snapshot.data;
        if (rail == null || rail.items.isEmpty) return const SizedBox.shrink();

        return MovieRail(
          title: rail.title,
          itemCount: rail.items.length,
          posterUrlBuilder: (i) => rail.items[i].posterUrl,
          titleBuilder: (i) => rail.items[i].title,
          subtitleBuilder: (i) =>
              rail.items[i].mediaType == 'tv' ? 'Série' : 'Filme',
          onTap: (i) => _openDetail(rail.items[i]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avora')),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            FutureBuilder<List<TopMovie>>(
              future: _topMoviesFuture,
              builder: (context, snapshot) {
                const title = '🏆 Top Filmes do Avora';
                if (snapshot.connectionState != ConnectionState.done) {
                  return const RailSkeleton(title: title);
                }
                if (snapshot.hasError) {
                  return RailError(title: title, onRetry: _reload);
                }

                final topMovies = snapshot.data ?? [];
                // Empty is expected before the community has rated anything;
                // the highlights rail below covers that case.
                if (topMovies.isEmpty) return const SizedBox.shrink();

                return MovieRail(
                  title: title,
                  itemCount: topMovies.length,
                  posterUrlBuilder: (i) => topMovies[i].posterUrl,
                  titleBuilder: (i) => topMovies[i].title,
                  subtitleBuilder: (i) =>
                      '★ ${topMovies[i].avgRating.toStringAsFixed(1)}',
                  onTap: (i) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MovieDetailScreen(
                        tmdbId: topMovies[i].tmdbId,
                        mediaType: topMovies[i].mediaType,
                        title: topMovies[i].title,
                        posterUrl: topMovies[i].posterUrl,
                      ),
                    ),
                  ),
                );
              },
            ),
            _buildTmdbRail(_recommendationsFuture, 'Escolhido para você'),
            _buildTmdbRail(_highlightsFuture, '⭐ Aclamados pela crítica'),
            FutureBuilder<List<TmdbSearchResult>>(
              future: _trendingFuture,
              builder: (context, snapshot) {
                const title = '🆕 Lançamentos e tendências';
                if (snapshot.connectionState != ConnectionState.done) {
                  return const RailSkeleton(title: title);
                }
                if (snapshot.hasError) {
                  return RailError(title: title, onRetry: _reload);
                }

                final trending = snapshot.data ?? [];
                if (trending.isEmpty) return const SizedBox.shrink();

                return MovieRail(
                  title: title,
                  itemCount: trending.length,
                  posterUrlBuilder: (i) => trending[i].posterUrl,
                  titleBuilder: (i) => trending[i].title,
                  subtitleBuilder: (i) =>
                      trending[i].mediaType == 'tv' ? 'Série' : 'Filme',
                  onTap: (i) => _openDetail(trending[i]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
