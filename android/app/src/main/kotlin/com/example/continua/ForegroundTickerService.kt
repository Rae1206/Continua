package com.example.continua

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.content.pm.PackageManager
import androidx.core.app.NotificationCompat
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

class ForegroundTickerService : Service() {
    private val scheduler = Executors.newSingleThreadScheduledExecutor()
    private var futureTask: ScheduledFuture<*>? = null
    private val client = OkHttpClient()
    // Frame cycle configuration: drawable resource names (without extension)
    private val frameNames = arrayOf("ic_frame_1", "ic_frame_2", "ic_frame_3", "ic_frame_4")
    private val frameIndex = AtomicInteger(0)

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val interval = intent?.getIntExtra("intervalSeconds", 60 * 60) ?: (60 * 60)

        val channelId = "keep_going_ticker_channel"
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val chan = NotificationChannel(channelId, "Keep Going (ticker)", NotificationManager.IMPORTANCE_LOW)
            chan.description = "Foreground ticker for periodic quote notifications"
            manager.createNotificationChannel(chan)
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: Intent(this, Class.forName("com.example.continua.MainActivity"))
        val pendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.getActivity(this, 0, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE)
        } else {
            PendingIntent.getActivity(this, 0, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT)
        }

        val notification: Notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Keep Going — running")
            .setContentText("Notifications every ${interval}s")
            .setSmallIcon(applicationInfo.icon)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()

        try {
            startForeground(42, notification)
        } catch (t: Throwable) {
            Log.w("ForegroundTicker", "startForeground failed: ${t.message}")
        }

        // Cancel any previous scheduled task
        futureTask?.cancel(true)

        // Schedule periodic fetching and notifying
        futureTask = scheduler.scheduleAtFixedRate({
            try {
                fetchAndNotify()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }, 0, interval.toLong(), TimeUnit.SECONDS)

        return START_STICKY
    }

    private fun fetchAndNotify() {
        try {
            val ai = applicationContext.packageManager.getApplicationInfo(applicationContext.packageName, PackageManager.GET_META_DATA)
            val meta = ai.metaData
            val supabaseUrl = meta?.getString("supabase_url") ?: return
            val anonKey = meta?.getString("supabase_anon_key") ?: return

            val url = "$supabaseUrl/rest/v1/quotes?select=*&order=random()&limit=1"
            val req = Request.Builder()
                .url(url)
                .addHeader("apikey", anonKey)
                .addHeader("Authorization", "Bearer $anonKey")
                .addHeader("Accept", "application/json")
                .build()

            val resp = client.newCall(req).execute()
            if (!resp.isSuccessful) return
            val body = resp.body?.string() ?: return
            val arr = JSONArray(body)
            if (arr.length() == 0) return
            val obj = arr.getJSONObject(0)
            val text = obj.optString("text", "")
            val author = obj.optString("author", "")

            val channelId = "keep_going_channel"
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val chan = NotificationChannel(channelId, "Keep Going", NotificationManager.IMPORTANCE_HIGH)
                chan.description = "Notifications for Keep Going quotes"
                manager.createNotificationChannel(chan)
            }

            val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: Intent(this, Class.forName("com.example.continua.MainActivity"))
            val pendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.getActivity(this, 0, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE)
            } else {
                PendingIntent.getActivity(this, 0, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT)
            }

            val contentTitle = if (text.isNotEmpty()) text else "Keep Going"
            val bigText = if (author.isNotEmpty()) "$text\n— $author" else text

            // Choose frame drawable if available, fallback to application icon
            val idx = frameIndex.getAndUpdate { cur -> (cur + 1) % frameNames.size }
            val frameResName = frameNames[idx % frameNames.size]
            val frameRes = resources.getIdentifier(frameResName, "drawable", packageName)
            val smallIconRes = if (frameRes != 0) frameRes else applicationInfo.icon

            val notification = NotificationCompat.Builder(this, channelId)
                .setContentTitle(contentTitle)
                .setContentText(author)
                .setSmallIcon(smallIconRes)
                .setContentIntent(pendingIntent)
                .setStyle(NotificationCompat.BigTextStyle().bigText(bigText))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setAutoCancel(true)
                .build()

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    val permission = android.Manifest.permission.POST_NOTIFICATIONS
                    if (checkSelfPermission(permission) == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                        manager.notify((System.currentTimeMillis() % 100000).toInt(), notification)
                    }
                } else {
                    manager.notify((System.currentTimeMillis() % 100000).toInt(), notification)
                }
            } catch (e: Exception) {
                Log.w("ForegroundTicker", "notify failed: ${e.message}")
            }

        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        futureTask?.cancel(true)
        scheduler.shutdownNow()
        try {
            stopForeground(true)
        } catch (e: Exception) {
        }
    }
}
