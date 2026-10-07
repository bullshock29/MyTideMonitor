package com.mtm.my_tide_monitor

import android.widget.RemoteViews
import kotlin.math.roundToInt

/**
 * The "glass" card behind every widget. Android widgets can't blur what's
 * behind them, so the look comes from three stacked pictures: a tinted
 * translucent fill, a soft light sheen across the top, and a fine edge.
 *
 * The widget's layout holds the three pictures (with the ids widget_bg,
 * widget_sheen and widget_border). setColorFilter tints a (white) shape, and
 * setImageAlpha makes it see-through by the amount the user chose.
 *
 * Colors go through [setThemedColor], so a widget that follows the phone
 * switches between light and dark by itself.
 */
object WidgetGlass {
    fun apply(views: RemoteViews, theme: WidgetTheme.Resolved) {
        val alpha = theme.backgroundAlpha

        views.setThemedColor(R.id.widget_bg, "setColorFilter", theme) { it.background }
        views.setInt(R.id.widget_bg, "setImageAlpha", alpha)

        views.setInt(R.id.widget_sheen, "setImageAlpha", (alpha * 0.85).roundToInt())

        views.setThemedColor(R.id.widget_border, "setColorFilter", theme) { it.border }
        views.setInt(R.id.widget_border, "setImageAlpha", maxOf(70, (alpha * 0.6).roundToInt()))
    }
}
