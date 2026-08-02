import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/group.dart';

/// Renders a group's identity in priority order: uploaded photo, then chosen
/// emoji, then the first letter of its name.
class GroupAvatar extends StatelessWidget {
  final Group group;
  final double size;

  const GroupAvatar({super.key, required this.group, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final photoUrl = group.photoUrl;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: photoUrl != null
            ? CachedNetworkImage(imageUrl: photoUrl, fit: BoxFit.cover)
            : DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.brandPurple.withValues(alpha: 0.9),
                      AppTheme.brandTeal.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    group.icon ?? group.name.characters.first.toUpperCase(),
                    style: TextStyle(
                      fontSize: size * 0.45,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// The emoji palette offered when customizing a group.
const groupIconChoices = [
  '🍿', '🎬', '🎥', '📺', '🎞️', '⭐', '❤️', '🔥',
  '🏠', '👨‍👩‍👧', '👯', '🌙', '🚀', '👻', '🦇', '🐉',
];
