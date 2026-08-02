import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/achievement.dart';

/// Shows one dialog per newly unlocked achievement, in sequence. Called
/// right after logging a rating, when sync_and_fetch_achievements() may
/// return entries with isNew: true.
Future<void> showUnlockedAchievements(
  BuildContext context,
  List<UnlockedAchievement> unlocked,
) async {
  final newOnes = unlocked.where((u) => u.isNew).toList();
  for (final entry in newOnes) {
    if (!context.mounted) return;
    final definition = achievementCatalog.firstWhere(
      (a) => a.id == entry.achievementId,
      // A server rollout could unlock an id the client's catalog doesn't
      // know about yet — show something generic rather than crash.
      orElse: () => const AchievementDefinition(
        id: '',
        emoji: '🏅',
        title: 'Nova conquista',
        description: '',
      ),
    );
    await showDialog<void>(
      context: context,
      builder: (_) => _AchievementUnlockedDialog(definition: definition),
    );
  }
}

class _AchievementUnlockedDialog extends StatelessWidget {
  final AchievementDefinition definition;

  const _AchievementUnlockedDialog({required this.definition});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF221545), AppTheme.background],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.brandTeal.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'CONQUISTA DESBLOQUEADA',
              style: TextStyle(
                color: AppTheme.brandTeal,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(definition.emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 14),
            Text(
              definition.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (definition.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                definition.description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Legal!'),
            ),
          ],
        ),
      ),
    );
  }
}
