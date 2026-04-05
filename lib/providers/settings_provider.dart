import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firebase_messaging_service.dart';

class SettingsState {
  final int intervalSeconds;
  final bool notificationsEnabled;

  SettingsState({
    required this.intervalSeconds,
    required this.notificationsEnabled,
  });

  SettingsState copyWith({int? intervalSeconds, bool? notificationsEnabled}) =>
      SettingsState(
        intervalSeconds: intervalSeconds ?? this.intervalSeconds,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      );

  /// Obtener texto del intervalo
  String get intervalText {
    for (final entry in NotificationIntervals.options.entries) {
      if (entry.value == intervalSeconds) {
        return entry.key;
      }
    }
    return '$intervalSeconds segundos';
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  static const _prefsKeyInterval = 'interval_seconds';
  static const _prefsKeyEnabled = 'notifications_enabled';

  SettingsNotifier()
    : super(
        SettingsState(
          intervalSeconds: NotificationIntervals.getDefault(),
          notificationsEnabled: true,
        ),
      );

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final interval =
        prefs.getInt(_prefsKeyInterval) ?? NotificationIntervals.getDefault();
    final enabled = prefs.getBool(_prefsKeyEnabled) ?? true;

    state = state.copyWith(
      intervalSeconds: interval,
      notificationsEnabled: enabled,
    );
  }

  /// Cambiar intervalo de notificaciones
  Future<void> setIntervalSeconds(int seconds) async {
    // Actualizar estado local
    state = state.copyWith(intervalSeconds: seconds);

    // Guardar en SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKeyInterval, seconds);

    // Actualizar en Supabase (tabla devices)
    if (state.notificationsEnabled) {
      await FirebaseMessagingService.updateIntervalPreference(seconds);
    }
  }

  /// Activar/desactivar notificaciones
  Future<void> setNotificationsEnabled(bool enabled) async {
    state = state.copyWith(notificationsEnabled: enabled);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyEnabled, enabled);

    if (enabled) {
      await FirebaseMessagingService.enableNotifications();
    } else {
      await FirebaseMessagingService.disableNotifications();
    }
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    return SettingsNotifier();
  },
);
