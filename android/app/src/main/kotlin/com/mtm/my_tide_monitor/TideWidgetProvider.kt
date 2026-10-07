package com.mtm.my_tide_monitor

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.widget.RemoteViews

/**
 * The list widget: a translucent, tinted "glass" card holding a list of the
 * saved locations. This draws the card itself; each row of the list is built
 * by [TideWidgetService].
 *
 * Each widget has its own look (see [WidgetConfig]), chosen on its settings
 * screen.
 *
 * Android can only redraw a widget when something asks it to, so [refreshAll]
 * is called when the app sends new data, on a timer (see [TideWidgetWorker]),
 * and when the time zone or clock changes.
 */
class TideWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, buildViews(context, id))
        manager.notifyAppWidgetViewDataChanged(ids, R.id.widget_list)
        TideWidgetWorker.schedule(context)
    }

    override fun onEnabled(context: Context) {
        TideWidgetWorker.schedule(context)
    }

    override fun onDisabled(context: Context) {
        WidgetRefresh.stopTimerIfUnused(context)
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        for (id in ids) WidgetStore.deleteConfig(context, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            // The times and "today" depend on these.
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_LOCALE_CHANGED -> WidgetRefresh.refreshAll(context)
        }
    }

    companion object {
        /** Redraws every list widget on the home screen with the latest data. */
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, TideWidgetProvider::class.java))
            if (ids.isEmpty()) return

            for (id in ids) manager.updateAppWidget(id, buildViews(context, id))
            manager.notifyAppWidgetViewDataChanged(ids, R.id.widget_list)
        }

        fun isNight(context: Context): Boolean {
            val mode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
            return mode == Configuration.UI_MODE_NIGHT_YES
        }

        /** The look of the list widget with these choices, for the widget itself and the settings screen. */
        fun themeFor(context: Context, snapshot: WidgetSnapshot?, config: WidgetConfig): WidgetTheme.Resolved {
            val night = isNight(context)
            return if (snapshot != null) WidgetTheme.resolve(snapshot, config, night) else WidgetTheme.fallback(night, config)
        }

        private fun buildViews(context: Context, widgetId: Int): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.tide_widget)
            val config = WidgetStore.configFor(context, widgetId)
            val theme = themeFor(context, WidgetStore.load(context), config)

            WidgetGlass.apply(views, theme)

            // The list of locations.
            val adapter = Intent(context, TideWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                // Makes this intent unique per widget, so Android keeps their lists apart.
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_list, adapter)
            views.setEmptyView(R.id.widget_list, R.id.widget_empty)
            views.setThemedColor(R.id.widget_empty, "setTextColor", theme) { it.onSurfaceVariant }
            views.setScaledTextSize(R.id.widget_empty, 14f, config.textScale)

            // Tapping a row opens the app on that location; tapping the empty
            // message just opens the app.
            views.setPendingIntentTemplate(R.id.widget_list, WidgetIntents.rowTemplate(context))
            views.setOnClickPendingIntent(R.id.widget_empty, WidgetIntents.openApp(context))

            return views
        }
    }
}
