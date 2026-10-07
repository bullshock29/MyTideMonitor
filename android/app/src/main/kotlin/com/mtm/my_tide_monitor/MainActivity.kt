package com.mtm.my_tide_monitor

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The app's one screen. Besides hosting Flutter, it is the link between the
 * app and the home screen widget:
 *
 *  - the app sends the widget its data (`saveSnapshot`)
 *  - a tap on a location in the widget arrives as an intent, and is handed to
 *    the app so it can open that location
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    // The station from a widget tap that started the app, until the app asks.
    private var launchStationId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        launchStationId = stationIdFrom(intent)
        // Used up: a rotation or restart must not open it again.
        intent?.data = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveSnapshot" -> {
                        val json = call.arguments as? String
                        if (json == null) {
                            result.error("bad_arguments", "Expected the snapshot as a string", null)
                        } else {
                            WidgetStore.save(applicationContext, json)
                            WidgetRefresh.refreshAll(applicationContext)
                            result.success(null)
                        }
                    }

                    "takeLaunchStationId" -> {
                        val id = launchStationId
                        launchStationId = null
                        result.success(id)
                    }

                    else -> result.notImplemented()
                }
            }
        }
    }

    // A widget tap while the app is already open arrives here.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        stationIdFrom(intent)?.let { id ->
            channel?.invokeMethod("stationTapped", id)
            intent.data = null
        }
    }

    // Taps look like mtm://station/8661070; the station id is the last part.
    private fun stationIdFrom(intent: Intent?): String? {
        val data = intent?.data ?: return null
        if (data.scheme != "mtm" || data.host != "station") return null
        return data.lastPathSegment
    }

    private companion object {
        const val CHANNEL = "com.mtm.my_tide_monitor/widget"
    }
}
