import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'supabase_service.dart';
import 'notification_controller.dart';

const String fetchQuoteTask = 'fetchQuoteTask';
const String _channelName = 'keep_going/preferences';

// Track initialization to avoid multiple Workmanager.initialize calls.
bool _workmanagerInitialized = false;

/// Save interval to native SharedPreferences so BootReceiver can read it.
/// This ensures the interval persists across app uninstall/reinstall or boot.
Future<void> _saveIntervalToNative(int intervalSeconds) async {
  try {
    const channel = MethodChannel(_channelName);
    await channel.invokeMethod('saveInterval', {'interval': intervalSeconds});
  } catch (_) {}
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      log('Background task executed: $task');
      final svc = SupabaseService();
      await svc.init();
      final quote = await svc.fetchRandomQuote();
      if (quote != null) {
        log('Quote: ${quote.text} — ${quote.author}');
        try {
          // Try to show the native notification via MethodChannel.
          await NotificationController.showNotification(
            quote.text,
            quote.author,
          );
        } catch (e) {
          log('Failed to show notification via MethodChannel: $e');
        }
      }
    } catch (e, s) {
      log('Background task error: $e', stackTrace: s);
    }
    return Future.value(true);
  });
}

/// Register or update a periodic background task using Workmanager.
///
/// `intervalSeconds` is the desired interval in seconds. Note: on Android
/// `WorkManager` enforces a minimum periodic interval (usually 15 minutes).
/// If a smaller interval is requested, the worker will be scheduled with
/// the platform minimum (15 minutes) and a log entry will be emitted.
Future<void> registerPeriodicBackgroundSeconds(int intervalSeconds) async {
  if (!_workmanagerInitialized) {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
    _workmanagerInitialized = true;
  }

  // WorkManager on Android has a minimum periodic interval (≈15 minutes).
  final minSeconds = 15 * 60;
  Duration freq;
  if (intervalSeconds < minSeconds) {
    log(
      'Requested interval $intervalSeconds s is below platform minimum. Using $minSeconds s instead.',
    );
    freq = Duration(seconds: minSeconds);
  } else {
    freq = Duration(seconds: intervalSeconds);
  }

  // Save to native prefs for BootReceiver persistence
  await _saveIntervalToNative(freq.inSeconds);

  await Workmanager().registerPeriodicTask(
    'keep_going_periodic',
    fetchQuoteTask,
    frequency: freq,
    existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
  );
}

/// Backwards-compatible convenience function that registers with 1 hour.
Future<void> registerPeriodicBackground() async =>
    registerPeriodicBackgroundSeconds(60 * 60);
