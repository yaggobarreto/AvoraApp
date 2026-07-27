import 'package:flutter/material.dart';

import '../../groups/data/groups_repository.dart';
import '../data/watch_entries_repository.dart';
import '../domain/movie.dart';

const _availableEmojis = ['😍', '😂', '😭', '😱', '😴', '🤯', '❤️'];

class LogWatchSheet extends StatefulWidget {
  final String groupId;
  final Movie movie;

  const LogWatchSheet({super.key, required this.groupId, required this.movie});

  @override
  State<LogWatchSheet> createState() => _LogWatchSheetState();
}

class _LogWatchSheetState extends State<LogWatchSheet> {
  final _watchEntriesRepository = WatchEntriesRepository();
  final _groupsRepository = GroupsRepository();
  final _commentController = TextEditingController();
  final _timesWatchedController = TextEditingController(text: '1');

  late Future<List<Map<String, dynamic>>> _membersFuture;

  DateTime _watchedAt = DateTime.now();
  String _location = watchLocations.first;
  double _rating = 5;
  final Set<String> _selectedEmojis = {};
  final Set<String> _selectedParticipants = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _membersFuture = _groupsRepository.fetchMembers(widget.groupId);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _timesWatchedController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _watchEntriesRepository.logWatch(
        groupId: widget.groupId,
        movieId: widget.movie.id,
        watchedAt: _watchedAt,
        watchLocation: _location,
        timesWatched: int.tryParse(_timesWatchedController.text) ?? 1,
        rating: _rating,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
        emojis: _selectedEmojis.toList(),
        participantUserIds: _selectedParticipants.toList(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.movie.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _location,
              decoration: const InputDecoration(labelText: 'Onde assistiu?'),
              items: [
                for (final loc in watchLocations)
                  DropdownMenuItem(value: loc, child: Text(watchLocationLabels[loc]!)),
              ],
              onChanged: (v) => setState(() => _location = v!),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data'),
              subtitle: Text('${_watchedAt.day}/${_watchedAt.month}/${_watchedAt.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _watchedAt,
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _watchedAt = picked);
              },
            ),
            TextField(
              controller: _timesWatchedController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantas vezes assistiu?'),
            ),
            const SizedBox(height: 12),
            Text('Avaliação: ${_rating.toStringAsFixed(1)} ★'),
            Slider(
              value: _rating,
              min: 0,
              max: 5,
              divisions: 10,
              label: _rating.toStringAsFixed(1),
              onChanged: (v) => setState(() => _rating = v),
            ),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(labelText: 'Comentário'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final emoji in _availableEmojis)
                  FilterChip(
                    label: Text(emoji),
                    selected: _selectedEmojis.contains(emoji),
                    onSelected: (selected) => setState(() {
                      selected
                          ? _selectedEmojis.add(emoji)
                          : _selectedEmojis.remove(emoji);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Assistido com:'),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _membersFuture,
              builder: (context, snapshot) {
                final members = snapshot.data ?? [];
                return Wrap(
                  spacing: 8,
                  children: [
                    for (final member in members)
                      FilterChip(
                        label: Text(member['name'] as String),
                        selected: _selectedParticipants.contains(member['user_id']),
                        onSelected: (selected) => setState(() {
                          selected
                              ? _selectedParticipants.add(member['user_id'] as String)
                              : _selectedParticipants.remove(member['user_id']);
                        }),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
