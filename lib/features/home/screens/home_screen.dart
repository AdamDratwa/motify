import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../goals/models/gate_decision.dart';
import '../../goals/models/goal_type.dart';
import '../../goals/providers/goals_providers.dart';
import '../../goals/screens/goal_editor_screen.dart';

final _number = NumberFormat.decimalPattern();

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Steps keep accumulating while the user is away, and blocking may have
    // been switched on in Settings, so re-check both on return.
    _lifecycle = AppLifecycleListener(onResume: () {
      _refreshSteps();
      ref.invalidate(blockingEnabledProvider);
    });

    // Keep the on-device copy that the native blocker reads up to date.
    ref.listenManual(appRulesProvider, (_, _) => _syncLockState(), fireImmediately: true);
    ref.listenManual(todayStepsProvider, (_, _) => _syncLockState());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _refreshSteps() => ref.invalidate(todayStepsProvider);

  void _syncLockState() {
    final rules = ref.read(appRulesProvider).valueOrNull;
    if (rules == null) return;
    final steps = ref.read(todayStepsProvider).valueOrNull;
    ref
        .read(appBlockingServiceProvider)
        .syncLockState(rules: rules, steps: steps)
        .catchError((Object e) => debugPrint('Couldn\'t sync lock state: $e'));
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(gateDecisionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Motify')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GoalEditorScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshSteps();
          await ref.read(todayStepsProvider.future).catchError((_) => 0);
        },
        child: entries.when(
          data: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              if (list.isNotEmpty && ref.watch(blockingEnabledProvider).valueOrNull == false)
                const _BlockingOffBanner(),
              _TodayCard(entries: list, onRetry: _refreshSteps),
              const SizedBox(height: 24),
              if (list.isEmpty)
                const _EmptyState()
              else ...[
                Text('Your goals', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final entry in list) _AppRuleCard(entry: entry),
              ],
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => ListView(
            padding: const EdgeInsets.all(24),
            children: [Text('Couldn\'t load your goals: $e', textAlign: TextAlign.center)],
          ),
        ),
      ),
    );
  }
}

/// Today's step count and what it takes to unlock the next locked app.
class _TodayCard extends ConsumerWidget {
  final List<GateDecisionEntry> entries;
  final VoidCallback onRetry;
  const _TodayCard({required this.entries, required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final steps = ref.watch(todayStepsProvider);

    if (steps.hasError && !steps.hasValue) {
      final denied = steps.error is StepsPermissionDenied;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Today', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(denied
                  ? 'Motify needs permission to read your steps from Health Connect.'
                  : 'Couldn\'t read your steps. Make sure Health Connect is installed '
                      'and Motify is allowed to read steps.'),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () async {
                  try {
                    if (denied) await ref.read(stepServiceProvider).requestPermissions();
                  } finally {
                    onRetry();
                  }
                },
                child: Text(denied ? 'Allow step access' : 'Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final stepCount = steps.valueOrNull;
    final locked = entries
        .where((e) => e.decision.reason == GateReason.goalNotMet)
        .toList()
      ..sort((a, b) => a.decision.targetValue.compareTo(b.decision.targetValue));
    final next = locked.isEmpty ? null : locked.first;
    final unlockedCount = entries.where((e) => e.decision.unlocked).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 96,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: stepCount == null ? null : (next?.decision.progressFraction ?? 1),
                    strokeWidth: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  const Center(child: Icon(Icons.directions_walk, size: 36)),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Steps today', style: theme.textTheme.labelLarge),
                  Text(
                    stepCount == null ? '…' : _number.format(stepCount),
                    style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  if (stepCount != null) Text(_nextUnlockText(next)),
                  if (entries.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$unlockedCount of ${entries.length} apps unlocked',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _nextUnlockText(GateDecisionEntry? next) {
    if (entries.isEmpty) return 'Add a goal to start unlocking apps.';
    if (next == null) return 'All apps unlocked for now. Nice work!';
    final left = next.decision.targetValue - next.decision.progressValue;
    final unit = next.rule.goalType.unitLabel(left);
    return '${_number.format(left)} $unit to unlock ${next.rule.appDisplayName}';
  }
}

class _BlockingOffBanner extends ConsumerWidget {
  const _BlockingOffBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('App blocking is off', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Locked apps can still be opened. In the next screen, tap '
              '"Motify app blocker" and switch it on.\n\n'
              'If it\'s greyed out ("Restricted setting"): open Settings → Apps → '
              'Motify, tap ⋮ in the top corner, choose "Allow restricted '
              'settings", then try again.',
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.read(appBlockingServiceProvider).requestBlockingPermission(),
              child: const Text('Turn on blocking'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No gated apps yet.\nTap + to pick an app and set a goal to unlock it.',
          textAlign: TextAlign.center,
        ),
      );
}

class _AppRuleCard extends StatelessWidget {
  final GateDecisionEntry entry;
  const _AppRuleCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final rule = entry.rule;
    final decision = entry.decision;
    final unit = rule.goalType.unitLabel(decision.targetValue);
    final left = decision.targetValue - decision.progressValue;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          decision.unlocked ? Icons.lock_open : Icons.lock_outline,
          color: decision.unlocked ? Colors.green : Colors.redAccent,
        ),
        title: Text(rule.appDisplayName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_number.format(decision.progressValue)} / '
              '${_number.format(decision.targetValue)} $unit'
              '${decision.reason == GateReason.goalNotMet ? ' · ${_number.format(left)} to go' : ''}',
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: decision.progressFraction),
            ),
          ],
        ),
        trailing: Text(_reasonLabel(decision.reason)),
      ),
    );
  }

  String _reasonLabel(GateReason reason) => switch (reason) {
        GateReason.disabledByUser => 'Off',
        GateReason.freeWindow => 'Free time',
        GateReason.goalMet => 'Unlocked',
        GateReason.goalNotMet => 'Locked',
      };
}
