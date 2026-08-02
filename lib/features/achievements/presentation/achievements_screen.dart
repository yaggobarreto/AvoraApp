import 'package:flutter/material.dart';

import '../../../core/network/app_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/achievements_repository.dart';
import '../domain/achievement.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late Future<List<UnlockedAchievement>> _future;

  @override
  void initState() {
    super.initState();
    _future = AchievementsRepository().syncAndFetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conquistas')),
      body: FutureBuilder<List<UnlockedAchievement>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(friendlyErrorMessage(snapshot.error!)));
          }

          final unlockedById = {
            for (final u in snapshot.data!) u.achievementId: u,
          };

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.95,
            ),
            itemCount: achievementCatalog.length,
            itemBuilder: (context, index) {
              final definition = achievementCatalog[index];
              return _AchievementCard(
                definition: definition,
                unlocked: unlockedById[definition.id],
              );
            },
          );
        },
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final AchievementDefinition definition;
  final UnlockedAchievement? unlocked;

  const _AchievementCard({required this.definition, this.unlocked});

  @override
  Widget build(BuildContext context) {
    final isUnlocked = unlocked != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: isUnlocked
            ? Border.all(color: AppTheme.brandTeal.withValues(alpha: 0.5))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(
            opacity: isUnlocked ? 1 : 0.35,
            child: Text(definition.emoji, style: const TextStyle(fontSize: 32)),
          ),
          const SizedBox(height: 10),
          Text(
            definition.title,
            style: TextStyle(
              color: isUnlocked ? AppTheme.onSurface : AppTheme.onSurfaceMuted,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              definition.description,
              style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12, height: 1.3),
            ),
          ),
          if (!isUnlocked)
            const Icon(Icons.lock_outline, size: 16, color: AppTheme.onSurfaceMuted),
        ],
      ),
    );
  }
}
