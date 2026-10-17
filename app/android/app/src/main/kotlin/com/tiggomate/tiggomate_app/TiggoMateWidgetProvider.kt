package com.tiggomate.tiggomate_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

class TiggoMateWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        const val PREFS_NAME = "tiggomate_widget_prefs"

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val vehicleName = prefs.getString("vehicle_name", "Tiggo 7 PHEV") ?: "Tiggo 7 PHEV"
            val batterySoc = prefs.getInt("battery_soc", 78)
            val batteryRange = prefs.getInt("battery_range", 95)
            val fuelLevel = prefs.getInt("fuel_level", 82)
            val fuelRange = prefs.getInt("fuel_range", 870)
            val totalRange = prefs.getInt("total_range", 965)
            val isLocked = prefs.getBoolean("is_locked", true)
            val isCharging = prefs.getBoolean("is_charging", false)
            val isClimateOn = prefs.getBoolean("is_climate_on", false)

            val views = RemoteViews(context.packageName, R.layout.tiggomate_widget)

            views.setTextViewText(R.id.widget_vehicle_name, vehicleName)
            views.setTextViewText(R.id.widget_battery_soc, "$batterySoc%")
            views.setTextViewText(R.id.widget_battery_range, "$batteryRange km EV")
            views.setTextViewText(R.id.widget_total_range, "$totalRange km")
            views.setTextViewText(R.id.widget_fuel_level, "$fuelLevel%")
            views.setTextViewText(R.id.widget_fuel_range, "$fuelRange km Fuel")

            val statusText = when {
                isCharging -> "⚡ Charging"
                isClimateOn -> "❄️ Pre-cooling"
                isLocked -> "🔒 Locked"
                else -> "🔓 Unlocked"
            }
            views.setTextViewText(R.id.widget_status_badge, statusText)

            // Dynamic Action Button labels
            views.setTextViewText(
                R.id.widget_btn_lock,
                if (isLocked) "🔓 Unlock" else "🔒 Lock"
            )
            views.setTextViewText(
                R.id.widget_btn_climate,
                if (isClimateOn) "❄️ Off" else "❄️ 22°C"
            )

            // Pending Intents for Action buttons
            views.setOnClickPendingIntent(
                R.id.widget_root,
                createActionPendingIntent(context, "tiggomate://action/open", 100)
            )
            views.setOnClickPendingIntent(
                R.id.widget_btn_lock,
                createActionPendingIntent(context, "tiggomate://action/lock", 101)
            )
            views.setOnClickPendingIntent(
                R.id.widget_btn_climate,
                createActionPendingIntent(context, "tiggomate://action/climate", 102)
            )
            views.setOnClickPendingIntent(
                R.id.widget_btn_charging,
                createActionPendingIntent(context, "tiggomate://action/charging", 103)
            )
            views.setOnClickPendingIntent(
                R.id.widget_btn_drive,
                createActionPendingIntent(context, "tiggomate://action/drive", 104)
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, TiggoMateWidgetProvider::class.java)
            val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            for (widgetId in allWidgetIds) {
                updateAppWidget(context, appWidgetManager, widgetId)
            }
        }

        private fun createActionPendingIntent(
            context: Context,
            uriString: String,
            requestCode: Int
        ): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse(uriString)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            return PendingIntent.getActivity(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
    }
}
