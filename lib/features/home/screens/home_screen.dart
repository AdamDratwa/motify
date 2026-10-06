import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/motify_theme.dart';
import '../../../core/widgets/motify_logo.dart';
import '../../../core/widgets/terminal_widgets.dart';
import '../../blocking/screens/blocking_setup_screen.dart';
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
    final blockingEnabled = ref.watch(blockingEnabledProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [MotifyLogo(size: 26), SizedBox(width: 10), Text('MOTIFY'), BlinkingCursor()],
        ),
        actions: [
          if (blockingEnabled != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: blockingEnabled
                  ? const StatusTag('● armed', color: MotifyColors.neon)
                  : const StatusTag('○ disarmed', color: MotifyColors.danger),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GoalEditorScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('LOCK APP'),
      ),
      body: GridBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            _refreshSteps();
            await ref.read(todayStepsProvider.future).catchError((_) => 0);
          },
          child: entries.when(
            data: (list) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                if (list.isNotEmpty && blockingEnabled == false) const _BlockingOffBanner(),
                _TodayCard(entries: list, onRetry: _refreshSteps),
                const SizedBox(height: 28),
                if (list.isEmpty)
                  const _EmptyState()
                else ...[
                  TerminalLabel('targets [${list.length}]'),
                  const SizedBox(height: 10),
                  for (final entry in list) _AppRuleCard(entry: entry),
                ],
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  '> error: couldn\'t load your goals\n> $e',
                  style: const TextStyle(color: MotifyColors.danger),
                ),
              ],
            ),
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
    final steps = ref.watch(todayStepsProvider);

    if (steps.hasError && !steps.hasValue) {
      final denied = steps.error is StepsPermissionDenied;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TerminalLabel('steps_today'),
              const SizedBox(height: 12),
              Text(
                denied
                    ? '> access denied: step data\nMotify needs permission to read your steps from Health Connect.'
                    : '> error: step data unavailable\nMake sure Health Connect is installed '
                        'and Motify is allowed to read steps.',
                style: const TextStyle(color: MotifyColors.danger),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  try {
                    if (denied) await ref.read(stepServiceProvider).requestPermissions();
                  } finally {
                    onRetry();
                  }
                },
                child: Text(denied ? 'ALLOW STEP ACCESS' : 'TRY AGAIN'),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: TerminalLabel('steps_today')),
                if (entries.isNotEmpty)
                  Text(
                    '$unlockedCount/${entries.length} unlocked',
                    style: const TextStyle(color: MotifyColors.textDim, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              stepCount == null ? '-----' : _number.format(stepCount),
              style: TextStyle(
                fontSize: 52,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: MotifyColors.neon,
                shadows: MotifyTheme.glow(MotifyColors.neon, blur: 18),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedProgressBar(
              value: stepCount == null ? 0 : (next?.decision.progressFraction ?? 1),
              height: 10,
            ),
            const SizedBox(height: 12),
            if (stepCount != null) _NextUnlockLine(entries: entries, next: next),
          ],
        ),
      ),
    );
  }
}

class _NextUnlockLine extends StatelessWidget {
  final List<GateDecisionEntry> entries;
  final GateDecisionEntry? next;
  const _NextUnlockLine({required this.entries, required this.next});

  @override
  Widget build(BuildContext context) {
    final next = this.next;
    if (entries.isEmpty) {
      return const Text('> add a target to start unlocking apps',
          style: TextStyle(color: MotifyColors.textDim));
    }
    if (next == null) {
      return const Text('> all targets unlocked. access granted.',
          style: TextStyle(color: MotifyColors.neon));
    }
    final left = next.decision.targetValue - next.decision.progressValue;
    final unit = next.rule.goalType.unitLabel(left);
    return Text.rich(
      TextSpan(children: [
        const TextSpan(text: '> '),
        TextSpan(
          text: '${_number.format(left)} $unit',
          style: const TextStyle(color: MotifyColors.neon, fontWeight: FontWeight.w700),
        ),
        const TextSpan(text: ' to unlock '),
        TextSpan(
          text: next.rule.appDisplayName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ]),
    );
  }
}

class _BlockingOffBanner extends StatelessWidget {
  const _BlockingOffBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MotifyColors.danger.withValues(alpha: 0.06),
        border: Border.all(color: MotifyColors.danger.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '⚠ BLOCKER OFFLINE',
            style: TextStyle(
              color: MotifyColors.danger,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              shadows: MotifyTheme.glow(MotifyColors.danger),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your locked apps can still be opened. Switching blocking on takes '
            'about a minute in Android settings, and we\'ll guide you through it.',
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: MotifyColors.danger,
              side: const BorderSide(color: MotifyColors.danger),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BlockingSetupScreen()),
            ),
            child: const Text('SET UP BLOCKING'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('> no targets acquired.', style: TextStyle(color: MotifyColors.textDim)),
            SizedBox(height: 6),
            Text('> tap LOCK APP to pick your first doom-scroll app.',
                style: TextStyle(color: MotifyColors.textDim)),
          ],
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
    final (label, color) = _status(decision.reason);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    rule.appDisplayName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                StatusTag(label, color: color),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedProgressBar(value: decision.progressFraction, color: color),
            const SizedBox(height: 8),
            Text(
              '${_number.format(decision.progressValue)} / '
              '${_number.format(decision.targetValue)} $unit'
              '${decision.reason == GateReason.goalNotMet ? ' · ${_number.format(left)} to go' : ''}',
              style: const TextStyle(color: MotifyColors.textDim, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  (String, Color) _status(GateReason reason) => switch (reason) {
        GateReason.disabledByUser => ('off', MotifyColors.textDim),
        GateReason.freeWindow => ('free time', MotifyColors.cyan),
        GateReason.goalMet => ('open', MotifyColors.neon),
        GateReason.goalNotMet => ('locked', MotifyColors.danger),
      };
}
