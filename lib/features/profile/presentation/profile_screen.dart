import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../movies/domain/movie.dart';
import '../data/profile_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _repository = ProfileRepository();
  final _imagePicker = ImagePicker();
  late Future<ProfileStats> _profileFuture;

  bool _isUploadingAvatar = false;
  String? _avatarUrlOverride;

  @override
  void initState() {
    super.initState();
    _profileFuture = _repository.fetchMyProfile();
  }

  Future<void> _pickAndUploadAvatar() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final extension = picked.name.split('.').last.toLowerCase();
      final newUrl = await _repository.uploadAvatar(
        Uint8List.fromList(bytes),
        extension == 'jpg' ? 'jpeg' : extension,
      );
      setState(() => _avatarUrlOverride = newUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar foto: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            onPressed: () => supabase.auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder<ProfileStats>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snapshot.data!;
          final avatarUrl = _avatarUrlOverride ?? profile.avatarUrl;
          final hours = profile.totalWatchedMinutes ~/ 60;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: AppTheme.brandPurple.withValues(alpha: 0.15),
                          backgroundImage:
                              avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null
                              ? Text(
                                  profile.name.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    color: AppTheme.onSurface,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                shape: BoxShape.circle,
                              ),
                              child: _isUploadingAvatar
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      profile.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    if (profile.currentStreakDays > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '🔥 ${profile.currentStreakDays} dias seguidos avaliando',
                        style: const TextStyle(color: AppTheme.onSurfaceMuted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _StatTile(label: 'Filmes', value: '${profile.moviesWatched}'),
                  _StatTile(label: 'Séries', value: '${profile.seriesWatched}'),
                  _StatTile(
                    label: 'Tempo assistido',
                    value: hours > 0 ? '${hours}h' : '-',
                  ),
                  _StatTile(
                    label: 'Nota média',
                    value: profile.avgRating != null
                        ? '★ ${profile.avgRating!.toStringAsFixed(1)}'
                        : '-',
                  ),
                  _StatTile(label: 'Gênero favorito', value: profile.favoriteGenre ?? '-'),
                  _StatTile(
                    label: 'Streamer favorito',
                    value: profile.favoriteStreamer != null
                        ? (watchLocationLabels[profile.favoriteStreamer] ??
                            profile.favoriteStreamer!)
                        : '-',
                  ),
                ],
              ),
              if (profile.recentRatings.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Últimas avaliações',
                  style: TextStyle(
                    color: AppTheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                for (final recent in profile.recentRatings)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: recent.posterUrl != null
                          ? CachedNetworkImage(
                              imageUrl: recent.posterUrl!,
                              width: 40,
                              fit: BoxFit.cover,
                            )
                          : const Icon(Icons.movie),
                    ),
                    title: Text(recent.movieTitle),
                    trailing: Text(
                      recent.rating != null ? '★ ${recent.rating!.toStringAsFixed(1)}' : '-',
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.onSurface,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceMuted)),
        ],
      ),
    );
  }
}
