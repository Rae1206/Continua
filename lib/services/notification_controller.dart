import 'package:flutter/services.dart';

class NotificationController {
  static const MethodChannel _channel = MethodChannel(
    'keep_going/notification',
  );

  // overlay permission removed; no-op kept for compatibility if called elsewhere
  static Future<bool> requestPermission() async => Future.value(false);

  static Future<bool> requestNotificationPermission() async {
    try {
      final res = await _channel.invokeMethod('requestNotificationPermission');
      return res == true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> showNotification(String text, String author) async {
    try {
      final res = await _channel.invokeMethod('showNotification', {
        'text': text,
        'author': author,
      });
      return res == true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> startForegroundTicker(int intervalSeconds) async {
    try {
      final res = await _channel.invokeMethod('startForegroundTicker', {
        'intervalSeconds': intervalSeconds,
      });
      return res == true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> stopForegroundTicker() async {
    try {
      final res = await _channel.invokeMethod('stopForegroundTicker');
      return res == true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> stopNotification() async {
    try {
      final res = await _channel.invokeMethod('stopNotification');
      return res == true;
    } catch (e) {
      return false;
    }
  }

  // AlarmManager-based scheduling (more reliable than WorkManager)
  static Future<bool> scheduleAlarm(int intervalSeconds) async {
    try {
      final res = await _channel.invokeMethod('scheduleAlarm', {
        'intervalSeconds': intervalSeconds,
      });
      return res == true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> cancelAlarm() async {
    try {
      final res = await _channel.invokeMethod('cancelAlarm');
      return res == true;
    } catch (e) {
      return false;
    }
  }

  // Open device settings for battery optimization
  static Future<bool> openBatteryOptimizationSettings() async {
    try {
      final res = await _channel.invokeMethod(
        'openBatteryOptimizationSettings',
      );
      return res == true;
    } catch (e) {
      return false;
    }
  }

  // Open device settings for autostart (manufacturer-specific)
  static Future<bool> openAutostartSettings() async {
    try {
      final res = await _channel.invokeMethod('openAutostartSettings');
      return res == true;
    } catch (e) {
      return false;
    }
  }
}
