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
 * [lockFor] mirrors `evaluateGate` in lib/features/goals/models/gate_decision.dart
 * — keep the two in sync. Free windows are evaluated here against the current
 * time, so e.g. "free after 4pm" kicks in without Motify being opened.
 */
object BlockingStore {
    private const val PREFS = "motify_blocking"
    private const val KEY_RULES = "rules"
    private const val KEY_STEPS = "steps"
    private const val KEY_STEPS_DATE = "stepsDate"

    data class Lock(val packageName: String, val appName: String, val stepsLeft: Int)

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

    /** Null if [packageName] isn't gated or is currently unlocked. */
    fun lockFor(context: Context, packageName: String): Lock? {
        val prefs = prefs(context)
        val rules = JSONArray(prefs.getString(KEY_RULES, null) ?: return null)
        val rule = (0 until rules.length())
            .map { rules.getJSONObject(it) }
            .firstOrNull { it.optString("appId") == packageName }
            ?: return null

        if (!rule.optBoolean("enabled", true)) return null

        val now = LocalDateTime.now()
        if (isInFreeWindow(rule.optJSONArray("freeWindows"), now)) return null

        // Steps synced on an earlier day don't count towards today's goal.
        val steps = if (prefs.getString(KEY_STEPS_DATE, null) == now.toLocalDate().toString()) {
            prefs.getInt(KEY_STEPS, 0)
        } else {
            0
        }
        val target = rule.optInt("targetValue")
        if (steps >= target) return null

        return Lock(packageName, rule.optString("appDisplayName", packageName), target - steps)
    }

    private fun isInFreeWindow(windows: JSONArray?, now: LocalDateTime): Boolean {
        if (windows == null) return false
        val today = now.dayOfWeek.name.lowercase() // matches Dart's Weekday enum names
        val minutesNow = now.hour * 60 + now.minute
        return (0 until windows.length()).map { windows.getJSONObject(it) }.any { window ->
            val days = window.optJSONArray("days") ?: JSONArray()
            val coversToday = (0 until days.length()).any { days.getString(it) == today }
            val start = window.optJSONObject("startTime")?.let(::minutesSinceMidnight)
            val end = window.optJSONObject("endTime")?.let(::minutesSinceMidnight)
            coversToday &&
                (start == null || minutesNow >= start) &&
                (end == null || minutesNow < end)
        }
    }

    private fun minutesSinceMidnight(time: JSONObject) =
        time.getInt("hour") * 60 + time.getInt("minute")

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
