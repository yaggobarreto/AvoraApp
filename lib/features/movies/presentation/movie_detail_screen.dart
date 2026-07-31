import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../data/tmdb_repository.dart';
import '../data/watch_entries_repository.dart';
import '../domain/movie.dart';

class MovieDetailScreen extends StatefulWidget {
  final Movie movie;
  final String groupId;

  const MovieDetailScreen({super.key, required this.movie, required this.groupId});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  final _tmdbRepository = TmdbRepository();
  final _watchEntriesRepository = WatchEntriesRepository();

  late Future<MovieDetails> _detailsFuture;
  late Future<List<Map<String, dynamic>>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _tmdbRepository.movieDetails(
      widget.movie.tmdbId,
      mediaType: widget.movie.mediaType,
    );
    _entriesFuture = _watchEntriesRepository.fetchEntriesForMovieInGroup(
      widget.groupId,
      widget.movie.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<MovieDetails>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          final details = snapshot.data!;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 220,
                backgroundColor: AppTheme.background,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (details.backdropUrl != null)
                        CachedNetworkImage(imageUrl: details.backdropUrl!, fit: BoxFit.cover),
                      const DecoratedBox(
                        decoration: BoxDecoration(gradient: AppTheme.posterScrim),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (details.posterUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: details.posterUrl!,
                              width: 90,
                              fit: BoxFit.cover,
                            ),
                          ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(details.title, style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 6),
                              Text(
                                [
                                  if (details.year != null) '${details.year}',
                                  if (details.runtimeMinutes != null)
                                    details.isSeries
                                        ? '${details.runtimeMinutes} min/ep'
                                        : '${details.runtimeMinutes} min',
                                  if (details.isSeries) 'Série',
                                ].join(' · '),
                                style: const TextStyle(color: AppTheme.onSurfaceMuted),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                details.genres.join(', '),
                                style: const TextStyle(color: AppTheme.onSurfaceMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (details.synopsis != null && details.synopsis!.isNotEmpty)
                      Text(details.synopsis!, style: const TextStyle(height: 1.4)),
                    if (details.director != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${details.isSeries ? 'Criado por' : 'Direção'}: ${details.director}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                    if (details.trailerUrl != null) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => launchUrl(Uri.parse(details.trailerUrl!)),
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('Assistir trailer'),
                      ),
                    ],
                    if (details.watchProviders.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text('Disponível em', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 56,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: details.watchProviders.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final provider = details.watchProviders[index];
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CachedNetworkImage(
                                imageUrl: provider.logoUrl,
                                width: 56,
                                height: 56,
                              ),
                            );
                          },
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Indisponível em streamings no momento.',
                        style: TextStyle(color: AppTheme.onSurfaceMuted),
                      ),
                    ],
                    if (details.cast.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text('Elenco', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 130,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: details.cast.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final member = details.cast[index];
                            return SizedBox(
                              width: 80,
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 32,
                                    backgroundColor: AppTheme.surfaceHigh,
                                    backgroundImage: member.profileUrl != null
                                        ? CachedNetworkImageProvider(member.profileUrl!)
                                        : null,
                                    child: member.profileUrl == null
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    member.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text('Avaliações do grupo', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _entriesFuture,
                      builder: (context, entrySnapshot) {
                        final entries = entrySnapshot.data ?? [];
                        if (entries.isEmpty) {
                          return const Text(
                            'Ninguém do grupo avaliou este título ainda.',
                            style: TextStyle(color: AppTheme.onSurfaceMuted),
                          );
                        }

                        final userId = supabase.auth.currentUser?.id;
                        final ratings = entries
                            .map((e) => (e['rating'] as num?)?.toDouble())
                            .whereType<double>()
                            .toList();
                        final groupAvg = ratings.isEmpty
                            ? null
                            : ratings.reduce((a, b) => a + b) / ratings.length;
                        final yourRatings = entries
                            .where((e) => e['logged_by'] == userId)
                            .map((e) => (e['rating'] as num?)?.toDouble())
                            .whereType<double>()
                            .toList();
                        final yourAvg = yourRatings.isEmpty
                            ? null
                            : yourRatings.reduce((a, b) => a + b) / yourRatings.length;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (yourAvg != null) ...[
                                  _RatingChip(label: 'Sua nota', value: yourAvg),
                                  const SizedBox(width: 10),
                                ],
                                if (groupAvg != null)
                                  _RatingChip(label: 'Nota do grupo', value: groupAvg),
                              ],
                            ),
                            const SizedBox(height: 16),
                            for (final entry in entries)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (entry['profiles']?['name'] as String?) ?? '—',
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                          if ((entry['comment'] as String?)?.isNotEmpty ?? false)
                                            Text(entry['comment'] as String),
                                        ],
                                      ),
                                    ),
                                    if (entry['rating'] != null)
                                      Text('★ ${entry['rating']}'),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  final String label;
  final double value;

  const _RatingChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text('★ ${value.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceMuted)),
        ],
      ),
    );
  }
}
