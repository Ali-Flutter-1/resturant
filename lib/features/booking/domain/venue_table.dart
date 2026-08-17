import 'package:equatable/equatable.dart';

import 'reservation.dart' show apiDate, formatBookingPrice, parseCalendarDate;

/// Where a table sits in the room.
enum TableArea {
  indoor('Indoor'),
  outdoor('Outdoor'),
  window('Window'),
  private('Private'),
  bar('Bar');

  const TableArea(this.label);

  final String label;
  String get apiValue => name;

  /// Falls back to [indoor] rather than throwing: an area the backend adds
  /// should not stop an admin from seeing their own tables.
  static TableArea fromApi(Object? value) =>
      switch (value?.toString().trim().toLowerCase()) {
        'outdoor' => outdoor,
        'window' => window,
        'private' => private,
        'bar' => bar,
        _ => indoor,
      };
}

/// A physical table, as admin manages it.
class VenueTable extends Equatable {
  const VenueTable({
    required this.id,
    required this.name,
    required this.seats,
    required this.area,
    this.description,
    this.imageUrl,
    this.bookingPricePence = 0,
    this.sortOrder = 0,
    this.isActive = true,
    this.isArchived = false,
  });

  factory VenueTable.fromJson(Map<String, dynamic> json) => VenueTable(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    seats: (json['seats'] as num?)?.toInt() ?? 0,
    area: TableArea.fromApi(json['area']),
    description: _text(json['description']),
    imageUrl: _text(json['image_url']),
    bookingPricePence: (json['booking_price_pence'] as num?)?.toInt() ?? 0,
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    isActive: json['is_active'] != false,
    isArchived: json['is_archived'] == true,
  );

  static String? _text(Object? raw) {
    final value = raw?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  final String id;
  final String name;
  final int seats;
  final TableArea area;
  final String? description;
  final String? imageUrl;

  /// What booking this table costs, in integer pence. Zero is free, which is the
  /// normal case — the guide notes there is no payment provider wired for the
  /// non-zero one yet.
  final int bookingPricePence;

  final int sortOrder;

  /// Whether customers can see it. Distinct from [isArchived]: an inactive table
  /// still exists and can be switched back on.
  final bool isActive;

  /// Soft-deleted. Restoring clears this but deliberately does **not** set
  /// [isActive] — the API leaves that as a second, separate decision.
  final bool isArchived;

  bool get isFree => bookingPricePence == 0;

  String get priceLabel => formatBookingPrice(bookingPricePence);

  String get seatsLabel => seats == 1 ? '1 seat' : '$seats seats';

  /// What a customer would see today.
  String get stateLabel {
    if (isArchived) return 'Archived';
    return isActive ? 'Live' : 'Hidden';
  }

  /// Only the fields the API accepts, and only the ones that changed.
  ///
  /// A PATCH that resends every field would overwrite a change another admin
  /// made in between with a value this screen happened to be holding.
  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'seats': seats,
    'area': area.apiValue,
    'description': ?description,
    'booking_price_pence': bookingPricePence,
    'sort_order': sortOrder,
    'is_active': isActive,
  };

  VenueTable copyWith({
    String? name,
    int? seats,
    TableArea? area,
    String? description,
    int? bookingPricePence,
    int? sortOrder,
    bool? isActive,
  }) => VenueTable(
    id: id,
    name: name ?? this.name,
    seats: seats ?? this.seats,
    area: area ?? this.area,
    description: description ?? this.description,
    imageUrl: imageUrl,
    bookingPricePence: bookingPricePence ?? this.bookingPricePence,
    sortOrder: sortOrder ?? this.sortOrder,
    isActive: isActive ?? this.isActive,
    isArchived: isArchived,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    seats,
    area,
    description,
    imageUrl,
    bookingPricePence,
    sortOrder,
    isActive,
    isArchived,
  ];
}

/// One sitting on the schedule, as admin manages it.
class VenueSlot extends Equatable {
  const VenueSlot({
    required this.id,
    required this.tableId,
    required this.tableName,
    required this.serviceDate,
    required this.startTime,
    required this.durationMinutes,
    required this.bufferMinutes,
    required this.pricePence,
    this.notes,
    this.isActive = true,
    this.isBooked = false,
  });

  factory VenueSlot.fromJson(Map<String, dynamic> json) => VenueSlot(
    id: json['id']?.toString() ?? '',
    tableId: json['table_id']?.toString() ?? '',
    tableName: json['table_name']?.toString() ?? '',
    serviceDate: parseCalendarDate(json['service_date']),
    startTime: json['start_time']?.toString() ?? '',
    durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
    bufferMinutes: (json['buffer_minutes'] as num?)?.toInt() ?? 0,
    pricePence: (json['price_pence'] as num?)?.toInt() ?? 0,
    notes: VenueTable._text(json['notes']),
    isActive: json['is_active'] != false,
    isBooked: json['is_booked'] == true,
  );

  final String id;
  final String tableId;
  final String tableName;

  /// The restaurant's calendar date, never an instant.
  final DateTime serviceDate;

  /// The restaurant's wall clock, kept as the API sent it.
  final String startTime;

  final int durationMinutes;

  /// Cleanup time before the next sitting. Start spacing is duration + buffer.
  final int bufferMinutes;

  final int pricePence;
  final String? notes;
  final bool isActive;

  /// True while a pending, confirmed or seated reservation holds it.
  ///
  /// A held slot must not be deleted or re-timed — the API refuses, and doing so
  /// would move a table out from under a customer who has already been told they
  /// have it. Closing it (`is_active: false`) stops further sales while leaving
  /// the existing booking alone, which is the correct move.
  final bool isBooked;

  String get timeLabel {
    final parts = startTime.split(':');
    return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : startTime;
  }

  /// When the table is free again — the sitting plus its cleanup.
  String get endsLabel {
    final parts = startTime.split(':');
    if (parts.length < 2) return '';
    final start = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
    final end = start + durationMinutes + bufferMinutes;
    // Wraps past midnight, which a late sitting legitimately does.
    final hour = (end ~/ 60) % 24;
    final minute = end % 60;
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  /// Only what `SlotUpdate` accepts. `table_id`, the date and the start time are
  /// not editable — moving a sitting means deleting it and making another.
  Map<String, dynamic> updateJson() => {
    'duration_minutes': durationMinutes,
    'buffer_minutes': bufferMinutes,
    'price_pence': pricePence,
    'notes': ?notes,
    'is_active': isActive,
  };

  @override
  List<Object?> get props => [
    id,
    tableId,
    tableName,
    serviceDate,
    startTime,
    durationMinutes,
    bufferMinutes,
    pricePence,
    notes,
    isActive,
    isBooked,
  ];
}

/// What a bulk generation actually did.
class SlotGenerateResult extends Equatable {
  const SlotGenerateResult({
    this.created = 0,
    this.skipped = 0,
    this.tables = 0,
  });

  factory SlotGenerateResult.fromJson(Map<String, dynamic> json) =>
      SlotGenerateResult(
        created: (json['created'] as num?)?.toInt() ?? 0,
        skipped: (json['skipped'] as num?)?.toInt() ?? 0,
        // The API sends either a count or the list of tables it touched.
        tables: switch (json['tables']) {
          final num n => n.toInt(),
          final List l => l.length,
          _ => 0,
        },
      );

  final int created;

  /// Rows that already existed for that table, date and start time. Reported
  /// rather than hidden: "created 0, skipped 84" is the difference between
  /// "nothing happened" and "it was already done".
  final int skipped;

  final int tables;

  @override
  List<Object?> get props => [created, skipped, tables];
}

/// A day of the week, for bulk generation.
enum SlotWeekday {
  mon('mon', 'Mon'),
  tue('tue', 'Tue'),
  wed('wed', 'Wed'),
  thu('thu', 'Thu'),
  fri('fri', 'Fri'),
  sat('sat', 'Sat'),
  sun('sun', 'Sun');

  const SlotWeekday(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

/// What a bulk generation is about to do, worked out locally.
///
/// The API decides for real, but an admin pressing "generate" over a month of
/// dates deserves to see the start times first: the spacing is
/// `turn + buffer`, which for 90 + 15 gives 18:00, 19:45, 21:30 — not the hourly
/// grid most people picture.
class SlotPreview extends Equatable {
  const SlotPreview({required this.starts, required this.lastEnds});

  factory SlotPreview.from({
    required String firstSitting,
    required String lastSitting,
    required int turnMinutes,
    required int bufferMinutes,
  }) {
    final first = _minutes(firstSitting);
    final last = _minutes(lastSitting);
    final step = turnMinutes + bufferMinutes;
    if (first == null || last == null || step <= 0 || last < first) {
      return const SlotPreview(starts: [], lastEnds: '');
    }

    final starts = <String>[];
    // Capped at the API's own ceiling of 24 sittings a day, so a nonsense step
    // cannot spin here.
    for (var at = first; at <= last && starts.length < 24; at += step) {
      starts.add(_label(at));
    }
    return SlotPreview(
      starts: starts,
      lastEnds: starts.isEmpty
          ? ''
          : _label(first + (starts.length - 1) * step + turnMinutes + bufferMinutes),
    );
  }

  static int? _minutes(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

  static String _label(int minutes) =>
      '${((minutes ~/ 60) % 24).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  final List<String> starts;

  /// When the last sitting's cleanup finishes — often later than the admin
  /// expects, and the reason to show this at all.
  final String lastEnds;

  int get perDay => starts.length;

  @override
  List<Object?> get props => [starts, lastEnds];
}

/// The API's `error.code` values for tables and sittings.
abstract final class VenueErrorCodes {
  static const String tableNotFound = 'TABLE_NOT_FOUND';
  static const String tableNameTaken = 'TABLE_NAME_TAKEN';

  /// Seats cannot drop below a party already booked on this table.
  static const String tableHasLargerBooking = 'TABLE_HAS_LARGER_BOOKING';

  /// Cannot archive while upcoming reservations exist.
  static const String tableHasBookings = 'TABLE_HAS_BOOKINGS';
  static const String tableArchived = 'TABLE_ARCHIVED';

  static const String slotAlreadyExists = 'SLOT_ALREADY_EXISTS';
  static const String slotOverlaps = 'SLOT_OVERLAPS_EXISTING';

  /// A pending, confirmed or seated booking holds it.
  static const String slotIsBooked = 'SLOT_IS_BOOKED';

  static const String noTables = 'NO_TABLES';
  static const String invalidWeekday = 'INVALID_WEEKDAY';
  static const String invalidDateRange = 'INVALID_DATE_RANGE';
  static const String dateRangeTooLong = 'DATE_RANGE_TOO_LONG';
  static const String invalidSittingRange = 'INVALID_SITTING_RANGE';
  static const String tooManySittings = 'TOO_MANY_SITTINGS';
  static const String noMatchingDates = 'NO_MATCHING_DATES';

  /// Whether the failure belongs beside the schedule fields rather than as a
  /// general banner — the admin's next move is to change one of them.
  static bool isScheduleProblem(String? code) =>
      code == slotOverlaps ||
      code == slotAlreadyExists ||
      code == invalidSittingRange ||
      code == tooManySittings ||
      code == invalidDateRange ||
      code == dateRangeTooLong ||
      code == noMatchingDates;
}

/// `2026-08-20`, re-exported so the venue screens do not reach into the
/// reservation file for it.
String venueDate(DateTime value) => apiDate(value);
