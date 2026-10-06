import 'app_rule.dart';

enum GateReason {
  /// The rule is paused by the user.
  disabledByUser,

  /// A free window (weekends, after 4pm, ...) is active.
  freeWindow,

  /// Today's time limit is used up; walking won't help until tomorrow.
  timeLimitReached,

  /// Today's step goal isn't reached yet.
  stepsNotMet,

  /// Every condition holds.
  allowed,
}

class GateDecision {
  final bool unlocked;
  final GateReason reason;
  final int steps;
  final int? stepGoal;
  final int usedMinutes;
  final int? limitMinutes;

  const GateDecision({
    required this.unlocked,
    required this.reason,
    required this.steps,
    required this.stepGoal,
    required this.usedMinutes,
    required this.limitMinutes,
  });

  int get stepsLeft => stepGoal == null ? 0 : (stepGoal! - steps).clamp(0, stepGoal!);
  int get minutesLeft =>
      limitMinutes == null ? 0 : (limitMinutes! - usedMinutes).clamp(0, limitMinutes!);

  double get stepsFraction =>
      stepGoal == null || stepGoal == 0 ? 1 : (steps / stepGoal!).clamp(0, 1);
  double get usageFraction =>
      limitMinutes == null || limitMinutes == 0 ? 1 : (usedMinutes / limitMinutes!).clamp(0, 1);
}

/// Pure decision logic: given a rule, the current time, today's steps and
/// today's usage of the app, is it unlocked? Side-effect free and mirrored
/// natively by BlockingStore.kt (android/app/src/main/kotlin/com/motify/motify/)
/// — keep the two in sync.
///
/// When both conditions fail, [GateReason.timeLimitReached] wins: it's the
/// one that steps can't fix today, so it's the more useful thing to show.
GateDecision evaluateGate({
  required AppRule rule,
  required DateTime now,
  required int steps,
  required int usedMinutes,
}) {
  GateDecision decide(bool unlocked, GateReason reason) => GateDecision(
    unlocked: unlocked,
    reason: reason,
    steps: steps,
    stepGoal: rule.stepGoal,
    usedMinutes: usedMinutes,
    limitMinutes: rule.dailyLimitMinutes,
  );

  if (!rule.enabled) return decide(true, GateReason.disabledByUser);
  if (rule.isInFreeWindow(now)) return decide(true, GateReason.freeWindow);

  final limit = rule.dailyLimitMinutes;
  if (limit != null && usedMinutes >= limit) return decide(false, GateReason.timeLimitReached);

  final goal = rule.stepGoal;
  if (goal != null && steps < goal) return decide(false, GateReason.stepsNotMet);

  return decide(true, GateReason.allowed);
}
