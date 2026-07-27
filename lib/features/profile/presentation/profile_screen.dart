import 'package:flutter/material.dart';

import '../../../core/network/supabase_config.dart';
import '../data/profile_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _repository = ProfileRepository();
  late Future<ProfileStats> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _repository.fetchMyProfile();
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
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage:
                      profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                  child: profile.avatarUrl == null
                      ? Text(profile.name.substring(0, 1).toUpperCase())
                      : null,
                ),
                const SizedBox(height: 12),
                Text(profile.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('${profile.moviesWatched} filmes registrados'),
              ],
            ),
          );
        },
      ),
    );
  }
}
