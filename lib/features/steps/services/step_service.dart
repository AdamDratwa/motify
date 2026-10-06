import 'package:health/health.dart';

/// Wraps the `health` package (HealthKit on iOS, Health Connect on Android)
/// to expose today's step count for goal progress.
class StepService {
  final Health _health = Health();
  static const _types = [HealthDataType.STEPS];

  Future<bool> requestPermissions() async {
    await _health.configure();
    final granted = await _health.requestAuthorization(_types, permissions: [
      HealthDataAccess.READ,
    ]);
    // Android: lets the native StepSyncWorker read steps while Motify is
    // closed, so locked apps unlock on time. Not available on every device
    // (needs a recent Health Connect); blocking still works without it, it
    // just re-checks steps only when an app is opened or Motify is.
    if (granted &&
        await _health.isHealthDataInBackgroundAvailable() &&
        !await _health.isHealthDataInBackgroundAuthorized()) {
      await _health.requestHealthDataInBackgroundAuthorization();
    }
    return granted;
  }

  /// Checks without prompting, so it's safe to call on every refresh.
  Future<bool> hasPermissions() async {
    await _health.configure();
    final granted = await _health.hasPermissions(_types, permissions: [
      HealthDataAccess.READ,
    ]);
    return granted ?? false;
  }

  Future<int> getStepsToday() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final steps = await _health.getTotalStepsInInterval(midnight, now);
    return steps ?? 0;
  }
}
