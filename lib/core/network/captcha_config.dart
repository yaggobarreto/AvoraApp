/// Cloudflare Turnstile configuration.
///
/// The site key is public by design (it ships in the page), so passing it via
/// `--dart-define` is safe — it is not a secret. The matching *secret* key
/// lives only on the Supabase side and never touches this codebase.
///
///     flutter build web --dart-define=TURNSTILE_SITE_KEY=0x4AAA...
///
/// Leaving it unset disables the CAPTCHA entirely: the widget renders nothing
/// and sign-up sends no token. That is the default so the app keeps working
/// before the keys exist — enabling it is a matter of passing this define and
/// turning on `[auth.captcha]` in supabase/config.toml. Enabling only one of
/// the two breaks sign-up, so they must be flipped together.
class CaptchaConfig {
  static const siteKey = String.fromEnvironment('TURNSTILE_SITE_KEY');

  static bool get isEnabled => siteKey.isNotEmpty;
}
