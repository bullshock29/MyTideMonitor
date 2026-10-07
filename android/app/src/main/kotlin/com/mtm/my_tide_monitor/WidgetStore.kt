package com.mtm.my_tide_monitor

import android.content.Context

/**
 * Keeps what the widgets draw from, so they work even when the app isn't
 * running: the snapshot the app sent, and each widget's own choices.
 */
object WidgetStore {
    private const val FILE = "tide_widget"
    private const val KEY_SNAPSHOT = "snapshot"

    private fun prefs(context: Context) = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    fun save(context: Context, json: String) {
        prefs(context).edit().putString(KEY_SNAPSHOT, json).apply()
    }

    /** The latest snapshot, or null if the app hasn't sent one yet (or it is unreadable). */
    fun load(context: Context): WidgetSnapshot? {
        val json = prefs(context).getString(KEY_SNAPSHOT, null) ?: return null
        return WidgetSnapshot.parse(json)
    }

    // ---- Each widget's own choices, kept under its Android widget id ----

    private fun modeKey(id: Int) = "widget_${id}_appearance"
    private fun opacityKey(id: Int) = "widget_${id}_opacity"
    private fun stationKey(id: Int) = "widget_${id}_station"
    private fun textSizeKey(id: Int) = "widget_${id}_text_size"

    fun saveConfig(context: Context, widgetId: Int, config: WidgetConfig) {
        val editor = prefs(context).edit()
        editor.putString(modeKey(widgetId), config.appearance)
        editor.putString(textSizeKey(widgetId), config.textSize)
        editor.putFloat(opacityKey(widgetId), config.opacity.toFloat())
        if (config.stationId == null) {
            editor.remove(stationKey(widgetId))
        } else {
            editor.putString(stationKey(widgetId), config.stationId)
        }
        editor.apply()
    }

    /** The choices for this widget, or null if none were ever made (it keeps the defaults). */
    fun loadConfig(context: Context, widgetId: Int): WidgetConfig? {
        val prefs = prefs(context)
        if (!prefs.contains(modeKey(widgetId))) return null
        return WidgetConfig.of(
            appearance = prefs.getString(modeKey(widgetId), null),
            opacity = prefs.getFloat(opacityKey(widgetId), WidgetConfig.DEFAULT_OPACITY.toFloat()).toDouble(),
            stationId = prefs.getString(stationKey(widgetId), null),
            textSize = prefs.getString(textSizeKey(widgetId), null),
        )
    }

    /** What to draw this widget with: its own choices, or the defaults. */
    fun configFor(context: Context, widgetId: Int): WidgetConfig = loadConfig(context, widgetId) ?: WidgetConfig.DEFAULT

    /** Forgets a widget's choices once it is taken off the home screen. */
    fun deleteConfig(context: Context, widgetId: Int) {
        prefs(context).edit()
            .remove(modeKey(widgetId))
            .remove(opacityKey(widgetId))
            .remove(stationKey(widgetId))
            .remove(textSizeKey(widgetId))
            .apply()
    }
}
