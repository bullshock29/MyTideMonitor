package com.mtm.my_tide_monitor

/**
 * The choices made for one widget on the home screen. Every widget has its
 * own, picked when it was added and changeable by touching and holding it
 * (see [WidgetConfigActivity]).
 */
data class WidgetConfig(
    /** "system" (follow the phone), "light" or "dark". */
    val appearance: String = "system",
    /** How solid the background is, from [MIN_OPACITY] to 1.0. */
    val opacity: Double = DEFAULT_OPACITY,
    /** The location a tide tile shows. Null means the first saved one. Unused by the list. */
    val stationId: String? = null,
    /** "small", "medium" or "large": how big the widget's text is. */
    val textSize: String = "medium",
) {
    /** What to multiply every text size in the widget by. */
    val textScale: Float get() = scaleFor(textSize)

    companion object {
        /** The most see-through a widget can be. Below this the text is hard to read. */
        const val MIN_OPACITY = 0.2
        const val DEFAULT_OPACITY = 0.75

        val TEXT_SIZES = listOf("small", "medium", "large")

        val DEFAULT = WidgetConfig()

        /** Small is a bit smaller than the normal text, large a bit bigger. */
        fun scaleFor(textSize: String): Float = when (textSize) {
            "small" -> 0.88f
            "large" -> 1.15f
            else -> 1f
        }

        /**
         * Builds a config from stored or typed-in values, putting anything odd
         * right: an unknown mode follows the phone, the opacity is kept in
         * range (in steps of 5%), an empty location means "the first one", and
         * an unknown text size is medium.
         */
        fun of(appearance: String?, opacity: Double?, stationId: String?, textSize: String? = null): WidgetConfig {
            val mode = if (appearance == "light" || appearance == "dark") appearance else "system"
            val steps = if (opacity == null || opacity.isNaN()) DEFAULT_OPACITY else Math.round(opacity * 20) / 20.0
            return WidgetConfig(
                appearance = mode,
                opacity = steps.coerceIn(MIN_OPACITY, 1.0),
                stationId = stationId?.takeIf { it.isNotBlank() },
                textSize = if (textSize in TEXT_SIZES) textSize!! else "medium",
            )
        }
    }
}
