package com.mtm.my_tide_monitor

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.RemoteViews
import android.widget.SeekBar
import android.widget.TextView
import kotlin.math.roundToInt

/**
 * The settings screen for one widget. Android opens it when a widget is added
 * to the home screen, and again when the widget is touched and held and
 * "settings" is chosen.
 *
 * Each widget keeps its own choices (see [WidgetConfig]): its look (follow the
 * phone, light or dark), how see-through it is, and, for the tide tile, which
 * saved location it shows. A live preview, drawn by the same code as the real
 * widget, sits over a colorful backdrop so the glass is easy to judge.
 *
 * Backing out without pressing Done cancels: a widget being added is not
 * added, and one being changed keeps what it had.
 */
class WidgetConfigActivity : Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private var isTile = false
    private var snapshot: WidgetSnapshot? = null

    private var appearance = "system"
    private var opacity = WidgetConfig.DEFAULT_OPACITY
    private var stationId: String? = null
    private var textSize = "medium"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Until Done is pressed, leaving means "cancel".
        setResult(RESULT_CANCELED)

        widgetId = intent?.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        val provider = AppWidgetManager.getInstance(this).getAppWidgetInfo(widgetId)?.provider
        isTile = provider?.className == TideTileProvider::class.java.name
        snapshot = WidgetStore.load(this)

        // A widget being changed starts from what it has; a new one from the defaults.
        val saved = WidgetStore.configFor(this, widgetId)
        appearance = saved.appearance
        opacity = saved.opacity
        textSize = saved.textSize
        stationId = chosenStation(saved.stationId)

        setContentView(R.layout.widget_config)
        keepClearOfSystemBars(findViewById(R.id.config_root))

        findViewById<TextView>(R.id.config_title).setText(if (isTile) R.string.config_title_tile else R.string.config_title_list)
        setUpLocations()
        setUpMode()
        setUpTextSize()
        setUpOpacity()
        findViewById<View>(R.id.config_done).setOnClickListener { done() }

        render()
    }

    // The saved location if it still exists, otherwise the first one.
    private fun chosenStation(saved: String?): String? {
        val locations = snapshot?.locations ?: return null
        return locations.firstOrNull { it.id == saved }?.id ?: locations.firstOrNull()?.id
    }

    private fun currentConfig() = WidgetConfig.of(appearance, opacity, if (isTile) stationId else null, textSize)

    // ---- Controls ----

    private fun setUpLocations() {
        val section = findViewById<View>(R.id.config_location_section)
        if (!isTile) {
            section.visibility = View.GONE
            return
        }

        val group = findViewById<RadioGroup>(R.id.config_locations)
        val locations = snapshot?.locations.orEmpty()
        if (locations.isEmpty()) {
            findViewById<View>(R.id.config_no_locations).visibility = View.VISIBLE
            return
        }

        for (location in locations) {
            val button = RadioButton(this).apply {
                id = View.generateViewId()
                text = location.name
                tag = location.id
                textSize = 16f
            }
            group.addView(button, RadioGroup.LayoutParams(RadioGroup.LayoutParams.MATCH_PARENT, RadioGroup.LayoutParams.WRAP_CONTENT))
            if (location.id == stationId) group.check(button.id)
        }
        group.setOnCheckedChangeListener { radios, checkedId ->
            stationId = radios.findViewById<View>(checkedId)?.tag as? String
            render()
        }
    }

    private fun setUpMode() {
        val group = findViewById<RadioGroup>(R.id.config_mode)
        group.check(
            when (appearance) {
                "light" -> R.id.config_mode_light
                "dark" -> R.id.config_mode_dark
                else -> R.id.config_mode_system
            },
        )
        group.setOnCheckedChangeListener { _, checkedId ->
            appearance = when (checkedId) {
                R.id.config_mode_light -> "light"
                R.id.config_mode_dark -> "dark"
                else -> "system"
            }
            render()
        }
    }

    private fun setUpTextSize() {
        val group = findViewById<RadioGroup>(R.id.config_text_size)
        group.check(
            when (textSize) {
                "small" -> R.id.config_size_small
                "large" -> R.id.config_size_large
                else -> R.id.config_size_medium
            },
        )
        group.setOnCheckedChangeListener { _, checkedId ->
            textSize = when (checkedId) {
                R.id.config_size_small -> "small"
                R.id.config_size_large -> "large"
                else -> "medium"
            }
            render()
        }
    }

    // The bar moves in 5% steps from the minimum to fully solid.
    private fun setUpOpacity() {
        val bar = findViewById<SeekBar>(R.id.config_opacity)
        bar.progress = ((opacity - WidgetConfig.MIN_OPACITY) / STEP).roundToInt()
        bar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar, progress: Int, fromUser: Boolean) {
                opacity = WidgetConfig.of("system", WidgetConfig.MIN_OPACITY + progress * STEP, null).opacity
                render()
            }

            override fun onStartTrackingTouch(seekBar: SeekBar) {}
            override fun onStopTrackingTouch(seekBar: SeekBar) {}
        })
    }

    private fun done() {
        WidgetStore.saveConfig(this, widgetId, currentConfig())
        // Redraws every widget (cheap), which includes this one with its new choices.
        WidgetRefresh.refreshAll(this)

        setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
        finish()
    }

    // ---- Preview ----

    private fun render() {
        findViewById<TextView>(R.id.config_opacity_label).text = getString(R.string.config_opacity, (opacity * 100).roundToInt())

        val container = findViewById<FrameLayout>(R.id.config_preview)
        container.removeAllViews()
        container.layoutParams = container.layoutParams.apply { height = dp(if (isTile) TILE_PREVIEW_DP else LIST_PREVIEW_DP) }

        try {
            val preview = if (isTile) {
                TideTileProvider.buildViews(this, widgetId, currentConfig(), snapshot).apply(this, container)
            } else {
                listPreview(container)
            }
            container.addView(preview, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        } catch (e: Exception) {
            // The preview is a nicety; the settings still work without it.
        }
    }

    // The list widget fills its list through a service, which only works on
    // the home screen. So the preview is the same glass with the same rows
    // placed in a plain column.
    private fun listPreview(container: ViewGroup): View {
        val config = currentConfig()
        val theme = TideWidgetProvider.themeFor(this, snapshot, config)
        val current = snapshot
        val hasRows = current != null && current.locations.isNotEmpty()

        val glass = RemoteViews(packageName, R.layout.config_list_preview)
        WidgetGlass.apply(glass, theme)
        glass.setViewVisibility(R.id.preview_empty, if (hasRows) View.GONE else View.VISIBLE)
        glass.setThemedColor(R.id.preview_empty, "setTextColor", theme) { it.onSurfaceVariant }

        val card = glass.apply(this, container)
        if (current != null && hasRows) {
            val rows = card.findViewById<LinearLayout>(R.id.preview_rows)
            for (row in ListRows.models(this, current, System.currentTimeMillis()).take(LIST_PREVIEW_ROWS)) {
                rows.addView(ListRows.view(this, row, theme, config.textScale, tappable = false).apply(this, rows))
            }
        }
        return card
    }

    // ---- Helpers ----

    private fun dp(value: Int) = (value * resources.displayMetrics.density).roundToInt()

    // Newer Android draws apps under the status and navigation bars; pad the
    // content so nothing sits behind them.
    private fun keepClearOfSystemBars(view: View) {
        val base = dp(20)
        view.setOnApplyWindowInsetsListener { v, insets ->
            val (left, top, right, bottom) = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val bars = insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
                listOf(bars.left, bars.top, bars.right, bars.bottom)
            } else {
                @Suppress("DEPRECATION")
                listOf(insets.systemWindowInsetLeft, insets.systemWindowInsetTop, insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
            }
            v.setPadding(base + left, base + top, base + right, base + bottom)
            insets
        }
        view.requestApplyInsets()
    }

    private companion object {
        const val STEP = 0.05
        const val TILE_PREVIEW_DP = 120
        const val LIST_PREVIEW_DP = 170
        const val LIST_PREVIEW_ROWS = 2
    }
}
