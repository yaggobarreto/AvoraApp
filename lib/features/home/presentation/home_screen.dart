import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/movie_rail.dart';
import '../../movies/data/tmdb_repository.dart';
import '../../movies/data/watch_entries_repository.dart';
import '../../movies/domain/movie.dart';
import '../../movies/presentation/movie_detail_screen.dart';
import '../../timeline/data/ranking_repository.dart';
import '../../timeline/domain/top_movie.dart';

class _Recommendations {
  final String seedTitle;
  final List<TmdbSearchResult> items;

  _Recommendations({required this.seedTitle, required this.items});
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

  late Future<List<TopMovie>> _topMoviesFuture;
  late Future<List<TmdbSearchResult>> _trendingFuture;
  late Future<_Recommendations?> _recommendationsFuture;

  @override
  void initState() {
    super.initState();
    _topMoviesFuture = _rankingRepository.fetchGlobalTopMovies();
    _trendingFuture = _tmdbRepository.trending();
    _recommendationsFuture = _loadRecommendations();
  }

  Future<_Recommendations?> _loadRecommendations() async {
    final seed = await _watchEntriesRepository.fetchMyFavoriteMovie();
    if (seed == null) return null;

    final items = await _tmdbRepository.recommendationsFor(seed.tmdbId, seed.mediaType);
    return _Recommendations(seedTitle: seed.title, items: items);
  }

  void _openDetail({
    required int tmdbId,
    required String mediaType,
    required String title,
    String? posterUrl,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieDetailScreen(
          tmdbId: tmdbId,
          mediaType: mediaType,
          title: title,
          posterUrl: posterUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avora')),
      body: ListView(
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
                onTap: (i) => _openDetail(
                  tmdbId: topMovies[i].tmdbId,
                  mediaType: topMovies[i].mediaType,
                  title: topMovies[i].title,
                  posterUrl: topMovies[i].posterUrl,
                ),
              );
            },
          ),
          FutureBuilder<_Recommendations?>(
            future: _recommendationsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox.shrink();
              }
              final recommendations = snapshot.data;
              if (recommendations == null) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recomendado', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 6),
                      const Text(
                        'Avalie um filme ou série para receber recomendações personalizadas.',
                        style: TextStyle(color: AppTheme.onSurfaceMuted),
                      ),
                    ],
                  ),
                );
              }
              if (recommendations.items.isEmpty) return const SizedBox.shrink();
              final items = recommendations.items;
              return MovieRail(
                title: 'Recomendado porque você gostou de ${recommendations.seedTitle}',
                itemCount: items.length,
                posterUrlBuilder: (i) => items[i].posterUrl,
                titleBuilder: (i) => items[i].title,
                subtitleBuilder: (i) => items[i].mediaType == 'tv' ? 'Série' : 'Filme',
                onTap: (i) => _openDetail(
                  tmdbId: items[i].tmdbId,
                  mediaType: items[i].mediaType,
                  title: items[i].title,
                  posterUrl: items[i].posterUrl,
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
                onTap: (i) => _openDetail(
                  tmdbId: trending[i].tmdbId,
                  mediaType: trending[i].mediaType,
                  title: trending[i].title,
                  posterUrl: trending[i].posterUrl,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
