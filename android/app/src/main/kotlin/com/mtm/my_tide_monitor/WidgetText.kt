package com.mtm.my_tide_monitor

import android.util.TypedValue
import android.widget.RemoteViews

/**
 * Sets how big a piece of text is. The layouts hold the normal ("medium")
 * sizes; this multiplies one by the widget's own text size choice (see
 * [WidgetConfig.textScale]), so "small" and "large" are the same layout with
 * smaller and bigger text.
 */
fun RemoteViews.setScaledTextSize(viewId: Int, baseSp: Float, scale: Float) {
    setTextViewTextSize(viewId, TypedValue.COMPLEX_UNIT_SP, baseSp * scale)
}
