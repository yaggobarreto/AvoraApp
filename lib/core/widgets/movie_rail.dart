import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A horizontal, Netflix-style scrolling rail of poster cards with a rank
/// badge — used for "Top Filmes do Avora" and similar ranked lists.
class MovieRail extends StatelessWidget {
  final String title;
  final int itemCount;
  final String? Function(int index) posterUrlBuilder;
  final String Function(int index) titleBuilder;
  final String? Function(int index) subtitleBuilder;
  final void Function(int index) onTap;

  const MovieRail({
    super.key,
    required this.title,
    required this.itemCount,
    required this.posterUrlBuilder,
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        SizedBox(
          height: 190,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _RailCard(
                rank: index + 1,
                posterUrl: posterUrlBuilder(index),
                title: titleBuilder(index),
                subtitle: subtitleBuilder(index),
                onTap: () => onTap(index),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RailCard extends StatelessWidget {
  final int rank;
  final String? posterUrl;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _RailCard({
    required this.rank,
    required this.posterUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox.expand(
                      child: posterUrl != null
                          ? CachedNetworkImage(imageUrl: posterUrl!, fit: BoxFit.cover)
                          : const ColoredBox(
                              color: AppTheme.surfaceHigh,
                              child: Icon(Icons.movie, color: AppTheme.onSurfaceMuted),
                            ),
                    ),
                  ),
                  Positioned(
                    left: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#$rank',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceMuted),
              ),
          ],
        ),
      ),
    );
  }
}
