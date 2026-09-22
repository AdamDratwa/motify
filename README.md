# Motify

Goal-gated social media access. Pick which installed apps stay locked until
you hit a goal (e.g. 10,000 steps), with rules that can turn themselves off
by weekday and time (weekends, after 4pm, etc).

## Stack
- **Flutter** (Dart) — shared UI and business logic (goals, scheduling, streaks)
- **Kotlin** (Android) — `UsageStatsManager` + `AccessibilityService` for foreground-app detection and the blocking overlay; Health Connect for steps
- **Swift** (iOS) — `FamilyControls` / `ManagedSettings` / `DeviceActivity` for blocking; HealthKit for steps
- **Firebase** — Auth, Firestore (rule sync), Cloud Messaging

## Project layout
```
lib/
  core/                    theme, routing
  features/
    goals/
      models/              AppRule, FreeWindow, GateDecision (pure, no Flutter deps)
      repository/          Firestore sync
      providers/           Riverpod wiring
      screens/             goal editor
    blocking/services/     MethodChannel bridge to native blocking module
    steps/services/        wraps the `health` package (HealthKit / Health Connect)
    onboarding/, home/     screens
android/app/src/main/kotlin/.../MainActivity.kt   blocking channel handler (stub, Phase 2)
ios/Runner/AppDelegate.swift                      blocking channel handler (stub, Phase 3)
```

Gating logic lives in `lib/features/goals/models/gate_decision.dart` as a pure
function (`evaluateGate`) so it's independently testable and mirrors what the
native side needs to replicate for instant, offline lock/unlock decisions.

## Roadmap (see full plan in project history)
- **Phase 0 — Setup** *(this scaffold)*: Flutter project, Firebase skeleton, CI.
- **Phase 1 — Shared core**: goal model, scheduling rules, streaks, Firestore sync, onboarding — buildable/testable now via `flutter run` on Android.
- **Phase 2 — Android native module**: real blocking via `AccessibilityService` + Health Connect steps.
- **Phase 3 — iOS native module**: `FamilyControls`/`ManagedSettings`/`HealthKit`, once Apple grants the Family Controls entitlement. Built via Codemagic (see `codemagic.yaml`) since this dev machine is Windows.
- **Phase 4 — Polish**: notifications, additional goal types, bypass/snooze allowance, analytics.

## Setup still needed before running
1. **Firebase project**: create one at console.firebase.google.com, then run
   `flutterfire configure` from this directory to generate
   `lib/firebase_options.dart` and the platform config files
   (`google-services.json`, `GoogleService-Info.plist`). The app runs without
   this (see the try/catch in `main.dart`) but rule sync won't work.
2. **Apple Developer account + Family Controls entitlement**: apply early
   (console.developer.apple.com), Phase 3 is blocked without it.
3. **Codemagic** (or another macOS CI): connect this repo to build/sign the
   iOS target, since local iOS builds aren't possible on Windows.
4. **Android SDK**: install Android Studio or the command-line SDK tools
   locally to build/run the Android target (`flutter doctor` will report
   what's missing).

## Local dev
```
flutter pub get
flutter run              # after installing Android SDK / connecting a device
flutter test
```
