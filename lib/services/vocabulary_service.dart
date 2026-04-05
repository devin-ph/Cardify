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

      final row = await client
          .from('vocabulary_hints')
          .select('id')
          .ilike('meaning', normalizedMeaning)
          .limit(1)
          .maybeSingle();

      return row == null ? null : row['id']?.toString();
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

      final response = await client
          .from('vocabulary_hints')
          .upsert({
            'topic': topic,
            'meaning': normalizedMeaning,
            'hint': hint,
            'masked_meaning': maskedMeaning,
            'hint_vi': hintVi,
            'created_at': DateTime.now().toIso8601String(),
          }, onConflict: 'meaning')
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
    } catch (e) {
      debugPrint('Error inserting vocabulary hint: $e');
      return null;
    }
  }

  Future<void> addCustomHintIfNeeded(String word, String topic) async {
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
    } catch (e) {
      debugPrint('Error adding custom hint: $e');
    }
  }
}
