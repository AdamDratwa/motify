import 'dart:convert';

import 'package:flutter/services.dart';

import '../../goals/models/app_rule.dart';
import '../../goals/models/gate_decision.dart';

class InstalledApp {
  final String appId; // Android package name / iOS bundle id (or token)
  final String displayName;
  final Uint8List? icon; // PNG bytes, when the platform provides one

  InstalledApp({required this.appId, required this.displayName, this.icon});

  factory InstalledApp.fromMap(Map<dynamic, dynamic> map) => InstalledApp(
        appId: map['appId'] as String,
        displayName: map['displayName'] as String,
        icon: map['icon'] as Uint8List?,
      );
}

/// Bridge to the native blocking module:
/// - Android: BlockingAccessibilityService + LockActivity, deciding from
///   rules/steps stored by BlockingStore (android/app/src/main/kotlin/com/motify/motify/)
/// - iOS: FamilyControls / ManagedSettings / DeviceActivity
///   (ios/Runner/BlockingModule.swift)
///
/// Implemented on Android. iOS is a stub until Phase 3 of the roadmap and
/// throws MissingPluginException.
class AppBlockingService {
  static const _channel = MethodChannel('com.motify.app/blocking');

  Future<List<InstalledApp>> getInstalledApps() async {
    final result = await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
    return (result ?? [])
        .map((e) => InstalledApp.fromMap(e as Map<dynamic, dynamic>))
        .toList();
  }

  /// Whether the OS-level permission needed to detect/block app launches
  /// has been granted (the Motify accessibility service on Android; Family
  /// Controls authorization on iOS).
  Future<bool> hasBlockingPermission() async {
    final result = await _channel.invokeMethod<bool>('hasBlockingPermission');
    return result ?? false;
  }

  /// Opens the relevant system settings screen / Apple's authorization
  /// prompt so the user can grant the permission above.
  Future<void> requestBlockingPermission() =>
      _channel.invokeMethod('requestBlockingPermission');

  /// Stores the rules and today's step count on-device, so the native side
  /// can decide instantly and offline whether to lock an app when it comes
  /// to the foreground (mirroring [evaluateGate]). Pass a null [steps] when
  /// they couldn't be read, to keep the last count synced today.
  Future<void> syncLockState({required List<AppRule> rules, int? steps}) =>
      _channel.invokeMethod('syncLockState', {
        'rules': jsonEncode([for (final rule in rules) rule.toJson()]),
        'steps': steps,
      });
}
