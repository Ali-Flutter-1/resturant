import 'package:equatable/equatable.dart';

/// Where a booking has got to.
///
/// The guide's rule that everything else follows from: **HTTP 201 from
/// `POST /reservations` means "request created and awaiting approval", never
/// "confirmed"**. So there is a [pending] state before [confirmed], and the app
/// must read `status` from every response rather than assuming success meant a
/// table.
enum ReservationStatus {
  pending('Awaiting approval'),
  confirmed('Confirmed'),
  rejected('Rejected'),
  seated('Seated'),
  completed('Completed'),
  cancelled('Cancelled'),
  noShow('No show'),
  expired('Approval expired');

  const ReservationStatus(this.label);

  /// The customer-facing wording, straight from the guide's table.
  final String label;

  String get apiValue => switch (this) {
    noShow => 'no_show',
    _ => name,
  };

  /// Unknown values fall to [pending] rather than throwing.
  ///
  /// The guide's own model throws on an unrecognised status. That is the wrong
  /// trade for a mobile app: a backend that gains a state would take the whole
  /// history screen down with it, when showing one row as in-progress costs
  /// nothing and the server refuses any action the state does not allow.
  static ReservationStatus fromApi(Object? value) => switch (value
      ?.toString()
      .trim()
      .toLowerCase()) {
    'pending' => pending,
    'confirmed' => confirmed,
    'rejected' => rejected,
    'seated' => seated,
    'completed' => completed,
    'cancelled' || 'canceled' => cancelled,
    'no_show' || 'noshow' => noShow,
    'expired' => expired,
    _ => pending,
  };

  /// Whether this booking still holds its slot, and so belongs at the top of the
  /// customer's list rather than in history.
  bool get isLive => switch (this) {
    pending || confirmed || seated => true,
    rejected || completed || cancelled || noShow || expired => false,
  };

  /// Nothing further can happen to it.
  bool get isFinal => !isLive;

  /// The sentence under the status on the customer's detail screen.
  String get customerNote => switch (this) {
    pending =>
      'The restaurant is reviewing your request. Your table is held until '
          'they answer.',
    confirmed =>
      'Your table is booked. Contact the restaurant if you need to change it.',
    rejected => 'The restaurant could not take this booking.',
    seated => 'Enjoy your meal.',
    completed => 'Thanks for visiting.',
    cancelled => 'This booking was cancelled.',
    noShow => 'This booking was marked as a no-show.',
    expired =>
      'Nobody reviewed the request in time, so the table was released. '
          'Please choose another sitting.',
  };
}

/// Why a sitting cannot be chosen.
enum UnavailableReason {
  booked('Already booked'),
  closed('Not available'),
  tooSoon('Too late to book'),
  tooSmall('Too small'),
  unknown('Not available');

  const UnavailableReason(this.label);
  final String label;

  static UnavailableReason fromApi(Object? value) => switch (value
      ?.toString()
      .trim()
      .toLowerCase()) {
    'booked' => booked,
    'closed' => closed,
    'too_soon' => tooSoon,
    'too_small' => tooSmall,
    _ => unknown,
  };
}

/// One sitting on one table.
///
/// [startTime] is a restaurant-local wall clock — `19:00:00` — not an instant.
/// It is deliberately kept as the string the API sent: converting it to a
/// `DateTime` and back through the device's timezone is how a 19:00 booking in
/// London becomes 23:00 for a customer whose phone is in Karachi.
class AvailabilitySitting extends Equatable {
  const AvailabilitySitting({
    required this.slotId,
    required this.startTime,
    required this.durationMinutes,
    required this.bufferMinutes,
    required this.pricePence,
    required this.isAvailable,
    this.notes,
    this.unavailableReason,
  });

  factory AvailabilitySitting.fromJson(Map<String, dynamic> json) =>
      AvailabilitySitting(
        slotId: json['slot_id']?.toString() ?? '',
        startTime: json['start_time']?.toString() ?? '',
        durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
        bufferMinutes: (json['buffer_minutes'] as num?)?.toInt() ?? 0,
        pricePence: (json['price_pence'] as num?)?.toInt() ?? 0,
        isAvailable: json['is_available'] == true,
        notes: json['notes']?.toString(),
        unavailableReason: json['unavailable_reason'] == null
            ? null
            : UnavailableReason.fromApi(json['unavailable_reason']),
      );

  final String slotId;
  final String startTime;
  final int durationMinutes;
  final int bufferMinutes;
  final int pricePence;
  final bool isAvailable;
  final String? notes;
  final UnavailableReason? unavailableReason;

  /// `19:00:00` as `19:00`. Nothing is converted; the seconds are simply not
  /// worth the width.
  String get label {
    final parts = startTime.split(':');
    return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : startTime;
  }

  bool get isFree => pricePence == 0;

  @override
  List<Object?> get props => [
    slotId,
    startTime,
    durationMinutes,
    bufferMinutes,
    pricePence,
    isAvailable,
    notes,
    unavailableReason,
  ];
}

/// A physical table and its sittings for one day.
class AvailabilityTable extends Equatable {
  const AvailabilityTable({
    required this.id,
    required this.name,
    required this.seats,
    required this.area,
    this.description,
    this.imageUrl,
    this.sittings = const [],
  });

  factory AvailabilityTable.fromJson(Map<String, dynamic> json) {
    final sittings = json['sittings'];
    return AvailabilityTable(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      seats: (json['seats'] as num?)?.toInt() ?? 0,
      area: json['area']?.toString() ?? '',
      description: json['description']?.toString(),
      imageUrl: json['image_url']?.toString(),
      sittings: sittings is List
          ? sittings
                .whereType<Map>()
                .map(
                  (s) =>
                      AvailabilitySitting.fromJson(Map<String, dynamic>.from(s)),
                )
                .toList()
          : const [],
    );
  }

  final String id;
  final String name;
  final int seats;
  final String area;
  final String? description;
  final String? imageUrl;
  final List<AvailabilitySitting> sittings;

  bool get hasFreeSitting => sittings.any((s) => s.isAvailable);

  /// `window` as `Window`. The API's areas are lowercase words.
  String get areaLabel => area.isEmpty
      ? ''
      : area[0].toUpperCase() + area.substring(1).replaceAll('_', ' ');

  @override
  List<Object?> get props => [
    id,
    name,
    seats,
    area,
    description,
    imageUrl,
    sittings,
  ];
}

/// Every table and sitting for one service date.
class Availability extends Equatable {
  const Availability({
    required this.serviceDate,
    this.guests,
    this.tables = const [],
  });

  factory Availability.fromJson(Map<String, dynamic> json) {
    final tables = json['tables'];
    return Availability(
      serviceDate: parseCalendarDate(json['service_date']),
      guests: (json['guests'] as num?)?.toInt(),
      tables: tables is List
          ? tables
                .whereType<Map>()
                .map(
                  (t) => AvailabilityTable.fromJson(Map<String, dynamic>.from(t)),
                )
                .toList()
          : const [],
    );
  }

  /// The restaurant's calendar date, not an instant.
  final DateTime serviceDate;
  final int? guests;
  final List<AvailabilityTable> tables;

  bool get hasAnySitting => tables.any((t) => t.sittings.isNotEmpty);
  bool get hasAnyFreeSitting => tables.any((t) => t.hasFreeSitting);

  @override
  List<Object?> get props => [serviceDate, guests, tables];
}

/// A booking, as the customer's list shows it.
class ReservationSummary extends Equatable {
  const ReservationSummary({
    required this.id,
    required this.reference,
    required this.status,
    required this.tableName,
    required this.serviceDate,
    required this.startTime,
    required this.guests,
    required this.pricePence,
  });

  factory ReservationSummary.fromJson(Map<String, dynamic> json) =>
      ReservationSummary(
        id: json['id']?.toString() ?? '',
        reference: json['reference']?.toString() ?? '',
        status: ReservationStatus.fromApi(json['status']),
        tableName: json['table_name']?.toString() ?? '',
        serviceDate: parseCalendarDate(json['service_date']),
        startTime: json['start_time']?.toString() ?? '',
        guests: (json['guests'] as num?)?.toInt() ?? 0,
        pricePence: (json['price_pence'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String reference;
  final ReservationStatus status;
  final String tableName;

  /// Restaurant-local calendar date. Never shifted to the device's timezone.
  final DateTime serviceDate;

  /// Restaurant-local wall clock, kept as the API's own string.
  final String startTime;

  final int guests;
  final int pricePence;

  String get timeLabel {
    final parts = startTime.split(':');
    return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : startTime;
  }

  String get guestLabel => guests == 1 ? '1 guest' : '$guests guests';

  @override
  List<Object?> get props => [
    id,
    reference,
    status,
    tableName,
    serviceDate,
    startTime,
    guests,
    pricePence,
  ];
}

/// A booking in full.
class ReservationDetail extends ReservationSummary {
  const ReservationDetail({
    required super.id,
    required super.reference,
    required super.status,
    required super.tableName,
    required super.serviceDate,
    required super.startTime,
    required super.guests,
    required super.pricePence,
    required this.slotId,
    required this.contactName,
    required this.contactPhone,
    required this.canCancel,
    this.specialRequests,
    this.cancellationReason,
    this.cancelledAt,
    this.expiresAt,
    this.approvedAt,
    this.rejectedAt,
    this.createdAt,
  });

  factory ReservationDetail.fromJson(Map<String, dynamic> json) =>
      ReservationDetail(
        id: json['id']?.toString() ?? '',
        reference: json['reference']?.toString() ?? '',
        status: ReservationStatus.fromApi(json['status']),
        tableName: json['table_name']?.toString() ?? '',
        serviceDate: parseCalendarDate(json['service_date']),
        startTime: json['start_time']?.toString() ?? '',
        guests: (json['guests'] as num?)?.toInt() ?? 0,
        pricePence: (json['price_pence'] as num?)?.toInt() ?? 0,
        slotId: json['slot_id']?.toString() ?? '',
        contactName: json['contact_name']?.toString() ?? '',
        contactPhone: json['contact_phone']?.toString() ?? '',
        // The server's word, never re-derived from the status. The guide is
        // explicit: staff can approve between the screen loading and the button
        // being pressed, and only the server knows.
        canCancel: json['can_cancel'] == true,
        specialRequests: _text(json['special_requests']),
        cancellationReason: _text(json['cancellation_reason']),
        cancelledAt: parseTimestamp(json['cancelled_at']),
        expiresAt: parseTimestamp(json['expires_at']),
        approvedAt: parseTimestamp(json['approved_at']),
        rejectedAt: parseTimestamp(json['rejected_at']),
        createdAt: parseTimestamp(json['created_at']),
      );

  static String? _text(Object? raw) {
    final value = raw?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  final String slotId;
  final String contactName;
  final String contactPhone;

  /// Whether the customer may cancel. Only ever the server's answer.
  final bool canCancel;

  final String? specialRequests;

  /// The restaurant's reason for rejecting or cancelling.
  final String? cancellationReason;

  final DateTime? cancelledAt;

  /// When an unreviewed request lapses. May be shown as a countdown, but the
  /// booking must be re-read before the app decides it expired — the device's
  /// clock is not the authority.
  final DateTime? expiresAt;

  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final DateTime? createdAt;

  /// How long until the approval window closes, or null when it has passed or
  /// there is no window.
  Duration? get timeLeft {
    final at = expiresAt;
    if (at == null) return null;
    final left = at.difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  @override
  List<Object?> get props => [
    ...super.props,
    slotId,
    contactName,
    contactPhone,
    canCancel,
    specialRequests,
    cancellationReason,
    cancelledAt,
    expiresAt,
    approvedAt,
    rejectedAt,
    createdAt,
  ];
}

/// The staff booking sheet's counters.
class ReservationStats extends Equatable {
  const ReservationStats({
    this.pendingApproval = 0,
    this.todayConfirmed = 0,
    this.todayGuests = 0,
    this.upcoming = 0,
    this.seatedNow = 0,
  });

  factory ReservationStats.fromJson(Map<String, dynamic> json) =>
      ReservationStats(
        pendingApproval: (json['pending_approval'] as num?)?.toInt() ?? 0,
        todayConfirmed: (json['today_confirmed'] as num?)?.toInt() ?? 0,
        todayGuests: (json['today_guests'] as num?)?.toInt() ?? 0,
        upcoming: (json['upcoming'] as num?)?.toInt() ?? 0,
        seatedNow: (json['seated_now'] as num?)?.toInt() ?? 0,
      );

  final int pendingApproval;
  final int todayConfirmed;
  final int todayGuests;
  final int upcoming;
  final int seatedNow;

  @override
  List<Object?> get props => [
    pendingApproval,
    todayConfirmed,
    todayGuests,
    upcoming,
    seatedNow,
  ];
}

/// What staff may do next, and whether a reason is required.
///
/// Every transition is validated server-side as well. This exists so the screen
/// offers only legal moves, not as a substitute for that — a second device can
/// change the booking between the list loading and a button being pressed, which
/// is a 409 the caller still has to handle.
abstract final class ReservationTransitions {
  static List<ReservationStatus> nextFor(ReservationStatus status) =>
      switch (status) {
        ReservationStatus.pending => const [
          ReservationStatus.confirmed,
          ReservationStatus.rejected,
          ReservationStatus.cancelled,
        ],
        ReservationStatus.confirmed => const [
          ReservationStatus.seated,
          ReservationStatus.noShow,
          ReservationStatus.cancelled,
        ],
        ReservationStatus.seated => const [
          ReservationStatus.completed,
          ReservationStatus.cancelled,
        ],
        _ => const [],
      };

  /// Rejecting, cancelling and marking a no-show all require a note, which is
  /// shown to the customer as the reason. The API returns 422 without one.
  static bool needsReason(ReservationStatus status) =>
      status == ReservationStatus.rejected ||
      status == ReservationStatus.cancelled ||
      status == ReservationStatus.noShow;

  /// The verb for the button.
  static String actionLabel(ReservationStatus status) => switch (status) {
    ReservationStatus.confirmed => 'Approve',
    ReservationStatus.rejected => 'Reject',
    ReservationStatus.seated => 'Seat',
    ReservationStatus.completed => 'Complete',
    ReservationStatus.cancelled => 'Cancel',
    ReservationStatus.noShow => 'No-show',
    _ => status.label,
  };
}

/// The API's `error.code` values for bookings.
abstract final class BookingErrorCodes {
  static const String slotAlreadyBooked = 'SLOT_ALREADY_BOOKED';
  static const String slotNotFound = 'SLOT_NOT_FOUND';
  static const String slotNotBookable = 'SLOT_NOT_BOOKABLE';
  static const String alreadyApproved = 'RESERVATION_ALREADY_APPROVED';
  static const String approvalExpired = 'RESERVATION_APPROVAL_EXPIRED';
  static const String cannotBeCancelled = 'RESERVATION_CANNOT_BE_CANCELLED';
  static const String alreadyFinished = 'RESERVATION_ALREADY_FINISHED';
  static const String statusUnchanged = 'RESERVATION_STATUS_UNCHANGED';
  static const String invalidTransition = 'INVALID_STATUS_TRANSITION';
  static const String notFound = 'RESERVATION_NOT_FOUND';
  static const String partyTooLarge = 'PARTY_TOO_LARGE_FOR_TABLE';
  static const String sittingInThePast = 'SITTING_IN_THE_PAST';
  static const String sittingTooSoon = 'SITTING_TOO_SOON';
  static const String sittingTooFarAhead = 'SITTING_TOO_FAR_AHEAD';

  /// Whether the chosen slot is gone, so the app must go back and re-read
  /// availability rather than letting the customer press the button again.
  static bool meansReloadAvailability(String? code) =>
      code == slotAlreadyBooked ||
      code == slotNotFound ||
      code == slotNotBookable ||
      code == sittingInThePast ||
      code == sittingTooSoon ||
      code == sittingTooFarAhead;

  /// Whether the booking on screen is stale and should be re-read.
  static bool meansReloadBooking(String? code) =>
      code == alreadyApproved ||
      code == approvalExpired ||
      code == cannotBeCancelled ||
      code == alreadyFinished ||
      code == statusUnchanged ||
      code == invalidTransition;
}

/// The restaurant's calendar date, parsed without a timezone.
///
/// `DateTime.parse('2026-08-20')` gives local midnight, which is fine — but only
/// as long as nothing calls `toUtc()` on it afterwards. Parsed by hand so the
/// intent is unmistakable: this is a date on a wall calendar, not an instant.
DateTime parseCalendarDate(Object? raw) {
  final parts = raw?.toString().split('-') ?? const [];
  if (parts.length < 3) return DateTime(1970);
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2].split('T').first);
  if (year == null || month == null || day == null) return DateTime(1970);
  return DateTime(year, month, day);
}

/// `2026-08-20`, for a query parameter.
String apiDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

/// A real instant — created, cancelled, approved. These *are* converted.
DateTime? parseTimestamp(Object? raw) =>
    raw == null ? null : DateTime.tryParse(raw.toString())?.toLocal();

/// Integer pence, formatted without ever touching a double.
String formatBookingPrice(int pence) {
  if (pence == 0) return 'Free';
  return '£${pence ~/ 100}.${(pence % 100).toString().padLeft(2, '0')}';
}
