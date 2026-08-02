import 'package:flutter/material.dart';

import '../../movies/domain/movie.dart';
import '../data/planner_repository.dart';
import '../domain/planned_session.dart';

/// Shared "Agendar Sessão" dialog — used both from the Planejador screen
/// (scheduling a title already in the watchlist) and directly from the
/// movie detail page (schedule without visiting the watchlist first).
/// Returns true if a session was scheduled.
Future<bool> showScheduleSessionDialog(
  BuildContext context, {
  required String groupId,
  required Movie movie,
}) async {
  var date = DateTime.now().add(const Duration(days: 1));
  var location = sessionLocations.first;
  final notesController = TextEditingController();

  final scheduled = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text('Agendar "${movie.title}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data e horário'),
              subtitle: Text(
                '${date.day}/${date.month}/${date.year} às '
                '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (pickedDate == null) return;
                if (!context.mounted) return;
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(date),
                );
                setDialogState(() {
                  date = DateTime(
                    pickedDate.year,
                    pickedDate.month,
                    pickedDate.day,
                    pickedTime?.hour ?? date.hour,
                    pickedTime?.minute ?? date.minute,
                  );
                });
              },
            ),
            DropdownButtonFormField<String>(
              initialValue: location,
              decoration: const InputDecoration(labelText: 'Local'),
              items: [
                for (final loc in sessionLocations)
                  DropdownMenuItem(value: loc, child: Text(sessionLocationLabels[loc]!)),
              ],
              onChanged: (v) => setDialogState(() => location = v!),
            ),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Observações (opcional)'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Agendar'),
          ),
        ],
      ),
    ),
  );

  if (scheduled != true || !context.mounted) return false;

  await PlannerRepository().scheduleSession(
    groupId: groupId,
    movieId: movie.id,
    scheduledAt: date,
    location: location,
    notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
  );
  return true;
}
