import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_status.dart';
import '../../../core/theme/motify_theme.dart';
import '../../../core/widgets/terminal_widgets.dart';
import '../../blocking/services/app_blocking_service.dart';
import '../models/app_rule.dart';
import '../models/free_window.dart';
import 'free_window_sheet.dart';
import '../models/weekday.dart';
import '../providers/goals_providers.dart';
import '../repository/goals_repository.dart';

/// Creates a rule, or edits/deletes [existing] when given.
class GoalEditorScreen extends ConsumerStatefulWidget {
  final AppRule? existing;
  const GoalEditorScreen({super.key, this.existing});

  @override
  ConsumerState<GoalEditorScreen> createState() => _GoalEditorScreenState();
}

class _GoalEditorScreenState extends ConsumerState<GoalEditorScreen> {
  final _appIdController = TextEditingController();
  final _appNameController = TextEditingController();
  final _stepGoalController = TextEditingController(text: '10000');
  final _limitController = TextEditingController(text: '30');
  bool _useStepGoal = true;
  bool _useLimit = false;

  List<InstalledApp>? _installedApps;
  InstalledApp? _selectedApp;
  bool _enabled = true;
  bool _saving = false;
  // New goals start with weekends free, as before; the user can remove it.
  final List<FreeWindow> _freeWindows = [
    const FreeWindow(id: 'weekend', days: {Weekday.saturday, Weekday.sunday}),
  ];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final rule = widget.existing;
    if (rule != null) {
      _selectedApp = InstalledApp(appId: rule.appId, displayName: rule.appDisplayName);
      _appIdController.text = rule.appId;
      _appNameController.text = rule.appDisplayName;
      _useStepGoal = rule.stepGoal != null;
      _useLimit = rule.dailyLimitMinutes != null;
      if (rule.stepGoal != null) _stepGoalController.text = '${rule.stepGoal}';
      if (rule.dailyLimitMinutes != null) _limitController.text = '${rule.dailyLimitMinutes}';
      _enabled = rule.enabled;
      _freeWindows
        ..clear()
        ..addAll(rule.freeWindows);
    }
    _loadInstalledApps();
  }

  @override
  void dispose() {
    _appIdController.dispose();
    _appNameController.dispose();
    _stepGoalController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _loadInstalledApps() async {
    try {
      final apps = await ref.read(appBlockingServiceProvider).getInstalledApps();
      if (!mounted) return;
      setState(() {
        _installedApps = apps;
        // Swap the placeholder for the real entry, so the icon shows too.
        final selected = _selectedApp;
        if (selected != null) {
          _selectedApp = apps.where((a) => a.appId == selected.appId).firstOrNull ?? selected;
        }
      });
    } catch (_) {
      // Native module not implemented yet (Phase 2/3) — fall back to
      // manual app id entry below.
      if (mounted) setState(() => _installedApps = []);
    }
  }

  Future<void> _editFreeWindow([int? index]) async {
    final result = await showFreeWindowSheet(
      context,
      initial: index == null ? null : _freeWindows[index],
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        _freeWindows.add(result);
      } else {
        _freeWindows[index] = result;
      }
    });
  }

  /// Plain-language result of the current switches, shown under them.
  String _conditionsSummary() => switch ((_useStepGoal, _useLimit)) {
    (true, true) => '> locked until you hit your steps, then open for the daily limit',
    (true, false) => '> locked until you hit your steps, then open all day',
    (false, true) => '> open until the daily limit is used up, then locked until midnight',
    (false, false) => '> turn on at least one condition',
  };

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// The repository, or null after telling the user why there isn't one.
  GoalsRepository? _repoOrShowError() {
    final repo = ref.read(goalsRepositoryProvider);
    if (repo == null) {
      final error = firebaseStartupError;
      _showError(
        error == null
            ? 'Not signed in to Firebase, so rules can\'t be saved yet. '
                  'Check that Firebase is configured and Anonymous sign-in is enabled.'
            : 'Can\'t save: ${describeFirebaseStartupError(error)}',
      );
    }
    return repo;
  }

  /// Runs a Firestore write with the saving spinner, then closes the screen.
  /// Firestore can wait indefinitely for the server (e.g. if the database
  /// hasn't been created), so don't let the button hang forever.
  Future<void> _write(Future<void> Function() write, {required String failure}) async {
    setState(() => _saving = true);
    try {
      await write().timeout(const Duration(seconds: 15));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _showError('$failure: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    final repo = _repoOrShowError();
    if (repo == null) return;

    final appId = _selectedApp?.appId ?? _appIdController.text.trim();
    final appName = _selectedApp?.displayName ?? _appNameController.text.trim();
    if (appId.isEmpty || appName.isEmpty) {
      _showError('Pick an app (or fill in both the app id and display name).');
      return;
    }

    final stepGoal = _useStepGoal ? int.tryParse(_stepGoalController.text.trim()) : null;
    final limitMinutes = _useLimit ? int.tryParse(_limitController.text.trim()) : null;
    if (!_useStepGoal && !_useLimit) {
      _showError('Turn on a step goal, a daily time limit, or both.');
      return;
    }
    if (_useStepGoal && (stepGoal == null || stepGoal <= 0)) {
      _showError('Enter how many steps unlock the app.');
      return;
    }
    if (_useLimit && (limitMinutes == null || limitMinutes <= 0 || limitMinutes >= 24 * 60)) {
      _showError('Enter a daily limit in minutes, e.g. 30.');
      return;
    }

    // Rules are keyed by app, so a second rule for the same app would
    // silently replace the first.
    final previous = widget.existing;
    final clash = (ref.read(appRulesProvider).valueOrNull ?? [])
        .where((r) => r.id == appId && r.id != previous?.id)
        .firstOrNull;
    if (clash != null) {
      _showError('${clash.appDisplayName} already has a goal. Edit that one instead.');
      return;
    }

    final rule = AppRule(
      id: appId,
      appId: appId,
      appDisplayName: appName,
      stepGoal: stepGoal,
      dailyLimitMinutes: limitMinutes,
      enabled: _enabled,
      freeWindows: List.of(_freeWindows),
      weeklyBypassAllowance: previous?.weeklyBypassAllowance ?? 0,
    );

    await _write(() async {
      await repo.upsertRule(rule);
      // Picked a different app while editing: the old rule is now replaced.
      if (previous != null && previous.id != rule.id) await repo.deleteRule(previous.id);
    }, failure: 'Couldn\'t save the goal');
  }

  Future<void> _delete() async {
    final rule = widget.existing!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MotifyColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: MotifyColors.danger),
        ),
        title: const Text('DELETE TARGET?', style: TextStyle(color: MotifyColors.danger)),
        content: Text('${rule.appDisplayName} will no longer be locked, whatever your steps.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('KEEP IT'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: MotifyColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repo = _repoOrShowError();
    if (repo == null) return;
    await _write(() => repo.deleteRule(rule.id), failure: 'Couldn\'t delete the goal');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'EDIT TARGET' : 'NEW TARGET'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Delete goal',
              color: MotifyColors.danger,
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isEditing) ...[
            const TerminalLabel('status'),
            SwitchListTile(
              title: const Text('Goal active'),
              subtitle: Text(
                _enabled ? 'The conditions below apply' : 'Paused: app is never locked',
                style: const TextStyle(color: MotifyColors.textDim, fontSize: 12),
              ),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            const SizedBox(height: 16),
          ],
          const TerminalLabel('app_to_lock'),
          const SizedBox(height: 8),
          _buildAppPicker(),
          const SizedBox(height: 24),
          const TerminalLabel('conditions'),
          SwitchListTile(
            title: const Text('Step goal'),
            subtitle: const Text(
              'Locked until you\'ve walked this much today',
              style: TextStyle(color: MotifyColors.textDim, fontSize: 12),
            ),
            value: _useStepGoal,
            onChanged: (v) => setState(() => _useStepGoal = v),
          ),
          if (_useStepGoal)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _stepGoalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Steps to unlock',
                  suffixText: 'steps',
                ),
              ),
            ),
          SwitchListTile(
            title: const Text('Daily time limit'),
            subtitle: const Text(
              'Locks for the rest of the day after this much use',
              style: TextStyle(color: MotifyColors.textDim, fontSize: 12),
            ),
            value: _useLimit,
            onChanged: (v) => setState(() => _useLimit = v),
          ),
          if (_useLimit)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _limitController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Minutes per day', suffixText: 'min'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              _conditionsSummary(),
              style: const TextStyle(color: MotifyColors.neon, fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
          const TerminalLabel('free_time'),
          const SizedBox(height: 4),
          const Text(
            'Times when this app is always unlocked, whatever your goals.',
            style: TextStyle(color: MotifyColors.textDim, fontSize: 12),
          ),
          const SizedBox(height: 8),
          if (_freeWindows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '> none: the goal applies all the time',
                style: TextStyle(color: MotifyColors.textDim),
              ),
            ),
          for (final (i, window) in _freeWindows.indexed)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.schedule, color: MotifyColors.cyan),
                title: Text(describeFreeWindow(window)),
                onTap: () => _editFreeWindow(i),
                trailing: IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _freeWindows.removeAt(i)),
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _editFreeWindow,
            icon: const Icon(Icons.add),
            label: const Text('ADD FREE TIME'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: MotifyColors.onNeon),
                  )
                : Text(_isEditing ? 'SAVE CHANGES' : 'SAVE & LOCK'),
          ),
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
            decoration: const InputDecoration(labelText: 'App id (package name / bundle id)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _appNameController,
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
        ],
      );
    }
    final selected = _selectedApp;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: selected == null ? const Icon(Icons.apps) : _AppIcon(app: selected),
        title: Text(selected?.displayName ?? 'Choose an app'),
        subtitle: selected == null ? null : Text(selected.appId),
        trailing: const Icon(Icons.chevron_right),
        onTap: _pickApp,
      ),
    );
  }

  Future<void> _pickApp() async {
    final picked = await showModalBottomSheet<InstalledApp>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AppPickerSheet(apps: _installedApps!),
    );
    if (picked != null) setState(() => _selectedApp = picked);
  }
}

class _AppPickerSheet extends StatefulWidget {
  final List<InstalledApp> apps;
  const _AppPickerSheet({required this.apps});

  @override
  State<_AppPickerSheet> createState() => _AppPickerSheetState();
}

class _AppPickerSheetState extends State<_AppPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.toLowerCase();
    final matches = widget.apps
        .where(
          (a) =>
              a.displayName.toLowerCase().contains(query) || a.appId.toLowerCase().contains(query),
        )
        .toList();

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search apps',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: matches.length,
              itemBuilder: (context, i) {
                final app = matches[i];
                return ListTile(
                  leading: _AppIcon(app: app),
                  title: Text(app.displayName),
                  subtitle: Text(app.appId),
                  onTap: () => Navigator.of(context).pop(app),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  final InstalledApp app;
  const _AppIcon({required this.app});

  @override
  Widget build(BuildContext context) {
    final icon = app.icon;
    if (icon == null) return const Icon(Icons.android, size: 40);
    return Image.memory(icon, width: 40, height: 40, gaplessPlayback: true);
  }
}
