package com.motify.motify

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * The gating rules and today's step count, as last synced from Dart
 * (AppBlockingService.syncLockState), stored on-device so the blocking
 * service can decide instantly and offline whether an app is locked.
 *
 * [evaluate] mirrors `evaluateGate` in lib/features/goals/models/gate_decision.dart
 * — keep the two in sync. Free windows are evaluated here against the current
 * time, so e.g. "free after 4pm" kicks in without Motify being opened.
 */
object BlockingStore {
    private const val PREFS = "motify_blocking"
    private const val KEY_RULES = "rules"
    private const val KEY_STEPS = "steps"
    private const val KEY_STEPS_DATE = "stepsDate"

    enum class LockReason { STEPS_NOT_MET, TIME_LIMIT_REACHED }

    data class Lock(
        val packageName: String,
        val appName: String,
        val reason: LockReason,
        val stepsLeft: Int,
        val limitMinutes: Int,
    )

    sealed interface Decision {
        /** No (active) rule for this app. */
        data object NotGated : Decision

        /**
         * Open right now. [millisUntilLimit] is how much daily time is left
         * when the rule has a limit (null otherwise), so the blocker can
         * re-check the moment it runs out; [inForeground] is from usage events.
         */
        data class Open(val millisUntilLimit: Long?, val inForeground: Boolean) : Decision

        data class Locked(val lock: Lock, val inForeground: Boolean) : Decision
    }

    fun save(context: Context, rulesJson: String, steps: Int?) {
        prefs(context).edit().putString(KEY_RULES, rulesJson).apply()
        if (steps != null) saveSteps(context, steps)
    }

    /**
     * Records today's step count. Steps only go up during a day, so a lower
     * reading from another source (Dart vs. StepReader) never re-locks an app.
     */
    @Synchronized
    fun saveSteps(context: Context, steps: Int) {
        val prefs = prefs(context)
        val today = LocalDate.now().toString()
        val current = if (prefs.getString(KEY_STEPS_DATE, null) == today) prefs.getInt(KEY_STEPS, 0) else 0
        prefs.edit()
            .putInt(KEY_STEPS, maxOf(current, steps))
            .putString(KEY_STEPS_DATE, today)
            .apply()
    }

    /** Whether [packageName] is locked right now; see [Decision]. */
    fun evaluate(context: Context, packageName: String): Decision {
        val prefs = prefs(context)
        val rules = JSONArray(prefs.getString(KEY_RULES, null) ?: return Decision.NotGated)
        val rule = (0 until rules.length())
            .map { rules.getJSONObject(it) }
            .firstOrNull { it.optString("appId") == packageName }
            ?: return Decision.NotGated

        if (!rule.optBoolean("enabled", true)) return Decision.NotGated

        val now = LocalDateTime.now()
        if (isInFreeWindow(rule.optJSONArray("freeWindows"), now)) return Decision.NotGated

        val appName = rule.optString("appDisplayName", packageName)
        // Rules saved before time limits existed only have targetValue.
        val limitMinutes = rule.optIntOrNull("dailyLimitMinutes")
        val stepGoal = rule.optIntOrNull("stepGoal")
            ?: if (limitMinutes == null) rule.optInt("targetValue", 10000) else null

        // Without usage access the limit can't be measured, so it isn't enforced.
        val usage = if (limitMinutes != null) {
            UsageTracker.usageToday(context, setOf(packageName))[packageName]
        } else {
            null
        }
        val inForeground = usage?.inForeground ?: false
        val millisUntilLimit = if (limitMinutes != null && usage != null) {
            limitMinutes * 60_000L - usage.millisToday
        } else {
            null
        }

        // Same order as Dart's evaluateGate: the time limit first, since
        // walking can't lift it today.
        if (millisUntilLimit != null && millisUntilLimit <= 0) {
            val lock = Lock(packageName, appName, LockReason.TIME_LIMIT_REACHED, 0, limitMinutes!!)
            return Decision.Locked(lock, inForeground)
        }

        if (stepGoal != null) {
            // Steps synced on an earlier day don't count towards today's goal.
            val steps = if (prefs.getString(KEY_STEPS_DATE, null) == now.toLocalDate().toString()) {
                prefs.getInt(KEY_STEPS, 0)
            } else {
                0
            }
            if (steps < stepGoal) {
                val lock = Lock(packageName, appName, LockReason.STEPS_NOT_MET, stepGoal - steps, limitMinutes ?: 0)
                return Decision.Locked(lock, inForeground)
            }
        }

        return Decision.Open(millisUntilLimit, inForeground)
    }

    private fun JSONObject.optIntOrNull(key: String): Int? =
        if (has(key) && !isNull(key)) getInt(key) else null

    /** Mirrors FreeWindow.coversNow in lib/features/goals/models/free_window.dart. */
    private fun isInFreeWindow(windows: JSONArray?, now: LocalDateTime): Boolean {
        if (windows == null) return false
        // Lowercase names match Dart's Weekday enum.
        val today = now.dayOfWeek.name.lowercase()
        val yesterday = now.dayOfWeek.minus(1).name.lowercase()
        val minutesNow = now.hour * 60 + now.minute
        return (0 until windows.length()).map { windows.getJSONObject(it) }.any { window ->
            val daysJson = window.optJSONArray("days") ?: JSONArray()
            val days = (0 until daysJson.length()).map { daysJson.getString(it) }.toSet()
            val start = window.optJSONObject("startTime")?.let(::minutesSinceMidnight)
            val end = window.optJSONObject("endTime")?.let(::minutesSinceMidnight)
            if (start != null && end != null && end <= start) {
                // Overnight, e.g. 22:00 → 07:00: tonight's part, or the
                // morning part of a window that started yesterday.
                (today in days && minutesNow >= start) || (yesterday in days && minutesNow < end)
            } else {
                today in days &&
                    (start == null || minutesNow >= start) &&
                    (end == null || minutesNow < end)
            }
        }
    }

    private fun minutesSinceMidnight(time: JSONObject) =
        time.getInt("hour") * 60 + time.getInt("minute")

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
