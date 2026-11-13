package com.tiggomate.tiggomate_app

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayList
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val QUICK_ACTIONS_CHANNEL = "com.tiggomate/quick_actions"
    private val SPEECH_CHANNEL = "com.tiggomate/speech"
    private val SPEECH_REQUEST_CODE = 9912

    private var initialActionUri: String? = null
    private var quickActionsChannel: MethodChannel? = null
    private var speechChannel: MethodChannel? = null
    private var pendingSpeechResult: MethodChannel.Result? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var speechRetryCount = 0
    private var tts: TextToSpeech? = null
    private var isTtsReady = false
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initialActionUri = intent?.dataString
        initTts {}
    }

    override fun onDestroy() {
        super.onDestroy()
        speechRecognizer?.destroy()
        speechRecognizer = null
        try {
            tts?.stop()
            tts?.shutdown()
        } catch (_: Exception) {}
        tts = null
        bluetoothChannel = null
        speechChannel = null
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

        // 2. Native Speech Recognition & Text-To-Speech Channel (DasHub & DashMate pattern)
        val spChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPEECH_CHANNEL)
        speechChannel = spChannel
        spChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startListening" -> {
                    val lang = call.argument<String>("lang")
                    startSpeechRecognition(lang, result)
                }
                "stopListening" -> {
                    try {
                        speechRecognizer?.stopListening()
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "cancelListening" -> {
                    try {
                        speechRecognizer?.cancel()
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "speak" -> {
                    val text = call.argument<String>("text") ?: ""
                    val lang = call.argument<String>("lang") ?: "ms-MY"
                    speakText(text, lang, result)
                }
                "stopSpeaking" -> {
                    try {
                        tts?.stop()
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "isSpeaking" -> {
                    result.success(tts?.isSpeaking ?: false)
                }
                "playChime" -> {
                    val type = call.argument<String>("type") ?: "listen"
                    when (type) {
                        "listen" -> InCarChimePlayer.playListenChime(this)
                        "success" -> InCarChimePlayer.playSuccessChime(this)
                        "error" -> InCarChimePlayer.playErrorChime(this)
                    }
                    result.success(true)
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

    private fun initTts(onReady: () -> Unit) {
        if (tts != null && isTtsReady) {
            onReady()
            return
        }
        try {
            tts = TextToSpeech(this) { status ->
                if (status == TextToSpeech.SUCCESS) {
                    isTtsReady = true
                    try {
                        tts?.setSpeechRate(1.02f)
                        tts?.setPitch(1.0f)
                    } catch (_: Exception) {}
                    mainHandler.post { onReady() }
                }
            }
        } catch (_: Exception) {
            isTtsReady = false
        }
    }

    private fun speakText(text: String, lang: String, result: MethodChannel.Result) {
        if (text.isBlank()) {
            result.success(true)
            return
        }
        initTts {
            performSpeak(text, lang, result)
        }
    }

    private fun performSpeak(text: String, lang: String, result: MethodChannel.Result) {
        try {
            val locale = if (lang.startsWith("en", ignoreCase = true)) {
                Locale.US
            } else {
                Locale("ms", "MY")
            }
            val res = tts?.setLanguage(locale)
            if (res == TextToSpeech.LANG_MISSING_DATA || res == TextToSpeech.LANG_NOT_SUPPORTED) {
                tts?.language = Locale.US
            }
            tts?.setPitch(1.0f)
            tts?.setSpeechRate(1.02f)
            val params = Bundle().apply {
                putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, 1.0f)
            }
            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, params, "tiggomate_voice_${System.currentTimeMillis()}")
            result.success(true)
        } catch (e: Exception) {
            result.error("TTS_ERROR", e.localizedMessage, null)
        }
    }

    private fun startSpeechRecognition(lang: String?, result: MethodChannel.Result) {
        runOnUiThread {
            if (!SpeechRecognizer.isRecognitionAvailable(this)) {
                tryLaunchSpeechIntent(result)
                return@runOnUiThread
            }

            speechRetryCount = 0
            doStartListening(lang, result)
        }
    }

    private fun doStartListening(lang: String?, result: MethodChannel.Result?) {
        try {
            speechRecognizer?.destroy()
            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this).apply {
                setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) {
                        InCarChimePlayer.playListenChime(this@MainActivity)
                        speechChannel?.invokeMethod("onSpeechEvent", mapOf(
                            "event" to "ready"
                        ))
                    }

                    override fun onBeginningOfSpeech() {
                        speechChannel?.invokeMethod("onSpeechEvent", mapOf(
                            "event" to "beginning"
                        ))
                    }

                    override fun onRmsChanged(rmsdB: Float) {
                        speechChannel?.invokeMethod("onSpeechEvent", mapOf(
                            "event" to "rms",
                            "rms" to rmsdB
                        ))
                    }

                    override fun onBufferReceived(buffer: ByteArray?) {}

                    override fun onEndOfSpeech() {
                        speechChannel?.invokeMethod("onSpeechEvent", mapOf(
                            "event" to "end"
                        ))
                    }

                    override fun onError(error: Int) {
                        // Transient error auto-retry (DasHub pattern: error 5, 8, 12, 13)
                        if ((error == 5 || error == 8 || error == 12 || error == 13) && speechRetryCount < 1) {
                            speechRetryCount++
                            mainHandler.postDelayed({
                                doStartListening(lang, pendingSpeechResult)
                            }, 250)
                            return
                        }

                        val localizedMsg = when (error) {
                            SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT ->
                                "No speech heard. Please try again."
                            SpeechRecognizer.ERROR_NETWORK, SpeechRecognizer.ERROR_NETWORK_TIMEOUT ->
                                "No internet connection for voice recognition."
                            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS ->
                                "Microphone permission is required."
                            else -> "Voice recognition error (Code $error). Please try again."
                        }

                        InCarChimePlayer.playErrorChime(this@MainActivity)
                        speechChannel?.invokeMethod("onSpeechEvent", mapOf(
                            "event" to "error",
                            "code" to error,
                            "message" to localizedMsg
                        ))

                        pendingSpeechResult?.success(null)
                        pendingSpeechResult = null
                    }

                    override fun onResults(results: Bundle?) {
                        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val text = if (!matches.isNullOrEmpty()) matches[0].trim() else null

                        if (!text.isNullOrEmpty()) {
                            InCarChimePlayer.playSuccessChime(this@MainActivity)
                        } else {
                            InCarChimePlayer.playErrorChime(this@MainActivity)
                        }

                        speechChannel?.invokeMethod("onSpeechEvent", mapOf(
                            "event" to "result",
                            "text" to (text ?: "")
                        ))

                        pendingSpeechResult?.success(text)
                        pendingSpeechResult = null
                    }

                    override fun onPartialResults(partialResults: Bundle?) {
                        val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        if (!matches.isNullOrEmpty()) {
                            val partialText = matches[0].trim()
                            speechChannel?.invokeMethod("onSpeechEvent", mapOf(
                                "event" to "partial",
                                "text" to partialText
                            ))
                        }
                    }

                    override fun onEvent(eventType: Int, params: Bundle?) {}
                })
            }

            val targetLang = when (lang) {
                "ms", "ms-MY" -> "ms-MY"
                else -> "en-MY"
            }

            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, "web_search")
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, targetLang)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                putExtra("calling_package", packageName)

                // Bilingual Speech Recognition: Support both English and Malay simultaneously
                putExtra("android.speech.extra.EXTRA_ADDITIONAL_LANGUAGES", arrayOf("en-MY", "ms-MY", "en-US"))

                // Android 14+ (API 34+) DasHub Language Auto-Detection & Switching
                if (Build.VERSION.SDK_INT >= 34) {
                    putExtra("android.speech.extra.ENABLE_LANGUAGE_DETECTION", true)
                    putExtra("android.speech.extra.LANGUAGE_DETECTION_ALLOWED_LANGUAGES", arrayListOf("en-MY", "ms-MY", "en-US", "en-GB"))
                    putExtra("android.speech.extra.ENABLE_LANGUAGE_SWITCH", "balanced")
                    putExtra("android.speech.extra.LANGUAGE_SWITCH_ALLOWED_LANGUAGES", arrayListOf("en-MY", "ms-MY", "en-US", "en-GB"))
                }
            }

            if (result != null) {
                pendingSpeechResult = result
            }
            speechRecognizer?.startListening(intent)
        } catch (e: Exception) {
            if (result != null) {
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

object InCarChimePlayer {
    private const val SAMPLE_RATE = 44100

    private fun playTone(freqs: List<Double>, durationsMs: List<Int>) {
        Thread {
            try {
                val totalSamples = durationsMs.sumOf { (SAMPLE_RATE * it) / 1000 }
                val buffer = ShortArray(totalSamples)
                var offset = 0

                for (i in freqs.indices) {
                    val freq = freqs[i]
                    val durationMs = durationsMs[i]
                    val count = (SAMPLE_RATE * durationMs) / 1000
                    val angularFreq = 2.0 * Math.PI * freq / SAMPLE_RATE

                    for (j in 0 until count) {
                        val progress = j.toDouble() / count
                        val envelope = if (progress < 0.08) {
                            progress / 0.08
                        } else {
                            Math.pow(1.0 - progress, 2.2)
                        }
                        // Fundamental sine + warm acoustic 2nd harmonic
                        val sample = (Math.sin(angularFreq * j) * 0.78 + Math.sin(angularFreq * 2.0 * j) * 0.22) * envelope
                        buffer[offset + j] = (sample * 32767.0 * 0.60).toInt().coerceIn(-32768, 32767).toShort()
                    }
                    offset += count
                }

                val attrs = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()

                val format = AudioFormat.Builder()
                    .setSampleRate(SAMPLE_RATE)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .build()

                val track = AudioTrack.Builder()
                    .setAudioAttributes(attrs)
                    .setAudioFormat(format)
                    .setBufferSizeInBytes(buffer.size * 2)
                    .setTransferMode(AudioTrack.MODE_STATIC)
                    .build()

                track.write(buffer, 0, buffer.size)
                track.play()
                val sleepTime = durationsMs.sum().toLong() + 30
                Thread.sleep(sleepTime)
                track.stop()
                track.release()
            } catch (_: Exception) {}
        }.start()
    }

    fun playListenChime(context: Context) {
        // Subtle dual rising tone: C5 (523Hz) -> G5 (784Hz)
        playTone(listOf(523.25, 783.99), listOf(65, 110))
    }

    fun playSuccessChime(context: Context) {
        // Clean high harmonic chime: G5 (784Hz) -> C6 (1046.5Hz)
        playTone(listOf(783.99, 1046.50), listOf(55, 135))
    }

    fun playErrorChime(context: Context) {
        // Soft double-tap error: E4 (329.6Hz) -> C4 (261.6Hz)
        playTone(listOf(329.63, 261.63), listOf(70, 95))
    }
}
