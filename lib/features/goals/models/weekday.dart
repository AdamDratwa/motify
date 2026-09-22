enum Weekday { monday, tuesday, wednesday, thursday, friday, saturday, sunday }

extension WeekdayFromDateTime on DateTime {
  Weekday get asWeekday => Weekday.values[weekday - 1];
}

extension WeekdayLabel on Weekday {
  String get shortLabel => switch (this) {
        Weekday.monday => 'Mon',
        Weekday.tuesday => 'Tue',
        Weekday.wednesday => 'Wed',
        Weekday.thursday => 'Thu',
        Weekday.friday => 'Fri',
        Weekday.saturday => 'Sat',
        Weekday.sunday => 'Sun',
      };
}
