package com.mtm.my_tide_monitor

import android.content.Context

/** The words the widgets show, taken from Android's string resources (so they can be translated). */
object WidgetLabels {
    fun from(context: Context) = Labels(
        high = context.getString(R.string.widget_high),
        low = context.getString(R.string.widget_low),
        rising = context.getString(R.string.widget_rising),
        falling = context.getString(R.string.widget_falling),
        needsRefresh = context.getString(R.string.widget_needs_refresh),
        nextHigh = context.getString(R.string.widget_next_high),
        nextLow = context.getString(R.string.widget_next_low),
        waves = context.getString(R.string.widget_waves),
        water = context.getString(R.string.widget_water),
        calm = context.getString(R.string.widget_wave_calm),
        small = context.getString(R.string.widget_wave_small),
        moderate = context.getString(R.string.widget_wave_moderate),
        large = context.getString(R.string.widget_wave_large),
        veryLarge = context.getString(R.string.widget_wave_very_large),
        hoursAgo = context.getString(R.string.widget_hours_ago),
    )
}
