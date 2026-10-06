package com.motify.motify

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.window.OnBackInvokedDispatcher
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.text.NumberFormat

/**
 * Full-screen "this app is locked" screen shown over a gated app by
 * [BlockingAccessibilityService]. Leaving it always goes to the home screen
 * (never back to the locked app), or into Motify to refresh today's steps.
 *
 * The lock decision may rest on a step count that's up to 15 minutes old
 * (StepSyncWorker), so on showing it re-reads steps — allowed here, since
 * we're in the foreground — and gets out of the way if the goal is now met.
 */
class LockActivity : Activity() {
    companion object {
        private const val EXTRA_PACKAGE = "packageName"
        private const val EXTRA_APP_NAME = "appName"
        private const val EXTRA_STEPS_LEFT = "stepsLeft"

        fun intent(context: Context, lock: BlockingStore.Lock): Intent =
            Intent(context, LockActivity::class.java)
                .putExtra(EXTRA_PACKAGE, lock.packageName)
                .putExtra(EXTRA_APP_NAME, lock.appName)
                .putExtra(EXTRA_STEPS_LEFT, lock.stepsLeft)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
    }

    private val scope = MainScope()
    private lateinit var titleView: TextView
    private lateinit var messageView: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        titleView = TextView(this).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 26f)
            gravity = Gravity.CENTER
        }
        messageView = TextView(this).apply {
            setTextColor(Color.parseColor("#CCFFFFFF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
            gravity = Gravity.CENTER
        }
        val icon = TextView(this).apply {
            text = "🔒"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 64f)
            gravity = Gravity.CENTER
        }
        val checkSteps = Button(this).apply {
            text = "Check my steps in Motify"
            setOnClickListener { openMotify() }
        }
        val goHome = Button(this).apply {
            text = "Go to home screen"
            setOnClickListener { goHome() }
        }

        val padding = dp(32)
        setContentView(LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#121212"))
            setPadding(padding, padding, padding, padding)
            addView(icon)
            addView(titleView, spacedParams(top = dp(16)))
            addView(messageView, spacedParams(top = dp(12)))
            addView(checkSteps, spacedParams(top = dp(40)))
            addView(goHome, spacedParams(top = dp(8)))
        })

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                OnBackInvokedDispatcher.PRIORITY_DEFAULT,
            ) { goHome() }
        }

        bind(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        bind(intent)
    }

    override fun onResume() {
        super.onResume()
        val lockedPackage = intent.getStringExtra(EXTRA_PACKAGE) ?: return
        scope.launch {
            val steps = StepReader.readStepsToday(this@LockActivity) ?: return@launch
            BlockingStore.saveSteps(this@LockActivity, steps)
            val lock = BlockingStore.lockFor(this@LockActivity, lockedPackage)
            if (lock == null) {
                // Goal met since the last sync: drop back into the app underneath.
                finish()
            } else {
                showLock(lock.appName, lock.stepsLeft)
            }
        }
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

    // Pre-Android 13 back handling; newer versions use the callback above.
    @Suppress("OVERRIDE_DEPRECATION")
    override fun onBackPressed() = goHome()

    private fun bind(intent: Intent) = showLock(
        appName = intent.getStringExtra(EXTRA_APP_NAME) ?: "This app",
        stepsLeft = intent.getIntExtra(EXTRA_STEPS_LEFT, 0),
    )

    private fun showLock(appName: String, stepsLeft: Int) {
        titleView.text = "$appName is locked"
        messageView.text =
            "Walk ${NumberFormat.getIntegerInstance().format(stepsLeft)} more steps to unlock it today."
    }

    private fun openMotify() {
        packageManager.getLaunchIntentForPackage(packageName)?.let {
            startActivity(it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
        finish()
    }

    private fun goHome() {
        startActivity(
            Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_HOME)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        finish()
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    private fun spacedParams(top: Int) = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT,
    ).apply { topMargin = top }
}
