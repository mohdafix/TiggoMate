package com.tiggomate.tiggomate_app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognizerIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val QUICK_ACTIONS_CHANNEL = "com.tiggomate/quick_actions"
    private val SPEECH_CHANNEL = "com.tiggomate/speech"
    private val SPEECH_REQUEST_CODE = 9912

    private var initialActionUri: String? = null
    private var quickActionsChannel: MethodChannel? = null
    private var pendingSpeechResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initialActionUri = intent?.dataString
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Quick Actions & Widget MethodChannel
        quickActionsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, QUICK_ACTIONS_CHANNEL).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialAction" -> {
                        val action = initialActionUri
                        initialActionUri = null
                        result.success(action)
                    }
                    "updateWidgetData" -> {
                        try {
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
                        } catch (e: Exception) {
                            result.error("ERROR", e.localizedMessage, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // 2. Native Speech Recognition Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPEECH_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startListening" -> {
                    try {
                        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
                            putExtra(RecognizerIntent.EXTRA_PROMPT, "Speak Tiggo 7 Command or Question...")
                        }
                        pendingSpeechResult = result
                        startActivityForResult(intent, SPEECH_REQUEST_CODE)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Speech recognition unavailable: ${e.localizedMessage}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SPEECH_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val matches = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                if (!matches.isNullOrEmpty()) {
                    pendingSpeechResult?.success(matches[0])
                } else {
                    pendingSpeechResult?.success(null)
                }
            } else {
                pendingSpeechResult?.success(null)
            }
            pendingSpeechResult = null
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val actionUri = intent.dataString
        if (actionUri != null) {
            quickActionsChannel?.invokeMethod("onQuickAction", actionUri)
        }
    }
}
