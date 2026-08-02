import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Placeholder cards shown while a rail loads.
///
/// The Home used to render nothing at all until every future resolved, so a
/// slow connection looked identical to an empty app. Showing the shape of the
/// content instead tells the user something is coming.
class RailSkeleton extends StatelessWidget {
  final String title;

  const RailSkeleton({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        SizedBox(
          height: 190,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => const _SkeletonCard(),
          ),
        ),
      ],
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.35, end: 0.7).animate(_controller),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(height: 10, width: 88, color: AppTheme.surfaceHigh),
            const SizedBox(height: 4),
            Container(height: 9, width: 54, color: AppTheme.surfaceHigh),
          ],
        ),
      ),
    );
  }
}

/// Shown when a rail fails to load. Previously a failed request rendered an
/// empty box, so a backend problem was indistinguishable from "no content" —
/// and the user had no way to retry short of restarting the app.
class RailError extends StatelessWidget {
  final String title;
  final VoidCallback onRetry;

  const RailError({super.key, required this.title, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Não foi possível carregar agora.',
                  style: TextStyle(color: AppTheme.onSurfaceMuted),
                ),
              ),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Tentar de novo'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
