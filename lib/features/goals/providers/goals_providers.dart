import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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

/// Today's step count, refreshed on read. In Phase 2+ this should also be
/// pushed to [AppBlockingService.syncLockState] whenever it changes so the
/// native overlay stays in sync without polling Dart.
final todayStepsProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(stepServiceProvider);
  await service.requestPermissions();
  return service.getStepsToday();
});

final gateDecisionsProvider = Provider<AsyncValue<List<GateDecisionEntry>>>((ref) {
  final rules = ref.watch(appRulesProvider);
  final steps = ref.watch(todayStepsProvider);

  return rules.when(
    data: (rulesList) => steps.when(
      data: (stepCount) => AsyncValue.data([
        for (final rule in rulesList)
          GateDecisionEntry(
            rule: rule,
            decision: evaluateGate(
              rule: rule,
              now: DateTime.now(),
              currentProgress: stepCount,
            ),
          ),
      ]),
      loading: () => const AsyncValue.loading(),
      error: (e, st) => AsyncValue.error(e, st),
    ),
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

class GateDecisionEntry {
  final AppRule rule;
  final GateDecision decision;
  const GateDecisionEntry({required this.rule, required this.decision});
}
