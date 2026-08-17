import '../../../core/network/page_data.dart';
import 'app_notification.dart';

/// Push registration and the in-app inbox.
abstract interface class NotificationRepository {
  /// Registers or updates this installation.
  ///
  /// Safe to call repeatedly — it upserts. The backend derives the user from the
  /// bearer token, so no user id or role is ever sent.
  Future<NotificationDevice> registerDevice({
    required String installationId,
    required String fcmToken,
    required String platform,
    String? appVersion,
    String? locale,
    String? timezone,
  });

  /// Removes this installation's registration.
  ///
  /// Idempotent, and must run **before** the logout call while the access token
  /// is still valid — otherwise the next person to sign in on this phone
  /// receives the previous user's alerts.
  Future<void> removeDevice(String installationId);

  Future<PageData<AppNotification>> inbox({int page = 1, int pageSize = 20});

  /// The badge. Cheap enough to call on startup and after a foreground push.
  Future<int> unreadCount();

  Future<AppNotification> markRead(String id);

  /// Returns how many rows this call actually changed.
  Future<int> markAllRead();
}
