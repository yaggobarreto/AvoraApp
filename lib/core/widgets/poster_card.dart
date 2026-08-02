import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// An image-forward card: the poster fills the whole tile, with a dark
/// scrim and title/subtitle overlaid at the bottom — used for movies
/// (search results, timeline entries) instead of a small thumbnail next to
/// a text row.
class PosterCard extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double height;

  const PosterCard({
    super.key,
    required this.title,
    this.imageUrl,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.height = 140,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: AppTheme.surface,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null)
                    CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 150),
                      errorWidget: (context, url, error) => const ColoredBox(
                        color: AppTheme.surfaceHigh,
                        child: Icon(Icons.movie, color: AppTheme.onSurfaceMuted),
                      ),
                    )
                  else
                    const ColoredBox(
                      color: AppTheme.surfaceHigh,
                      child: Icon(Icons.movie, color: AppTheme.onSurfaceMuted, size: 40),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(gradient: AppTheme.posterScrim),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 12,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        ?trailing,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
