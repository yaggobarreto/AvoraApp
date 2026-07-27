import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Primary call-to-action button using the brand's purple-to-teal gradient
/// instead of a flat color fill.
class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const GradientButton({super.key, required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: Center(
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                child: IconTheme.merge(
                  data: const IconThemeData(color: Colors.white),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
