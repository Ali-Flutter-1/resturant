import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/push_service.dart';

/// Handles a message that arrives while the app is in the background.
///
/// Top-level and annotated on purpose: Firebase runs this in a separate isolate,
/// so it cannot be a closure or an instance method, and `@pragma` stops release
/// tree-shaking removing it.
///
/// It deliberately does nothing. There is no UI context here, the system has
/// already shown the notification, and doing real work in this isolate — a
/// network call, a navigation — is how background handlers become crashes nobody
/// can reproduce. The tap is handled by `onMessageOpenedApp` instead.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Intentionally empty. See the note above.
}

/// Push, through Firebase Cloud Messaging.
///
/// The three details that are easy to get wrong and expensive to debug:
///
///  * **The Android channel id must be exactly `restaurant_updates`.** The
///    backend sends that id in every Android message; a different one means the
///    OS falls back or shows nothing in the foreground.
///  * **On iOS, wait for the APNs token before asking for the FCM one.** APNs
///    has not necessarily answered at startup, and registering a token derived
///    from nothing gives the backend one that can never be delivered to.
///  * **Show a foreground notification once.** Firebase does not display
///    messages while the app is foregrounded, so this shows a local one — and
///    deduplicates on `messageId`, because a retry can deliver the same message
///    twice.
class FirebasePushService implements PushService {
  FirebasePushService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? local,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _local = local ?? FlutterLocalNotificationsPlugin();

  /// The channel the backend addresses. Exactly this string.
  static const String channelId = 'restaurant_updates';

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    channelId,
    'Order and booking updates',
    description: 'Important changes to orders and table bookings.',
    importance: Importance.high,
  );

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _local;

  /// Message ids already shown, so a redelivery does not alert twice.
  final _shown = <String>{};

  bool _ready = false;

  @override
  bool get isAvailable => true;

  /// Creates the channel and wires the foreground presenter.
  ///
  /// Safe to call more than once.
  Future<void> initialise() async {
    if (_ready) return;
    _ready = true;

    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Permission is asked for through Firebase instead, so the two do not
          // race to show the same system prompt.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    if (!kIsWeb && Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);
    }

    if (!kIsWeb && Platform.isIOS) {
      // iOS would otherwise show Firebase's own banner as well as the local one.
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );
    }
  }

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    // Provisional counts: iOS delivers quietly to the notification centre, which
    // is still a delivery.
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> token() async {
    if (!kIsWeb && Platform.isIOS) {
      // Null until APNs has answered. Returning null rather than pressing on is
      // the point: the coordinator tries again when `tokenChanges` fires.
      final apns = await _messaging.getAPNSToken();
      if (apns == null) return null;
    }
    return _messaging.getToken();
  }

  @override
  Stream<String> get tokenChanges => _messaging.onTokenRefresh;

  @override
  Stream<Map<String, dynamic>> get foregroundMessages =>
      FirebaseMessaging.onMessage.map((message) {
        _present(message);
        return _data(message);
      });

  @override
  Stream<Map<String, dynamic>> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp.map(_data);

  /// The notification that launched a terminated app, or null.
  ///
  /// Read once at startup. Not a stream, because it is a single fact about how
  /// this launch began.
  Future<Map<String, dynamic>?> initialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _data(message);
  }

  /// Shows one local notification for a foreground message.
  Future<void> _present(RemoteMessage message) async {
    final id = message.messageId;
    // Deduplicated: FCM can redeliver, and two identical banners for one event
    // reads as a bug.
    if (id != null && !_shown.add(id)) return;
    // Bounded, so a long session does not accumulate ids for ever.
    if (_shown.length > 200) _shown.clear();

    final notification = message.notification;
    if (notification == null) return;

    await _local.show(
      // A stable-ish id from the message, so the OS replaces rather than stacks
      // repeat alerts about the same thing.
      id: id.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  static Map<String, dynamic> _data(RemoteMessage message) =>
      Map<String, dynamic>.from(message.data);
}
