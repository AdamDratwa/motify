import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../goals/models/gate_decision.dart';
import '../../goals/models/goal_type.dart';
import '../../goals/providers/goals_providers.dart';
import '../../goals/screens/goal_editor_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(gateDecisionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Motify')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GoalEditorScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: entries.when(
        data: (list) => list.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (context, i) => _AppRuleCard(entry: list[i]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Something went wrong: $e')),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No gated apps yet.\nTap + to pick an app and set a goal to unlock it.',
            textAlign: TextAlign.center,
          ),
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
            Text('${rule.goalType.label}: ${decision.progressValue}/${decision.targetValue}'),
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
