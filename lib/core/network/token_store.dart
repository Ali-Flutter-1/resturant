import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the session tokens live.
///
/// The Keychain on Apple platforms and the Keystore-backed store on Android,
/// rather than Hive. Hive is the app's choice for ordinary local data, but a
/// refresh token is a bearer credential: on a rooted or jailbroken device an
/// unencrypted Hive box is readable, and this API's refresh tokens are
/// single-use with session-wide revocation on reuse — so a leaked one is worth
/// stealing.
///
/// Reads are cached in memory after the first hit. Every authenticated request
/// needs the access token, and going to the platform keychain on each one is
/// both slow and pointless.
class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'auth.access_token';
  static const _refreshKey = 'auth.refresh_token';

  final FlutterSecureStorage _storage;

  String? _access;
  String? _refresh;
  bool _loaded = false;

  /// Pulls both tokens into memory. Call once at startup so the first request
  /// doesn't have to wait on the keychain.
  Future<void> restore() async {
    if (_loaded) return;
    try {
      _access = await _storage.read(key: _accessKey);
      _refresh = await _storage.read(key: _refreshKey);
    } on Object {
      // A keychain that cannot be read means no session, which is a valid
      // state — the user signs in again. It must never crash startup.
      _access = null;
      _refresh = null;
    }
    _loaded = true;
  }

  String? get accessToken => _access;
  String? get refreshToken => _refresh;
  bool get hasSession => _refresh != null;

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    _access = accessToken;
    _refresh = refreshToken;
    _loaded = true;
    try {
      await _storage.write(key: _accessKey, value: accessToken);
      await _storage.write(key: _refreshKey, value: refreshToken);
    } on Object {
      // Kept in memory regardless, so the current session still works even if
      // it cannot survive a restart.
    }
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    _loaded = true;
    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    } on Object {
      // Nothing useful to do; the in-memory tokens are already gone.
    }
  }
}
