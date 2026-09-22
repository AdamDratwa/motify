package com.motify.motify

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val BLOCKING_CHANNEL = "com.motify.app/blocking"

/**
 * Phase 2 (see project README roadmap) wires this channel up to:
 *  - UsageStatsManager, to detect the foreground app
 *  - BlockingAccessibilityService, to show the lock overlay
 *  - Health Connect, for step data (currently read from Dart via the
 *    `health` package directly, so no bridging needed there)
 *
 * Until then every method just reports as not implemented so the Dart
 * side's fallback UI (manual app-id entry, "permission unavailable"
 * messaging) kicks in instead of the app crashing.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BLOCKING_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // TODO(phase-2): getInstalledApps -> PackageManager.getInstalledApplications
                    // TODO(phase-2): hasBlockingPermission -> check Usage Access + Accessibility settings
                    // TODO(phase-2): requestBlockingPermission -> launch Settings.ACTION_USAGE_ACCESS_SETTINGS
                    // TODO(phase-2): syncLockState -> persist to SharedPreferences read by BlockingAccessibilityService
                    else -> result.notImplemented()
                }
            }
    }
}
