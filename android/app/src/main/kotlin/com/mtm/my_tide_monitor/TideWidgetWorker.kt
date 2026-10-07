package com.mtm.my_tide_monitor

import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequest
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * Redraws the widget every so often, so the tide height and the rising or
 * falling arrow stay current while the app is closed.
 *
 * It needs no network: the widget works the height out from the tides the app
 * already saved. Android won't run this more often than every 15 minutes, and
 * may delay it to save battery.
 */
class TideWidgetWorker(context: Context, params: WorkerParameters) : Worker(context, params) {

    override fun doWork(): Result {
        WidgetRefresh.refreshAll(applicationContext)
        return Result.success()
    }

    companion object {
        private const val NAME = "tide_widget_refresh"

        fun schedule(context: Context) {
            val request = PeriodicWorkRequest.Builder(
                TideWidgetWorker::class.java,
                15,
                TimeUnit.MINUTES,
            ).build()

            // Keep any schedule that already exists rather than restarting it.
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request,
            )
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(NAME)
        }
    }
}
