import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../domain/app_notification.dart';
import '../domain/notification_repository.dart';
import '../domain/push_service.dart';
import 'installation_id.dart';

/// Keeps this installation registered, and turns taps into navigation.
///
/// The rules it exists to enforce, all from the integration guide:
///
///  * **Register after sign-in, after a restored session, and on every token
///    rotation.** A token saved once at install eventually stops working.
///  * **Remove the device before logging out**, while the access token is still
///    valid. Skip that and the next person to sign in on this phone gets the
///    previous user's alerts.
///  * **Never block sign-in on any of it.** Registration is retried, not
///    insisted on; somebody with no notifications is still a user with an app.
///  * **A push is a hint, not state.** A tap carries an id and nothing more —
///    the screen it opens fetches the record itself.
class PushCoordinator {
  PushCoordinator({
    required NotificationRepository repository,
    required PushService push,
    InstallationId? installationId,
    String? appVersion,
  }) : _repository = repository,
       _push = push,
       _installationId = installationId ?? InstallationId(),
       _appVersion = appVersion;

  final NotificationRepository _repository;
  final PushService _push;
  final InstallationId _installationId;
  final String? _appVersion;

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<Map<String, dynamic>>? _openedSubscription;
  StreamSubscription<Map<String, dynamic>>? _foregroundSubscription;

  /// A tap that arrived before the app was ready to act on it.
  ///
  /// A terminated app launched from a notification has no session and no
  /// navigator yet. Navigating then would either fail or land on sign-in, so the
  /// payload waits here until [releasePending] is called.
  NotificationPayload? _pending;

  /// Taps, once the app can act on them.
  final _opened = StreamController<NotificationPayload>.broadcast();
  Stream<NotificationPayload> get opened => _opened.stream;

  /// Foreground messages, for refreshing the badge and whatever is on screen.
  final _received = StreamController<NotificationPayload>.broadcast();
  Stream<NotificationPayload> get received => _received.stream;

  bool _started = false;

  /// Begins listening. Safe to call more than once.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    _tokenSubscription = _push.tokenChanges.listen((_) {
      // Fire and forget: a rotation must not hold anything up, and a failure is
      // recoverable on the next startup.
      register();
    });
    _openedSubscription = _push.openedMessages.listen(_handleOpened);
    _foregroundSubscription = _push.foregroundMessages.listen((data) {
      _received.add(NotificationPayload.fromData(data));
    });
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _opened.close();
    await _received.close();
  }

  /// Registers this installation, if there is anything to register.
  ///
  /// Returns true when the backend accepted it. Never throws: this runs beside
  /// sign-in, and a notification registration failing is not a reason to keep
  /// somebody out of the app.
  Future<bool> register() async {
    if (!_push.isAvailable) return false;

    try {
      final granted = await _push.requestPermission();
      if (!granted) return false;

      final token = await _push.token();
      // Null on iOS until APNs has answered. Not an error — the token arrives
      // through `tokenChanges` shortly after, and this runs again then.
      if (token == null || token.isEmpty) return false;

      await _repository.registerDevice(
        installationId: await _installationId.read(),
        fcmToken: token,
        platform: _platform,
        appVersion: _appVersion,
        locale: _locale,
        timezone: _timezone,
      );
      return true;
    } on ApiFailure catch (failure) {
      // Queued for the next startup rather than surfaced. The one case worth
      // knowing about in a log is the backend having no Firebase credentials,
      // which is a deployment problem no retry will fix.
      debugPrint(
        'Device registration failed (${failure.code ?? failure.kind}). '
        'Will retry on next launch.',
      );
      return false;
    } on Object catch (error) {
      debugPrint('Device registration failed: $error');
      return false;
    }
  }

  /// Removes this device's registration.
  ///
  /// **Call this before the logout request**, while the access token still
  /// works. Returns regardless of the outcome: if the network is down the local
  /// session must still be cleared, because leaving somebody signed in for the
  /// sake of tidy bookkeeping is the worse failure.
  Future<void> unregister() async {
    try {
      await _repository.removeDevice(await _installationId.read());
    } on Object catch (error) {
      // Idempotent on the server, and re-registering this installation for
      // another user transfers ownership anyway — so a missed removal is
      // corrected by the next sign-in rather than leaving alerts stranded.
      debugPrint('Device removal failed, continuing with sign-out: $error');
    }
  }

  void _handleOpened(Map<String, dynamic> data) {
    final payload = NotificationPayload.fromData(data);
    if (_opened.hasListener) {
      _opened.add(payload);
    } else {
      _pending = payload;
    }
  }

  /// Hands over a tap that arrived before the app was ready — a terminated app
  /// launched from a notification, or one opened before the session restored.
  NotificationPayload? releasePending() {
    final payload = _pending;
    _pending = null;
    return payload;
  }

  /// Records a tap the app was not ready for. Used by startup, which reads the
  /// launch notification before any listener exists.
  void holdPending(Map<String, dynamic> data) =>
      _pending = NotificationPayload.fromData(data);

  static String get _platform {
    if (kIsWeb) return 'android';
    return Platform.isIOS ? 'ios' : 'android';
  }

  static String? get _locale {
    if (kIsWeb) return null;
    // `en_GB` from the platform, `en-GB` on the wire.
    final name = Platform.localeName.split('.').first.replaceAll('_', '-');
    return name.isEmpty ? null : name;
  }

  /// An IANA zone name, or null when the platform will not name one.
  ///
  /// Deliberately never a UTC offset: the backend schedules against the zone, so
  /// `+05:00` would be wrong twice a year for anywhere with daylight saving.
  static String? get _timezone {
    if (kIsWeb) return null;
    try {
      final name = DateTime.now().timeZoneName;
      // Abbreviations like `PKT` or `BST` are not IANA names, so they are
      // dropped rather than sent as one.
      return name.contains('/') ? name : null;
    } on Object {
      return null;
    }
  }
}
