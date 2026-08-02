import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/network/app_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/feed_repository.dart';
import '../domain/feed_event.dart';

class ActivityFeedScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const ActivityFeedScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  static const _pageSize = FeedRepository.defaultPageSize;
  static const _loadMoreThreshold = 400.0;

  final _repository = FeedRepository();
  final _scrollController = ScrollController();

  final List<FeedEvent> _events = [];
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  Object? _loadError;

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
      final page = await _repository.fetchGroupActivity(widget.groupId, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _events
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
      final page = await _repository.fetchGroupActivity(
        widget.groupId,
        limit: _pageSize,
        offset: _events.length,
      );
      if (!mounted) return;
      setState(() {
        _events.addAll(page);
        _hasMore = page.length == _pageSize;
      });
    } catch (e) {
      debugPrint('Failed to load more of the activity feed: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Atividade · ${widget.groupName}')),
      body: Builder(
        builder: (context) {
          if (_isLoadingInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_loadError != null) {
            return Center(child: Text(friendlyErrorMessage(_loadError!)));
          }
          if (_events.isEmpty) {
            return const Center(
              child: Text(
                'Nada por aqui ainda. Registre um filme para começar.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadInitial,
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _events.length + (_isLoadingMore ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(height: 1, color: AppTheme.surfaceHigh),
              itemBuilder: (context, index) {
                if (index >= _events.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _FeedTile(event: _events[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _FeedTile extends StatelessWidget {
  final FeedEvent event;

  const _FeedTile({required this.event});

  String get _headline {
    switch (event.type) {
      case FeedEventType.watchEntry:
        final rating = event.rating != null ? ' ★ ${event.rating!.toStringAsFixed(1)}' : '';
        return '${event.actorName} avaliou "${event.movieTitle}"$rating';
      case FeedEventType.memberJoined:
        return '${event.actorName} entrou no grupo';
      case FeedEventType.sessionScheduled:
        return '${event.actorName} agendou uma sessão de "${event.movieTitle}"';
      case FeedEventType.watchlistAdded:
        return '${event.actorName} adicionou "${event.movieTitle}" à lista';
    }
  }

  IconData get _icon {
    switch (event.type) {
      case FeedEventType.watchEntry:
        return Icons.star_rounded;
      case FeedEventType.memberJoined:
        return Icons.person_add_alt_1_rounded;
      case FeedEventType.sessionScheduled:
        return Icons.event_available_rounded;
      case FeedEventType.watchlistAdded:
        return Icons.bookmark_add_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: event.moviePosterUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: event.moviePosterUrl!,
                width: 40,
                fit: BoxFit.cover,
              ),
            )
          : CircleAvatar(
              backgroundColor: AppTheme.surfaceHigh,
              child: Icon(_icon, size: 18, color: AppTheme.onSurfaceMuted),
            ),
      title: Text(_headline),
      subtitle: Text(_relativeTime(event.createdAt)),
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'agora mesmo';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    if (diff.inDays < 7) return 'há ${diff.inDays}d';
    return '${time.day}/${time.month}/${time.year}';
  }
}
