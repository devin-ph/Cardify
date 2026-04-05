import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/topic_classifier.dart';

class VocabularyHint {
  final String id;
  final String topic;
  final String meaning;
  final String hint;
  final String maskedMeaning;
  final String hintVi;
  final DateTime createdAt;

  VocabularyHint({
    required this.id,
    required this.topic,
    required this.meaning,
    required this.hint,
    required this.maskedMeaning,
    required this.hintVi,
    required this.createdAt,
  });

  factory VocabularyHint.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'];
    DateTime timestamp;
    if (createdAtRaw is String) {
      timestamp = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    } else if (createdAtRaw is DateTime) {
      timestamp = createdAtRaw;
    } else {
      timestamp = DateTime.now();
    }

    return VocabularyHint(
      id: json['id']?.toString() ?? '',
      topic: json['topic']?.toString() ?? '',
      meaning: json['meaning']?.toString() ?? '',
      hint: json['hint']?.toString() ?? '',
      maskedMeaning: json['masked_meaning']?.toString() ?? '',
      hintVi: json['hint_vi']?.toString() ?? '',
      createdAt: timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topic': topic,
      'meaning': meaning,
      'hint': hint,
      'masked_meaning': maskedMeaning,
      'hint_vi': hintVi,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class VocabularyService {
  static final VocabularyService instance = VocabularyService._();
  VocabularyService._();

  final List<VocabularyHint> _hints = [];
  final ValueNotifier<List<VocabularyHint>> hintsNotifier =
      ValueNotifier<List<VocabularyHint>>([]);

  bool _initialized = false;
  bool _canWriteHintsRemotely = true;

  Future<void> loadHints() async {
    if (_initialized) return;
    try {
      final client = Supabase.instance.client;

      final response = await client.from('vocabulary_hints').select();

      _hints.clear();
      for (final row in response as List<dynamic>) {
        _hints.add(VocabularyHint.fromJson(row as Map<String, dynamic>));
      }
      hintsNotifier.value = List.unmodifiable(_hints);
      _initialized = true;
    } catch (e) {
      debugPrint('Error loading vocabulary hints: $e');
    }
  }

  Map<String, int> getTopicCounts() {
    final counts = <String, int>{};
    for (final hint in _hints) {
      final topic = TopicClassifier.toVietnameseCanonical(hint.topic);
      counts[topic] = (counts[topic] ?? 0) + 1;
    }
    return counts;
  }

  List<VocabularyHint> getUnscannedHints(Set<String> knownWords) {
    return _hints.where((h) {
      final word = h.meaning.toLowerCase().trim();
      return !knownWords.any((k) => k.toLowerCase() == word);
    }).toList();
  }

  Future<String?> findVocabularyIdByMeaning(String meaning) async {
    try {
      final client = Supabase.instance.client;
      final normalizedMeaning = meaning.toLowerCase().trim();
      if (normalizedMeaning.isEmpty) {
        return null;
      }

      Future<String?> lookupByPattern(String pattern) async {
        final row = await client
            .from('vocabulary_hints')
            .select('id')
            .ilike('meaning', pattern)
            .limit(1)
            .maybeSingle();
        return row == null ? null : row['id']?.toString();
      }

      final exactId = await lookupByPattern(normalizedMeaning);
      if (exactId != null && exactId.isNotEmpty) {
        return exactId;
      }

      final compactMeaning = normalizedMeaning.replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      if (compactMeaning != normalizedMeaning) {
        final compactId = await lookupByPattern(compactMeaning);
        if (compactId != null && compactId.isNotEmpty) {
          return compactId;
        }
      }

      final fuzzyPattern = '%$normalizedMeaning%';
      final fuzzyId = await lookupByPattern(fuzzyPattern);
      if (fuzzyId != null && fuzzyId.isNotEmpty) {
        return fuzzyId;
      }

      // Some datasets keep Vietnamese labels in hint_vi instead of meaning.
      try {
        final row = await client
            .from('vocabulary_hints')
            .select('id')
            .ilike('hint_vi', fuzzyPattern)
            .limit(1)
            .maybeSingle();
        return row == null ? null : row['id']?.toString();
      } on PostgrestException {
        return null;
      }
    } catch (e) {
      debugPrint('Error finding vocabulary by meaning: $e');
      return null;
    }
  }

  Future<String?> insertVocabularyHint({
    required String topic,
    required String meaning,
    required String hint,
    required String maskedMeaning,
    required String hintVi,
  }) async {
    try {
      final client = Supabase.instance.client;
      final normalizedMeaning = meaning.trim().toLowerCase();
      if (normalizedMeaning.isEmpty) return null;

      final existingId = await findVocabularyIdByMeaning(normalizedMeaning);
      if (existingId != null && existingId.isNotEmpty) {
        return existingId;
      }

      if (!_canWriteHintsRemotely) {
        return null;
      }

      final response = await client
          .from('vocabulary_hints')
          .insert({
            'topic': topic,
            'meaning': normalizedMeaning,
            'hint': hint,
            'masked_meaning': maskedMeaning,
            'hint_vi': hintVi,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .maybeSingle();

      if (response != null && response['id'] != null) {
        return response['id']?.toString();
      }

      final fallback = await client
          .from('vocabulary_hints')
          .select('id')
          .ilike('meaning', normalizedMeaning)
          .limit(1)
          .maybeSingle();

      return fallback == null ? null : fallback['id']?.toString();
    } on PostgrestException catch (error) {
      if (error.code == '42501') {
        // RLS denied: skip future remote writes to avoid repeated runtime spam.
        _canWriteHintsRemotely = false;
        return null;
      }

      if (error.code == '23505') {
        final existing = await findVocabularyIdByMeaning(meaning);
        return existing;
      }

      debugPrint('Error inserting vocabulary hint: $error');
      return null;
    } catch (e) {
      debugPrint('Error inserting vocabulary hint: $e');
      return null;
    }
  }

  Future<void> addCustomHintIfNeeded(String word, String topic) async {
    if (!_canWriteHintsRemotely) {
      return;
    }

    final wordLower = word.toLowerCase().trim();
    final exists = _hints.any(
      (h) => h.meaning.toLowerCase().trim() == wordLower,
    );
    if (exists) return;

    try {
      final maskedMeaning = word.replaceAll(RegExp(r'[aeiou]'), '*');
      final hintVi = 'Từ vựng tạo của bạn';

      final client = Supabase.instance.client;
      final response = await client.from('vocabulary_hints').insert({
        'topic': topic,
        'meaning': word,
        'hint': '',
        'masked_meaning': maskedMeaning,
        'hint_vi': hintVi,
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      if (response.isNotEmpty) {
        final newHint = VocabularyHint.fromJson(response[0]);
        _hints.add(newHint);
        hintsNotifier.value = List.unmodifiable(_hints);
      }
    } on PostgrestException catch (error) {
      if (error.code == '42501') {
        _canWriteHintsRemotely = false;
        return;
      }
      debugPrint('Error adding custom hint: $error');
    } catch (e) {
      debugPrint('Error adding custom hint: $e');
    }
  }
}
