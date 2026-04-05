package com.example.continua

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

/**
 * Service that shows a system notification containing a quote.
 * Replaces the former overlay-based implementation.
 */
class NotificationService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val text = intent?.getStringExtra("text") ?: ""
        val author = intent?.getStringExtra("author") ?: ""

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

        val smallIcon = try { applicationInfo.icon } catch (_: Exception) { android.R.drawable.ic_dialog_info }

        val contentTitle = if (text.isNotEmpty()) text else "Keep Going"
        val bigText = if (author.isNotEmpty()) "$text\n— $author" else text

        val notification: Notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle(contentTitle)
            .setContentText(author)
            .setSmallIcon(smallIcon)
            .setContentIntent(pendingIntent)
            .setStyle(NotificationCompat.BigTextStyle().bigText(bigText))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .build()

        try {
            startForeground(1, notification)
        } catch (t: Throwable) {
            android.util.Log.w("NotificationService", "startForeground failed: ${t.message}")
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val permission = android.Manifest.permission.POST_NOTIFICATIONS
                if (checkSelfPermission(permission) == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                    manager.notify(1001, notification)
                } else {
                    android.util.Log.d("NotificationService", "POST_NOTIFICATIONS not granted; skipping notify")
                }
            } else {
                manager.notify(1001, notification)
            }
        } catch (e: Exception) {
            android.util.Log.w("NotificationService", "notify failed: ${e.message}")
        }

        Handler(Looper.getMainLooper()).postDelayed({
            try {
                stopForeground(false)
            } catch (e: Exception) {
            }
            try {
                stopSelf()
            } catch (e: Exception) {
            }
        }, 1500)

        return START_NOT_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
    }
}
