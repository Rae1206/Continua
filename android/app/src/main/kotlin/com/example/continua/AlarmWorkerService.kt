package com.example.continua

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray

/**
 * Service that fetches a quote from Supabase and shows a notification.
 * Used by AlarmReceiver to work around Android 8+ restrictions on network calls in BroadcastReceiver.
 */
class AlarmWorkerService : Service() {
    
    companion object {
        const val CHANNEL_ID = "keep_going_channel"
        const val TAG = "AlarmWorker"
    }
    
    private var wakeLock: PowerManager.WakeLock? = null
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service created")
        
        // Acquire wake lock to ensure CPU stays awake during work
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "KeepGoing:AlarmWorkerWakeLock"
        ).apply {
            acquire(60 * 1000L) // 1 minute max
        }
        Log.d(TAG, "WakeLock acquired")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service started, startId=$startId")
        
        // Create notification channel
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Keep Going", NotificationManager.IMPORTANCE_HIGH)
            channel.description = "Notifications for Keep Going quotes"
            channel.enableVibration(true)
            channel.setShowBadge(true)
            manager.createNotificationChannel(channel)
            Log.d(TAG, "Notification channel created")
        }
        
        // Show foreground notification while working
        val foregroundNotification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Keep Going")
            .setContentText("Fetching quote...")
            .setSmallIcon(applicationInfo.icon)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
        
        startForeground(1, foregroundNotification)
        Log.d(TAG, "Foreground started")
        
        // Fetch quote and show notification
        fetchQuoteAndNotify()
        
        return START_NOT_STICKY
    }
    
    private fun fetchQuoteAndNotify() {
        try {
            val ai = applicationContext.packageManager.getApplicationInfo(
                applicationContext.packageName, 
                android.content.pm.PackageManager.GET_META_DATA
            )
            val meta = ai.metaData
            val supabaseUrl = meta?.getString("supabase_url")
            val anonKey = meta?.getString("supabase_anon_key")
            
            Log.d(TAG, "supabaseUrl: $supabaseUrl, anonKey: ${anonKey?.take(10)}...")
            
            if (supabaseUrl == null || anonKey == null) {
                Log.e(TAG, "Missing supabase config in manifest")
                stopSelf()
                return
            }
            
            val client = OkHttpClient()
            val url = "$supabaseUrl/rest/v1/quotes?select=*&order=random()&limit=1"
            Log.d(TAG, "Fetching from: $url")
            
            val req = Request.Builder()
                .url(url)
                .addHeader("apikey", anonKey)
                .addHeader("Authorization", "Bearer $anonKey")
                .addHeader("Accept", "application/json")
                .build()
            
            val resp = client.newCall(req).execute()
            Log.d(TAG, "Response code: ${resp.code}")
            
            if (!resp.isSuccessful) {
                Log.e(TAG, "HTTP error: ${resp.code}")
                stopSelf()
                return
            }
            
            val body = resp.body?.string() ?: run {
                Log.e(TAG, "Empty response body")
                stopSelf()
                return
            }
            
            val arr = JSONArray(body)
            if (arr.length() == 0) {
                Log.w(TAG, "No quotes returned")
                stopSelf()
                return
            }
            
            val obj = arr.getJSONObject(0)
            val text = obj.optString("text", "")
            val author = obj.optString("author", "")
            
            Log.d(TAG, "Got quote: $text - $author")
            showNotification(text, author)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error: ${e.message}", e)
        } finally {
            releaseWakeLock()
            stopSelf()
        }
    }
    
    private fun showNotification(text: String, author: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) 
            ?: Intent(this, Class.forName("com.example.continua.MainActivity"))
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
        
        val contentTitle = if (text.isNotEmpty()) text else "Keep Going"
        val bigText = if (author.isNotEmpty()) "$text\n— $author" else text
        
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(contentTitle)
            .setContentText(author)
            .setSmallIcon(applicationInfo.icon)
            .setContentIntent(pendingIntent)
            .setStyle(NotificationCompat.BigTextStyle().bigText(bigText))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 250, 250, 250))
            .build()
        
        try {
            manager.notify(1001, notification)
            Log.d(TAG, "Notification shown successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show notification: ${e.message}")
        }
    }
    
    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                    Log.d(TAG, "WakeLock released")
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error releasing wake lock: ${e.message}")
        }
    }
    
    override fun onDestroy() {
        releaseWakeLock()
        Log.d(TAG, "Service destroyed")
        super.onDestroy()
    }
}
