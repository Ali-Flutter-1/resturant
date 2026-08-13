/// The restaurant's own clock.
///
/// The venue is in the UK, so anything the app says about the time of day should
/// follow London — not the device. A customer ordering from Colombo or New York
/// should still be greeted with the café's morning, because that is whose morning
/// it is.
///
/// Dart carries no timezone database, and pulling one in for a greeting would be
/// a lot of bytes for one string. British Summer Time is a short, exact rule, so
/// it is implemented here rather than approximated:
///
///  * BST begins on the **last Sunday in March** at 01:00 UTC.
///  * It ends on the **last Sunday in October** at 01:00 UTC.
///
/// Between those, London is UTC+1; otherwise UTC+0.
abstract final class UkTime {
  /// London's wall clock, right now.
  static DateTime now() => at(DateTime.now().toUtc());

  /// London's wall clock at [utc]. Exposed so a test can name a moment rather
  /// than depending on when it runs.
  static DateTime at(DateTime utc) {
    final moment = utc.isUtc ? utc : utc.toUtc();
    return isSummerTime(moment) ? moment.add(const Duration(hours: 1)) : moment;
  }

  /// Whether British Summer Time is in force at [utc].
  static bool isSummerTime(DateTime utc) {
    final start = _lastSundayOfMonth(utc.year, 3);
    final end = _lastSundayOfMonth(utc.year, 10);
    // Both switches happen at 01:00 UTC, which is what makes the comparison a
    // simple one — in local terms the clocks go forward at 01:00 and back at
    // 02:00, and reasoning in UTC avoids the hour that exists twice.
    return !utc.isBefore(start) && utc.isBefore(end);
  }

  static DateTime _lastSundayOfMonth(int year, int month) {
    // Day zero of the next month is the last day of this one.
    final lastDay = DateTime.utc(year, month + 1, 0);
    final sunday = lastDay.day - (lastDay.weekday % 7);
    return DateTime.utc(year, month, sunday, 1);
  }

  /// "Good morning" and friends, on the restaurant's clock.
  ///
  /// The old greeting was the literal string "Good Morning," whatever the hour,
  /// which read as broken to anyone opening the app after lunch.
  static String greeting([DateTime? utc]) {
    final hour = (utc == null ? now() : at(utc)).hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }
}
