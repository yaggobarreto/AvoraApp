import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
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

          return Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
              decoration: BoxDecoration(
                color: AppTheme.cardSurface,
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
                                  color: AppTheme.cardOnSurface,
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
                      color: AppTheme.cardOnSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${profile.moviesWatched} filmes registrados',
                    style: const TextStyle(color: AppTheme.cardOnSurface),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
