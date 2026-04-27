import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  SupabaseClient? client;

  factory SupabaseService() => _instance;
  SupabaseService._internal();

  /// Initialize Supabase client if not already initialized.
  Future<void> init() async {
    try {
      if (kSupabaseUrl.startsWith('REPLACE') ||
          kSupabaseAnonKey.startsWith('REPLACE')) {
        throw Exception(
          'Supabase URL or anon key not configured. Set values in lib/constants.dart',
        );
      }

      // Supabase.instance throws if not initialized yet. Try to read the client
      // and if that fails, initialize Supabase and read the client again.
      try {
        client = Supabase.instance.client;
        if (client != null) return;
      } catch (_) {
        // not initialized yet - continue to initialize
      }

      await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey);
      client = Supabase.instance.client;
    } catch (e, st) {
      developer.log('Supabase init error: $e', stackTrace: st);
      rethrow;
    }
  }

}
