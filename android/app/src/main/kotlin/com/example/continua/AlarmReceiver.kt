package com.example.continua

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray

/**
 * AlarmReceiver: maneja alarmas periódicas para mostrar quotes.
 * Se re-programa automáticamente después de cada ejecución.
 * AlarmManager es más confiable que WorkManager en Xiaomi/MIUI.
 */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("AlarmReceiver", "Alarm triggered, starting service for quote...")
        
        // Start a foreground service to fetch quote and show notification
        // This is much more reliable on MIUI/EMUI than direct notification from receiver
        val serviceIntent = Intent(context, AlarmWorkerService::class.java)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
        
        // Also reschedule the next alarm
        rescheduleNextAlarm(context)
    }
    
    private fun fetchAndShowQuote(context: Context) {
        try {
            val ai = context.packageManager.getApplicationInfo(
                context.packageName, 
                android.content.pm.PackageManager.GET_META_DATA
            )
            val meta = ai.metaData
            val supabaseUrl = meta?.getString("supabase_url")
            val anonKey = meta?.getString("supabase_anon_key")
            
            if (supabaseUrl == null || anonKey == null) {
                Log.e("AlarmReceiver", "Missing Supabase config in manifest")
                return
            }
            
            val client = okhttp3.OkHttpClient()
            val url = "$supabaseUrl/rest/v1/quotes?select=*&order=random()&limit=1"
            
            val req = okhttp3.Request.Builder()
                .url(url)
                .addHeader("apikey", anonKey)
                .addHeader("Authorization", "Bearer $anonKey")
                .addHeader("Accept", "application/json")
                .build()
            
            val resp = client.newCall(req).execute()
            if (!resp.isSuccessful) {
                Log.e("AlarmReceiver", "HTTP error: ${resp.code}")
                return
            }
            
            val body = resp.body?.string() ?: return
            val arr = org.json.JSONArray(body)
            if (arr.length() == 0) return
            
            val obj = arr.getJSONObject(0)
            val text = obj.optString("text", "")
            val author = obj.optString("author", "")
            
            Log.d("AlarmReceiver", "Got quote: $text - $author")
            showNotificationDirect(context, text, author)
            
        } catch (e: Exception) {
            Log.e("AlarmReceiver", "Error fetching quote: ${e.message}")
        }
    }
    
    private fun showNotificationDirect(context: Context, text: String, author: String) {
        val channelId = "keep_going_channel"
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val chan = android.app.NotificationChannel(channelId, "Keep Going", android.app.NotificationManager.IMPORTANCE_HIGH)
            chan.description = "Notifications for Keep Going quotes"
            chan.enableVibration(true)
            chan.setShowBadge(true)
            manager.createNotificationChannel(chan)
        }
        
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName) 
            ?: Intent(context, Class.forName("com.example.continua.MainActivity"))
        val pendingIntent = PendingIntent.getActivity(context, 0, launchIntent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE)
        
        val contentTitle = if (text.isNotEmpty()) text else "Keep Going"
        val bigText = if (author.isNotEmpty()) "$text\n— $author" else text
        
        val notification = NotificationCompat.Builder(context, channelId)
            .setContentTitle(contentTitle)
            .setContentText(author)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentIntent(pendingIntent)
            .setStyle(NotificationCompat.BigTextStyle().bigText(bigText))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 250, 250, 250))
            .build()
        
        try {
            manager.notify(1001, notification)
            Log.d("AlarmReceiver", "Notification shown successfully")
        } catch (e: Exception) {
            Log.e("AlarmReceiver", "Failed to show notification: ${e.message}")
        }
    }
    
    private fun rescheduleNextAlarm(context: Context) {
        try {
            val prefs = context.getSharedPreferences("keep_going_prefs", Context.MODE_PRIVATE)
            val intervalMinutes = prefs.getInt("interval_minutes", 15).coerceAtLeast(15)
            val intervalSeconds = intervalMinutes * 60
            
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val alarmIntent = Intent(context, AlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                0,
                alarmIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Cancel existing
            alarmManager.cancel(pendingIntent)
            
            // CRITICAL: Use chained EXACT alarms instead of inexact repeating
            // Inexact alarms can be delayed 15-30+ minutes by Android's battery optimization
            // Exact alarms with setExactAndAllowWhileIdle are much more reliable
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                // Android 12+: Check if we have exact alarm permission
                if (alarmManager.canScheduleExactAlarms()) {
                    // Use exact alarm that wakes device up
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        System.currentTimeMillis() + (intervalSeconds * 1000L),
                        pendingIntent
                    )
                    Log.d("AlarmReceiver", "Scheduled EXACT alarm in $intervalMinutes minutes")
                } else {
                    // Fallback to inexact if permission not granted
                    alarmManager.setInexactRepeating(
                        AlarmManager.RTC_WAKEUP,
                        System.currentTimeMillis() + (intervalSeconds * 1000L),
                        intervalSeconds.toLong(),
                        pendingIntent
                    )
                    Log.d("AlarmReceiver", "Scheduled INEXACT alarm (no exact permission)")
                }
            } else if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                // Android 6-11: Use exact alarm
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    System.currentTimeMillis() + (intervalSeconds * 1000L),
                    pendingIntent
                )
                Log.d("AlarmReceiver", "Scheduled EXACT alarm (Android 6-11)")
            } else {
                // Android 5 and below
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    System.currentTimeMillis() + (intervalSeconds * 1000L),
                    pendingIntent
                )
                Log.d("AlarmReceiver", "Scheduled EXACT alarm (Android 5)")
            }
            
        } catch (e: Exception) {
            Log.e("AlarmReceiver", "Failed to reschedule: ${e.message}")
        }
    }
    
    private fun showNotification(context: Context, text: String, author: String) {
        val channelId = "keep_going_channel"
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val chan = android.app.NotificationChannel(channelId, "Keep Going", android.app.NotificationManager.IMPORTANCE_HIGH)
            chan.description = "Notifications for Keep Going quotes"
            manager.createNotificationChannel(chan)
        }
        
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName) 
            ?: Intent(context, Class.forName("com.example.continua.MainActivity"))
        val pendingIntent = PendingIntent.getActivity(context, 0, launchIntent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE)
        
        val contentTitle = if (text.isNotEmpty()) text else "Keep Going"
        val bigText = if (author.isNotEmpty()) "$text\n— $author" else text
        
        val notification = NotificationCompat.Builder(context, channelId)
            .setContentTitle(contentTitle)
            .setContentText(author)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentIntent(pendingIntent)
            .setStyle(NotificationCompat.BigTextStyle().bigText(bigText))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .build()
        
        try {
            // Try to show notification with foreground service for reliability
            val serviceIntent = Intent(context, NotificationService::class.java)
            serviceIntent.putExtra("text", text)
            serviceIntent.putExtra("author", author)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (e: Exception) {
            Log.w("AlarmReceiver", "startService failed: ${e.message}")
            // Fallback to direct notification
            try {
                manager.notify((System.currentTimeMillis() % 100000).toInt(), notification)
            } catch (e2: Exception) {
                Log.w("AlarmReceiver", "notify failed: ${e2.message}")
            }
        }
    }
}
