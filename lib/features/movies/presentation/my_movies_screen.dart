import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/network/app_errors.dart';
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
  final String groupName;

  const MyMoviesScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<MyMoviesScreen> createState() => _MyMoviesScreenState();
}

class _MyMoviesScreenState extends State<MyMoviesScreen> {
  static const _pageSize = TimelineRepository.defaultPageSize;
  static const _loadMoreThreshold = 400.0;

  final _repository = TimelineRepository();
  final _scrollController = ScrollController();

  final List<WatchEntry> _allEntries = [];
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  Object? _loadError;

  bool _isGrid = true;
  _SortOrder _sortOrder = _SortOrder.newest;
  String? _genreFilter;
  String? _locationFilter;
  int? _yearFilter;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Filtering/sorting happens over whatever has loaded so far — the genre,
  // streamer and year dropdowns grow to include a value only once an entry
  // using it has actually been fetched, and more loads automatically as the
  // user scrolls, including while a filter is active.
  void _onScroll() {
    if (!_hasMore || _isLoadingMore || _isLoadingInitial) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoadingInitial = true;
      _loadError = null;
    });
    try {
      final page = await _repository.fetchMyEntries(widget.groupId, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _allEntries
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

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final page = await _repository.fetchMyEntries(
        widget.groupId,
        limit: _pageSize,
        offset: _allEntries.length,
      );
      if (!mounted) return;
      setState(() {
        _allEntries.addAll(page);
        _hasMore = page.length == _pageSize;
      });
    } catch (e) {
      debugPrint('Failed to load more of "Meus filmes": $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
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
      body: Builder(
        builder: (context) {
          if (_isLoadingInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_loadError != null) {
            return Center(child: Text(friendlyErrorMessage(_loadError!)));
          }
          if (_allEntries.isEmpty) {
            return const Center(
              child: Text(
                'Você ainda não registrou nenhum filme aqui.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final genres = _allEntries.expand((e) => e.movie.genres).toSet().toList()..sort();
          final locations = _allEntries.map((e) => e.watchLocation).toSet().toList();
          final years = _allEntries.map((e) => e.watchedAt.year).toSet().toList()
            ..sort((a, b) => b.compareTo(a));

          final entries = _applyFiltersAndSort(_allEntries);

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
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.55,
      ),
      itemCount: entries.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= entries.length) return const _LoadingMoreTile();

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
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= entries.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

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
        builder: (_) => MovieDetailScreen.forGroup(
          movie: entry.movie,
          groupId: widget.groupId,
          groupName: widget.groupName,
        ),
      ),
    );
  }
}

class _LoadingMoreTile extends StatelessWidget {
  const _LoadingMoreTile();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
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
