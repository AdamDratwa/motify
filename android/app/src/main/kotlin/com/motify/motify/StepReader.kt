package com.motify.motify

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * Reads today's step total straight from Health Connect, for when Dart isn't
 * running (StepSyncWorker, LockActivity). Uses the same READ_STEPS permission
 * the user granted via the `health` plugin; reads from the background also
 * need READ_HEALTH_DATA_IN_BACKGROUND, requested in StepService.
 */
object StepReader {
    /** Null if Health Connect is unavailable, permission is missing, or the read fails. */
    suspend fun readStepsToday(context: Context): Int? {
        if (HealthConnectClient.getSdkStatus(context) != HealthConnectClient.SDK_AVAILABLE) return null
        return try {
            val client = HealthConnectClient.getOrCreate(context)
            val granted = client.permissionController.getGrantedPermissions()
            if (HealthPermission.getReadPermission(StepsRecord::class) !in granted) return null

            val startOfDay = LocalDate.now().atStartOfDay(ZoneId.systemDefault()).toInstant()
            val result = client.aggregate(
                AggregateRequest(
                    metrics = setOf(StepsRecord.COUNT_TOTAL),
                    timeRangeFilter = TimeRangeFilter.between(startOfDay, Instant.now()),
                ),
            )
            result[StepsRecord.COUNT_TOTAL]?.toInt() ?: 0
        } catch (e: Exception) {
            // e.g. SecurityException for a background read without the
            // background permission; callers keep the last synced count.
            null
        }
    }
}
