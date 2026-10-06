/// A minimal wall-clock time (no Flutter/material dependency) so the
/// scheduling model stays testable outside the widget layer.
class SimpleTime implements Comparable<SimpleTime> {
  final int hour;
  final int minute;

  const SimpleTime(this.hour, this.minute)
    : assert(hour >= 0 && hour < 24),
      assert(minute >= 0 && minute < 60);

  factory SimpleTime.fromDateTime(DateTime dt) => SimpleTime(dt.hour, dt.minute);

  int get minutesSinceMidnight => hour * 60 + minute;

  @override
  int compareTo(SimpleTime other) => minutesSinceMidnight.compareTo(other.minutesSinceMidnight);

  bool operator <(SimpleTime other) => compareTo(other) < 0;
  bool operator <=(SimpleTime other) => compareTo(other) <= 0;
  bool operator >(SimpleTime other) => compareTo(other) > 0;
  bool operator >=(SimpleTime other) => compareTo(other) >= 0;

  Map<String, dynamic> toJson() => {'hour': hour, 'minute': minute};

  factory SimpleTime.fromJson(Map<String, dynamic> json) =>
      SimpleTime(json['hour'] as int, json['minute'] as int);

  @override
  bool operator ==(Object other) =>
      other is SimpleTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
