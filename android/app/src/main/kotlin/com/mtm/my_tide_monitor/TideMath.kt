package com.mtm.my_tide_monitor

import kotlin.math.PI
import kotlin.math.cos

/**
 * Works out the tide height at any moment from the high and low tides on
 * either side of it. This is the same math as the app's tide chart
 * (lib/services/tide_curve.dart), so the widget and the app agree.
 *
 * Between a low and the next high (or the other way) the water follows a half
 * cosine wave: it moves slowly near the extremes and fastest halfway between.
 */
object TideMath {
    /**
     * The index of the extreme at or just before [nowMs], so that [nowMs] falls
     * between that one and the next. Returns -1 if [nowMs] isn't inside the
     * range the extremes cover. [extremes] must be in time order.
     */
    private fun segmentStart(extremes: List<Extreme>, nowMs: Long): Int {
        for (i in 0 until extremes.size - 1) {
            if (nowMs >= extremes[i].timeMs && nowMs < extremes[i + 1].timeMs) return i
        }
        return -1
    }

    /** The tide height in feet at [nowMs], or null if the extremes don't cover that moment. */
    fun heightAt(extremes: List<Extreme>, nowMs: Long): Double? {
        val i = segmentStart(extremes, nowMs)
        if (i < 0) return null

        val from = extremes[i]
        val to = extremes[i + 1]
        val fraction = (nowMs - from.timeMs).toDouble() / (to.timeMs - from.timeMs)
        val eased = (1 - cos(PI * fraction)) / 2
        return from.feet + (to.feet - from.feet) * eased
    }

    /** True if the tide is coming in at [nowMs], false if going out, null if unknown. */
    fun isRising(extremes: List<Extreme>, nowMs: Long): Boolean? {
        val i = segmentStart(extremes, nowMs)
        if (i < 0) return null
        return extremes[i + 1].feet > extremes[i].feet
    }

    /** The next high tide after [nowMs], if there is one. */
    fun nextHigh(extremes: List<Extreme>, nowMs: Long): Extreme? =
        extremes.firstOrNull { it.isHigh && it.timeMs > nowMs }

    /** The next low tide after [nowMs], if there is one. */
    fun nextLow(extremes: List<Extreme>, nowMs: Long): Extreme? =
        extremes.firstOrNull { !it.isHigh && it.timeMs > nowMs }
}
