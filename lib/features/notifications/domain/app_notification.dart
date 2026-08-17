import 'package:equatable/equatable.dart';

/// What happened.
///
/// The complete version-1 event set. [unknown] exists because a payload is
/// untrusted input: a backend that adds an event must not crash an older app,
/// and the guide's own rule is to fall back to the inbox rather than throw.
enum NotificationEvent {
  orderPreparing('order_preparing'),
  orderReady('order_ready'),
  orderOutForDelivery('order_out_for_delivery'),
  orderCompleted('order_completed'),
  orderRejected('order_rejected'),
  orderCancelled('order_cancelled'),
  orderPlacedAdmin('order_placed_admin'),
  orderCancelledAdmin('order_cancelled_admin'),
  bookingConfirmed('booking_confirmed'),
  bookingRejected('booking_rejected'),
  bookingCancelled('booking_cancelled'),
  bookingExpired('booking_expired'),
  bookingNoShow('booking_no_show'),
  bookingRequestedAdmin('booking_requested_admin'),
  bookingCancelledAdmin('booking_cancelled_admin'),
  unknown('');

  const NotificationEvent(this.wire);

  final String wire;

  static NotificationEvent fromApi(Object? value) {
    final raw = value?.toString().trim().toLowerCase();
    for (final event in values) {
      if (event != unknown && event.wire == raw) return event;
    }
    return unknown;
  }

  /// Whether this is addressed to staff rather than the customer.
  ///
  /// Decides which detail endpoint the tap should read — `/orders/{id}` or
  /// `/admin/orders/{id}` — since the two carry different fields and a customer
  /// calling the admin one gets a 403.
  bool get isForStaff => switch (this) {
    orderPlacedAdmin ||
    orderCancelledAdmin ||
    bookingRequestedAdmin ||
    bookingCancelledAdmin => true,
    _ => false,
  };

  bool get isOrder => switch (this) {
    orderPreparing ||
    orderReady ||
    orderOutForDelivery ||
    orderCompleted ||
    orderRejected ||
    orderCancelled ||
    orderPlacedAdmin ||
    orderCancelledAdmin => true,
    _ => false,
  };

  bool get isBooking => switch (this) {
    bookingConfirmed ||
    bookingRejected ||
    bookingCancelled ||
    bookingExpired ||
    bookingNoShow ||
    bookingRequestedAdmin ||
    bookingCancelledAdmin => true,
    _ => false,
  };
}

/// What the notification is about.
enum NotificationEntity {
  order,
  reservation,
  unknown;

  static NotificationEntity fromApi(Object? value) =>
      switch (value?.toString().trim().toLowerCase()) {
        'order' => order,
        'reservation' || 'booking' => reservation,
        _ => unknown,
      };
}

/// Where a tap should go.
///
/// Deliberately a small closed set rather than the payload's `route` string. The
/// guide is explicit: **do not navigate blindly**. A push is untrusted input, and
/// executing an arbitrary route out of it is how a malformed — or hostile —
/// message sends somebody somewhere the app never intended. The route field is a
/// diagnostic hint; this is what the app acts on.
enum NotificationTarget {
  customerOrder,
  adminOrder,
  customerBooking,
  adminBooking,

  /// The safe fallback for anything unrecognised, malformed or incomplete.
  inbox,
}

/// The push payload, after validation.
///
/// Every value on the wire is a string, so nothing here is parsed as anything
/// else. [entityId] is kept as text and only handed to an API path — it is never
/// interpolated into a route the app then executes.
class NotificationPayload extends Equatable {
  const NotificationPayload({
    required this.event,
    required this.entity,
    required this.entityId,
    this.schemaVersion,
    this.reference,
  });

  /// The version this app understands. A payload claiming anything else opens
  /// the inbox rather than being guessed at.
  static const String supportedSchema = '1';

  factory NotificationPayload.fromData(Map<String, dynamic> data) {
    return NotificationPayload(
      schemaVersion: data['schema_version']?.toString(),
      event: NotificationEvent.fromApi(data['type']),
      entity: NotificationEntity.fromApi(data['entity_type']),
      entityId: data['entity_id']?.toString() ?? '',
      reference: data['reference']?.toString(),
    );
  }

  final String? schemaVersion;
  final NotificationEvent event;
  final NotificationEntity entity;

  /// The affected record. Present but not trusted to be well-formed.
  final String entityId;

  /// Human-friendly order or booking reference. Display only.
  final String? reference;

  /// Where to go, or [NotificationTarget.inbox] when anything does not add up.
  ///
  /// The checks are all the same shape: if the payload cannot be believed, fall
  /// back rather than guess. A wrong screen is worse than the inbox, because the
  /// inbox is always true.
  NotificationTarget get target {
    // An unknown schema means the fields may mean something else entirely.
    if (schemaVersion != null && schemaVersion != supportedSchema) {
      return NotificationTarget.inbox;
    }
    if (event == NotificationEvent.unknown) return NotificationTarget.inbox;
    if (entityId.trim().isEmpty) return NotificationTarget.inbox;

    // The event and the entity must agree. A booking event carrying an order id
    // is a payload nobody should act on.
    if (event.isOrder && entity != NotificationEntity.order) {
      return NotificationTarget.inbox;
    }
    if (event.isBooking && entity != NotificationEntity.reservation) {
      return NotificationTarget.inbox;
    }

    return switch ((event.isOrder, event.isForStaff)) {
      (true, false) => NotificationTarget.customerOrder,
      (true, true) => NotificationTarget.adminOrder,
      (false, false) => NotificationTarget.customerBooking,
      (false, true) => NotificationTarget.adminBooking,
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    event,
    entity,
    entityId,
    reference,
  ];
}

/// One row in the in-app inbox.
///
/// The durable record. A push can be delayed, dismissed or never shown at all —
/// the guide is explicit that this list, not the notification tray, is the
/// reliable history and the badge's source.
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
    this.readAt,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final blob = json['data'];
    final data = blob is Map
        ? Map<String, dynamic>.from(blob)
        : <String, dynamic>{};

    // The row's own columns win over the `data` blob: they are what the database
    // indexed and what the backend queries on. A row whose blob is missing or
    // malformed still routes correctly.
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      payload: NotificationPayload.fromData({
        ...data,
        'type': json['event_type'] ?? data['type'],
        'entity_type': json['entity_type'] ?? data['entity_type'],
        'entity_id': json['entity_id'] ?? data['entity_id'],
      }),
      readAt: _date(json['read_at']),
      createdAt: _date(json['created_at']),
    );
  }

  static DateTime? _date(Object? raw) =>
      raw == null ? null : DateTime.tryParse(raw.toString())?.toLocal();

  final String id;
  final String title;
  final String body;
  final NotificationPayload payload;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get isUnread => readAt == null;

  AppNotification markRead(DateTime at) => AppNotification(
    id: id,
    title: title,
    body: body,
    payload: payload,
    readAt: readAt ?? at,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [id, title, body, payload, readAt, createdAt];
}

/// A registered installation.
///
/// Note what is absent: the FCM token. The API deliberately never sends it back,
/// and nothing in the app should ever log or display one.
class NotificationDevice extends Equatable {
  const NotificationDevice({
    required this.installationId,
    required this.platform,
    this.isActive = true,
    this.lastSeenAt,
  });

  factory NotificationDevice.fromJson(Map<String, dynamic> json) =>
      NotificationDevice(
        installationId: json['installation_id']?.toString() ?? '',
        platform: json['platform']?.toString() ?? '',
        isActive: json['is_active'] != false,
        lastSeenAt: AppNotification._date(json['last_seen_at']),
      );

  final String installationId;
  final String platform;
  final bool isActive;
  final DateTime? lastSeenAt;

  @override
  List<Object?> get props => [installationId, platform, isActive, lastSeenAt];
}

/// The API's `error.code` values for this area.
abstract final class NotificationErrorCodes {
  static const String notFound = 'NOTIFICATION_NOT_FOUND';
  static const String permissionDenied = 'PERMISSION_DENIED';

  /// The backend has no Firebase credentials. A deployment problem, not
  /// something the user did or can fix.
  static const String firebaseNotConfigured = 'FIREBASE_NOT_CONFIGURED';
}
