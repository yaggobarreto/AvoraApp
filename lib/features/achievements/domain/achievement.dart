/// The achievement catalog: display metadata only (title, emoji,
/// description). Whether one is actually earned is decided entirely by
/// `sync_and_fetch_achievements()` in the database — this list exists so the
/// UI has something to render for every id that function can return,
/// including the ones a user hasn't unlocked yet.
class AchievementDefinition {
  final String id;
  final String emoji;
  final String title;
  final String description;

  const AchievementDefinition({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
  });
}

const achievementCatalog = <AchievementDefinition>[
  AchievementDefinition(
    id: 'first_watch',
    emoji: '🎬',
    title: 'Primeira Sessão',
    description: 'Registre seu primeiro filme ou série.',
  ),
  AchievementDefinition(
    id: 'ten_watched',
    emoji: '🍿',
    title: 'Maratonista',
    description: 'Registre 10 títulos.',
  ),
  AchievementDefinition(
    id: 'fifty_watched',
    emoji: '🏆',
    title: 'Cinéfilo',
    description: 'Registre 50 títulos.',
  ),
  AchievementDefinition(
    id: 'first_series',
    emoji: '📺',
    title: 'Ligado nas Séries',
    description: 'Registre sua primeira série.',
  ),
  AchievementDefinition(
    id: 'five_star_fan',
    emoji: '⭐',
    title: 'Nota Máxima',
    description: 'Dê nota 5 para 5 títulos.',
  ),
  AchievementDefinition(
    id: 'genre_explorer',
    emoji: '🧭',
    title: 'Explorador',
    description: 'Assista títulos de 5 gêneros diferentes.',
  ),
  AchievementDefinition(
    id: 'group_founder',
    emoji: '🏠',
    title: 'Fundador',
    description: 'Crie um grupo.',
  ),
  AchievementDefinition(
    id: 'social_butterfly',
    emoji: '👯',
    title: 'Sociável',
    description: 'Participe de 3 grupos.',
  ),
  AchievementDefinition(
    id: 'week_streak',
    emoji: '🔥',
    title: 'Semana em Chamas',
    description: 'Avalie algo por 7 dias seguidos.',
  ),
];

class UnlockedAchievement {
  final String achievementId;
  final DateTime unlockedAt;
  final bool isNew;

  UnlockedAchievement({
    required this.achievementId,
    required this.unlockedAt,
    required this.isNew,
  });

  factory UnlockedAchievement.fromMap(Map<String, dynamic> map) {
    return UnlockedAchievement(
      achievementId: map['achievement_id'] as String,
      unlockedAt: DateTime.parse(map['unlocked_at'] as String),
      isNew: map['is_new'] as bool,
    );
  }
}
