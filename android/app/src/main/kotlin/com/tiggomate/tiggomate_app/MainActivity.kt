package com.tiggomate.tiggomate_app

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
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
    private var speechRecognizer: SpeechRecognizer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initialActionUri = intent?.dataString
    }

    override fun onDestroy() {
        super.onDestroy()
        speechRecognizer?.destroy()
        speechRecognizer = null
        bluetoothChannel = null
    }

    companion object {
        var bluetoothChannel: io.flutter.plugin.common.MethodChannel? = null

        fun notifyBluetoothConnected(name: String, address: String) {
            bluetoothChannel?.let { channel ->
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    channel.invokeMethod("onCarConnected", mapOf("name" to name, "address" to address))
                }
            }
        }

        fun notifyBluetoothDisconnected(name: String, address: String) {
            bluetoothChannel?.let { channel ->
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    channel.invokeMethod("onCarDisconnected", mapOf("name" to name, "address" to address))
                }
            }
        }
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
                                    (args["is_bound"] as? Boolean)?.let { putBoolean("is_bound", it) }
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
                    startSpeechRecognition(result)
                }
                "stopListening" -> {
                    try {
                        speechRecognizer?.stopListening()
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 3. Bluetooth Car Driving & Tracking Channel
        val btChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.tiggomate/bluetooth_tracker")
        bluetoothChannel = btChannel
        btChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundTracking" -> {
                    val name = call.argument<String>("vehicleName") ?: "Chery Tiggo"
                    TiggoMateForegroundService.start(this, name)
                    result.success(true)
                }
                "stopForegroundTracking" -> {
                    TiggoMateForegroundService.stop(this)
                    result.success(true)
                }
                "checkCurrentConnection" -> {
                    try {
                        val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as? android.bluetooth.BluetoothManager
                        val adapter = btManager?.adapter
                        if (adapter != null && adapter.isEnabled) {
                            val a2dp = adapter.getProfileConnectionState(android.bluetooth.BluetoothProfile.A2DP) == android.bluetooth.BluetoothProfile.STATE_CONNECTED
                            val headset = adapter.getProfileConnectionState(android.bluetooth.BluetoothProfile.HEADSET) == android.bluetooth.BluetoothProfile.STATE_CONNECTED
                            if (a2dp || headset) {
                                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                                val customName = prefs.getString("flutter.tm_car_bluetooth_name", null)?.uppercase()?.trim()

                                val bonded = adapter.bondedDevices ?: emptySet()
                                val carDevice = bonded.firstOrNull { d ->
                                    val n = (d.name ?: "").uppercase()
                                    (!customName.isNullOrEmpty() && n.contains(customName)) ||
                                    n.contains("CHERY") || n.contains("TIGGO") || n.contains("CARLINKO") || n.contains("JAECOO") || n.contains("OMODA") || n.contains("CAR-") || n.contains("CAR_BT")
                                }
                                result.success(mapOf(
                                    "connected" to true,
                                    "name" to (carDevice?.name ?: "Chery Tiggo")
                                ))
                                return@setMethodCallHandler
                            }
                        }
                        result.success(mapOf("connected" to false, "name" to null))
                    } catch (e: Exception) {
                        result.success(mapOf("connected" to false, "name" to null))
                    }
                }
                "getPairedDevices" -> {
                    try {
                        val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as? android.bluetooth.BluetoothManager
                        val adapter = btManager?.adapter
                        if (adapter != null && adapter.isEnabled) {
                            val bonded = adapter.bondedDevices ?: emptySet()
                            val list = bonded.map { d ->
                                mapOf("name" to (d.name ?: "Unknown"), "address" to d.address)
                            }
                            result.success(list)
                        } else {
                            result.success(emptyList<Map<String, String>>())
                        }
                    } catch (e: Exception) {
                        result.success(emptyList<Map<String, String>>())
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 4. Battery Optimization & Autostart Management Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.tiggomate/battery_optimization").setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                    val isIgnoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        pm?.isIgnoringBatteryOptimizations(packageName) ?: false
                    } else {
                        true
                    }
                    result.success(isIgnoring)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        try {
                            val fallback = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            startActivity(fallback)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("ERROR", e2.localizedMessage, null)
                        }
                    }
                }
                "openAutostartSettings" -> {
                    val manufacturer = Build.MANUFACTURER.lowercase()
                    val intent = Intent()
                    try {
                        when {
                            manufacturer.contains("xiaomi") || manufacturer.contains("redmi") || manufacturer.contains("poco") -> {
                                intent.component = ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
                            }
                            manufacturer.contains("huawei") || manufacturer.contains("honor") -> {
                                intent.component = ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")
                            }
                            manufacturer.contains("oppo") || manufacturer.contains("realme") -> {
                                intent.component = ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")
                            }
                            manufacturer.contains("vivo") -> {
                                intent.component = ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")
                            }
                            manufacturer.contains("samsung") -> {
                                intent.component = ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity")
                            }
                            else -> {
                                intent.action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                                intent.data = Uri.parse("package:$packageName")
                            }
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(fallback)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("ERROR", e2.localizedMessage, null)
                        }
                    }
                }
                "getManufacturer" -> {
                    result.success(mapOf(
                        "manufacturer" to Build.MANUFACTURER,
                        "brand" to Build.BRAND,
                        "model" to Build.MODEL
                    ))
                }
                "startGuardianService" -> {
                    val name = call.argument<String>("vehicleName") ?: "Chery Tiggo"
                    TiggoMateForegroundService.startGuardian(this, name)
                    result.success(true)
                }
                "stopGuardianService" -> {
                    TiggoMateForegroundService.stop(this)
                    result.success(true)
                }
                "isGuardianRunning" -> {
                    result.success(TiggoMateForegroundService.isGuardianRunning)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startSpeechRecognition(result: MethodChannel.Result) {
        runOnUiThread {
            if (!SpeechRecognizer.isRecognitionAvailable(this)) {
                tryLaunchSpeechIntent(result)
                return@runOnUiThread
            }

            try {
                speechRecognizer?.destroy()
                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this).apply {
                    setRecognitionListener(object : RecognitionListener {
                        override fun onReadyForSpeech(params: Bundle?) {}
                        override fun onBeginningOfSpeech() {}
                        override fun onRmsChanged(rmsdB: Float) {}
                        override fun onBufferReceived(buffer: ByteArray?) {}
                        override fun onEndOfSpeech() {}
                        override fun onError(error: Int) {
                            if (pendingSpeechResult != null) {
                                tryLaunchSpeechIntent(pendingSpeechResult!!)
                            }
                        }
                        override fun onResults(results: Bundle?) {
                            val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            if (!matches.isNullOrEmpty()) {
                                pendingSpeechResult?.success(matches[0])
                            } else {
                                pendingSpeechResult?.success(null)
                            }
                            pendingSpeechResult = null
                        }
                        override fun onPartialResults(partialResults: Bundle?) {}
                        override fun onEvent(eventType: Int, params: Bundle?) {}
                    })
                }

                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                }
                pendingSpeechResult = result
                speechRecognizer?.startListening(intent)
            } catch (e: Exception) {
                tryLaunchSpeechIntent(result)
            }
        }
    }

    private fun tryLaunchSpeechIntent(result: MethodChannel.Result) {
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
            pendingSpeechResult = null
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
