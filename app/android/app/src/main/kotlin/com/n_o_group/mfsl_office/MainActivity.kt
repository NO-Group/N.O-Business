package com.n_o_group.mfsl_office

import android.content.Context
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges the Android home-screen widget + launcher shortcuts to Flutter.
 *
 *  - "mtek/launch" : platform -> Dart, carries a tapped shortcut's target
 *    screen ("openScreen"). Dart -> platform, "consumePendingScreen" reads
 *    the screen requested while the app was cold-started.
 *  - "mtek/widget" : Dart -> platform, "updateStats" writes the three
 *    headline figures into SharedPreferences and refreshes the widget.
 */
class MainActivity : FlutterFragmentActivity() {

    private var pendingScreen: String? = null
    private var launchChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val screen = intent?.getStringExtra(EXTRA_SCREEN)
        if (!screen.isNullOrEmpty()) {
            pendingScreen = screen
            // App already running: forward the tap straight to Flutter.
            launchChannel?.invokeMethod(METHOD_OPEN_SCREEN, screen)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        launchChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_LAUNCH,
        )
        launchChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                METHOD_CONSUME_SCREEN -> {
                    val screen = pendingScreen
                    pendingScreen = null
                    result.success(screen)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_WIDGET)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    METHOD_UPDATE_STATS -> {
                        val args = call.arguments as? Map<*, *>
                        getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                            .edit()
                            .putString(KEY_SALES, args?.get(KEY_SALES) as? String ?: DASH)
                            .putString(KEY_RECEIPTS, args?.get(KEY_RECEIPTS) as? String ?: DASH)
                            .putString(KEY_INVOICES, args?.get(KEY_INVOICES) as? String ?: DASH)
                            .apply()
                        MtekWidgetProvider.refresh(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        const val EXTRA_SCREEN = "mtek_screen"
        const val CHANNEL_LAUNCH = "mtek/launch"
        const val CHANNEL_WIDGET = "mtek/widget"
        const val METHOD_OPEN_SCREEN = "openScreen"
        const val METHOD_CONSUME_SCREEN = "consumePendingScreen"
        const val METHOD_UPDATE_STATS = "updateStats"

        const val PREFS = "mtek_widget_stats"
        const val KEY_SALES = "todaySales"
        const val KEY_RECEIPTS = "receipts"
        const val KEY_INVOICES = "invoices"
        const val DASH = "—"

        const val ACTION_REFRESH = "com.n_o_group.mfsl_office.WIDGET_REFRESH"
    }
}
