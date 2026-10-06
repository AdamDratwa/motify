import 'package:flutter_test/flutter_test.dart';
import 'package:motify/features/goals/models/app_rule.dart';
import 'package:motify/features/goals/models/free_window.dart';
import 'package:motify/features/goals/models/gate_decision.dart';
import 'package:motify/features/goals/models/weekday.dart';

AppRule rule({int? stepGoal, int? limit, bool enabled = true, List<FreeWindow> free = const []}) =>
    AppRule(
      id: 'ig',
      appId: 'com.instagram.android',
      appDisplayName: 'Instagram',
      stepGoal: stepGoal,
      dailyLimitMinutes: limit,
      enabled: enabled,
      freeWindows: free,
    );

// A Wednesday, so weekend windows don't apply.
final wednesdayNoon = DateTime(2026, 10, 7, 12);

GateDecision gate(AppRule r, {int steps = 0, int used = 0}) =>
    evaluateGate(rule: r, now: wednesdayNoon, steps: steps, usedMinutes: used);

void main() {
  group('step goal only', () {
    test('locked below the goal, open at it', () {
      expect(gate(rule(stepGoal: 10000), steps: 9999).reason, GateReason.stepsNotMet);
      expect(gate(rule(stepGoal: 10000), steps: 10000).reason, GateReason.allowed);
    });

    test('usage is irrelevant without a limit', () {
      expect(gate(rule(stepGoal: 100), steps: 100, used: 600).unlocked, isTrue);
    });
  });

  group('time limit only', () {
    test('open until the limit is used up, then locked', () {
      expect(gate(rule(limit: 30), used: 29).reason, GateReason.allowed);
      expect(gate(rule(limit: 30), used: 29).minutesLeft, 1);
      expect(gate(rule(limit: 30), used: 30).reason, GateReason.timeLimitReached);
    });
  });

  group('both', () {
    final both = rule(stepGoal: 10000, limit: 30);

    test('locked until steps are met', () {
      expect(gate(both, steps: 5000, used: 0).reason, GateReason.stepsNotMet);
    });

    test('then open while time remains', () {
      expect(gate(both, steps: 10000, used: 10).reason, GateReason.allowed);
    });

    test('time limit wins when both fail, since walking cannot fix it', () {
      expect(gate(both, steps: 0, used: 30).reason, GateReason.timeLimitReached);
    });
  });

  test('paused rules and free windows override every condition', () {
    expect(gate(rule(stepGoal: 10000, enabled: false)).reason, GateReason.disabledByUser);
    final allWeek = FreeWindow(id: 'all', days: Weekday.values.toSet());
    expect(gate(rule(limit: 10, free: [allWeek]), used: 999).reason, GateReason.freeWindow);
  });

  test('rules saved before time limits existed still load as step goals', () {
    final legacy = AppRule.fromJson({
      'id': 'ig',
      'appId': 'com.instagram.android',
      'appDisplayName': 'Instagram',
      'goalType': 'steps',
      'targetValue': 8000,
    });
    expect(legacy.stepGoal, 8000);
    expect(legacy.dailyLimitMinutes, isNull);
  });

  test('json round trip keeps both conditions', () {
    final r = AppRule.fromJson(rule(stepGoal: 5000, limit: 45).toJson());
    expect((r.stepGoal, r.dailyLimitMinutes), (5000, 45));
  });
}
