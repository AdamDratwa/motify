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
  bool _saving = false;
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final repo = ref.read(goalsRepositoryProvider);
    if (repo == null) {
      _showError('Not signed in to Firebase, so rules can\'t be saved yet. '
          'Check that Firebase is configured and Anonymous sign-in is enabled.');
      return;
    }

    final appId = _selectedApp?.appId ?? _appIdController.text.trim();
    final appName = _selectedApp?.displayName ?? _appNameController.text.trim();
    final target = int.tryParse(_targetController.text) ?? 10000;
    if (appId.isEmpty || appName.isEmpty) {
      _showError('Pick an app (or fill in both the app id and display name).');
      return;
    }

    final rule = AppRule(
      id: appId,
      appId: appId,
      appDisplayName: appName,
      goalType: GoalType.steps,
      targetValue: target,
      freeWindows: _buildFreeWindows(),
    );

    setState(() => _saving = true);
    try {
      // Firestore can wait indefinitely for the server (e.g. if the database
      // hasn't been created), so don't let the button hang forever.
      await repo.upsertRule(rule).timeout(const Duration(seconds: 15));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _showError('Couldn\'t save the rule: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
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
        .where((a) =>
            a.displayName.toLowerCase().contains(query) || a.appId.toLowerCase().contains(query))
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
                border: OutlineInputBorder(),
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
