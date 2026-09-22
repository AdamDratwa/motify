import 'package:health/health.dart';

/// Wraps the `health` package (HealthKit on iOS, Health Connect on Android)
/// to expose today's step count for goal progress.
class StepService {
  final Health _health = Health();
  static const _types = [HealthDataType.STEPS];

  Future<bool> requestPermissions() async {
    await _health.configure();
    return _health.requestAuthorization(_types, permissions: [
      HealthDataAccess.READ,
    ]);
  }

  Future<int> getStepsToday() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final steps = await _health.getTotalStepsInInterval(midnight, now);
    return steps ?? 0;
  }
}
