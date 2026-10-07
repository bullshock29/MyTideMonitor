package com.mtm.my_tide_monitor

import android.os.Build
import android.widget.RemoteViews

/**
 * Sets a color on a view of the widget, in a way that follows the phone's
 * light and dark mode by itself where Android allows it.
 *
 * A widget is drawn from instructions that were fixed when it was last
 * updated, so a color picked then would stay the same after the phone
 * switched to dark mode, until the next update. Android 14 and newer lets us
 * hand over both a light color and a dark color in one instruction, and the
 * phone picks the right one on the spot. Older versions get the color for the
 * mode the phone was in at the time, and catch up on the next update.
 *
 * [method] is the name of a View method taking a color, such as
 * "setTextColor" or "setColorFilter". [pick] chooses which of the palette's
 * colors to use.
 */
fun RemoteViews.setThemedColor(
    viewId: Int,
    method: String,
    theme: WidgetTheme.Resolved,
    pick: (Palette) -> Int,
) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
        setColorInt(viewId, method, pick(theme.notNightPalette), pick(theme.nightPalette))
    } else {
        setInt(viewId, method, pick(theme.palette))
    }
}
