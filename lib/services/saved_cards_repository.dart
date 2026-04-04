import 'topic_classifier.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/analysis_result.dart';
import '../models/saved_card.dart';

class SavedCardsRepository {
  SavedCardsRepository._();

  static final SavedCardsRepository instance = SavedCardsRepository._();

  final List<SavedCard> _cards = [];
  final Map<String, Set<String>> _knownWordsByTopic = <String, Set<String>>{};
  final ValueNotifier<List<SavedCard>> cardsNotifier =
      ValueNotifier<List<SavedCard>>(const <SavedCard>[]);
  final StreamController<List<SavedCard>> _cardsController =
      StreamController<List<SavedCard>>.broadcast();
  StreamSubscription<List<Map<String, dynamic>>>? _remoteSubscription;
  bool _watchingCards = false;
  String? _watchingScope;
  bool _localStateLoaded = false;
  String? _loadedScope;

  static const String _localCardsKey = 'saved_cards_local_json';
  static const String _localKnownWordsKey = 'known_words_local_json';

  SupabaseClient? get _clientOrNull {
    try {
      if (!dotenv.isInitialized) return null;

      final configuredUrl = dotenv.maybeGet('SUPABASE_URL')?.trim() ?? '';
      final configuredKey = dotenv.maybeGet('SUPABASE_ANON_KEY')?.trim() ?? '';
      if (configuredUrl.isEmpty ||
          configuredKey.isEmpty ||
          configuredUrl == 'https://example.supabase.co' ||
          configuredKey == 'example-key') {
        return null;
      }

      final client = Supabase.instance.client;
      final url = client.rest.url.toString();
      final isPlaceholderUrl = url.contains('example.supabase.co');
      if (isPlaceholderUrl) {
        return null;
      }
      return client;
    } catch (_) {
      return null;
    }
  }

  String get _bucketName => _dotenvValue('SUPABASE_BUCKET', 'btl');
  String get _tableName => _dotenvValue('SUPABASE_TABLE', 'flashcards');

  String _dotenvValue(String key, String fallback) {
    try {
      if (!dotenv.isInitialized) return fallback;
      return dotenv.maybeGet(key) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  String _storageScope() {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      return (userId == null || userId.isEmpty) ? 'anonymous' : userId;
    } catch (_) {
      return 'anonymous';
    }
  }

  List<SavedCard> get cards => List.unmodifiable(_cards);

  bool containsWord(String normalizedWord) {
    return _cards.any((card) => card.id == normalizedWord);
  }

  Set<String> _knownWordsForTopic(String topic) {
    return _knownWordsByTopic.putIfAbsent(topic.trim(), () => <String>{});
  }

  bool isKnown(String normalizedWord, {String? topic}) {
    final key = normalizedWord.trim().toLowerCase();
    if (key.isEmpty) {
      return false;
    }

    if (topic != null && topic.trim().isNotEmpty) {
      return _knownWordsForTopic(topic).contains(key);
    }

    return _knownWordsByTopic.values.any(
      (knownWords) => knownWords.contains(key),
    );
  }

  void markKnown(String normalizedWord, {String? topic}) {
    final key = normalizedWord.trim().toLowerCase();
    if (key.isEmpty) {
      return;
    }

    final topicName = topic?.trim();
    if (topicName != null && topicName.isNotEmpty) {
      final knownWords = _knownWordsForTopic(topicName);
      if (!knownWords.add(key)) {
        return;
      }
    } else {
      final alreadyKnown = _knownWordsByTopic.values.any(
        (knownWords) => knownWords.contains(key),
      );
      if (alreadyKnown) {
        return;
      }
      _knownWordsForTopic('General').add(key);
    }

    _publishCards();
    unawaited(_persistLocalState());
  }

  void unmarkKnown(String normalizedWord, {String? topic}) {
    final key = normalizedWord.trim().toLowerCase();
    if (key.isEmpty) {
      return;
    }

    if (topic != null && topic.trim().isNotEmpty) {
      final knownWords = _knownWordsByTopic[topic.trim()];
      if (knownWords != null && knownWords.remove(key)) {
        if (knownWords.isEmpty) {
          _knownWordsByTopic.remove(topic.trim());
        }
        _publishCards();
      }
      return;
    }

    var removed = false;
    final emptyTopics = <String>[];
    for (final entry in _knownWordsByTopic.entries) {
      if (entry.value.remove(key)) {
        removed = true;
        if (entry.value.isEmpty) {
          emptyTopics.add(entry.key);
        }
      }
    }
    for (final topicName in emptyTopics) {
      _knownWordsByTopic.remove(topicName);
    }
    if (removed) {
      _publishCards();
      unawaited(_persistLocalState());
    }
  }

  int knownCountForTopic(String topic) {
    return _knownWordsForTopic(topic).length;
  }

  int imageCountForTopic(String topic) {
    return _cards.where((card) {
      if (TopicClassifier.normalizeTopic(card.topic) != topic) {
        return false;
      }

      final hasImageBytes =
          card.imageBytes != null && card.imageBytes!.isNotEmpty;
      final hasImageUrl =
          card.imageUrl != null && card.imageUrl!.trim().isNotEmpty;
      return hasImageBytes || hasImageUrl;
    }).length;
  }

  int savedCountForTopic(String topic) {
    return _cards.where((card) => card.topic == topic).length;
  }

  int totalCountForTopic(String topic, {int baseCount = 50}) {
    final savedCount = savedCountForTopic(topic);
    return baseCount + savedCount;
  }

  void _publishCards() {
    final List<SavedCard> snapshot = List<SavedCard>.unmodifiable(_cards);
    cardsNotifier.value = snapshot;
    if (!_cardsController.isClosed) {
      _cardsController.add(snapshot);
    }
  }

  Map<String, dynamic> _cardToMap(SavedCard card) {
    final encodedImage =
        (card.imageBytes != null && card.imageBytes!.isNotEmpty)
        ? base64Encode(card.imageBytes!)
        : null;

    return {
      'id': card.id,
      'topic': card.topic,
      'word': card.word,
      'phonetic': card.phonetic,
      'meaning': card.meaning,
      'example': card.example,
      'word_type': card.wordType,
      if (encodedImage != null) 'image_bytes_base64': encodedImage,
      'image_url': card.imageUrl,
      'saved_at': card.savedAt.toIso8601String(),
    };
  }

  String _cardsStorageKey() => '${_storageScope()}::$_localCardsKey';

  String _knownWordsStorageKey() => '${_storageScope()}::$_localKnownWordsKey';

  Future<void> _persistLocalState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cardsStorageKey(),
        jsonEncode(_cards.map(_cardToMap).toList()),
      );
      await prefs.setString(
        _knownWordsStorageKey(),
        jsonEncode(
          _knownWordsByTopic.map(
            (topic, words) => MapEntry(topic, words.toList()),
          ),
        ),
      );
    } catch (_) {
      // Ignore local persistence failures so the app can keep working.
    }
  }

  Future<void> _loadLocalState() async {
    final scope = _storageScope();
    if (_localStateLoaded && _loadedScope == scope) {
      return;
    }
    _localStateLoaded = true;
    _loadedScope = scope;

    try {
      final prefs = await SharedPreferences.getInstance();

      final cardsJson = prefs.getString(_cardsStorageKey());
      if (cardsJson != null && cardsJson.isNotEmpty) {
        final decoded = jsonDecode(cardsJson);
        if (decoded is List) {
          final localCards = decoded
              .whereType<Map>()
              .map(
                (item) => SavedCard.fromMap(
                  Map<String, dynamic>.from(item.cast<String, dynamic>()),
                ),
              )
              .toList();
          _cards
            ..clear()
            ..addAll(localCards);
        }
      }

      final knownWordsJson = prefs.getString(_knownWordsStorageKey());
      if (knownWordsJson != null && knownWordsJson.isNotEmpty) {
        final decoded = jsonDecode(knownWordsJson);
        if (decoded is Map) {
          _knownWordsByTopic
            ..clear()
            ..addAll(
              decoded.map(
                (key, value) => MapEntry(
                  key.toString(),
                  value is List
                      ? value.map((item) => item.toString()).toSet()
                      : <String>{},
                ),
              ),
            );
        }
      }

      _publishCards();
    } catch (_) {
      // Ignore local load failures and fall back to remote/runtime state.
    }
  }

  void _upsertLocalCard(SavedCard card) {
    final index = _cards.indexWhere((item) => item.id == card.id);
    if (index >= 0) {
      _cards[index] = card;
    } else {
      _cards.add(card);
    }
    _publishCards();
    unawaited(_persistLocalState());
  }

  Future<String?> findExistingWord(String normalizedWord) async {
    final client = _clientOrNull;
    if (client == null) {
      return null;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    try {
      final row = await client
          .from(_tableName)
          .select('word')
          .eq('user_id', uid)
          .ilike('word', normalizedWord)
          .limit(1)
          .maybeSingle();
      return row == null ? null : row['word']?.toString();
    } catch (_) {
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

    final client = _clientOrNull;
    final timestamp = DateTime.now();
    String? imageUrl;

    if (client != null) {
      try {
        if (imageBytes != null && imageBytes.isNotEmpty) {
          imageUrl = await _uploadImage(client, imageBytes, normalized);
        }

        await client.from(_tableName).upsert({
          'user_id': FirebaseAuth.instance.currentUser?.uid,
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
        if (error.message.toLowerCase().contains('user_id')) {
          throw Exception(
            'Lỗi: Bảng flashcards trong Supabase chưa có cột "user_id". Vui lòng mở Supabase và thêm cột "user_id" kiểu "text".',
          );
        }
        throw Exception('Lỗi lưu dữ liệu Supabase: ${error.message}');
      }
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

  Future<SavedCard> addManualCard({
    required String word,
    required String meaning,
    String phonetic = '',
    String example = '',
    String topic = 'Từ mới',
    String? wordType,
    Uint8List? imageBytes,
  }) async {
    final normalized = word.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw Exception('Vui lòng nhập từ mới');
    }
    if (meaning.trim().isEmpty) {
      throw Exception('Vui lòng nhập nghĩa tiếng Việt');
    }

    final existingWord = await findExistingWord(normalized);
    if (existingWord != null) {
      throw Exception('Từ này đã có trong danh sách');
    }

    final client = _clientOrNull;
    String? imageUrl;

    if (client != null && imageBytes != null && imageBytes.isNotEmpty) {
      try {
        imageUrl = await _uploadImage(client, imageBytes, normalized);
      } catch (_) {
        imageUrl = null;
      }
    }

    final card = SavedCard(
      id: normalized,
      topic: topic.trim().isEmpty ? 'Từ mới' : topic.trim(),
      word: word.trim(),
      phonetic: phonetic.trim(),
      meaning: meaning.trim(),
      example: example.trim(),
      wordType: wordType?.trim().isEmpty == true ? null : wordType?.trim(),
      imageBytes: imageBytes,
      imageUrl: imageUrl,
      savedAt: DateTime.now(),
    );

    if (client != null) {
      try {
        await client.from(_tableName).upsert({
          'user_id': FirebaseAuth.instance.currentUser?.uid,
          'word': card.word,
          'topic': card.topic,
          'phonetic': card.phonetic,
          'meaning': card.meaning,
          'word_type': card.wordType,
          'example': card.example,
          'image_url': card.imageUrl,
          'saved_at': card.savedAt.toIso8601String(),
        });
      } on PostgrestException catch (error) {
        if (error.message.toLowerCase().contains('user_id')) {
          throw Exception(
            'Lỗi: Bảng flashcards trong Supabase chưa có cột "user_id". Vui lòng mở Supabase và thêm cột "user_id" kiểu "text".',
          );
        }
        throw Exception('Lỗi lưu từ mới lên Supabase: ${error.message}');
      }
    }

    _upsertLocalCard(card);
    return card;
  }

  Future<SavedCard> upsertManualCardFromReview({
    required String word,
    required String meaning,
    required String topic,
    String phonetic = '',
    String example = '',
    String? wordType,
    Uint8List? imageBytes,
    String? existingImageUrl,
    bool removeImage = false,
  }) async {
    final normalized = word.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw Exception('Vui lòng nhập từ mới');
    }
    if (meaning.trim().isEmpty) {
      throw Exception('Vui lòng nhập nghĩa tiếng Việt');
    }

    final existingWord = await findExistingWord(normalized);
    final client = _clientOrNull;
    final timestamp = DateTime.now();
    var imageUrl = existingImageUrl?.trim();
    if (imageUrl != null && imageUrl.isEmpty) {
      imageUrl = null;
    }

    if (removeImage) {
      imageBytes = null;
      imageUrl = null;
    }

    if (client != null &&
        !removeImage &&
        imageBytes != null &&
        imageBytes.isNotEmpty) {
      try {
        imageUrl = await _uploadImage(client, imageBytes, normalized);
      } catch (_) {
        imageUrl = null;
      }
    }

    if (client != null) {
      final payload = { 'user_id': FirebaseAuth.instance.currentUser?.uid,
        'word': word.trim(),
        'topic': topic.trim().isEmpty ? 'Từ mới' : topic.trim(),
        'phonetic': phonetic.trim(),
        'meaning': meaning.trim(),
        'word_type': wordType,
        'example': example.trim(),
        if (removeImage) 'image_url': null,
        if (imageUrl != null) 'image_url': imageUrl,
        'saved_at': timestamp.toIso8601String(),
      };

      try {
        if (existingWord != null) {
          await client
              .from(_tableName)
              .update(payload).eq('user_id', FirebaseAuth.instance.currentUser?.uid ?? '').ilike('word', normalized);
        } else {
          await client.from(_tableName).upsert(payload);
        }
      } catch (_) {
        if (existingWord != null) {
          try {
            await client
                .from(_tableName)
                .update(payload).eq('user_id', FirebaseAuth.instance.currentUser?.uid ?? '').ilike('word', normalized);
          } catch (_) {
            // Ignore remote issues and keep the local save.
          }
        }
      }
    }

    final localExistingIndex = _cards.indexWhere(
      (item) => item.id == normalized,
    );
    final localExisting = localExistingIndex >= 0
        ? _cards[localExistingIndex]
        : null;
    final card = SavedCard(
      id: normalized,
      topic: topic.trim().isEmpty ? 'Từ mới' : topic.trim(),
      word: word.trim(),
      phonetic: phonetic.trim(),
      meaning: meaning.trim(),
      example: example.trim(),
      wordType: wordType?.trim().isEmpty == true ? null : wordType?.trim(),
      imageBytes: removeImage
          ? null
          : (imageBytes ?? localExisting?.imageBytes),
      imageUrl: removeImage ? null : (imageUrl ?? localExisting?.imageUrl),
      savedAt: timestamp,
    );

    _upsertLocalCard(card);
    return card;
  }

  Future<SavedCard> replaceExistingWord({
    required String existingWord,
    required AnalysisResult result,
    Uint8List? imageBytes,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Người dùng chưa đăng nhập');

    final client = _clientOrNull;
    final timestamp = DateTime.now();
    String? imageUrl;

    if (client != null) {
      try {
        if (imageBytes != null && imageBytes.isNotEmpty) {
          imageUrl = await _uploadImage(
            client,
            imageBytes,
            result.normalizedWord,
          );
        }

        final updatedRow = await client
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
            .eq('user_id', uid)
            .eq('word', existingWord)
            .select()
            .maybeSingle();

        if (updatedRow == null) {
          throw Exception('Khong tim thay tu can cap nhat trong Supabase');
        }
      } catch (_) {
        // Remote update is optional.
      }
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

  Future<String> _uploadImage(
    SupabaseClient client,
    Uint8List bytes,
    String normalizedWord,
  ) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_$normalizedWord.jpg';
    final path = 'cards/$fileName';
    await client.storage
        .from(_bucketName)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    return client.storage.from(_bucketName).getPublicUrl(path);
  }

  Stream<List<SavedCard>> watchCards() {
    final scope = _storageScope();

    if (_watchingCards && _watchingScope == scope) {
      return _cardsController.stream;
    }

    if (_watchingCards && _watchingScope != scope) {
      _remoteSubscription?.cancel();
      _remoteSubscription = null;
      _cards.clear();
      _knownWordsByTopic.clear();
      _watchingCards = false;
      _localStateLoaded = false;
      _loadedScope = null;
      _publishCards();
    }

    _watchingCards = true;
    _watchingScope = scope;
    unawaited(_loadLocalState());

    final client = _clientOrNull;
    if (client != null) {
      _remoteSubscription ??= client
          .from(_tableName)
          .stream(primaryKey: ['user_id', 'word'])
          .order('saved_at', ascending: false)
          .listen((rows) {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            final userRows = uid != null
                ? rows.where((row) => row['user_id'] == uid).toList()
                : <Map<String, dynamic>>[];
            final mapped = userRows
                .map((row) => SavedCard.fromMap(row))
                .toList();
            final merged = <String, SavedCard>{
              for (final card in _cards) card.id: card,
              for (final card in mapped) card.id: card,
            };
            _cards
              ..clear()
              ..addAll(merged.values.toList());
            _publishCards();
          });
    }

    _publishCards();
    return _cardsController.stream;
  }
}




