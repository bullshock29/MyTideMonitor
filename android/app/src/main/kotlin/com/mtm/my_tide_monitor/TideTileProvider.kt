package com.mtm.my_tide_monitor

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import java.util.Locale
import java.util.TimeZone

/**
 * The tide tile: one location on a glass card, laid out like the tiles on the
 * app's home screen. The location, light or dark look, and opacity are this
 * widget's own (see [WidgetConfig]), chosen on its settings screen.
 *
 * It shows the tide now with which way it's going, the next high and low, and
 * the waves and water temperature as the app last read them.
 */
class TideTileProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val snapshot = WidgetStore.load(context)
        for (id in ids) manager.updateAppWidget(id, buildViews(context, id, WidgetStore.configFor(context, id), snapshot))
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
        /** Redraws every tile on the home screen with the latest data. */
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, TideTileProvider::class.java))
            if (ids.isEmpty()) return

            val snapshot = WidgetStore.load(context)
            for (id in ids) manager.updateAppWidget(id, buildViews(context, id, WidgetStore.configFor(context, id), snapshot))
        }

        /** The location a tile with this [config] shows: the one chosen, or the first saved one if none was. */
        fun locationFor(snapshot: WidgetSnapshot?, config: WidgetConfig): WidgetLocation? {
            val locations = snapshot?.locations ?: return null
            return if (config.stationId == null) locations.firstOrNull() else locations.firstOrNull { it.id == config.stationId }
        }

        /**
         * Draws a tile. Used for the widget itself, and (with a [config] not
         * yet saved) for the preview on its settings screen.
         */
        fun buildViews(
            context: Context,
            widgetId: Int,
            config: WidgetConfig,
            snapshot: WidgetSnapshot?,
            nowMs: Long = System.currentTimeMillis(),
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.tide_tile)
            val theme = TideWidgetProvider.themeFor(context, snapshot, config)
            WidgetGlass.apply(views, theme)

            val scale = config.textScale
            val location = locationFor(snapshot, config)
            when {
                snapshot == null -> showMessage(context, views, theme, scale, R.string.widget_tile_open_app)
                snapshot.locations.isEmpty() -> showMessage(context, views, theme, scale, R.string.widget_empty)
                location == null -> showMessage(context, views, theme, scale, R.string.widget_tile_missing)
                else -> {
                    val tile = WidgetFormat.buildTile(
                        location, snapshot, nowMs, TimeZone.getDefault(), Locale.getDefault(), WidgetLabels.from(context),
                    )
                    showTile(views, theme, scale, tile)
                    views.setOnClickPendingIntent(R.id.tile_root, WidgetIntents.openStation(context, location.id))
                    return views
                }
            }

            views.setOnClickPendingIntent(R.id.tile_root, WidgetIntents.openApp(context))
            return views
        }

        // No location to show: just a message on the glass.
        private fun showMessage(context: Context, views: RemoteViews, theme: WidgetTheme.Resolved, scale: Float, textId: Int) {
            views.setViewVisibility(R.id.tile_header, View.GONE)
            views.setViewVisibility(R.id.tile_cells, View.GONE)
            views.setViewVisibility(R.id.tile_message, View.VISIBLE)
            views.setTextViewText(R.id.tile_message, context.getString(textId))
            views.setThemedColor(R.id.tile_message, "setTextColor", theme) { it.onSurfaceVariant }
            views.setScaledTextSize(R.id.tile_message, MESSAGE_SP, scale)
        }

        private fun showTile(views: RemoteViews, theme: WidgetTheme.Resolved, scale: Float, tile: TileModel) {
            views.setViewVisibility(R.id.tile_header, View.VISIBLE)
            views.setScaledTextSize(R.id.tile_name, 15f, scale)
            views.setScaledTextSize(R.id.tile_height, 17f, scale)
            views.setScaledTextSize(R.id.tile_direction, 11f, scale)
            views.setTextViewText(R.id.tile_name, tile.name)
            views.setTextViewText(R.id.tile_height, tile.height)
            views.setTextViewText(R.id.tile_direction, tile.direction)
            views.setThemedColor(R.id.tile_name, "setTextColor", theme) { it.onSurface }
            views.setThemedColor(R.id.tile_height, "setTextColor", theme) { it.onSurface }
            views.setThemedColor(R.id.tile_direction, "setTextColor", theme) { it.accent }

            // The tides ran out: say so where the boxes would be.
            if (tile.message != null) {
                views.setViewVisibility(R.id.tile_cells, View.GONE)
                views.setViewVisibility(R.id.tile_message, View.VISIBLE)
                views.setTextViewText(R.id.tile_message, tile.message)
                views.setThemedColor(R.id.tile_message, "setTextColor", theme) { it.onSurfaceVariant }
                views.setScaledTextSize(R.id.tile_message, MESSAGE_SP, scale)
                return
            }

            views.setViewVisibility(R.id.tile_message, View.GONE)
            views.setViewVisibility(R.id.tile_cells, View.VISIBLE)
            bindCell(views, theme, scale, HIGH, tile.nextHigh)
            bindCell(views, theme, scale, LOW, tile.nextLow)
            bindCell(views, theme, scale, WAVES, tile.waves)
            bindCell(views, theme, scale, WATER, tile.water)

            // With no waves or water temperature to show, the second row goes
            // and the first takes all the height.
            views.setViewVisibility(R.id.tile_row_sea, if (tile.waves == null && tile.water == null) View.GONE else View.VISIBLE)
        }

        private class CellIds(val frame: Int, val bg: Int, val label: Int, val value: Int, val sub: Int)

        private val HIGH = CellIds(R.id.tile_high_cell, R.id.tile_high_bg, R.id.tile_high_label, R.id.tile_high_value, R.id.tile_high_sub)
        private val LOW = CellIds(R.id.tile_low_cell, R.id.tile_low_bg, R.id.tile_low_label, R.id.tile_low_value, R.id.tile_low_sub)
        private val WAVES = CellIds(R.id.tile_waves_cell, R.id.tile_waves_bg, R.id.tile_waves_label, R.id.tile_waves_value, R.id.tile_waves_sub)
        private val WATER = CellIds(R.id.tile_water_cell, R.id.tile_water_bg, R.id.tile_water_label, R.id.tile_water_value, R.id.tile_water_sub)

        // A plate with nothing to say (no waves for this place, say) is left
        // out, and the one beside it takes its space.
        private fun bindCell(views: RemoteViews, theme: WidgetTheme.Resolved, scale: Float, ids: CellIds, cell: Cell?) {
            if (cell == null) {
                views.setViewVisibility(ids.frame, View.GONE)
                return
            }
            views.setViewVisibility(ids.frame, View.VISIBLE)

            views.setTextViewText(ids.label, cell.label)
            views.setTextViewText(ids.value, cell.value)
            views.setTextViewText(ids.sub, cell.sub)
            views.setViewVisibility(ids.sub, if (cell.sub.isEmpty()) View.GONE else View.VISIBLE)

            views.setScaledTextSize(ids.label, 11f, scale)
            views.setScaledTextSize(ids.value, 16f, scale)
            views.setScaledTextSize(ids.sub, 10f, scale)

            views.setThemedColor(ids.label, "setTextColor", theme) { it.onSurfaceVariant }
            views.setThemedColor(ids.value, "setTextColor", theme) { it.onSurface }
            views.setThemedColor(ids.sub, "setTextColor", theme) { it.onSurfaceVariant }

            // A faint plate behind the text: the text color at a low alpha, so
            // it darkens a light card and lightens a dark one.
            views.setThemedColor(ids.bg, "setColorFilter", theme) { it.onSurface }
            views.setInt(ids.bg, "setImageAlpha", CELL_PLATE_ALPHA)
        }

        private const val CELL_PLATE_ALPHA = 30
        private const val MESSAGE_SP = 13f
    }
}
