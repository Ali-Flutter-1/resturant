import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// This installation's identity.
///
/// One UUID, generated the first time the app runs and reused for ever after.
/// It identifies *this install of this app*, and deliberately nothing else — the
/// guide rules out IMEI, the advertising IDs, the phone number and the user id,
/// because each of those either identifies the person or survives an uninstall.
///
/// A fresh UUID on every startup would be just as wrong in the other direction:
/// the backend would accumulate one dead registration per launch and keep
/// pushing to all of them.
class InstallationId {
  InstallationId({FlutterSecureStorage? storage, Random? random})
    : _storage = storage ?? const FlutterSecureStorage(),
      _random = random ?? Random.secure();

  static const String storageKey = 'notification_installation_id';

  final FlutterSecureStorage _storage;
  final Random _random;

  String? _cached;

  /// Reads it, creating one on first use.
  ///
  /// Held in memory after the first read: this is asked for on every device
  /// registration, and a keychain round trip per call is wasted work.
  Future<String> read() async {
    final cached = _cached;
    if (cached != null) return cached;

    final stored = await _storage.read(key: storageKey);
    if (stored != null && stored.trim().isNotEmpty) {
      return _cached = stored.trim();
    }

    final created = _uuidV4();
    await _storage.write(key: storageKey, value: created);
    return _cached = created;
  }

  /// Forgets it. Not called on sign-out — the installation outlives the session,
  /// and the backend transfers ownership when a different user registers the
  /// same one. Here for a deliberate privacy reset.
  Future<void> clear() async {
    _cached = null;
    await _storage.delete(key: storageKey);
  }

  /// A version-4 UUID.
  ///
  /// `Random.secure` rather than the default generator: a predictable
  /// installation id would let one device guess another's, and the cost of the
  /// secure source here is nothing.
  String _uuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    // Version 4, variant 1, as the spec requires.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int start, int end) => bytes
        .sublist(start, end)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-'
        '${hex(10, 16)}';
  }
}
