import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/firebase_status.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // No firebase_options.dart exists until `flutterfire configure` is run
  // against a real Firebase project (see README). Keep the app usable
  // without it during early local development.
  try {
    await Firebase.initializeApp();
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (e) {
    debugPrint('Firebase not configured yet: $e');
    firebaseStartupError = e;
  }

  runApp(const ProviderScope(child: MotifyApp()));
}
