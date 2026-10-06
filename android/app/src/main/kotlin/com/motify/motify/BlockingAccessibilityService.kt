package com.motify.motify

import android.accessibilityservice.AccessibilityService
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent

/**
 * Notified by the system whenever a new window comes to the foreground. If it
 * belongs to an app that's currently locked, covers it with [LockActivity].
 *
 * Apps with a daily time limit are open when they come to the front, so for
 * those a timer re-checks the moment the remaining time runs out — otherwise
 * the user could keep scrolling past the limit as long as they never left.
 *
 * The user enables this in Settings → Accessibility → Motify; Dart checks that
 * via the `hasBlockingPermission` channel method in MainActivity.
 */
class BlockingAccessibilityService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private var watchedPackage: String? = null
    private val limitCheck = Runnable { watchedPackage?.let(::onLimitTimer) }

    override fun onServiceConnected() {
        super.onServiceConnected()
        // Keep steps fresh even if Motify itself isn't opened after a reboot.
        StepSyncWorker.schedule(this)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val foregroundPackage = event.packageName?.toString() ?: return
        if (foregroundPackage == packageName) return

        when (val decision = BlockingStore.evaluate(this, foregroundPackage)) {
            is BlockingStore.Decision.Locked -> lock(decision.lock)
            is BlockingStore.Decision.Open -> decision.millisUntilLimit?.let { watch(foregroundPackage, it) }
            // Don't stop a running timer here: this may be a keyboard,
            // notification shade or dialog on top of the watched app. The
            // timer itself checks whether that app is still in front.
            BlockingStore.Decision.NotGated -> Unit
        }
    }

    private fun onLimitTimer(watched: String) {
        when (val decision = BlockingStore.evaluate(this, watched)) {
            // Only cover it if the user is still in it; otherwise the next
            // time it comes to the front is soon enough.
            is BlockingStore.Decision.Locked -> if (decision.inForeground) lock(decision.lock) else stopWatching()
            is BlockingStore.Decision.Open ->
                if (decision.inForeground && decision.millisUntilLimit != null) {
                    watch(watched, decision.millisUntilLimit)
                } else {
                    stopWatching()
                }
            BlockingStore.Decision.NotGated -> stopWatching()
        }
    }

    private fun watch(pkg: String, millisUntilLimit: Long) {
        handler.removeCallbacks(limitCheck)
        watchedPackage = pkg
        // A second's slack so usage events have caught up when we re-check.
        handler.postDelayed(limitCheck, millisUntilLimit.coerceAtLeast(0) + 1_000)
    }

    private fun stopWatching() {
        handler.removeCallbacks(limitCheck)
        watchedPackage = null
    }

    private fun lock(lock: BlockingStore.Lock) {
        stopWatching()
        startActivity(LockActivity.intent(this, lock))
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        stopWatching()
        super.onDestroy()
    }
}
