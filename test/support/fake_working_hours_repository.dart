import 'package:practice/core/network/api_failure.dart';
import 'package:practice/features/hours/domain/working_hours.dart';
import 'package:practice/features/hours/domain/working_hours_repository.dart';

/// Opening hours, in memory.
class FakeWorkingHoursRepository implements WorkingHoursRepository {
  FakeWorkingHoursRepository({List<DayHours>? days, this.delay})
    : _days = days ?? [...weekdaysOnly];

  final Duration? delay;

  /// Monday to Friday configured, the weekend deliberately absent — which is
  /// "not set", not "closed", and the difference is what several tests are for.
  static final weekdaysOnly = <DayHours>[
    for (var weekday = 0; weekday < 5; weekday++)
      DayHours(
        weekday: weekday,
        isClosed: false,
        opensAt: '10:00',
        closesAt: '22:00',
      ),
  ];

  List<DayHours> _days;

  ApiFailure? failure;
  ApiFailure? writeFailure;

  int readCalls = 0;
  List<Map<String, dynamic>>? lastWeekSent;
  int? clearedWeekday;

  Future<void> _wait() async {
    final pause = delay;
    if (pause != null) await Future<void>.delayed(pause);
  }

  void _check() {
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<WorkingHours> hours() async {
    readCalls++;
    await _wait();
    _check();
    return WorkingHours(days: List.of(_days));
  }

  @override
  Future<WorkingHours> adminHours() => hours();

  @override
  Future<WorkingHours> setWeek(List<DayHours> days) async {
    lastWeekSent = [for (final day in days) day.toJson()];
    await _wait();
    final error = writeFailure ?? failure;
    if (error != null) throw error;

    // Only the days the API would keep: a closed day is still configured, but a
    // day with no times at all is not something the backend stores.
    _days = [
      for (final day in days)
        if (day.isClosed || day.isComplete) day,
    ];
    return WorkingHours(days: List.of(_days));
  }

  @override
  Future<DayHours> setDay(DayHours day) async {
    await _wait();
    final error = writeFailure ?? failure;
    if (error != null) throw error;

    _days = [
      for (final existing in _days)
        if (existing.weekday != day.weekday) existing,
      day,
    ]..sort((a, b) => a.weekday.compareTo(b.weekday));
    return day;
  }

  @override
  Future<void> clearDay(int weekday) async {
    clearedWeekday = weekday;
    await _wait();
    final error = writeFailure ?? failure;
    if (error != null) throw error;

    _days = [
      for (final day in _days)
        if (day.weekday != weekday) day,
    ];
  }
}
