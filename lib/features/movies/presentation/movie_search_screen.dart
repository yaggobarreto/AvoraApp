import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/app_errors.dart';
import '../../../core/widgets/poster_card.dart';
import '../../achievements/presentation/achievement_sync_prompt.dart';
import '../data/tmdb_repository.dart';
import '../data/watch_entries_repository.dart';
import '../domain/movie.dart';
import 'log_watch_sheet.dart';
import 'story_share_prompt.dart';

class MovieSearchScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const MovieSearchScreen({super.key, required this.groupId, required this.groupName});

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
  Timer? _debounce;
  int _searchGeneration = 0;

  void _onQueryChanged(String query) {
    setState(() {}); // refresh the clear button's visibility
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      _searchGeneration++; // invalidate any in-flight search's result
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), _search);
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchGeneration++;
    _searchController.clear();
    setState(() {
      _results = [];
      _isSearching = false;
    });
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final generation = ++_searchGeneration;
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final results = await _tmdbRepository.search(query);
      if (mounted && generation == _searchGeneration) {
        setState(() => _results = results);
      }
    } catch (e) {
      if (mounted && generation == _searchGeneration) {
        setState(() => _errorMessage = friendlyErrorMessage(e));
      }
    } finally {
      if (mounted && generation == _searchGeneration) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _selectMovie(TmdbSearchResult result) async {
    setState(() => _isLoggingMovie = true);
    try {
      final movie = await _watchEntriesRepository.cacheMovieFromTmdb(
        result.tmdbId,
        mediaType: result.mediaType,
      );
      if (!mounted) return;

      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => LogWatchSheet(groupId: widget.groupId, movie: movie),
      );

      if (saved == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registrado!')),
        );
        await syncAndCelebrateAchievements(context);
        if (!mounted) return;
        await maybeOfferStoryShare(
          context,
          groupId: widget.groupId,
          groupName: widget.groupName,
          movie: movie,
        );
        if (mounted) Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isLoggingMovie = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastrar filme ou série')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Ex: Interestelar',
                suffixIcon: _searchController.text.isEmpty
                    ? const Icon(Icons.search)
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _clearSearch,
                      ),
              ),
              onChanged: _onQueryChanged,
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
                    return PosterCard(
                      imageUrl: result.posterUrl,
                      title: result.title,
                      subtitle: result.year?.toString(),
                      height: 110,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          result.mediaType == 'tv' ? 'Série' : 'Filme',
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                      onTap: _isLoggingMovie ? null : () => _selectMovie(result),
                    );
                  },
                ),
                if (_isLoggingMovie)
                  const ColoredBox(
                    color: Colors.black45,
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
