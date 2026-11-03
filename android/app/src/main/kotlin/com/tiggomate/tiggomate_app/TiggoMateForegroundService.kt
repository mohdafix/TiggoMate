package com.tiggomate.tiggomate_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Ongoing Foreground Service keeping TiggoMate alive while driving.
 *
 * Prevents Android OS from entering Doze mode or freezing network sockets
 * while the car is in motion or connected to the vehicle's Bluetooth / CarLinko BLE.
 */
class TiggoMateForegroundService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == ACTION_STOP) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        val vehicleName = intent?.getStringExtra(EXTRA_VEHICLE_NAME) ?: "Chery Tiggo"
        createNotificationChannel()

        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🚗 Driving Tracker Active")
            .setContentText("Connected to $vehicleName • Auto-trip and live CAN-bus logging")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setContentIntent(pendingIntent)
            .build()

        startForeground(NOTIFICATION_ID, notification)
        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val existing = manager.getNotificationChannel(CHANNEL_ID)
            if (existing == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "TiggoMate Driving Tracker",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Keeps telematics active and logs trips continuously while driving"
                    setShowBadge(false)
                }
                manager.createNotificationChannel(channel)
            }
        }
    }

    companion object {
        const val CHANNEL_ID = "tiggomate_driving_service_channel"
        const val NOTIFICATION_ID = 8842

        const val ACTION_START = "com.tiggomate.service.START_DRIVING"
        const val ACTION_STOP = "com.tiggomate.service.STOP_DRIVING"
        const val EXTRA_VEHICLE_NAME = "vehicle_name"

        fun start(context: Context, vehicleName: String = "Chery Tiggo") {
            val intent = Intent(context, TiggoMateForegroundService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_VEHICLE_NAME, vehicleName)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, TiggoMateForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }
}
