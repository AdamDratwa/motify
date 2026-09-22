import 'app_rule.dart';

enum GateReason { disabledByUser, freeWindow, goalMet, goalNotMet }

class GateDecision {
  final bool unlocked;
  final GateReason reason;
  final int progressValue;
  final int targetValue;

  const GateDecision({
    required this.unlocked,
    required this.reason,
    required this.progressValue,
    required this.targetValue,
  });

  double get progressFraction =>
      targetValue == 0 ? 1 : (progressValue / targetValue).clamp(0, 1);
}

/// Pure decision logic: given a rule, the current time, and today's progress
/// toward the goal, is the app unlocked? This runs on-device (and must stay
/// side-effect free) so the native blocking overlay can call it instantly
/// without a network round-trip.
GateDecision evaluateGate({
  required AppRule rule,
  required DateTime now,
  required int currentProgress,
}) {
  if (!rule.enabled) {
    return GateDecision(
      unlocked: true,
      reason: GateReason.disabledByUser,
      progressValue: currentProgress,
      targetValue: rule.targetValue,
    );
  }
  if (rule.isInFreeWindow(now)) {
    return GateDecision(
      unlocked: true,
      reason: GateReason.freeWindow,
      progressValue: currentProgress,
      targetValue: rule.targetValue,
    );
  }
  final met = currentProgress >= rule.targetValue;
  return GateDecision(
    unlocked: met,
    reason: met ? GateReason.goalMet : GateReason.goalNotMet,
    progressValue: currentProgress,
    targetValue: rule.targetValue,
  );
}
