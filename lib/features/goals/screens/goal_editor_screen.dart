import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../blocking/services/app_blocking_service.dart';
import '../models/app_rule.dart';
import '../models/free_window.dart';
import '../models/goal_type.dart';
import '../models/simple_time.dart';
import '../models/weekday.dart';
import '../providers/goals_providers.dart';

class GoalEditorScreen extends ConsumerStatefulWidget {
  const GoalEditorScreen({super.key});

  @override
  ConsumerState<GoalEditorScreen> createState() => _GoalEditorScreenState();
}

class _GoalEditorScreenState extends ConsumerState<GoalEditorScreen> {
  final _appIdController = TextEditingController();
  final _appNameController = TextEditingController();
  final _targetController = TextEditingController(text: '10000');

  List<InstalledApp>? _installedApps;
  InstalledApp? _selectedApp;
  bool _weekendsFree = true;
  bool _freeAfter4pm = false;
  final List<FreeWindow> _customWindows = [];

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
  }

  Future<void> _loadInstalledApps() async {
    try {
      final apps = await ref.read(appBlockingServiceProvider).getInstalledApps();
      if (mounted) setState(() => _installedApps = apps);
    } catch (_) {
      // Native module not implemented yet (Phase 2/3) — fall back to
      // manual app id entry below.
      if (mounted) setState(() => _installedApps = []);
    }
  }

  List<FreeWindow> _buildFreeWindows() {
    final windows = <FreeWindow>[];
    if (_weekendsFree) {
      windows.add(FreeWindow(
        id: 'weekend',
        days: {Weekday.saturday, Weekday.sunday},
      ));
    }
    if (_freeAfter4pm) {
      windows.add(FreeWindow(
        id: 'after-4pm',
        days: Weekday.values.toSet(),
        startTime: const SimpleTime(16, 0),
      ));
    }
    windows.addAll(_customWindows);
    return windows;
  }

  Future<void> _save() async {
    final repo = ref.read(goalsRepositoryProvider);
    if (repo == null) return;

    final appId = _selectedApp?.appId ?? _appIdController.text.trim();
    final appName = _selectedApp?.displayName ?? _appNameController.text.trim();
    final target = int.tryParse(_targetController.text) ?? 10000;
    if (appId.isEmpty || appName.isEmpty) return;

    final rule = AppRule(
      id: appId,
      appId: appId,
      appDisplayName: appName,
      goalType: GoalType.steps,
      targetValue: target,
      freeWindows: _buildFreeWindows(),
    );

    await repo.upsertRule(rule);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gate an app')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('App', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _buildAppPicker(),
          const SizedBox(height: 24),
          Text('Goal', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _targetController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Steps required to unlock',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text('When is this off?', style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile(
            title: const Text('Free on weekends'),
            value: _weekendsFree,
            onChanged: (v) => setState(() => _weekendsFree = v),
          ),
          SwitchListTile(
            title: const Text('Free every day after 4:00 PM'),
            value: _freeAfter4pm,
            onChanged: (v) => setState(() => _freeAfter4pm = v),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }

  Widget _buildAppPicker() {
    if (_installedApps == null) {
      return const LinearProgressIndicator();
    }
    if (_installedApps!.isEmpty) {
      // No native app-list support yet — manual entry fallback.
      return Column(
        children: [
          TextField(
            controller: _appIdController,
            decoration: const InputDecoration(
              labelText: 'App id (package name / bundle id)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _appNameController,
            decoration: const InputDecoration(
              labelText: 'Display name',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      );
    }
    return DropdownButtonFormField<InstalledApp>(
      initialValue: _selectedApp,
      items: _installedApps!
          .map((a) => DropdownMenuItem(value: a, child: Text(a.displayName)))
          .toList(),
      onChanged: (v) => setState(() => _selectedApp = v),
      decoration: const InputDecoration(border: OutlineInputBorder()),
    );
  }
}
