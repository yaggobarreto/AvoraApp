import 'package:flutter/material.dart';

/// Turnstile renders a browser widget, so there is nothing to show off the
/// web. Enabling CAPTCHA on the Supabase project while shipping a mobile
/// build would therefore reject every sign-up from the app — mobile needs a
/// webview-based challenge first. See docs/SECURITY.md.
const bool turnstileSupported = false;

class TurnstileWidget extends StatelessWidget {
  final ValueChanged<String?> onToken;

  const TurnstileWidget({super.key, required this.onToken});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
