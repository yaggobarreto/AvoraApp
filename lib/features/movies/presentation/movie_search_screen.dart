import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/tmdb_repository.dart';
import '../data/watch_entries_repository.dart';
import '../domain/movie.dart';
import 'log_watch_sheet.dart';

class MovieSearchScreen extends StatefulWidget {
  final String groupId;

  const MovieSearchScreen({super.key, required this.groupId});

  @override
  State<MovieSearchScreen> createState() => _MovieSearchScreenState();
}

class _MovieSearchScreenState extends State<MovieSearchScreen> {
  final _tmdbRepository = TmdbRepository();
  final _watchEntriesRepository = WatchEntriesRepository();
  final _searchController = TextEditingController();

  List<TmdbSearchResult> _results = [];
  bool _isSearching = false;
  bool _isLoggingMovie = false;
  String? _errorMessage;

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final results = await _tmdbRepository.search(query);
      setState(() => _results = results);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _selectMovie(TmdbSearchResult result) async {
    setState(() => _isLoggingMovie = true);
    try {
      final movie = await _watchEntriesRepository.cacheMovieFromTmdb(result.tmdbId);
      if (!mounted) return;

      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => LogWatchSheet(groupId: widget.groupId, movie: movie),
      );

      if (saved == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Filme registrado!')),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isLoggingMovie = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastrar filme')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppTheme.cardOnSurface),
              decoration: InputDecoration(
                hintText: 'Ex: Interestelar',
                filled: true,
                fillColor: AppTheme.cardSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: AppTheme.cardOnSurface),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          if (_isSearching) const LinearProgressIndicator(),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final result = _results[index];
                    return Card(
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: result.posterUrl != null
                              ? Image.network(
                                  result.posterUrl!,
                                  width: 40,
                                  fit: BoxFit.cover,
                                )
                              : const Icon(Icons.movie),
                        ),
                        title: Text(result.title),
                        subtitle: Text(result.year?.toString() ?? ''),
                        onTap: _isLoggingMovie ? null : () => _selectMovie(result),
                      ),
                    );
                  },
                ),
                if (_isLoggingMovie) const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
