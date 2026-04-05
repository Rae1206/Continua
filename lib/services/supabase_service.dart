import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/quote.dart';
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

  /// Fetch a list of quotes from the `quotes` table. Returns empty list on no-data.
  Future<List<Quote>> fetchQuotes({int limit = 100}) async {
    if (client == null) throw Exception('Supabase not initialized');
    try {
      // Newer postgrest client returns the parsed body directly when awaited.
      final dynamic raw = await client!.from('quotes').select().limit(limit);
      if (raw == null) return [];

      // The postgrest client may return a List of maps or a Map wrapping a 'data' list.
      if (raw is List<dynamic>) {
        final list = raw.cast<Map<String, dynamic>>();
        return list
            .map((m) => Quote.fromMap(Map<String, dynamic>.from(m)))
            .toList();
      }

      if (raw is Map<String, dynamic>) {
        final inner = raw['data'];
        if (inner is List) {
          final list = inner.cast<Map<String, dynamic>>();
          return list
              .map((m) => Quote.fromMap(Map<String, dynamic>.from(m)))
              .toList();
        }
      }

      // Unknown shape — return empty list but log for debugging
      developer.log('Unexpected Supabase response shape: ${raw.runtimeType}');
      return [];
    } catch (e, st) {
      developer.log('fetchQuotes error: $e', stackTrace: st);
      rethrow;
    }
  }

  Future<Quote?> fetchRandomQuote() async {
    final list = await fetchQuotes(limit: 200);
    if (list.isEmpty) return null;
    list.shuffle();
    return list.first;
  }

  /// Save a new quote to the database
  Future<bool> saveQuote(String text, String author) async {
    if (client == null) {
      await init();
      if (client == null) return false;
    }

    try {
      await client!.from('quotes').insert({'text': text, 'author': author});
      return true;
    } catch (e, st) {
      developer.log('saveQuote error: $e', stackTrace: st);
      return false;
    }
  }
}
