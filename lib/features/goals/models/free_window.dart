import 'simple_time.dart';
import 'weekday.dart';

/// A recurring time window during which an app's goal restriction is
/// switched off, e.g. "all day on Sat/Sun" or "every day after 16:00".
///
/// [startTime]/[endTime] are null to mean "from start of day" /
/// "to end of day" respectively, so a whole-day window is
/// FreeWindow(days: {...}, startTime: null, endTime: null).
class FreeWindow {
  final String id;
  final Set<Weekday> days;
  final SimpleTime? startTime;
  final SimpleTime? endTime;

  const FreeWindow({
    required this.id,
    required this.days,
    this.startTime,
    this.endTime,
  });

  bool coversNow(DateTime now) {
    if (!days.contains(now.asWeekday)) return false;
    final t = SimpleTime.fromDateTime(now);
    if (startTime != null && t < startTime!) return false;
    if (endTime != null && t >= endTime!) return false;
    return true;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'days': days.map((d) => d.name).toList(),
        'startTime': startTime?.toJson(),
        'endTime': endTime?.toJson(),
      };

  factory FreeWindow.fromJson(Map<String, dynamic> json) => FreeWindow(
        id: json['id'] as String,
        days: (json['days'] as List)
            .map((d) => Weekday.values.byName(d as String))
            .toSet(),
        startTime: json['startTime'] == null
            ? null
            : SimpleTime.fromJson(json['startTime'] as Map<String, dynamic>),
        endTime: json['endTime'] == null
            ? null
            : SimpleTime.fromJson(json['endTime'] as Map<String, dynamic>),
      );
}
