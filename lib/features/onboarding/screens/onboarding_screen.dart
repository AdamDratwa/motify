import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/motify_theme.dart';
import '../../../core/widgets/motify_logo.dart';
import '../../../core/widgets/terminal_widgets.dart';
import '../../goals/providers/goals_providers.dart';
import '../../home/screens/home_screen.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  Future<void> _requestPermissionsAndContinue(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await ref.read(stepServiceProvider).requestPermissions();
    // Blocking is switched on from the home screen's banner instead, which
    // explains the Accessibility settings step before sending the user there.
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const headline = TextStyle(
      fontSize: 44,
      height: 1.05,
      fontWeight: FontWeight.w800,
      color: MotifyColors.neon,
    );

    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    MotifyLogo(size: 28),
                    SizedBox(width: 10),
                    Text(
                      'motify v1.0 // habit override',
                      style: TextStyle(color: MotifyColors.textDim, fontSize: 12, letterSpacing: 1.5),
                    ),
                  ],
                ),
                const Spacer(),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'HACK\nYOUR\nHABITS'),
                      WidgetSpan(
                        child: BlinkingCursor(
                          style: headline.copyWith(shadows: MotifyTheme.glow(MotifyColors.neon)),
                        ),
                      ),
                    ],
                  ),
                  style: headline.copyWith(shadows: MotifyTheme.glow(MotifyColors.neon)),
                ),
                const SizedBox(height: 32),
                const _TerminalLog(lines: [
                  ('> scanning habits...', MotifyColors.textDim),
                  ('> threat detected: doom_scrolling', MotifyColors.danger),
                  ('> countermeasure: lock apps until goal met', MotifyColors.text),
                  ('> unlock key: your daily steps', MotifyColors.text),
                  ('> ready.', MotifyColors.neon),
                ]),
                const Spacer(),
                FilledButton(
                  onPressed: () => _requestPermissionsAndContinue(context, ref),
                  child: const Text('> INITIALIZE'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Next: allow Motify to read your steps from Health Connect.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: MotifyColors.textDim, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lines that type themselves out one character at a time.
class _TerminalLog extends StatefulWidget {
  final List<(String, Color)> lines;
  const _TerminalLog({required this.lines});

  @override
  State<_TerminalLog> createState() => _TerminalLogState();
}

class _TerminalLogState extends State<_TerminalLog> with SingleTickerProviderStateMixin {
  late final int _totalChars = widget.lines.fold(0, (sum, line) => sum + line.$1.length);
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _totalChars * 22),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          var typed = (_controller.value * _totalChars).round();
          final rows = <Widget>[];
          for (final (text, color) in widget.lines) {
            final shown = typed.clamp(0, text.length);
            typed -= text.length;
            rows.add(Padding(
              padding: const EdgeInsets.only(bottom: 6),
              // Reserve each line's space up front so the layout doesn't
              // jump while typing; untyped text is just transparent.
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: text.substring(0, shown)),
                  TextSpan(
                    text: text.substring(shown),
                    style: const TextStyle(color: Colors.transparent),
                  ),
                ]),
                style: TextStyle(color: color, fontSize: 13),
              ),
            ));
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
        },
      );
}
