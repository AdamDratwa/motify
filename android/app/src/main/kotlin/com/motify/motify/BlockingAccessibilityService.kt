package com.motify.motify

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent

/**
 * Notified by the system whenever a new window comes to the foreground. If it
 * belongs to an app that's currently locked, covers it with [LockActivity].
 *
 * The user enables this in Settings → Accessibility → Motify; Dart checks that
 * via the `hasBlockingPermission` channel method in MainActivity.
 */
class BlockingAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        super.onServiceConnected()
        // Keep steps fresh even if Motify itself isn't opened after a reboot.
        StepSyncWorker.schedule(this)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val foregroundPackage = event.packageName?.toString() ?: return
        if (foregroundPackage == packageName) return

        val lock = BlockingStore.lockFor(this, foregroundPackage) ?: return
        startActivity(LockActivity.intent(this, lock))
    }

    override fun onInterrupt() {}
}
