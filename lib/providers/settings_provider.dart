import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firebase_messaging_service.dart';
import '../services/notification_controller.dart';

class SettingsState {
  final int intervalSeconds;
  final bool notificationsEnabled;
  final List<String> preferredTags;

  SettingsState({
    required this.intervalSeconds,
    required this.notificationsEnabled,
    this.preferredTags = const [],
  });

  SettingsState copyWith({
    int? intervalSeconds,
    bool? notificationsEnabled,
    List<String>? preferredTags,
  }) =>
      SettingsState(
        intervalSeconds: intervalSeconds ?? this.intervalSeconds,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        preferredTags: preferredTags ?? this.preferredTags,
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
  static const _prefsKeyTags = 'preferred_tags';

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
    final tags = prefs.getStringList(_prefsKeyTags) ?? [];

    state = state.copyWith(
      intervalSeconds: interval,
      notificationsEnabled: enabled,
      preferredTags: tags,
    );
  }

  /// Cambiar intervalo de notificaciones
  Future<void> setIntervalSeconds(int seconds) async {
    // Actualizar estado local
    state = state.copyWith(intervalSeconds: seconds);

    // Guardar en SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKeyInterval, seconds);

    // Programar alarma local (AlarmManager) - más confiable que FCM en muchos Android
    if (state.notificationsEnabled) {
      await NotificationController.scheduleAlarm(seconds);
    }

    // Actualizar registro del dispositivo en Supabase (para cuando vuelva FCM)
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

  /// Actualizar tags/categorías preferidas
  Future<void> setPreferredTags(List<String> tags) async {
    state = state.copyWith(preferredTags: tags);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKeyTags, tags);

    if (state.notificationsEnabled) {
      await FirebaseMessagingService.updatePreferredTags(tags);
    }
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    return SettingsNotifier();
  },
);
