import 'package:flutter/material.dart';

import '../data/achievements_repository.dart';
import 'achievement_unlocked_dialog.dart';

/// Checks for newly unlocked achievements and celebrates any of them, right
/// after a rating gets logged — the moment a milestone is actually crossed.
Future<void> syncAndCelebrateAchievements(BuildContext context) async {
  try {
    final unlocked = await AchievementsRepository().syncAndFetch();
    if (!context.mounted) return;
    await showUnlockedAchievements(context, unlocked);
  } catch (e) {
    // A missed celebration isn't worth surfacing as an error — the rating
    // itself already saved successfully.
    debugPrint('Achievement sync failed: $e');
  }
}
