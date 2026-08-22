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

  /// The last profile `/auth/me` returned.
  ///
  /// Kept so the app can open the right shell when it starts with no network:
  /// the tokens alone say a session exists, but not whose, and the shell has to
  /// know the role before it can build. Never a credential -- only the fields
  /// the [AuthUser] model already carries, so nothing the API tells us to keep
  /// out of the app (`password_hash`, `google_sub`) can end up here even if the
  /// server starts sending it.
  static const _userKey = 'auth.last_user';

  final FlutterSecureStorage _storage;

  String? _access;
  String? _refresh;
  String? _user;
  bool _loaded = false;

  /// Pulls both tokens into memory. Call once at startup so the first request
  /// doesn't have to wait on the keychain.
  Future<void> restore() async {
    if (_loaded) return;
    try {
      _access = await _storage.read(key: _accessKey);
      _refresh = await _storage.read(key: _refreshKey);
      _user = await _storage.read(key: _userKey);
    } on Object {
      // A keychain that cannot be read means no session, which is a valid
      // state — the user signs in again. It must never crash startup.
      _access = null;
      _refresh = null;
      _user = null;
    }
    _loaded = true;
  }

  String? get accessToken => _access;
  String? get refreshToken => _refresh;
  bool get hasSession => _refresh != null;

  /// The cached profile as JSON, or null if there is none.
  String? get lastUser => _user;

  Future<void> saveUser(String json) async {
    _user = json;
    try {
      await _storage.write(key: _userKey, value: json);
    } on Object {
      // In memory is enough for this session; the next launch simply asks the
      // server again, which is what it would do anyway.
    }
  }

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
    _user = null;
    _loaded = true;
    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
      await _storage.delete(key: _userKey);
    } on Object {
      // Nothing useful to do; the in-memory tokens are already gone.
    }
  }
}
