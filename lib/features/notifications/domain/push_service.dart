import 'dart:async';

/// The device's push channel.
///
/// An interface rather than Firebase directly, because the Firebase
/// configuration files are not in this project yet. Everything the app does
/// *around* push — registering the installation, the inbox, the badge, safe
/// routing, logout cleanup — is finished and testable against this; the only
/// piece still missing is the implementation that actually talks to FCM.
///
/// When the config arrives, adding it is one class:
///
///  1. `flutterfire configure` to generate `firebase_options.dart`, and drop
///     `google-services.json` / `GoogleService-Info.plist` into place.
///  2. `flutter pub add firebase_core firebase_messaging
///     flutter_local_notifications`.
///  3. Initialise Firebase in `main` and register a **top-level**
///     `@pragma('vm:entry-point')` background handler — it must not be a closure
///     or an instance method, and the pragma stops release tree-shaking removing
///     it.
///  4. Write `FirebasePushService implements PushService` and hand it to
///     [PushCoordinator] in place of [NoPushService].
///
/// Two details from the guide that are easy to miss and expensive to get wrong:
///
///  * **On iOS, wait for `getAPNSToken()` before `getToken()`.** The APNs token
///    may not exist yet at startup, and registering a half-finished token gives
///    the backend one that can never be delivered to.
///  * **Create the Android channel with the id `restaurant_updates`, exactly.**
///    The backend sends that id in every Android message; a different one means
///    no foreground alert.
abstract interface class PushService {
  /// Whether this build can receive push at all. False until Firebase is wired.
  bool get isAvailable;

  /// Asks the user. Returns false if they declined or the platform refused.
  ///
  /// iOS generally will not show the system prompt twice, so this should be
  /// called at a moment where the benefit has already been explained.
  Future<bool> requestPermission();

  /// The FCM registration token, or null when there is not a usable one yet.
  Future<String?> token();

  /// Fires whenever Firebase rotates the token. A token saved once at install
  /// eventually stops working, so every emission must be re-registered.
  Stream<String> get tokenChanges;

  /// Messages that arrive while the app is in the foreground.
  Stream<Map<String, dynamic>> get foregroundMessages;

  /// A notification the user tapped — from the background, or the one that
  /// launched a terminated app.
  Stream<Map<String, dynamic>> get openedMessages;
}

/// The stand-in used until Firebase is configured.
///
/// Deliberately not a throwing stub: the rest of the notification feature is
/// real and works without push, because the in-app inbox is the durable record
/// either way. This build simply never receives an OS alert.
class NoPushService implements PushService {
  const NoPushService();

  @override
  bool get isAvailable => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> get tokenChanges => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get foregroundMessages => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get openedMessages => const Stream.empty();
}
