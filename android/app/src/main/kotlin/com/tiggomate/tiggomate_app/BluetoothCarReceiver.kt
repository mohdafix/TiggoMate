package com.tiggomate.tiggomate_app

import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * BroadcastReceiver triggered by Android OS whenever a Bluetooth device
 * connects or disconnects (even when TiggoMate is in the background or screen is off).
 */
class BluetoothCarReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val device: BluetoothDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
        }

        if (device == null) return

        val deviceName = try {
            device.name ?: "Bluetooth Device"
        } catch (_: SecurityException) {
            "Vehicle Bluetooth"
        }

        val deviceAddress = device.address ?: ""

        if (!isCarDevice(context, deviceName)) {
            return
        }

        when (action) {
            BluetoothDevice.ACTION_ACL_CONNECTED -> {
                // 1. Start foreground service so Android will not freeze the app while driving
                TiggoMateForegroundService.start(context, deviceName)

                // 2. Notify Flutter Dart layer if engine is running
                MainActivity.notifyBluetoothConnected(deviceName, deviceAddress)
            }
            BluetoothDevice.ACTION_ACL_DISCONNECTED -> {
                // 1. Notify Flutter Dart layer to snap parking location & finalize trip immediately
                MainActivity.notifyBluetoothDisconnected(deviceName, deviceAddress)

                // 2. Stop foreground service to conserve phone battery when walking away
                TiggoMateForegroundService.stop(context)
            }
        }
    }

    private fun isCarDevice(context: Context, name: String): Boolean {
        val upper = name.uppercase()
        // Check standard Chery / Jaecoo / CarLinko / In-car head unit patterns
        if (upper.contains("CHERY") ||
            upper.contains("TIGGO") ||
            upper.contains("JAECOO") ||
            upper.contains("OMODA") ||
            upper.contains("CARLINKO") ||
            upper.contains("CAR-") ||
            upper.contains("CAR_BT") ||
            upper.contains("MY_CAR") ||
            upper.contains("BT_CAR") ||
            upper.contains("ANDROID AUTO")
        ) {
            return true
        }

        // Also check user's custom configured Bluetooth device name in SharedPreferences
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val customName = prefs.getString("flutter.tm_car_bluetooth_name", null)
        if (!customName.isNullOrBlank()) {
            if (upper.contains(customName.uppercase().trim())) {
                return true
            }
        }

        return false
    }
}
