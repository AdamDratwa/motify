package com.motify.motify

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * Re-reads today's steps in the background so locked apps unlock once the
 * goal is reached, without the user having to open Motify first.
 */
class StepSyncWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        StepReader.readStepsToday(applicationContext)?.let {
            BlockingStore.saveSteps(applicationContext, it)
        }
        // Nothing to retry on failure: the next periodic run reads again.
        return Result.success()
    }

    companion object {
        private const val WORK_NAME = "step-sync"

        /** Safe to call repeatedly; keeps the existing schedule if there is one. */
        fun schedule(context: Context) {
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                // 15 minutes is the shortest interval WorkManager allows.
                PeriodicWorkRequestBuilder<StepSyncWorker>(15, TimeUnit.MINUTES).build(),
            )
        }
    }
}
