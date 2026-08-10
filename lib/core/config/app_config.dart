import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Everything the app reads from the environment.
///
/// Values live in `.env`, which is git-ignored — `.env.example` is the
/// committed template. Nothing here is a compile-time constant, so pointing a
/// build at staging or production is a file change rather than a code change,
/// and no URL or client id is baked into the binary.
///
/// [load] must run before `runApp`, and every getter asserts rather than
/// silently defaulting: a missing base URL should fail loudly at startup, not
/// turn into a stream of confusing request errors later.
abstract final class AppConfig {
  static bool _loaded = false;

  /// Reads `.env`. Safe to call twice; the second call is a no-op.
  ///
  /// A missing or unreadable file is not fatal here — the getters below raise
  /// with a message that says what to do about it, which is far more useful
  /// than a stack trace out of the dotenv package.
  static Future<void> load() async {
    if (_loaded) return;
    try {
      await dotenv.load();
    } on Object {
      // Swallowed deliberately: the getters report the real problem in terms
      // the developer can act on.
    }
    _loaded = true;
  }

  static String _require(String key) {
    final value = dotenv.maybeGet(key)?.trim();
    if (value == null || value.isEmpty) {
      throw StateError(
        'Missing "$key". Copy .env.example to .env and fill it in.',
      );
    }
    return value;
  }

  /// Base URL of the API, without a trailing slash.
  static String get apiBaseUrl {
    final raw = _require('API_BASE_URL');
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  /// Applied to connect, send and receive separately.
  static Duration get apiTimeout {
    final seconds =
        int.tryParse(dotenv.maybeGet('API_TIMEOUT_SECONDS') ?? '') ?? 20;
    return Duration(seconds: seconds);
  }

  /// Empty when Google sign-in has not been configured. The UI hides the
  /// button in that case rather than offering one that cannot succeed.
  static String get googleClientId =>
      dotenv.maybeGet('GOOGLE_CLIENT_ID')?.trim() ?? '';

  static bool get hasGoogleSignIn => googleClientId.isNotEmpty;
}
