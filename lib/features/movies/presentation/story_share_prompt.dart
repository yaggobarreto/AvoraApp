import 'package:flutter/material.dart';

import '../../../core/network/supabase_config.dart';
import '../data/watch_entries_repository.dart';
import '../domain/movie.dart';
import 'story_share_screen.dart';

/// Opens the Story share screen right after a rating is logged, pre-filled
/// with the user's score and the group's median — the "auto-share" the
/// feature previously required hunting for a button on the movie's detail
/// page to reach.
///
/// This still stops short of posting anything by itself: Instagram (and the
/// OS share sheet in general) has no API for silently sharing on a user's
/// behalf, so a tap of theirs on the actual share button is unavoidable and
/// appropriate. "Automatic" here means the *prompt* appears without the user
/// having to go find it, not that a post happens without their input.
Future<void> maybeOfferStoryShare(
  BuildContext context, {
  required String groupId,
  required String groupName,
  required Movie movie,
}) async {
  try {
    final entries = await WatchEntriesRepository()
        .fetchEntriesForMovieInGroup(groupId, movie.id);
    final userId = supabase.auth.currentUser?.id;

    final ratings = entries
        .map((e) => (e['rating'] as num?)?.toDouble())
        .whereType<double>()
        .toList();
    final yourRatings = entries
        .where((e) => e['logged_by'] == userId)
        .map((e) => (e['rating'] as num?)?.toDouble())
        .whereType<double>()
        .toList();

    // Nothing to show if this particular log had no rating attached.
    if (yourRatings.isEmpty || !context.mounted) return;

    final yourAvg = yourRatings.reduce((a, b) => a + b) / yourRatings.length;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryShareScreen(
          movieTitle: movie.title,
          posterUrl: movie.posterUrl,
          myRating: yourAvg,
          groupMedianRating: medianRating(ratings),
          groupName: groupName,
        ),
      ),
    );
  } catch (e) {
    // This is a convenience prompt, not part of the save itself — the rating
    // is already safely stored, so a failure here should never surface as an
    // error to the user.
    debugPrint('Could not prepare story share prompt: $e');
  }
}
