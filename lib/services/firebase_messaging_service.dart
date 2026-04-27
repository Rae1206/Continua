import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../constants.dart';
import 'notification_controller.dart';

/// Intervalos disponibles para notificaciones
class NotificationIntervals {
  static const Map<String, int> options = {
    '15 minutos': 900,
    '30 minutos': 1800,
    '1 hora': 3600,
    '2 horas': 7200,
    '6 horas': 21600,
    '12 horas': 43200,
    '24 horas': 86400,
  };

  static int getDefault() => 900; // 15 minutos
}

/// Service to handle Firebase Cloud Messaging (FCM) for push notifications.
/// This enables notifications when the app is closed or in background.
class FirebaseMessagingService {
  static FirebaseMessaging? _messaging;
  static bool _isInitialized = false;
  static String? _currentToken;
  static String? _deviceId;
  static final Uuid _uuid = const Uuid();

  /// Initialize Firebase and FCM
  static Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      debugPrint('Firebase: Starting initialization...');

      // Initialize Firebase Core
      await Firebase.initializeApp();
      debugPrint('Firebase: Core initialized');

      _messaging = FirebaseMessaging.instance;
      debugPrint('Firebase: Messaging instance created');

      // Request permission
      await _requestPermission();
      debugPrint('Firebase: Permission requested');

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages when app is opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Get initial message if app was launched from notification (cold start)
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _handleInitialMessage(initialMessage);
      }

      // Try to get token - but don't wait forever
      try {
        final token = await _getToken().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('Firebase: Token timeout');
            return null;
          },
        );

        if (token != null) {
          _currentToken = token;
          debugPrint('Firebase: Got token, saving to Supabase');
          await _saveTokenToSupabase(token);
        }
      } catch (e) {
        debugPrint('Firebase: Token error (non-blocking): $e');
      }

      await registerDevice();

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh);

      _isInitialized = true;
      debugPrint('Firebase Messaging initialized successfully');
      return true;
    } catch (e, st) {
      debugPrint('Error initializing Firebase Messaging: $e - $st');
      return false;
    }
  }

  static Future<void> _requestPermission() async {
    try {
      final settings = await _messaging?.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings?.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('Notification permission granted');
      } else if (settings?.authorizationStatus ==
          AuthorizationStatus.provisional) {
        debugPrint('Provisional notification permission granted');
      } else {
        debugPrint('Notification permission denied');
      }
    } catch (e) {
      debugPrint('Error requesting permission: $e');
    }
  }

  static Future<String?> _getToken() async {
    try {
      final token = await _messaging?.getToken(vapidKey: _getVapidKey());
      return token;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  static String _getVapidKey() {
    return 'BLJjD8J8DMxkGH7ofOt5CY8pSr1CvS4FMM9KwwtRDaQyLhYY74FQ3llqYq77rx9z_bm_qJ6bHclqkn05C1XXT5w';
  }

  /// Obtener o crear ID único del dispositivo
  static Future<String> _getOrCreateDeviceId() async {
    if (_deviceId != null) return _deviceId!;

    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id');

    if (_deviceId == null) {
      _deviceId = _uuid.v4();
      await prefs.setString('device_id', _deviceId!);
    }

    return _deviceId!;
  }

  /// Obtener intervalo guardado localmente
  static Future<int> _getStoredInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('interval_seconds') ??
        NotificationIntervals.getDefault();
  }

  /// Guardar intervalo localmente
  static Future<void> _storeIntervalLocally(int intervalSeconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('interval_seconds', intervalSeconds);
  }

  static Future<bool> _ensureSupabaseClient() async {
    try {
      final client = Supabase.instance.client;
      if (client != null) {
        return true;
      }
    } catch (_) {
      // not initialized yet
    }

    try {
      debugPrint('Initializing Supabase for device registration...');
      await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey);
      return true;
    } catch (e) {
      debugPrint('Supabase init failed: $e');
      return false;
    }
  }

  static String _normalizeText(String text) {
    if (text.isEmpty) return text;
    final bytes = latin1.encode(text);
    final utf8Text = utf8.decode(bytes, allowMalformed: true);
    return utf8Text
        .replaceAll('\u0000', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll('Ã', 'Á')
        .replaceAll('Ã‰', 'É')
        .replaceAll('Ã', 'Í')
        .replaceAll('Ã“', 'Ó')
        .replaceAll('Ãš', 'Ú')
        .replaceAll('Ã‘', 'Ñ')
        .replaceAll('Ã¡', 'á')
        .replaceAll('Ã©', 'é')
        .replaceAll('Ã­', 'í')
        .replaceAll('Ã³', 'ó')
        .replaceAll('Ãº', 'ú')
        .replaceAll('Ã±', 'ñ')
        .replaceAll('Â¿', '¿')
        .replaceAll('Â¡', '¡')
        .replaceAll('â€œ', '“')
        .replaceAll('â€', '”')
        .replaceAll('â€˜', '‘')
        .replaceAll('â€™', '’')
        .replaceAll('â€“', '–')
        .replaceAll('â€”', '—');
  }

  /// Guardar dispositivo con token en Supabase
  static Future<bool> _saveTokenToSupabase(String token) async {
    return _upsertDevice(token: token);
  }

  static Future<bool> _upsertDevice({
    String? token,
    int? intervalSeconds,
  }) async {
    try {
      final ready = await _ensureSupabaseClient();
      if (!ready) {
        debugPrint('ERROR: No se pudo inicializar Supabase');
        return false;
      }

      final client = Supabase.instance.client;
      final deviceId = await _getOrCreateDeviceId();
      final interval = intervalSeconds ?? await _getStoredInterval();

      final response = await client.from('devices').upsert({
        'id': deviceId,
        'fcm_token': token,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'interval_seconds': interval,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id').select();

      debugPrint(
        'Device upsert: $deviceId (interval: ${interval}s, token:${token != null}) - Response: $response',
      );
      return response != null;
    } catch (e, st) {
      debugPrint('Error upserting device in Supabase: $e - $st');
      return false;
    }
  }

  /// Actualizar intervalo de notificaciones
  static Future<void> updateIntervalPreference(int intervalSeconds) async {
    try {
      final ready = await _ensureSupabaseClient();
      if (!ready) return;

      final deviceId = await _getOrCreateDeviceId();
      debugPrint('Updating interval for device: $deviceId');

      // Si no tenemos token, esperar y reintentar hasta 3 veces
      if (_currentToken == null) {
        debugPrint('No FCM token, waiting and retrying...');
        for (int i = 0; i < 3; i++) {
          await Future.delayed(Duration(seconds: i + 1));
          _currentToken = await _getToken();
          if (_currentToken != null) {
            debugPrint('FCM token obtained after ${i + 1} attempts');
            break;
          }
        }
      }

      // Guardar localmente
      await _storeIntervalLocally(intervalSeconds);

      await _upsertDevice(token: _currentToken, intervalSeconds: intervalSeconds);
    } catch (e, st) {
      debugPrint('Error updating interval: $e - $st');
    }
  }

  /// Obtener el intervalo actual
  static Future<int> getCurrentInterval() async {
    final deviceId = await _getOrCreateDeviceId();
    try {
      final client = Supabase.instance.client;
      if (client == null) return NotificationIntervals.getDefault();

      final response = await client
          .from('devices')
          .select('interval_seconds')
          .eq('id', deviceId)
          .maybeSingle();

      if (response != null && response['interval_seconds'] != null) {
        return response['interval_seconds'] as int;
      }
    } catch (e) {
      debugPrint('Error getting interval: $e');
    }
    return await _getStoredInterval();
  }

  /// Register device in Supabase - call this when app starts
  static Future<bool> registerDevice() async {
    try {
      final ready = await _ensureSupabaseClient();
      if (!ready) return false;

      // Get or create device ID
      final deviceId = await _getOrCreateDeviceId();

      // Get FCM token (can be null on first attempts)
      final token = await _getToken();
      _currentToken = token;

      // Get stored interval
      final intervalSeconds = await _getStoredInterval();

      // Save to Supabase even when token is null (keeps row alive)
      await _upsertDevice(token: token, intervalSeconds: intervalSeconds);

      debugPrint(
        'Device registered/upserted: $deviceId (token:${token != null})',
      );
      return true;
    } catch (e, st) {
      debugPrint('Error registering device: $e - $st');
      return false;
    }
  }

  /// Desactivar notificaciones (borrar token)
  static Future<void> disableNotifications() async {
    try {
      final ready = await _ensureSupabaseClient();
      if (!ready) {
        await _storeIntervalLocally(0);
        return;
      }

      await _storeIntervalLocally(0); // 0 = desactivado
      await _upsertDevice(token: null, intervalSeconds: 0);
      debugPrint('Notifications disabled');
    } catch (e) {
      debugPrint('Error disabling notifications: $e');
    }
  }

  /// Reactivar notificaciones
  static Future<void> enableNotifications() async {
    final token = await _getToken();
    if (token != null) {
      _currentToken = token;
      await _storeIntervalLocally(NotificationIntervals.getDefault());
      await registerDevice();
      await _saveTokenToSupabase(token);
    }
  }

  static Future<void> _onTokenRefresh(String token) async {
    debugPrint('FCM Token refreshed: $token');
    _currentToken = token;
    await registerDevice();
    await _saveTokenToSupabase(token);
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Received foreground message: ${message.notification?.title}');

    final data = message.data;
    final rawText = data['text'] as String? ?? message.notification?.body ?? '';
    final rawAuthor = data['author'] as String? ??
        data['reference'] as String? ??
        'Unknown';

    final text = _normalizeText(rawText);
    final author = _normalizeText(rawAuthor);

    NotificationController.showNotification(text, author);
    unawaited(registerDevice());
  }

  static void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('App opened from notification: ${message.notification?.title}');
    unawaited(registerDevice());
    _processMessage(message);
  }

  static void _handleInitialMessage(RemoteMessage message) {
    debugPrint(
      'App launched from notification: ${message.notification?.title}',
    );
    unawaited(registerDevice());
    _processMessage(message);
  }

  static void _processMessage(RemoteMessage message) {
    final data = message.data;
    debugPrint('Message data: ${jsonEncode(data)}');
  }

  static Future<bool> subscribeToTopic(String topic) async {
    try {
      await _messaging?.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
      return true;
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
      return false;
    }
  }

  static Future<bool> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging?.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
      return true;
    } catch (e) {
      debugPrint('Error unsubscribing from topic: $e');
      return false;
    }
  }

  static Future<void> deleteToken() async {
    try {
      await _messaging?.deleteToken();
      debugPrint('FCM token deleted');
    } catch (e) {
      debugPrint('Error deleting token: $e');
    }
  }

  static Future<String?> getToken() async {
    return _currentToken ?? await _messaging?.getToken();
  }
}
