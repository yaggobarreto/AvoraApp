/// Cloudflare Turnstile CAPTCHA widget.
///
/// Turnstile is a browser widget, so a real implementation exists only on
/// web. The stub keeps the rest of the app platform-agnostic: on mobile the
/// widget renders nothing and never produces a token.
library;

export 'turnstile_stub.dart' if (dart.library.js_interop) 'turnstile_web.dart';
