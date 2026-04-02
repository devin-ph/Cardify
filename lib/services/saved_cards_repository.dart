import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/analysis_result.dart';
import '../models/saved_card.dart';

class SavedCardsRepository {
  SavedCardsRepository._();

  static final SavedCardsRepository instance = SavedCardsRepository._();

  final List<SavedCard> _cards = [];
  SupabaseClient get _client => Supabase.instance.client;

  String get _bucketName => dotenv.maybeGet('SUPABASE_BUCKET') ?? 'btl';
  String get _tableName => dotenv.maybeGet('SUPABASE_TABLE') ?? 'flashcards';

  List<SavedCard> get cards => List.unmodifiable(_cards);

  bool containsWord(String normalizedWord) {
    return _cards.any((card) => card.id == normalizedWord);
  }

  Future<String?> findExistingWord(String normalizedWord) async {
    final localMatch = _cards.where((card) => card.id == normalizedWord);
    if (localMatch.isNotEmpty) {
      return localMatch.first.word;
    }

    try {
      final row = await _client
          .from(_tableName)
          .select('word')
          .ilike('word', normalizedWord)
          .limit(1)
          .maybeSingle();
      return row == null ? null : row['word']?.toString();
    } on PostgrestException {
      return null;
    }
  }

  Future<SavedCard?> saveResult(
    AnalysisResult result,
    Uint8List? imageBytes,
  ) async {
    final normalized = result.normalizedWord;
    if (normalized.isEmpty) {
      throw Exception('Không thể lưu thẻ thiếu từ vựng');
    }
    final existingWord = await findExistingWord(normalized);
    if (existingWord != null) {
      return null;
    }
    final timestamp = DateTime.now();
    String? imageUrl;

    try {
      if (imageBytes != null && imageBytes.isNotEmpty) {
        imageUrl = await _uploadImage(imageBytes, normalized);
      }

      await _client.from(_tableName).insert({
        'word': result.word,
        'topic': result.topic,
        'phonetic': result.phonetic,
        'meaning': result.vietnameseMeaning,
        'word_type': result.wordType,
        'example': result.exampleSentence,
        'image_url': imageUrl,
        'saved_at': timestamp.toIso8601String(),
      });
    } on StorageException catch (error) {
      throw Exception('Lỗi tải ảnh lên Supabase: ${error.message}');
    } on PostgrestException catch (error) {
      throw Exception('Lỗi lưu dữ liệu Supabase: ${error.message}');
    }

    final card = SavedCard.fromAnalysisResult(
      result,
      imageBytes,
      remoteUrl: imageUrl,
      timestamp: timestamp,
    );
    _upsertLocalCard(card);
    return card;
  }

  Future<SavedCard> replaceExistingWord({
    required String existingWord,
    required AnalysisResult result,
    Uint8List? imageBytes,
  }) async {
    final timestamp = DateTime.now();
    String? imageUrl;

    try {
      if (imageBytes != null && imageBytes.isNotEmpty) {
        imageUrl = await _uploadImage(imageBytes, result.normalizedWord);
      }

      final updatedRow = await _client
          .from(_tableName)
          .update({
            'word': result.word,
            'topic': result.topic,
            'phonetic': result.phonetic,
            'meaning': result.vietnameseMeaning,
            'word_type': result.wordType,
            'example': result.exampleSentence,
            if (imageUrl != null) 'image_url': imageUrl,
            'saved_at': timestamp.toIso8601String(),
          })
          .eq('word', existingWord)
          .select()
          .maybeSingle();

      if (updatedRow == null) {
        throw Exception('Khong tim thay tu can cap nhat trong Supabase');
      }
    } on StorageException catch (error) {
      throw Exception('Loi tai anh len Supabase: ${error.message}');
    } on PostgrestException catch (error) {
      throw Exception('Loi cap nhat du lieu Supabase: ${error.message}');
    }

    final card = SavedCard.fromAnalysisResult(
      result,
      imageBytes,
      remoteUrl: imageUrl,
      timestamp: timestamp,
    );
    _upsertLocalCard(card);
    return card;
  }

  void _upsertLocalCard(SavedCard card) {
    final index = _cards.indexWhere((item) => item.id == card.id);
    if (index >= 0) {
      _cards[index] = card;
    } else {
      _cards.add(card);
    }
  }

  Future<String> _uploadImage(Uint8List bytes, String normalizedWord) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_$normalizedWord.jpg';
    final path = 'cards/$fileName';
    await _client.storage
        .from(_bucketName)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    return _client.storage.from(_bucketName).getPublicUrl(path);
  }

  Stream<List<SavedCard>> watchCards() {
    return _client
        .from(_tableName)
        .stream(primaryKey: ['word'])
        .order('saved_at', ascending: false)
        .map((rows) {
          final mapped = rows.map((row) => SavedCard.fromMap(row)).toList();
          _cards
            ..clear()
            ..addAll(mapped);
          return mapped;
        });
  }
}
