import 'package:flutter/material.dart';

import 'core/theme/motify_theme.dart';
import 'features/onboarding/screens/onboarding_screen.dart';

class MotifyApp extends StatelessWidget {
  const MotifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Motify',
      debugShowCheckedModeBanner: false,
      theme: MotifyTheme.light,
      darkTheme: MotifyTheme.dark,
      home: const OnboardingScreen(),
    );
  }
}
