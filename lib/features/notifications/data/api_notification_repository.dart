import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/network/page_data.dart';
import '../domain/app_notification.dart';
import '../domain/notification_repository.dart';

class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  @override
  Future<NotificationDevice> registerDevice({
    required String installationId,
    required String fcmToken,
    required String platform,
    String? appVersion,
    String? locale,
    String? timezone,
  }) async {
    final data = await _client.object(
      ApiConstants.notificationDevices,
      method: 'POST',
      body: {
        'installation_id': installationId,
        'fcm_token': fcmToken,
        'platform': platform,
        'app_version': ?appVersion,
        'locale': ?locale,
        // An IANA name, never a UTC offset — the backend schedules against it.
        'timezone': ?timezone,
      },
      // No user id and no role. The backend derives both from the token, and a
      // client-supplied role would be a client-supplied permission.
    );
    return NotificationDevice.fromJson(data);
  }

  @override
  Future<void> removeDevice(String installationId) async {
    // `send`, not `object`: this route answers `data: null`, and asking for an
    // object would report a successful removal as a decode failure.
    await _client.send(
      ApiConstants.notificationDevice(installationId),
      method: 'DELETE',
    );
  }

  @override
  Future<PageData<AppNotification>> inbox({
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await _client.page(
      ApiConstants.notifications,
      query: {'page': page, 'page_size': pageSize.clamp(1, 100)},
    );
    return data.map(AppNotification.fromJson);
  }

  @override
  Future<int> unreadCount() async {
    final data = await _client.object(ApiConstants.notificationsUnreadCount);
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<AppNotification> markRead(String id) async => AppNotification.fromJson(
    await _client.object(ApiConstants.notificationRead(id), method: 'PATCH'),
  );

  @override
  Future<int> markAllRead() async {
    final data = await _client.object(
      ApiConstants.notificationsReadAll,
      method: 'POST',
    );
    // The count is how many rows *this call* changed, which is not the same as
    // how many were on screen — another device may have read some already.
    return (data['count'] as num?)?.toInt() ?? 0;
  }
}
