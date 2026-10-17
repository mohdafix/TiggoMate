package com.tiggomate.tiggomate_app

import android.content.Context
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.tiggomate/quick_actions"
    private var initialActionUri: String? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initialActionUri = intent?.dataString
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialAction" -> {
                        val action = initialActionUri
                        initialActionUri = null
                        result.success(action)
                    }
                    "updateWidgetData" -> {
                        val args = call.arguments as? Map<*, *>
                        if (args != null) {
                            val prefs = getSharedPreferences(TiggoMateWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
                            prefs.edit().apply {
                                (args["vehicle_name"] as? String)?.let { putString("vehicle_name", it) }
                                (args["battery_soc"] as? Number)?.let { putInt("battery_soc", it.toInt()) }
                                (args["battery_range"] as? Number)?.let { putInt("battery_range", it.toInt()) }
                                (args["fuel_level"] as? Number)?.let { putInt("fuel_level", it.toInt()) }
                                (args["fuel_range"] as? Number)?.let { putInt("fuel_range", it.toInt()) }
                                (args["total_range"] as? Number)?.let { putInt("total_range", it.toInt()) }
                                (args["is_locked"] as? Boolean)?.let { putBoolean("is_locked", it) }
                                (args["is_charging"] as? Boolean)?.let { putBoolean("is_charging", it) }
                                (args["is_climate_on"] as? Boolean)?.let { putBoolean("is_climate_on", it) }
                                apply()
                            }
                            TiggoMateWidgetProvider.updateAllWidgets(this@MainActivity)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGS", "Widget arguments must be a Map", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val actionUri = intent.dataString
        if (actionUri != null) {
            methodChannel?.invokeMethod("onQuickAction", actionUri)
        }
    }
}
