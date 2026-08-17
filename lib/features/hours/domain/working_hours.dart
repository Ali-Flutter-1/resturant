import 'package:equatable/equatable.dart';

/// One day's opening hours.
///
/// [opensAt] and [closesAt] are the restaurant's wall clock — `10:00:00` — and
/// are deliberately kept as strings. They are not instants, and converting them
/// through the device's timezone is how a London restaurant appears to open at
/// 14:00 for somebody whose phone is in Karachi.
class DayHours extends Equatable {
  const DayHours({
    required this.weekday,
    required this.isClosed,
    this.opensAt,
    this.closesAt,
    this.createdAt,
    this.updatedAt,
  });

  factory DayHours.fromJson(Map<String, dynamic> json) => DayHours(
    weekday: (json['weekday'] as num?)?.toInt() ?? 0,
    isClosed: json['is_closed'] == true,
    opensAt: _time(json['opens_at']),
    closesAt: _time(json['closes_at']),
    createdAt: _date(json['created_at']),
    updatedAt: _date(json['updated_at']),
  );

  /// The API sends `10:00:00`; the seconds are never worth the width.
  static String? _time(Object? raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : value;
  }

  static DateTime? _date(Object? raw) =>
      raw == null ? null : DateTime.tryParse(raw.toString())?.toLocal();

  /// 0 = Monday … 6 = Sunday, as the API numbers them.
  final int weekday;

  final bool isClosed;
  final String? opensAt;
  final String? closesAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const List<String> weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  String get name =>
      weekday >= 0 && weekday < 7 ? weekdayNames[weekday] : 'Day $weekday';

  String get shortName => name.substring(0, 3);

  /// Whether both times are present, which is what an open day needs.
  bool get isComplete => opensAt != null && closesAt != null;

  /// `10:00 – 22:00`, or the reason there is no range.
  String get label {
    if (isClosed) return 'Closed';
    if (!isComplete) return 'Not set';
    return '$opensAt – $closesAt';
  }

  /// What the API accepts back. Seconds are added because the field is a `time`;
  /// the backend strips them again, but sending `10:00` alone has been refused
  /// by stricter parsers before.
  Map<String, dynamic> toJson() => {
    'weekday': weekday,
    'is_closed': isClosed,
    // Both null on a closed day rather than left at their old values — a closed
    // Sunday with `opens_at: 10:00` still on it is a contradiction the next
    // reader has to resolve.
    'opens_at': isClosed ? null : _withSeconds(opensAt),
    'closes_at': isClosed ? null : _withSeconds(closesAt),
  };

  static String? _withSeconds(String? value) {
    if (value == null || value.isEmpty) return null;
    return value.split(':').length == 2 ? '$value:00' : value;
  }

  DayHours copyWith({
    bool? isClosed,
    String? opensAt,
    String? closesAt,
    bool clearTimes = false,
  }) => DayHours(
    weekday: weekday,
    isClosed: isClosed ?? this.isClosed,
    opensAt: clearTimes ? null : (opensAt ?? this.opensAt),
    closesAt: clearTimes ? null : (closesAt ?? this.closesAt),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  List<Object?> get props => [
    weekday,
    isClosed,
    opensAt,
    closesAt,
    createdAt,
    updatedAt,
  ];
}

/// The week.
///
/// The API returns only the days that have been configured. A **missing** day
/// means "hours not set", which is not the same as "closed" — the guide is
/// explicit about that, and conflating them would tell customers the restaurant
/// is shut on a day nobody has got round to filling in.
class WorkingHours extends Equatable {
  const WorkingHours({this.days = const []});

  factory WorkingHours.fromList(List<Map<String, dynamic>> rows) =>
      WorkingHours(days: rows.map(DayHours.fromJson).toList());

  final List<DayHours> days;

  bool get isEmpty => days.isEmpty;

  DayHours? forWeekday(int weekday) {
    for (final day in days) {
      if (day.weekday == weekday) return day;
    }
    return null;
  }

  /// Every weekday in order, with a placeholder for any the API did not send.
  ///
  /// The placeholder is *not* closed — see the class note.
  List<DayHours> get wholeWeek => [
    for (var weekday = 0; weekday < 7; weekday++)
      forWeekday(weekday) ?? DayHours(weekday: weekday, isClosed: false),
  ];

  /// Whether a weekday has been configured at all.
  bool isConfigured(int weekday) => forWeekday(weekday) != null;

  /// Today's hours, by the device's own calendar.
  ///
  /// `DateTime.weekday` is 1 = Monday … 7 = Sunday; the API is 0-based.
  DayHours? get today => forWeekday(DateTime.now().weekday - 1);

  /// A one-line summary for the customer, or null when nothing is configured.
  ///
  /// Deliberately never says "Open now". Working hours are informational: the
  /// guide states the backend does not yet reject orders or bookings outside
  /// them, so claiming the restaurant is open would be a promise the server has
  /// not made.
  String? get todayLabel {
    final day = today;
    if (day == null) return null;
    if (day.isClosed) return 'Closed today';
    if (!day.isComplete) return null;
    return 'Today ${day.opensAt} – ${day.closesAt}';
  }

  @override
  List<Object?> get props => [days];
}

/// The API's `error.code` values for this area.
abstract final class WorkingHoursErrorCodes {
  /// A day that was never configured, or has already been cleared.
  static const String notSet = 'WORKING_HOURS_NOT_SET';
}
