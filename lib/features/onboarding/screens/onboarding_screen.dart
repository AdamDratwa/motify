import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../goals/providers/goals_providers.dart';
import '../../home/screens/home_screen.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  Future<void> _requestPermissionsAndContinue(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await ref.read(stepServiceProvider).requestPermissions();
    try {
      final hasPermission =
          await ref.read(appBlockingServiceProvider).hasBlockingPermission();
      if (!hasPermission) {
        await ref.read(appBlockingServiceProvider).requestBlockingPermission();
      }
    } catch (_) {
      // Native blocking module isn't implemented yet (Phase 2/3 of the
      // roadmap) — step tracking and goal editing still work without it.
    }
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_clock, size: 72),
              const SizedBox(height: 24),
              Text(
                'Earn your scroll time',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Motify keeps the apps you pick locked until you hit a '
                'goal you set, like 10,000 steps. You choose which apps, '
                'the goal, and when the rule takes a break.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => _requestPermissionsAndContinue(context, ref),
                child: const Text('Get started'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
