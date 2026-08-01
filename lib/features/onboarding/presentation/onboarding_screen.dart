import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gradient_button.dart';
import '../data/preferences_repository.dart';
import '../domain/taste_preferences.dart';

/// Asked once, right after the first sign-in, so the Home has something to
/// recommend from before the user has rated anything.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _repository = PreferencesRepository();

  final _selectedGenres = <int>{};
  ContentPreference _contentPreference = ContentPreference.both;
  bool _isSaving = false;

  /// Two is enough to make a discover query meaningful without turning this
  /// into a chore.
  static const _minGenres = 2;

  bool get _canContinue => _selectedGenres.length >= _minGenres;

  Future<void> _finish({required bool skip}) async {
    setState(() => _isSaving = true);
    try {
      if (skip) {
        await _repository.skipOnboarding();
      } else {
        await _repository.savePreferences(
          genreIds: _selectedGenres.toList(),
          contentPreference: _contentPreference,
        );
      }
      widget.onFinished();
    } catch (e) {
      debugPrint('Onboarding save failed: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não deu para salvar. Tente de novo.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.8),
            radius: 1.2,
            colors: [Color(0xFF221545), AppTheme.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'O que você curte assistir?',
                          style: TextStyle(
                            color: AppTheme.onSurface,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Escolha pelo menos 2 para a gente já começar a '
                          'sugerir coisas boas.',
                          style: TextStyle(
                            color: AppTheme.onSurfaceMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final genre in genreChoices)
                              _GenreChip(
                                genre: genre,
                                selected: _selectedGenres.contains(genre.id),
                                onTap: () => setState(() {
                                  if (!_selectedGenres.remove(genre.id)) {
                                    _selectedGenres.add(genre.id);
                                  }
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 34),
                        const Text(
                          'Filmes ou séries?',
                          style: TextStyle(
                            color: AppTheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            for (final preference in ContentPreference.values)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: _PreferenceButton(
                                    label: preference.label,
                                    selected: _contentPreference == preference,
                                    onTap: () => setState(
                                      () => _contentPreference = preference,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    children: [
                      GradientButton(
                        onPressed: (!_canContinue || _isSaving)
                            ? null
                            : () => _finish(skip: false),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _canContinue
                                    ? 'Continuar'
                                    : 'Escolha ao menos $_minGenres',
                              ),
                      ),
                      TextButton(
                        onPressed: _isSaving ? null : () => _finish(skip: true),
                        child: const Text('Pular por agora'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  final GenreChoice genre;
  final bool selected;
  final VoidCallback onTap;

  const _GenreChip({
    required this.genre,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.primaryGradient : null,
          color: selected ? null : AppTheme.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0xFF2E2E3C),
          ),
        ),
        child: Text(
          '${genre.emoji}  ${genre.label}',
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.onSurface,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _PreferenceButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PreferenceButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.primaryGradient : null,
          color: selected ? null : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0xFF2E2E3C),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
