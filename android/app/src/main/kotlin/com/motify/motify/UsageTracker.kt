package com.motify.motify

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build
import android.os.Process
import java.time.LocalDate
import java.time.ZoneId

/**
 * How long apps have been in the foreground today, from Android's usage
 * events. Needs the "Usage access" special permission, which the user grants
 * in Settings (MainActivity's requestUsageAccess opens it).
 */
object UsageTracker {
    // UsageEvents.Event.ACTIVITY_RESUMED / ACTIVITY_PAUSED (named so from API 29;
    // same values as the older MOVE_TO_FOREGROUND / MOVE_TO_BACKGROUND).
    private const val RESUMED = 1
    private const val PAUSED = 2

    data class Usage(val millisToday: Long, val inForeground: Boolean)

    fun hasAccess(context: Context): Boolean {
        val appOps = context.getSystemService(AppOpsManager::class.java)
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /**
     * Today's foreground time for each of [packages], and whether it's in the
     * foreground right now. Empty without usage access.
     */
    fun usageToday(context: Context, packages: Set<String>): Map<String, Usage> {
        if (packages.isEmpty() || !hasAccess(context)) return emptyMap()
        val usageStats = context.getSystemService(UsageStatsManager::class.java)
        val dayStart = LocalDate.now().atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
        val now = System.currentTimeMillis()

        val totals = mutableMapOf<String, Long>()
        // Resumed activities per app: an app with several activities can
        // resume one before pausing another, so count rather than flag.
        val openActivities = mutableMapOf<String, Int>()
        val openSince = mutableMapOf<String, Long>()
        val seen = mutableSetOf<String>()

        val events = usageStats.queryEvents(dayStart, now)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName
            if (pkg !in packages) continue
            when (event.eventType) {
                RESUMED -> {
                    val open = openActivities[pkg] ?: 0
                    if (open == 0) openSince[pkg] = event.timeStamp
                    openActivities[pkg] = open + 1
                }
                PAUSED -> {
                    val open = openActivities[pkg] ?: 0
                    when {
                        open > 1 -> openActivities[pkg] = open - 1
                        open == 1 -> {
                            openActivities[pkg] = 0
                            totals[pkg] = (totals[pkg] ?: 0) + event.timeStamp - openSince.getValue(pkg)
                        }
                        // Paused before any resume today: it was open since before midnight.
                        pkg !in seen -> totals[pkg] = (totals[pkg] ?: 0) + event.timeStamp - dayStart
                    }
                }
                else -> continue
            }
            seen += pkg
        }

        return packages.associateWith { pkg ->
            val inForeground = (openActivities[pkg] ?: 0) > 0
            val running = if (inForeground) now - openSince.getValue(pkg) else 0
            Usage((totals[pkg] ?: 0) + running, inForeground)
        }
    }
}
