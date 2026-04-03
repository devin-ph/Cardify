import 'dart:typed_data';
import 'dart:convert';

import 'analysis_result.dart';

class SavedCard {
  final String id;
  final String topic;
  final String word;
  final String phonetic;
  final String meaning;
  final String example;
  final String? wordType;
  final Uint8List? imageBytes;
  final String? imageUrl;
  final DateTime savedAt;

  SavedCard({
    required this.id,
    required this.topic,
    required this.word,
    required this.phonetic,
    required this.meaning,
    required this.example,
    this.wordType,
    required this.imageBytes,
    this.imageUrl,
    required this.savedAt,
  });

  factory SavedCard.fromAnalysisResult(
    AnalysisResult result,
    Uint8List? bytes, {
    String? remoteUrl,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    return SavedCard(
      id: result.normalizedWord,
      topic: result.topic,
      word: result.word,
      phonetic: result.phonetic,
      meaning: result.vietnameseMeaning,
      example: result.exampleSentence,
      wordType: result.wordType,
      imageBytes: bytes,
      imageUrl: remoteUrl,
      savedAt: now,
    );
  }

  factory SavedCard.fromMap(Map<String, dynamic> data) {
    final savedAtRaw = data['saved_at'];
    DateTime timestamp;
    if (savedAtRaw is String) {
      timestamp = DateTime.tryParse(savedAtRaw) ?? DateTime.now();
    } else if (savedAtRaw is DateTime) {
      timestamp = savedAtRaw;
    } else {
      timestamp = DateTime.now();
    }

    final normalizedId = (data['word'] ?? data['id'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    Uint8List? restoredImageBytes;
    final imageBase64Raw = data['image_bytes_base64']?.toString();
    if (imageBase64Raw != null && imageBase64Raw.trim().isNotEmpty) {
      try {
        restoredImageBytes = base64Decode(imageBase64Raw.trim());
      } catch (_) {
        restoredImageBytes = null;
      }
    }

    return SavedCard(
      id: normalizedId.isEmpty
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : normalizedId,
      topic: data['topic']?.toString() ?? 'General',
      word: data['word']?.toString() ?? '',
      phonetic: data['phonetic']?.toString() ?? '',
      meaning: data['meaning']?.toString() ?? '',
      example: data['example']?.toString() ?? '',
      wordType: data['word_type']?.toString(),
      imageBytes: restoredImageBytes,
      imageUrl: data['image_url']?.toString(),
      savedAt: timestamp,
    );
  }
}
