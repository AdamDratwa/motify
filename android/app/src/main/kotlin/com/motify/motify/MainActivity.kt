package com.motify.motify

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

private const val BLOCKING_CHANNEL = "com.motify.app/blocking"
private const val ICON_SIZE_PX = 96

/**
 * Hosts the blocking channel used by lib/features/blocking/services/app_blocking_service.dart:
 *  - getInstalledApps: launchable apps for the "which app to gate" picker
 *  - hasBlockingPermission / requestBlockingPermission: whether
 *    BlockingAccessibilityService is switched on, and the settings screen to do so
 *  - syncLockState: stores rules + today's steps in [BlockingStore], which the
 *    accessibility service reads to decide whether to show [LockActivity]
 *
 * Step data is read from Dart via the `health` package, so it needs no bridging.
 *
 * Extends FlutterFragmentActivity (not FlutterActivity) because the `health`
 * plugin needs it to launch the Health Connect permission screen.
 */
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        StepSyncWorker.schedule(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BLOCKING_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Loading labels and icons for every app takes a moment,
                    // so keep it off the UI thread.
                    "getInstalledApps" -> Thread {
                        try {
                            val apps = getLaunchableApps()
                            runOnUiThread { result.success(apps) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("installed_apps_failed", e.message, null) }
                        }
                    }.start()
                    "hasBlockingPermission" -> result.success(isBlockingServiceEnabled())
                    "requestBlockingPermission" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }
                    "syncLockState" -> {
                        val rulesJson = call.argument<String>("rules")
                        if (rulesJson == null) {
                            result.error("bad_args", "rules is required", null)
                        } else {
                            BlockingStore.save(this, rulesJson, call.argument<Number>("steps")?.toInt())
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isBlockingServiceEnabled(): Boolean {
        val expected = ComponentName(this, BlockingAccessibilityService::class.java)
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        return enabled.split(':').any { ComponentName.unflattenFromString(it) == expected }
    }

    /**
     * Apps that show up in the launcher — i.e. the ones a user could open and
     * we'd want to gate. Visible thanks to the MAIN/LAUNCHER <queries> entry
     * in AndroidManifest.xml, so QUERY_ALL_PACKAGES isn't needed.
     */
    private fun getLaunchableApps(): List<Map<String, Any>> {
        val pm = packageManager
        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val activities = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(launcherIntent, PackageManager.ResolveInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(launcherIntent, 0)
        }

        return activities
            .map { it.activityInfo.applicationInfo }
            .filter { it.packageName != packageName }
            .distinctBy { it.packageName }
            .map { info ->
                mapOf(
                    "appId" to info.packageName,
                    "displayName" to pm.getApplicationLabel(info).toString(),
                    "icon" to pm.getApplicationIcon(info).toPngBytes(),
                )
            }
            .sortedBy { (it["displayName"] as String).lowercase() }
    }

    private fun Drawable.toPngBytes(): ByteArray {
        val bitmap = Bitmap.createBitmap(ICON_SIZE_PX, ICON_SIZE_PX, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        setBounds(0, 0, ICON_SIZE_PX, ICON_SIZE_PX)
        draw(canvas)
        return ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            bitmap.recycle()
            out.toByteArray()
        }
    }
}
