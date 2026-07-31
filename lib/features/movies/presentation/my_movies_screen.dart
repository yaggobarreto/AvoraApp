import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../timeline/data/timeline_repository.dart';
import '../../timeline/domain/watch_entry.dart';
import '../domain/movie.dart';
import 'movie_detail_screen.dart';

enum _SortOrder { highestRating, lowestRating, newest, oldest }

const _sortLabels = {
  _SortOrder.highestRating: 'Maior nota',
  _SortOrder.lowestRating: 'Menor nota',
  _SortOrder.newest: 'Mais recente',
  _SortOrder.oldest: 'Mais antigo',
};

class MyMoviesScreen extends StatefulWidget {
  final String groupId;

  const MyMoviesScreen({super.key, required this.groupId});

  @override
  State<MyMoviesScreen> createState() => _MyMoviesScreenState();
}

class _MyMoviesScreenState extends State<MyMoviesScreen> {
  final _repository = TimelineRepository();
  late Future<List<WatchEntry>> _entriesFuture;

  bool _isGrid = true;
  _SortOrder _sortOrder = _SortOrder.newest;
  String? _genreFilter;
  String? _locationFilter;
  int? _yearFilter;

  @override
  void initState() {
    super.initState();
    _entriesFuture = _repository.fetchMyEntries(widget.groupId);
  }

  List<WatchEntry> _applyFiltersAndSort(List<WatchEntry> entries) {
    var filtered = entries.where((e) {
      if (_genreFilter != null && !e.movie.genres.contains(_genreFilter)) return false;
      if (_locationFilter != null && e.watchLocation != _locationFilter) return false;
      if (_yearFilter != null && e.watchedAt.year != _yearFilter) return false;
      return true;
    }).toList();

    filtered.sort((a, b) {
      switch (_sortOrder) {
        case _SortOrder.highestRating:
          return (b.rating ?? 0).compareTo(a.rating ?? 0);
        case _SortOrder.lowestRating:
          return (a.rating ?? 0).compareTo(b.rating ?? 0);
        case _SortOrder.newest:
          return b.watchedAt.compareTo(a.watchedAt);
        case _SortOrder.oldest:
          return a.watchedAt.compareTo(b.watchedAt);
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus filmes'),
        actions: [
          IconButton(
            icon: Icon(_isGrid ? Icons.view_list : Icons.grid_view_rounded),
            onPressed: () => setState(() => _isGrid = !_isGrid),
          ),
        ],
      ),
      body: FutureBuilder<List<WatchEntry>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final allEntries = snapshot.data ?? [];
          if (allEntries.isEmpty) {
            return const Center(
              child: Text(
                'Você ainda não registrou nenhum filme aqui.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final genres = allEntries.expand((e) => e.movie.genres).toSet().toList()..sort();
          final locations = allEntries.map((e) => e.watchLocation).toSet().toList();
          final years = allEntries.map((e) => e.watchedAt.year).toSet().toList()
            ..sort((a, b) => b.compareTo(a));

          final entries = _applyFiltersAndSort(allEntries);

          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _FilterDropdown<_SortOrder>(
                      label: 'Ordenar',
                      value: _sortOrder,
                      items: _SortOrder.values,
                      itemLabel: (v) => _sortLabels[v]!,
                      onChanged: (v) => setState(() => _sortOrder = v!),
                    ),
                    const SizedBox(width: 8),
                    _FilterDropdown<String?>(
                      label: 'Gênero',
                      value: _genreFilter,
                      items: [null, ...genres],
                      itemLabel: (v) => v ?? 'Todos',
                      onChanged: (v) => setState(() => _genreFilter = v),
                    ),
                    const SizedBox(width: 8),
                    _FilterDropdown<String?>(
                      label: 'Streamer',
                      value: _locationFilter,
                      items: [null, ...locations],
                      itemLabel: (v) => v == null ? 'Todos' : watchLocationLabels[v]!,
                      onChanged: (v) => setState(() => _locationFilter = v),
                    ),
                    const SizedBox(width: 8),
                    _FilterDropdown<int?>(
                      label: 'Ano',
                      value: _yearFilter,
                      items: [null, ...years],
                      itemLabel: (v) => v?.toString() ?? 'Todos',
                      onChanged: (v) => setState(() => _yearFilter = v),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isGrid ? _buildGrid(entries) : _buildList(entries),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGrid(List<WatchEntry> entries) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.55,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return InkWell(
          onTap: () => _openDetail(entry),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: entry.movie.posterUrl != null
                      ? CachedNetworkImage(
                          imageUrl: entry.movie.posterUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        )
                      : const ColoredBox(
                          color: AppTheme.surfaceHigh,
                          child: Icon(Icons.movie),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '★ ${entry.rating?.toStringAsFixed(1) ?? '-'}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(List<WatchEntry> entries) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: entry.movie.posterUrl != null
                ? CachedNetworkImage(imageUrl: entry.movie.posterUrl!, width: 40, fit: BoxFit.cover)
                : const Icon(Icons.movie),
          ),
          title: Text(entry.movie.title),
          subtitle: Text(
            '★ ${entry.rating?.toStringAsFixed(1) ?? '-'} · '
            '${watchLocationLabels[entry.watchLocation]} · '
            '${entry.watchedAt.day}/${entry.watchedAt.month}/${entry.watchedAt.year}',
          ),
          onTap: () => _openDetail(entry),
        );
      },
    );
  }

  void _openDetail(WatchEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieDetailScreen.forGroup(movie: entry.movie, groupId: widget.groupId),
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: AppTheme.surfaceHigh,
          items: [
            for (final item in items)
              DropdownMenuItem<T>(value: item, child: Text('$label: ${itemLabel(item)}')),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
