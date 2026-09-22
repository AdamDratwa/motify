import 'package:flutter/services.dart';

class InstalledApp {
  final String appId; // Android package name / iOS bundle id (or token)
  final String displayName;

  InstalledApp({required this.appId, required this.displayName});

  factory InstalledApp.fromMap(Map<dynamic, dynamic> map) => InstalledApp(
        appId: map['appId'] as String,
        displayName: map['displayName'] as String,
      );
}

/// Bridge to the native blocking module:
/// - Android: UsageStatsManager + AccessibilityService overlay
///   (android/app/src/main/kotlin/.../BlockingAccessibilityService.kt)
/// - iOS: FamilyControls / ManagedSettings / DeviceActivity
///   (ios/Runner/BlockingModule.swift)
///
/// Both are unimplemented stubs until Phase 2 (Android) / Phase 3 (iOS) of
/// the roadmap; calls currently throw PlatformException("unimplemented").
class AppBlockingService {
  static const _channel = MethodChannel('com.motify.app/blocking');

  Future<List<InstalledApp>> getInstalledApps() async {
    final result = await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
    return (result ?? [])
        .map((e) => InstalledApp.fromMap(e as Map<dynamic, dynamic>))
        .toList();
  }

  /// Whether the OS-level permission needed to detect/block app launches
  /// has been granted (Usage Access + Accessibility on Android; Family
  /// Controls authorization on iOS).
  Future<bool> hasBlockingPermission() async {
    final result = await _channel.invokeMethod<bool>('hasBlockingPermission');
    return result ?? false;
  }

  /// Opens the relevant system settings screen / Apple's authorization
  /// prompt so the user can grant the permission above.
  Future<void> requestBlockingPermission() =>
      _channel.invokeMethod('requestBlockingPermission');

  /// Pushes the current unlocked/locked state per app so the native side
  /// can decide instantly, without a network round-trip, whether to show
  /// the blocking overlay when it detects that app coming to the foreground.
  Future<void> syncLockState(Map<String, bool> appIdToUnlocked) =>
      _channel.invokeMethod('syncLockState', appIdToUnlocked);
}
