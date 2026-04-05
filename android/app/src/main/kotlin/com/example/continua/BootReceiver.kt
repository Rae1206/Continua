package com.example.continua

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Receiver that re-schedules the periodic quote fetch after device boot.
 * Uses AlarmManager instead of WorkManager for better reliability on Xiaomi/MIUI.
 * 
 * CRITICAL for MIUI: This receiver must be exported and have proper intent filters.
 * Also, the app must be added to "Autostart" and "Battery Saver" exceptions.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON" ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON_COMPLETE") {
            
            Log.d("BootReceiver", "Device booted, scheduling alarm")
            
            try {
                // Get interval from SharedPreferences (default 15 minutes)
                val prefs = context.getSharedPreferences("keep_going_prefs", Context.MODE_PRIVATE)
                val intervalMinutes = prefs.getInt("interval_minutes", 15).coerceAtLeast(15)
                val intervalSeconds = intervalMinutes * 60
                
                Log.d("BootReceiver", "Using interval: $intervalMinutes minutes")
                
                // Schedule repeating alarm using AlarmManager
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val alarmIntent = Intent(context, AlarmReceiver::class.java)
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    0,
                    alarmIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                
                // Cancel any existing alarm
                alarmManager.cancel(pendingIntent)
                
                // Use chained exact alarms instead of inexact repeating
                // Inexact alarms can be delayed 15-30+ minutes by Android battery optimization
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                    if (alarmManager.canScheduleExactAlarms()) {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            System.currentTimeMillis() + (intervalSeconds * 1000L),
                            pendingIntent
                        )
                    } else {
                        alarmManager.setInexactRepeating(
                            AlarmManager.RTC_WAKEUP,
                            System.currentTimeMillis() + (intervalSeconds * 1000L),
                            intervalSeconds.toLong(),
                            pendingIntent
                        )
                    }
                } else if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        System.currentTimeMillis() + (intervalSeconds * 1000L),
                        pendingIntent
                    )
                } else {
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        System.currentTimeMillis() + (intervalSeconds * 1000L),
                        pendingIntent
                    )
                }
                
                Log.d("BootReceiver", "Alarm scheduled every $intervalMinutes minutes")
            } catch (e: Exception) {
                Log.e("BootReceiver", "Failed to schedule alarm: ${e.message}")
            }
        }
    }
}
