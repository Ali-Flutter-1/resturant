import 'working_hours.dart';

/// The restaurant's opening hours.
abstract interface class WorkingHoursRepository {
  /// The public week. Needs no session — somebody deciding whether to walk over
  /// does not have an account.
  Future<WorkingHours> hours();

  /// The same week with audit timestamps. Admin only.
  Future<WorkingHours> adminHours();

  /// Replaces the whole week. Must carry exactly seven days, one per weekday.
  Future<WorkingHours> setWeek(List<DayHours> days);

  /// Replaces one day.
  Future<DayHours> setDay(DayHours day);

  /// Clears one day, so it reads as "not configured" rather than closed.
  Future<void> clearDay(int weekday);
}
