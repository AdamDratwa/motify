import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../blocking/services/app_blocking_service.dart';
import '../../steps/services/step_service.dart';
import '../models/app_rule.dart';
import '../models/gate_decision.dart';
import '../repository/goals_repository.dart';

// Null when Firebase isn't configured (see main.dart), so the app still opens.
final currentUidProvider = Provider<String?>((ref) {
  if (Firebase.apps.isEmpty) return null;
  return FirebaseAuth.instance.currentUser?.uid;
});

final goalsRepositoryProvider = Provider<GoalsRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return GoalsRepository(uid: uid);
});

final appRulesProvider = StreamProvider<List<AppRule>>((ref) {
  final repo = ref.watch(goalsRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchRules();
});

final stepServiceProvider = Provider((ref) => StepService());
final appBlockingServiceProvider = Provider((ref) => AppBlockingService());

/// Whether app blocking is switched on; null where the platform doesn't
/// support it yet (iOS until Phase 3).
final blockingEnabledProvider = FutureProvider<bool?>((ref) async {
  try {
    return await ref.watch(appBlockingServiceProvider).hasBlockingPermission();
  } on MissingPluginException {
    return null;
  }
});

/// Today's step count, refreshed on read. In Phase 2+ this should also be
/// pushed to [AppBlockingService.syncLockState] whenever it changes so the
/// native overlay stays in sync without polling Dart.
final todayStepsProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(stepServiceProvider);
  // Only check here: this re-runs on every refresh/resume, and prompting each
  // time would reopen the permission screen right after the user dismissed it.
  if (!await service.hasPermissions()) throw const StepsPermissionDenied();
  return service.getStepsToday();
});

class StepsPermissionDenied implements Exception {
  const StepsPermissionDenied();
}

/// Whether Motify may read app usage time (needed for daily limits); null
/// where the platform doesn't support it.
final usageAccessProvider = FutureProvider<bool?>((ref) async {
  try {
    return await ref.watch(appBlockingServiceProvider).hasUsageAccess();
  } on MissingPluginException {
    return null;
  }
});

/// Minutes used today per app, for the apps that have a daily limit. Empty
/// without usage access. Refreshed by the home screen while it's visible.
final usageTodayProvider = FutureProvider<Map<String, int>>((ref) async {
  final rules = ref.watch(appRulesProvider).valueOrNull ?? const [];
  final appIds = [
    for (final r in rules)
      if (r.dailyLimitMinutes != null) r.appId,
  ];
  if (appIds.isEmpty || await ref.watch(usageAccessProvider.future) != true) return const {};
  return ref.watch(appBlockingServiceProvider).getUsageToday(appIds);
});

/// Rules paired with today's lock decision. Step and usage failures don't
/// block this: unknown steps count as 0 (apps with a step goal stay locked,
/// the safe default) and unknown usage as 0 minutes.
final gateDecisionsProvider = Provider<AsyncValue<List<GateDecisionEntry>>>((ref) {
  final rules = ref.watch(appRulesProvider);
  final stepCount = ref.watch(todayStepsProvider).valueOrNull ?? 0;
  final usage = ref.watch(usageTodayProvider).valueOrNull ?? const {};

  return rules.whenData(
    (rulesList) => [
      for (final rule in rulesList)
        GateDecisionEntry(
          rule: rule,
          decision: evaluateGate(
            rule: rule,
            now: DateTime.now(),
            steps: stepCount,
            usedMinutes: usage[rule.appId] ?? 0,
          ),
        ),
    ],
  );
});

class GateDecisionEntry {
  final AppRule rule;
  final GateDecision decision;
  const GateDecisionEntry({required this.rule, required this.decision});
}
