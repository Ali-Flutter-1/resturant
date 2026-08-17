import 'package:practice/core/network/api_failure.dart';
import 'package:practice/core/network/page_data.dart';
import 'package:practice/features/notifications/domain/app_notification.dart';
import 'package:practice/features/notifications/domain/notification_repository.dart';

/// The inbox, in memory.
///
/// Returns copies rather than its own list, for the same reason as the other
/// fakes: a shared reference lets a write mutate the list already in cubit
/// state, Equatable then sees no change, and `emit` silently does nothing.
class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository({List<AppNotification>? items, this.delay})
    : _items = items ?? [];

  final Duration? delay;

  static AppNotification item({
    String id = 'n1',
    String event = 'order_ready',
    String entityType = 'order',
    String entityId = 'o1',
    String title = 'Order ready',
    String body = 'Order ABCD-1234 is ready for collection.',
    DateTime? readAt,
    DateTime? createdAt,
  }) => AppNotification.fromJson({
    'id': id,
    'event_type': event,
    'entity_type': entityType,
    'entity_id': entityId,
    'title': title,
    'body': body,
    'data': {
      'schema_version': '1',
      'type': event,
      'entity_type': entityType,
      'entity_id': entityId,
      'reference': 'ABCD-1234',
      'route': '/orders/$entityId',
    },
    'read_at': readAt?.toIso8601String(),
    'created_at': (createdAt ?? DateTime(2026, 8, 15, 12)).toIso8601String(),
  });

  List<AppNotification> _items;

  ApiFailure? failure;

  /// Fails only the writes, so a test can load fine and be refused on the mark.
  ApiFailure? writeFailure;

  int inboxCalls = 0;
  int unreadCalls = 0;
  int markAllCalls = 0;
  final List<String> markedRead = [];
  Map<String, Object?>? lastRegistration;
  String? removedInstallation;

  Future<void> _wait() async {
    final pause = delay;
    if (pause != null) await Future<void>.delayed(pause);
  }

  void _check() {
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<NotificationDevice> registerDevice({
    required String installationId,
    required String fcmToken,
    required String platform,
    String? appVersion,
    String? locale,
    String? timezone,
  }) async {
    lastRegistration = {
      'installation_id': installationId,
      'fcm_token': fcmToken,
      'platform': platform,
      'app_version': appVersion,
      'locale': locale,
      'timezone': timezone,
    };
    await _wait();
    final error = writeFailure ?? failure;
    if (error != null) throw error;

    return NotificationDevice(
      installationId: installationId,
      platform: platform,
    );
  }

  @override
  Future<void> removeDevice(String installationId) async {
    removedInstallation = installationId;
    await _wait();
    final error = writeFailure ?? failure;
    if (error != null) throw error;
  }

  @override
  Future<PageData<AppNotification>> inbox({
    int page = 1,
    int pageSize = 20,
  }) async {
    inboxCalls++;
    await _wait();
    _check();
    return PageData(
      items: List.of(_items),
      page: page,
      pageSize: pageSize,
      total: _items.length,
      totalPages: _items.isEmpty ? 0 : 1,
    );
  }

  @override
  Future<int> unreadCount() async {
    unreadCalls++;
    await _wait();
    _check();
    return _items.where((i) => i.isUnread).length;
  }

  @override
  Future<AppNotification> markRead(String id) async {
    markedRead.add(id);
    await _wait();
    final error = writeFailure ?? failure;
    if (error != null) throw error;

    final updated = _items
        .firstWhere((i) => i.id == id)
        .markRead(DateTime(2026, 8, 15, 13));
    _items = [
      for (final i in _items)
        if (i.id == id) updated else i,
    ];
    return updated;
  }

  @override
  Future<int> markAllRead() async {
    markAllCalls++;
    await _wait();
    final error = writeFailure ?? failure;
    if (error != null) throw error;

    final changed = _items.where((i) => i.isUnread).length;
    _items = [for (final i in _items) i.markRead(DateTime(2026, 8, 15, 13))];
    return changed;
  }
}
