package com.mtm.my_tide_monitor

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context

/** Redraws the widgets on the home screen, whichever kind they are. */
object WidgetRefresh {
    fun refreshAll(context: Context) {
        TideWidgetProvider.refreshAll(context)
        TideTileProvider.refreshAll(context)
    }

    /** Whether any widget of ours is on the home screen. */
    fun hasWidgets(context: Context): Boolean {
        val manager = AppWidgetManager.getInstance(context)
        return listOf(TideWidgetProvider::class.java, TideTileProvider::class.java).any {
            manager.getAppWidgetIds(ComponentName(context, it)).isNotEmpty()
        }
    }

    /** Stops the timed redraw once the last widget is gone. */
    fun stopTimerIfUnused(context: Context) {
        if (!hasWidgets(context)) TideWidgetWorker.cancel(context)
    }
}
