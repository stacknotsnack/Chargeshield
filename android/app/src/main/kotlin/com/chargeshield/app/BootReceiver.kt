package com.chargeshield.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import id.flutter.flutter_background_service.BackgroundService

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != "android.intent.action.QUICKBOOT_POWERON"
        ) return

        // Only restart the service if the user had tracking enabled before reboot.
        // Avoids ForegroundServiceStartNotAllowedException on Android 14+
        // and prevents unwanted restarts when the user had tracking off.
        val prefs: SharedPreferences =
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val trackingEnabled =
            prefs.getBoolean("flutter.tracking_enabled", false)

        if (!trackingEnabled) return

        try {
            val serviceIntent = Intent(context, BackgroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (e: Exception) {
            // Swallow — if the service can't start on boot (e.g. Android 14
            // background-start restrictions), the user will restart it manually.
        }
    }
}
