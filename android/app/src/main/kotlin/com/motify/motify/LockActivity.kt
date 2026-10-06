package com.motify.motify

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
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

        // Same palette as MotifyColors in lib/core/theme/motify_theme.dart.
        private const val BACKGROUND = 0xFF05080A.toInt()
        private const val NEON = 0xFF00FF9C.toInt()
        private const val ON_NEON = 0xFF00170D.toInt()
        private const val DANGER = 0xFFFF2E63.toInt()
        private const val TEXT = 0xFFD5FBEA.toInt()
        private const val TEXT_DIM = 0xFF6E9487.toInt()
        private const val LINE = 0xFF1C3A31.toInt()

        fun intent(context: Context, lock: BlockingStore.Lock): Intent =
            Intent(context, LockActivity::class.java)
                .putExtra(EXTRA_PACKAGE, lock.packageName)
                .putExtra(EXTRA_APP_NAME, lock.appName)
                .putExtra(EXTRA_STEPS_LEFT, lock.stepsLeft)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
    }

    private val scope = MainScope()
    private lateinit var targetView: TextView
    private lateinit var stepsView: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val title = terminalText("ACCESS DENIED", DANGER, 34f, bold = true).apply {
            // Neon glow, matching MotifyTheme.glow on the Flutter side.
            setShadowLayer(dp(10).toFloat(), 0f, 0f, DANGER)
        }
        val subtitle = terminalText("// motify blocker", TEXT_DIM, 13f)
        targetView = terminalText("", TEXT, 16f)
        stepsView = terminalText("", NEON, 16f, bold = true).apply {
            setShadowLayer(dp(6).toFloat(), 0f, 0f, NEON)
        }
        val checkSteps = terminalButton("CHECK MY STEPS", filled = true) { openMotify() }
        val goHome = terminalButton("GO TO HOME SCREEN", filled = false) { goHome() }

        val padding = dp(28)
        setContentView(LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundColor(BACKGROUND)
            setPadding(padding, padding, padding, padding)
            addView(title)
            addView(subtitle, spacedParams(top = dp(4)))
            addView(targetView, spacedParams(top = dp(32)))
            addView(stepsView, spacedParams(top = dp(8)))
            addView(checkSteps, spacedParams(top = dp(48)))
            addView(goHome, spacedParams(top = dp(12)))
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
        targetView.text = "> target: $appName\n> status: locked"
        stepsView.text = "> ${NumberFormat.getIntegerInstance().format(stepsLeft)} steps until unlock"
    }

    private fun terminalText(text: String, color: Int, sizeSp: Float, bold: Boolean = false) =
        TextView(this).apply {
            this.text = text
            setTextColor(color)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
            typeface = font(bold)
            setLineSpacing(0f, 1.25f)
        }

    private fun terminalButton(label: String, filled: Boolean, onClick: () -> Unit) =
        Button(this).apply {
            text = label
            isAllCaps = false
            stateListAnimator = null // no Material elevation shadow
            typeface = font(bold = true)
            letterSpacing = 0.1f
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            setTextColor(if (filled) ON_NEON else TEXT_DIM)
            setPadding(dp(16), dp(16), dp(16), dp(16))
            background = GradientDrawable().apply {
                cornerRadius = dp(4).toFloat()
                if (filled) setColor(NEON) else setStroke(dp(1), LINE)
            }
            setOnClickListener { onClick() }
        }

    /**
     * JetBrains Mono, bundled with the Flutter assets inside the APK so the
     * lock screen matches the app; falls back to the system monospace font.
     */
    private fun font(bold: Boolean): Typeface = try {
        val file = if (bold) "JetBrainsMono-ExtraBold.ttf" else "JetBrainsMono-Regular.ttf"
        Typeface.createFromAsset(assets, "flutter_assets/assets/fonts/$file")
    } catch (e: Exception) {
        Typeface.create(Typeface.MONOSPACE, if (bold) Typeface.BOLD else Typeface.NORMAL)
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
