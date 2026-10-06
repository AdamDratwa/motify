import 'package:flutter_test/flutter_test.dart';
import 'package:motify/features/goals/models/free_window.dart';
import 'package:motify/features/goals/models/simple_time.dart';
import 'package:motify/features/goals/models/weekday.dart';
import 'package:motify/features/goals/screens/free_window_sheet.dart';

// 2026-10-09 is a Friday.
DateTime fri(int h, [int m = 0]) => DateTime(2026, 10, 9, h, m);
DateTime sat(int h, [int m = 0]) => DateTime(2026, 10, 10, h, m);

void main() {
  test('from-only window runs to midnight', () {
    final w = FreeWindow(id: 'a', days: Weekday.values.toSet(), startTime: const SimpleTime(18, 30));
    expect(w.coversNow(fri(18, 29)), isFalse);
    expect(w.coversNow(fri(18, 30)), isTrue);
    expect(w.coversNow(fri(23, 59)), isTrue);
  });

  test('until-only window runs from midnight', () {
    final w = FreeWindow(id: 'a', days: {Weekday.friday}, endTime: const SimpleTime(9, 0));
    expect(w.coversNow(fri(8, 59)), isTrue);
    expect(w.coversNow(fri(9, 0)), isFalse);
  });

  test('overnight window continues into the next morning', () {
    final w = FreeWindow(
      id: 'a',
      days: {Weekday.friday},
      startTime: const SimpleTime(22, 0),
      endTime: const SimpleTime(7, 0),
    );
    expect(w.coversNow(fri(21, 59)), isFalse);
    expect(w.coversNow(fri(22, 0)), isTrue);
    expect(w.coversNow(sat(6, 59)), isTrue, reason: 'started Friday night');
    expect(w.coversNow(sat(7, 0)), isFalse);
    expect(w.coversNow(sat(22, 0)), isFalse, reason: 'Saturday is not a start day');
    expect(w.coversNow(fri(3, 0)), isFalse, reason: 'Thursday night is not a start day');
  });

  test('summaries', () {
    expect(
      describeFreeWindow(const FreeWindow(id: 'a', days: {Weekday.saturday, Weekday.sunday})),
      'Weekends · all day',
    );
    expect(
      describeFreeWindow(
        FreeWindow(
          id: 'a',
          days: Weekday.values.take(5).toSet(),
          startTime: const SimpleTime(16, 0),
        ),
      ),
      'Weekdays · 16:00 → midnight',
    );
    expect(
      describeFreeWindow(
        const FreeWindow(
          id: 'a',
          days: {Weekday.friday},
          startTime: SimpleTime(22, 0),
          endTime: SimpleTime(7, 0),
        ),
      ),
      'Fri · 22:00 → 07:00 (next day)',
    );
  });
}
