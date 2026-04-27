import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../models/bible_verse.dart';

class BibleVerseService {
  static const String _baseUrl = 'https://esbiblia.net/api';
  static const String _version = 'rvr';

  static const BibleVerse fallbackVerse = BibleVerse(
    reference: 'Filipenses 4:13',
    text: 'Todo lo puedo en Cristo que me fortalece.',
  );

  Future<BibleVerse> fetchRandomVerse({bool allowFallback = true}) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/random/?v=$_version'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('EsBiblia respondió ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final verses = data['verses'];
        if (verses is List && verses.isNotEmpty) {
          final first = verses.first;
          if (first is Map<String, dynamic>) {
            final bookName = first['book_name']?.toString().trim() ?? '';
            final bookId = first['book_id']?.toString().trim() ?? '';
            final chapter = first['chapter']?.toString().trim() ?? '';
            final verse = first['verse']?.toString().trim() ?? '';
            final text = _cleanText(first['text']?.toString() ?? '');
            if (text.isNotEmpty) {
              final reference = _buildReference(
                data['reference']?.toString(),
                bookName: bookName,
                bookId: bookId,
                chapter: chapter,
                verse: verse,
              );
              return BibleVerse(reference: reference, text: text);
            }
          }
        }
      }

      throw Exception('Respuesta inesperada de EsBiblia');
    } catch (e, st) {
      developer.log('fetchRandomVerse error: $e', stackTrace: st);
      if (allowFallback) return fallbackVerse;
      rethrow;
    }
  }

  String _buildReference(
    String? apiReference, {
    required String bookName,
    required String bookId,
    required String chapter,
    required String verse,
  }) {
    final cleanApiReference = _cleanText(apiReference ?? '');
    final fallbackReference = [
      bookName.isNotEmpty ? bookName : bookId,
      if (chapter.isNotEmpty && verse.isNotEmpty) '$chapter:$verse',
    ].join(' ').trim();

    if (cleanApiReference.isNotEmpty &&
        !cleanApiReference.contains('None') &&
        !cleanApiReference.endsWith('None')) {
      return cleanApiReference;
    }

    return fallbackReference.isNotEmpty ? fallbackReference : fallbackVerse.reference;
  }

  String _cleanText(String input) {
    final normalized = input
        .replaceAll('\u0000', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return normalized
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
}
