package com.mtm.my_tide_monitor

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import java.util.Locale
import java.util.TimeZone

/** Supplies the rows of the list widget: one per saved location. */
class TideWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        val widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        return TideRemoteViewsFactory(applicationContext, widgetId)
    }
}

/** Builds the rows of the list widget. Also used for the preview on the widget's settings screen. */
object ListRows {
    /** What each row says at [nowMs]. */
    fun models(context: Context, snapshot: WidgetSnapshot, nowMs: Long): List<RowModel> {
        val labels = WidgetLabels.from(context)
        return snapshot.locations.map {
            WidgetFormat.buildRow(it, snapshot, nowMs, TimeZone.getDefault(), Locale.getDefault(), labels)
        }
    }

    /**
     * One row, drawn in [theme] with its text multiplied by [textScale]. With
     * [tappable] set, tapping it opens that location (which only works inside
     * the widget's list).
     */
    fun view(context: Context, row: RowModel, theme: WidgetTheme.Resolved, textScale: Float, tappable: Boolean): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.tide_widget_row)

        views.setScaledTextSize(R.id.row_name, 15f, textScale)
        views.setScaledTextSize(R.id.row_detail, 12f, textScale)
        views.setScaledTextSize(R.id.row_height, 19f, textScale)
        views.setScaledTextSize(R.id.row_direction, 12f, textScale)

        views.setTextViewText(R.id.row_name, row.name)
        views.setTextViewText(R.id.row_detail, row.detail)
        views.setTextViewText(R.id.row_height, row.height)
        views.setTextViewText(R.id.row_direction, row.direction)

        // A widget that follows the phone switches between its light and dark
        // colors by itself (see setThemedColor).
        views.setThemedColor(R.id.row_name, "setTextColor", theme) { it.onSurface }
        views.setThemedColor(R.id.row_detail, "setTextColor", theme) { it.onSurfaceVariant }
        views.setThemedColor(R.id.row_height, "setTextColor", theme) { it.onSurface }
        views.setThemedColor(R.id.row_direction, "setTextColor", theme) { it.accent }

        // Tapping the row opens the app on this location's detail screen.
        if (tappable) {
            val fillIn = Intent().apply { data = WidgetIntents.stationUri(row.id) }
            views.setOnClickFillInIntent(R.id.widget_row, fillIn)
        }
        return views
    }
}

/**
 * Builds the rows. Android asks it to reload ([onDataSetChanged]) whenever the
 * widget is redrawn, and each time it works out the tide height from the
 * current time, so a redraw always shows the right "now".
 */
class TideRemoteViewsFactory(
    private val context: Context,
    private val widgetId: Int,
) : RemoteViewsService.RemoteViewsFactory {
    private var rows: List<RowModel> = emptyList()
    private var theme: WidgetTheme.Resolved = WidgetTheme.fallback(false)
    private var textScale = 1f

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val night = TideWidgetProvider.isNight(context)
        val config = WidgetStore.configFor(context, widgetId)
        val snapshot = WidgetStore.load(context)
        textScale = config.textScale

        if (snapshot == null) {
            rows = emptyList()
            theme = WidgetTheme.fallback(night, config)
            return
        }

        rows = ListRows.models(context, snapshot, System.currentTimeMillis())
        theme = WidgetTheme.resolve(snapshot, config, night)
    }

    override fun getCount(): Int = rows.size

    override fun getViewAt(position: Int): RemoteViews? {
        val row = rows.getOrNull(position) ?: return null
        return ListRows.view(context, row, theme, textScale, tappable = true)
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = rows.getOrNull(position)?.id?.hashCode()?.toLong() ?: position.toLong()

    override fun hasStableIds(): Boolean = true

    override fun onDestroy() {}
}
