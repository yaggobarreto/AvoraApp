import 'package:flutter/foundation.dart';

/// Captures a group invite code from the app's launch URL (e.g.
/// `https://avora.app/?join=CODE` on web) so it can be applied right after
/// the user logs in or signs up, instead of requiring them to type the code
/// in by hand.
class PendingInvite {
  static String? code;

  static void captureFromUrl() {
    if (!kIsWeb) return;
    code = Uri.base.queryParameters['join'];
  }

  static String? consume() {
    final value = code;
    code = null;
    return value;
  }
}
