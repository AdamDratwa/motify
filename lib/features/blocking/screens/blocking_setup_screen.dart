import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/motify_theme.dart';
import '../../goals/providers/goals_providers.dart';

/// Walks the user through switching on Motify's accessibility service,
/// including Android's "restricted setting" hurdle for apps installed from
/// a file rather than the Play Store. Re-checks whenever the user returns
/// from system settings, and confirms once blocking is on.
class BlockingSetupScreen extends ConsumerStatefulWidget {
  const BlockingSetupScreen({super.key});

  @override
  ConsumerState<BlockingSetupScreen> createState() => _BlockingSetupScreenState();
}

class _BlockingSetupScreenState extends ConsumerState<BlockingSetupScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(blockingEnabledProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = ref.watch(blockingEnabledProvider).valueOrNull == true;
    final service = ref.read(appBlockingServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ARM THE BLOCKER')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (enabled) ...[
            Card(
              color: theme.colorScheme.primaryContainer,
              child: const ListTile(
                leading: Icon(Icons.check_circle, size: 32),
                title: Text('App blocking is on'),
                subtitle: Text('Locked apps now show a lock screen until you reach your goal.'),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('DONE'),
            ),
          ] else ...[
            const Text(
              'Android only lets Motify see which app you open after you switch on '
              '"Motify app blocker" in Accessibility settings. Motify only sees app '
              'names, never what\'s on your screen or what you type.',
            ),
            const SizedBox(height: 24),
            _Step(
              number: 1,
              title: 'Switch on "Motify app blocker"',
              body: 'Tap the button below, turn on the switch for "Motify app blocker" '
                  '(sometimes shown as "motify") and tap Allow.\n\n'
                  'If you land on a list instead, look for Motify under:\n'
                  '• Samsung: Installed apps\n'
                  '• Oppo, OnePlus, Realme, Pixel, Xiaomi: Downloaded apps\n'
                  '• Some phones: Installed services\n'
                  'Or search Settings for "Motify".',
              action: FilledButton(
                onPressed: service.requestBlockingPermission,
                child: const Text('OPEN BLOCKER SETTING'),
              ),
            ),
            _Step(
              number: 2,
              title: 'Switch greyed out or "Restricted setting"?',
              body: 'Android blocks this switch for apps installed from a file '
                  'instead of the Play Store. To allow it:\n'
                  '1. Tap OK on the "Restricted setting" message. Android 15+ only '
                  'offers step 3 after you have tried step 1 once.\n'
                  '2. Tap the button below to open Motify\'s App info.\n'
                  '3. Tap ⋮ in the top-right corner and choose '
                  '"Allow restricted settings", then confirm with your PIN or fingerprint.\n'
                  '4. Go back to step 1 and switch the blocker on.',
              action: OutlinedButton(
                onPressed: service.openAppInfo,
                child: const Text('OPEN MOTIFY APP INFO'),
              ),
            ),
            _Step(
              number: 3,
              title: 'Let Motify keep running',
              body: 'Some phones (Oppo, OnePlus, Realme, Xiaomi, Huawei) switch the '
                  'blocker off when they close background apps to save battery. In '
                  'Motify\'s App info, open Battery usage (or Battery) and allow '
                  'background activity and auto launch, or choose "Unrestricted".',
              action: OutlinedButton(
                onPressed: service.openAppInfo,
                child: const Text('OPEN MOTIFY APP INFO'),
              ),
            ),
            const _Step(
              number: 4,
              title: 'Come back here',
              body: 'This screen checks automatically and confirms once blocking is on.',
            ),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String title;
  final String body;
  final Widget? action;

  const _Step({required this.number, required this.title, required this.body, this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: MotifyColors.neon,
            foregroundColor: MotifyColors.onNeon,
            child: Text('$number', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(body),
                if (action != null) ...[const SizedBox(height: 12), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
