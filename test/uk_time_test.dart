import 'package:flutter_test/flutter_test.dart';
import 'package:practice/core/time/uk_time.dart';

/// The restaurant's clock.
///
/// Worth testing precisely rather than by eye: the greeting is wrong for an hour
/// either side of a clock change if the rule is approximated, and wrong all
/// summer if BST is ignored.
void main() {
  group('British Summer Time', () {
    test('is not in force in the middle of winter', () {
      final january = DateTime.utc(2026, 1, 15, 12);
      expect(UkTime.isSummerTime(january), isFalse);
      expect(UkTime.at(january).hour, 12);
    });

    test('is in force in the middle of summer', () {
      final july = DateTime.utc(2026, 7, 15, 12);
      expect(UkTime.isSummerTime(july), isTrue);
      // London is an hour ahead of UTC.
      expect(UkTime.at(july).hour, 13);
    });

    test('begins on the last Sunday in March at 01:00 UTC', () {
      // 2026: the last Sunday in March is the 29th.
      expect(
        UkTime.isSummerTime(DateTime.utc(2026, 3, 29, 0, 59)),
        isFalse,
        reason: 'a minute before the switch is still GMT',
      );
      expect(UkTime.isSummerTime(DateTime.utc(2026, 3, 29, 1)), isTrue);
    });

    test('ends on the last Sunday in October at 01:00 UTC', () {
      // 2026: the last Sunday in October is the 25th.
      expect(UkTime.isSummerTime(DateTime.utc(2026, 10, 25, 0, 59)), isTrue);
      expect(
        UkTime.isSummerTime(DateTime.utc(2026, 10, 25, 1)),
        isFalse,
        reason: 'the clocks have gone back',
      );
    });

    test('finds the right Sunday in a year where the month ends on one', () {
      // 2027: March has 31 days and the 28th is the last Sunday.
      expect(UkTime.isSummerTime(DateTime.utc(2027, 3, 28, 1)), isTrue);
      expect(UkTime.isSummerTime(DateTime.utc(2027, 3, 27, 23)), isFalse);
    });
  });

  group('the greeting', () {
    test('follows the hour, not a hardcoded string', () {
      // It used to read "Good Morning," at every hour of the day.
      expect(UkTime.greeting(DateTime.utc(2026, 1, 15, 8)), 'Good morning');
      expect(UkTime.greeting(DateTime.utc(2026, 1, 15, 13)), 'Good afternoon');
      expect(UkTime.greeting(DateTime.utc(2026, 1, 15, 20)), 'Good evening');
    });

    test('uses London, so summer shifts the boundary', () {
      // 11:30 UTC in July is 12:30 in London — afternoon there, morning by UTC.
      expect(
        UkTime.greeting(DateTime.utc(2026, 7, 15, 11, 30)),
        'Good afternoon',
      );
      expect(
        UkTime.greeting(DateTime.utc(2026, 1, 15, 11, 30)),
        'Good morning',
      );
    });

    test('midnight and noon fall on the right side', () {
      expect(UkTime.greeting(DateTime.utc(2026, 1, 15, 0)), 'Good morning');
      expect(UkTime.greeting(DateTime.utc(2026, 1, 15, 12)), 'Good afternoon');
      expect(UkTime.greeting(DateTime.utc(2026, 1, 15, 18)), 'Good evening');
    });
  });
}
