package com.example.continua

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.ComponentName
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
private val CHANNEL = "keep_going/notification"
private val PREFS_CHANNEL = "keep_going/preferences"
private val PREFS_NAME = "keep_going_prefs"
private val REQUEST_CODE_POST_NOTIFICATIONS = 1002

override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
super.configureFlutterEngine(flutterEngine)

// Request POST_NOTIFICATIONS on Android 13+ (only once on first launch)
checkAndRequestNotificationPermission()

MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call: MethodCall, result ->
when (call.method) {
// overlay permission removed — no-op
"requestNotificationPermission" -> {
checkAndRequestNotificationPermission()
result.success(true)
}
"showNotification" -> {
val text = call.argument<String>("text") ?: ""
val author = call.argument<String>("author") ?: ""
val intent = Intent(this, NotificationService::class.java)
intent.putExtra("text", text)
intent.putExtra("author", author)
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
startForegroundService(intent)
} else {
startService(intent)
}
result.success(true)
}
"stopNotification" -> {
val intent = Intent(this, NotificationService::class.java)
stopService(intent)
result.success(true)
}
"startForegroundTicker" -> {
val interval = call.argument<Int>("intervalSeconds") ?: 60*60
val intent = Intent(this, ForegroundTickerService::class.java)
intent.putExtra("intervalSeconds", interval)
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
startForegroundService(intent)
} else {
startService(intent)
}
result.success(true)
}
"stopForegroundTicker" -> {
val intent = Intent(this, ForegroundTickerService::class.java)
stopService(intent)
result.success(true)
}
"scheduleAlarm" -> {
val intervalSeconds = call.argument<Int>("intervalSeconds") ?: 900
scheduleAlarm(this, intervalSeconds)
result.success(true)
}
"cancelAlarm" -> {
cancelAlarm(this)
result.success(true)
}
"openBatteryOptimizationSettings" -> {
openBatteryOptimizationSettings()
result.success(true)
}
"openAutostartSettings" -> {
openAutostartSettings()
result.success(true)
}
else -> result.notImplemented()
}
}

// Handle preferences channel for BootReceiver persistence
MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PREFS_CHANNEL).setMethodCallHandler { call, result ->
when (call.method) {
"saveInterval" -> {
val interval = call.argument<Int>("interval") ?: 900 // default 15 min
getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
.edit()
.putInt("interval_minutes", interval / 60)
.apply()
result.success(true)
}
else -> result.notImplemented()
}
}
}

private fun checkAndRequestNotificationPermission() {
    // Request POST_NOTIFICATIONS (Android 13+)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        val permission = Manifest.permission.POST_NOTIFICATIONS
        if (ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(permission), REQUEST_CODE_POST_NOTIFICATIONS)
        }
    }
    
    // Request SCHEDULE_EXACT_ALARM permission (Android 12+)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (!alarmManager.canScheduleExactAlarms()) {
            // Open settings so user can grant the permission
            try {
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
            } catch (e: Exception) {
                Log.e("MainActivity", "Failed to open exact alarm settings: ${e.message}")
            }
        }
    }
}

private fun openBatteryOptimizationSettings() {
try {
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
intent.data = Uri.parse("package:$packageName")
startActivity(intent)
}
} catch (e: Exception) {
Log.e("MainActivity", "Failed to open battery optimization settings: ${e.message}")
}
}

private fun openAutostartSettings() {
try {
val manufacturer = Build.MANUFACTURER.lowercase()
val autoStartIntent = when {
manufacturer.contains("xiaomi") || manufacturer.contains("redmi") -> {
Intent().setClassName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
}
manufacturer.contains("huawei") || manufacturer.contains("honor") -> {
Intent().setComponent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"))
}
manufacturer.contains("oppo") -> {
Intent().setClassName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")
}
manufacturer.contains("vivo") -> {
Intent().setClassName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity")
}
manufacturer.contains("realme") -> {
Intent().setClassName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")
}
manufacturer.contains("samsung") -> {
Intent().setComponent(ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity"))
}
manufacturer.contains("oneplus") -> {
Intent().setComponent(ComponentName("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"))
}
else -> {
// Fallback: open app battery settings
Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
data = Uri.parse("package:$packageName")
}
}
}
startActivity(autoStartIntent)
} catch (e: Exception) {
Log.e("MainActivity", "Failed to open autostart settings: ${e.message}")
try {
// Ultimate fallback
val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
intent.data = Uri.parse("package:$packageName")
startActivity(intent)
} catch (e2: Exception) {
Log.e("MainActivity", "Ultimate fallback failed: ${e2.message}")
}
}
}

override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
super.onRequestPermissionsResult(requestCode, permissions, grantResults)
if (requestCode == REQUEST_CODE_POST_NOTIFICATIONS) {
if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
Log.d("MainActivity", "POST_NOTIFICATIONS granted")
} else {
Log.d("MainActivity", "POST_NOTIFICATIONS denied")
}
}
}

private fun scheduleAlarm(context: Context, intervalSeconds: Int) {
try {
    // CRITICAL: Save interval to SharedPreferences so AlarmReceiver and BootReceiver can read it
    val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    prefs.edit().putInt("interval_minutes", intervalSeconds / 60).apply()
    Log.d("MainActivity", "Saved interval: ${intervalSeconds / 60} minutes")

    val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    val intent = Intent(context, AlarmReceiver::class.java)
    val pendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    // Cancel any existing alarm
    alarmManager.cancel(pendingIntent)

    // Schedule repeating alarm (exact alarm for Android 12+)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        if (alarmManager.canScheduleExactAlarms()) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + (intervalSeconds * 1000L),
                pendingIntent
            )
            // Also set inexact repeating as backup
            alarmManager.setInexactRepeating(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + (intervalSeconds * 1000L),
                intervalSeconds.toLong(),
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
    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
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

    Log.d("MainActivity", "Alarm scheduled every $intervalSeconds seconds")
} catch (e: Exception) {
    Log.e("MainActivity", "Failed to schedule alarm: ${e.message}")
}
}

private fun cancelAlarm(context: Context) {
try {
val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
val intent = Intent(context, AlarmReceiver::class.java)
val pendingIntent = PendingIntent.getBroadcast(
context,
0,
intent,
PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
)
alarmManager.cancel(pendingIntent)
Log.d("MainActivity", "Alarm cancelled")
} catch (e: Exception) {
Log.e("MainActivity", "Failed to cancel alarm: ${e.message}")
}
}
}
