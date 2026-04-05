import 'topic_classifier.dart';
import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/analysis_result.dart';
import '../models/saved_card.dart';
import 'vocabulary_service.dart';

class SavedCardsRepository {
  SavedCardsRepository._() {
    FirebaseAuth.instance.authStateChanges().listen((_) {
      _useUuidCompatibleUserId = false;
      _resolvedCardsTableName = null;
      watchCards();
    });
  }

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
  bool _useUuidCompatibleUserId = false;
  String? _resolvedCardsTableName;

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

  String get _cardsTableName => _dotenvValue('SUPABASE_TABLE', 'saved_cards');

  List<String> _cardsTableCandidates() {
    final configured = _cardsTableName.trim().isEmpty
        ? 'saved_cards'
        : _cardsTableName.trim();
    final ordered = <String>[
      if (_resolvedCardsTableName != null &&
          _resolvedCardsTableName!.trim().isNotEmpty)
        _resolvedCardsTableName!.trim(),
      configured,
      'saved_cards',
    ];
    final seen = <String>{};
    return ordered.where((name) => seen.add(name)).toList();
  }

  bool _looksLikeUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }

  String _uuidCompatibleUserId(String firebaseUid) {
    final trimmed = firebaseUid.trim();
    if (trimmed.isEmpty) {
      return '00000000-0000-4000-8000-000000000000';
    }
    if (_looksLikeUuid(trimmed)) {
      return trimmed.toLowerCase();
    }

    final bytes = utf8.encode(trimmed);
    final buffer = StringBuffer();
    var index = 0;
    while (buffer.length < 32) {
      final value = bytes[index % bytes.length];
      buffer.write(value.toRadixString(16).padLeft(2, '0'));
      index++;
    }

    final chars = buffer.toString().substring(0, 32).split('');
    chars[12] = '4';
    final variantNibble = int.parse(chars[16], radix: 16);
    chars[16] = ((variantNibble & 0x3) | 0x8).toRadixString(16);
    final hex = chars.join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  bool _isInvalidUuidInput(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == '22P02' && message.contains('uuid');
  }

  bool _isMissingTableError(PostgrestException error) {
    final code = error.code?.toLowerCase() ?? '';
    final message = error.message.toLowerCase();
    return code == '42p01' ||
        code == 'pgrst205' ||
        message.contains('could not find the table') ||
        (message.contains('relation') && message.contains('does not exist'));
  }

  bool _isMissingColumnError(PostgrestException error, {String? columnName}) {
    final code = error.code?.toLowerCase() ?? '';
    final message = error.message.toLowerCase();
    if (code != '42703' && code != 'pgrst204') {
      return false;
    }
    if (columnName == null || columnName.trim().isEmpty) {
      return message.contains('column');
    }
    return message.contains(columnName.toLowerCase());
  }

  Future<T> _runWithSupabaseUserId<T>(
    String firebaseUid,
    Future<T> Function(String supabaseUid) operation,
  ) async {
    final primaryUid = _useUuidCompatibleUserId
        ? _uuidCompatibleUserId(firebaseUid)
        : firebaseUid;

    try {
      return await operation(primaryUid);
    } on PostgrestException catch (error) {
      final canRetryWithUuid =
          !_useUuidCompatibleUserId &&
          !_looksLikeUuid(firebaseUid) &&
          _isInvalidUuidInput(error);
      if (!canRetryWithUuid) {
        rethrow;
      }

      _useUuidCompatibleUserId = true;
      return operation(_uuidCompatibleUserId(firebaseUid));
    }
  }

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
    final normalizedTopic = TopicClassifier.toVietnameseCanonical(topic);
    final knownWords = _knownWordsByTopic.putIfAbsent(
      normalizedTopic,
      () => <String>{},
    );

    final legacyTopic = TopicClassifier.normalizeTopic(topic);
    if (legacyTopic != normalizedTopic &&
        _knownWordsByTopic.containsKey(legacyTopic)) {
      knownWords.addAll(_knownWordsByTopic.remove(legacyTopic)!);
    }

    return knownWords;
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
      _knownWordsForTopic('Chung').add(key);
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
      final knownWords = _knownWordsForTopic(topic);
      if (knownWords.remove(key)) {
        if (knownWords.isEmpty) {
          _knownWordsByTopic.remove(
            TopicClassifier.toVietnameseCanonical(topic),
          );
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
    final normalizedTopic = TopicClassifier.toVietnameseCanonical(topic);
    return _cards
        .where(
          (card) =>
              TopicClassifier.toVietnameseCanonical(card.topic) ==
              normalizedTopic,
        )
        .length;
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
      'vocabulary_id': card.vocabularyId,
      'topic': card.topic,
      'word': card.word,
      'phonetic': card.phonetic,
      'meaning': card.meaning,
      'example': card.example,
      'word_type': card.wordType,
      'image_bytes_base64': encodedImage,
      'image_url': card.imageUrl,
      'created_at': card.savedAt.toIso8601String(),
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
          _knownWordsByTopic.clear();
          for (final entry in decoded.entries) {
            final canonicalTopic = TopicClassifier.toVietnameseCanonical(
              entry.key.toString(),
            );
            if (canonicalTopic.isEmpty) {
              continue;
            }

            final words = entry.value is List
                ? entry.value.map((item) => item.toString()).toSet()
                : <String>{};
            final knownWords = _knownWordsForTopic(canonicalTopic);
            knownWords.addAll(words);
          }
        }
      }

      _publishCards();

      final client = _clientOrNull;
      if (client != null) {
        unawaited(_syncLocalCardsToRemoteBestEffort(client));
      }
    } catch (_) {
      // Ignore local load failures and fall back to remote/runtime state.
    }
  }

  Future<bool> _remoteCardExistsByVocabularyId(
    SupabaseClient client,
    String firebaseUid,
    String vocabularyId,
    String normalizedWord,
  ) async {
    final normalizedVocabularyId = vocabularyId.trim();
    if (normalizedVocabularyId.isEmpty) {
      return false;
    }

    final candidates = _cardsTableCandidates();
    for (var index = 0; index < candidates.length; index++) {
      final tableName = candidates[index];
      try {
        final row = await _runWithSupabaseUserId(firebaseUid, (supabaseUid) {
          return client
              .from(tableName)
              .select('id')
              .eq('user_id', supabaseUid)
              .eq('vocabulary_id', normalizedVocabularyId)
              .limit(1)
              .maybeSingle();
        });

        _resolvedCardsTableName = tableName;
        if (row != null) {
          return true;
        }
      } on PostgrestException catch (error) {
        final canFallbackToWord =
            _isMissingColumnError(error, columnName: 'vocabulary_id') &&
            normalizedWord.trim().isNotEmpty;
        if (canFallbackToWord) {
          try {
            final row = await _runWithSupabaseUserId(firebaseUid, (
              supabaseUid,
            ) {
              return client
                  .from(tableName)
                  .select('id')
                  .eq('user_id', supabaseUid)
                  .ilike('word', normalizedWord.trim())
                  .limit(1)
                  .maybeSingle();
            });
            _resolvedCardsTableName = tableName;
            if (row != null) {
              return true;
            }
            return false;
          } on PostgrestException catch (_) {
            return false;
          }
        }

        final canFallback =
            _isMissingTableError(error) && index < candidates.length - 1;
        if (canFallback) {
          continue;
        }
        rethrow;
      }
    }

    return false;
  }

  Future<bool> _remoteCardExistsByWord(
    SupabaseClient client,
    String firebaseUid,
    String normalizedWord,
  ) async {
    final targetWord = normalizedWord.trim();
    if (targetWord.isEmpty) {
      return false;
    }

    final candidates = _cardsTableCandidates();
    for (var index = 0; index < candidates.length; index++) {
      final tableName = candidates[index];
      try {
        final row = await _runWithSupabaseUserId(firebaseUid, (supabaseUid) {
          return client
              .from(tableName)
              .select('id')
              .eq('user_id', supabaseUid)
              .ilike('word', targetWord)
              .limit(1)
              .maybeSingle();
        });
        _resolvedCardsTableName = tableName;
        if (row != null) {
          return true;
        }
      } on PostgrestException catch (error) {
        final canFallback =
            _isMissingTableError(error) && index < candidates.length - 1;
        if (canFallback) {
          continue;
        }
        return false;
      }
    }

    return false;
  }

  Future<void> _syncLocalCardsToRemoteBestEffort(SupabaseClient client) async {
    final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
    if (firebaseUid == null || firebaseUid.isEmpty) {
      return;
    }

    final localSnapshot = List<SavedCard>.from(_cards);
    var changed = false;

    for (final card in localSnapshot) {
      final localWord = card.word.trim();
      final localMeaning = card.meaning.trim();
      final localTopic = card.topic.trim();
      if (localWord.isEmpty) {
        continue;
      }

      try {
        var vocabularyId = card.vocabularyId.trim();
        if (vocabularyId.isEmpty) {
          vocabularyId = await _resolveOrCreateVocabularyId(
            word: card.id,
            topic: localTopic,
            hintVi: localMeaning,
          );
        }

        final existsRemotely = vocabularyId.isNotEmpty
            ? await _remoteCardExistsByVocabularyId(
                client,
                firebaseUid,
                vocabularyId,
                localWord,
              )
            : await _remoteCardExistsByWord(client, firebaseUid, localWord);
        if (!existsRemotely) {
          final payloads = <Map<String, dynamic>>[
            if (vocabularyId.isNotEmpty)
              {
                'vocabulary_id': vocabularyId,
                'topic': localTopic,
                'image_url': card.imageUrl,
              },
            {
              'word': localWord,
              'meaning': localMeaning,
              'topic': localTopic,
              'image_url': card.imageUrl,
              'saved_at': card.savedAt.toIso8601String(),
            },
          ];
          await _insertRemoteCardRow(client, firebaseUid, payloads);
        }

        if (card.vocabularyId.trim().isEmpty) {
          final index = _cards.indexWhere((item) => item.id == card.id);
          if (index >= 0) {
            _cards[index] = SavedCard(
              id: card.id,
              vocabularyId: vocabularyId,
              topic: card.topic,
              word: card.word,
              phonetic: card.phonetic,
              meaning: card.meaning,
              example: card.example,
              wordType: card.wordType,
              imageBytes: card.imageBytes,
              imageUrl: card.imageUrl,
              savedAt: card.savedAt,
            );
            changed = true;
          }
        }
      } catch (_) {
        // Keep local cards usable even if remote sync fails.
      }
    }

    if (changed) {
      _publishCards();
      await _persistLocalState();
    }
  }

  Future<void> _insertRemoteCardRow(
    SupabaseClient client,
    String firebaseUid,
    List<Map<String, dynamic>> payloadCandidates,
  ) async {
    final candidates = _cardsTableCandidates();
    PostgrestException? lastPostgrestError;
    final sanitizedPayloadCandidates = payloadCandidates
        .map((payload) => Map<String, dynamic>.from(payload))
        .where((payload) => payload.isNotEmpty)
        .toList();
    if (sanitizedPayloadCandidates.isEmpty) {
      return;
    }

    for (var index = 0; index < candidates.length; index++) {
      final tableName = candidates[index];
      for (final payload in sanitizedPayloadCandidates) {
        try {
          await _runWithSupabaseUserId(firebaseUid, (supabaseUid) {
            final rowPayload = <String, dynamic>{
              ...payload,
              'user_id': supabaseUid,
            };
            return client.from(tableName).insert(rowPayload);
          });
          _resolvedCardsTableName = tableName;
          return;
        } on PostgrestException catch (error) {
          lastPostgrestError = error;
          if (_isMissingColumnError(error)) {
            continue;
          }
          final canFallback =
              _isMissingTableError(error) && index < candidates.length - 1;
          if (canFallback) {
            break;
          }
          rethrow;
        }
      }

      if (lastPostgrestError != null &&
          _isMissingTableError(lastPostgrestError) &&
          index < candidates.length - 1) {
        continue;
      }
      if (lastPostgrestError != null && _isMissingColumnError(lastPostgrestError)) {
        // Tried all payload variants for this table, continue to the next table candidate.
        if (index < candidates.length - 1) {
          continue;
        }
      }
    }

    if (lastPostgrestError != null) {
      throw lastPostgrestError;
    }
  }

  Future<void> _updateRemoteCardRowById(
    SupabaseClient client,
    String firebaseUid,
    String cardId,
    Map<String, dynamic> payload,
  ) async {
    final candidates = _cardsTableCandidates();
    PostgrestException? lastPostgrestError;

    for (var index = 0; index < candidates.length; index++) {
      final tableName = candidates[index];
      try {
        await _runWithSupabaseUserId(firebaseUid, (supabaseUid) {
          return client
              .from(tableName)
              .update(payload)
              .eq('user_id', supabaseUid)
              .eq('id', cardId);
        });
        _resolvedCardsTableName = tableName;
        return;
      } on PostgrestException catch (error) {
        lastPostgrestError = error;
        final canFallback =
            _isMissingTableError(error) && index < candidates.length - 1;
        if (canFallback) {
          continue;
        }
        rethrow;
      }
    }

    if (lastPostgrestError != null) {
      throw lastPostgrestError;
    }
  }

  Future<List<SavedCard>> _hydrateRemoteCards(
    SupabaseClient client,
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) {
      return <SavedCard>[];
    }

    final normalizedRows = rows
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    final vocabularyIds = <String>{};
    for (final row in normalizedRows) {
      final word = row['word']?.toString().trim() ?? '';
      final vocabularyId = row['vocabulary_id']?.toString().trim() ?? '';
      if (word.isEmpty && vocabularyId.isNotEmpty) {
        vocabularyIds.add(vocabularyId);
      }
    }

    if (vocabularyIds.isNotEmpty) {
      try {
        final hintsRaw = await client
            .from('vocabulary_hints')
            .select('id, meaning, hint_vi, topic')
            .inFilter('id', vocabularyIds.toList());

        final hintsById = <String, Map<String, dynamic>>{};
        for (final raw in hintsRaw.whereType<Map>()) {
          final hint = Map<String, dynamic>.from(raw.cast<String, dynamic>());
          final id = hint['id']?.toString().trim() ?? '';
          if (id.isNotEmpty) {
            hintsById[id] = hint;
          }
        }

        for (final row in normalizedRows) {
          final vocabularyId = row['vocabulary_id']?.toString().trim() ?? '';
          final hint = hintsById[vocabularyId];
          if (hint == null) {
            continue;
          }

          final rowWord = row['word']?.toString().trim() ?? '';
          final rowMeaning = row['meaning']?.toString().trim() ?? '';
          final rowTopic = row['topic']?.toString().trim() ?? '';

          if (rowWord.isEmpty) {
            row['word'] = hint['meaning']?.toString() ?? '';
          }
          if (rowMeaning.isEmpty) {
            row['meaning'] = hint['hint_vi']?.toString() ?? '';
          }
          if (rowTopic.isEmpty) {
            row['topic'] = hint['topic']?.toString() ?? '';
          }
        }
      } catch (_) {
        // Best-effort enrichment; keep using raw row when lookup fails.
      }
    }

    return normalizedRows
        .map(SavedCard.fromMap)
        .where((card) => card.word.trim().isNotEmpty)
        .toList();
  }

  Future<void> _mergeRemoteRows(
    SupabaseClient client,
    List<Map<String, dynamic>> rows,
  ) async {
    final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
    if (firebaseUid == null || firebaseUid.isEmpty) {
      return;
    }

    final rawUid = firebaseUid;
    final uuidUid = _uuidCompatibleUserId(firebaseUid);
    final userRows = rows
        .where((row) {
          final rowUserId = row['user_id']?.toString();
          return rowUserId == rawUid || rowUserId == uuidUid;
        })
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    if (userRows.isEmpty) {
      return;
    }

    if (rawUid != uuidUid &&
        userRows.any((row) => row['user_id']?.toString() == uuidUid)) {
      _useUuidCompatibleUserId = true;
    }

    final mapped = await _hydrateRemoteCards(client, userRows);
    final merged = <String, SavedCard>{
      for (final card in _cards) card.id: card,
      for (final card in mapped) card.id: card,
    };
    _cards
      ..clear()
      ..addAll(merged.values.toList());
    _publishCards();
  }

  void _ensureRemoteSubscription(SupabaseClient client) {
    if (_remoteSubscription != null) {
      return;
    }

    final candidates = _cardsTableCandidates();

    void subscribeAt(int index) {
      if (index < 0 || index >= candidates.length) {
        return;
      }

      final tableName = candidates[index];
      _remoteSubscription?.cancel();
      _remoteSubscription = client
          .from(tableName)
          .stream(primaryKey: ['user_id', 'id'])
          .listen(
            (rows) {
              _resolvedCardsTableName = tableName;
              unawaited(_mergeRemoteRows(client, rows));
            },
            onError: (Object error, StackTrace stackTrace) {
              if (error is PostgrestException &&
                  _isMissingTableError(error) &&
                  index < candidates.length - 1) {
                subscribeAt(index + 1);
              }
            },
          );
    }

    subscribeAt(0);
  }

  Future<void> _loadRemoteCardsOnce(SupabaseClient client) async {
    final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
    if (firebaseUid == null || firebaseUid.isEmpty) {
      return;
    }

    Future<List<SavedCard>> readFromTable(String tableName) async {
      dynamic response;
      try {
        response = await _runWithSupabaseUserId(firebaseUid, (supabaseUid) {
          return client
              .from(tableName)
              .select()
              .eq('user_id', supabaseUid)
              .order('created_at', ascending: false);
        });
      } on PostgrestException catch (error) {
        if (_isMissingTableError(error)) {
          rethrow;
        }

        final message = error.message.toLowerCase();
        final missingCreatedAt =
            error.code == '42703' && message.contains('created_at');
        if (!missingCreatedAt) {
          rethrow;
        }

        // Some custom tables (for example flashcards) don't include created_at.
        response = await _runWithSupabaseUserId(firebaseUid, (supabaseUid) {
          return client.from(tableName).select().eq('user_id', supabaseUid);
        });
      }

      if (response is! List) {
        return <SavedCard>[];
      }
      final rows = response
          .whereType<Map>()
          .map(
            (row) => Map<String, dynamic>.from(row.cast<String, dynamic>()),
          )
          .toList();

      return _hydrateRemoteCards(client, rows);
    }

    try {
      final candidates = _cardsTableCandidates();
      for (var index = 0; index < candidates.length; index++) {
        final tableName = candidates[index];
        try {
          final remoteCards = await readFromTable(tableName);
          final hasRemoteData = remoteCards.isNotEmpty;
          final isLastCandidate = index == candidates.length - 1;

          if (hasRemoteData || _cards.isNotEmpty || isLastCandidate) {
            _resolvedCardsTableName = tableName;
            final merged = <String, SavedCard>{
              for (final card in _cards) card.id: card,
              for (final card in remoteCards) card.id: card,
            };
            _cards
              ..clear()
              ..addAll(merged.values.toList());
            _publishCards();
          }

          if (hasRemoteData || _cards.isNotEmpty) {
            return;
          }
        } on PostgrestException catch (error) {
          final canFallback =
              _isMissingTableError(error) && index < candidates.length - 1;
          if (canFallback) {
            continue;
          }
          rethrow;
        }
      }
    } catch (_) {
      // Best-effort remote load; realtime stream or local cache may still populate cards.
    }
  }

  void _upsertLocalCard(SavedCard card) {
    if (card.topic.isNotEmpty) {
      VocabularyService.instance.addCustomHintIfNeeded(card.word, card.topic);
    }
    final index = _cards.indexWhere((item) => item.id == card.id);
    if (index >= 0) {
      _cards[index] = card;
    } else {
      _cards.add(card);
    }
    _publishCards();
    unawaited(_persistLocalState());
  }

  Future<String> _resolveOrCreateVocabularyId({
    required String word,
    required String topic,
    required String hintVi,
  }) async {
    final normalizedWord = word.trim();
    final normalizedHintVi = hintVi.trim();
    if (normalizedWord.isEmpty) {
      throw Exception('Không thể tạo bản ghi từ vựng do thiếu từ tiếng Anh');
    }

    final lookupCandidates = <String>{
      normalizedWord,
      if (normalizedHintVi.isNotEmpty) normalizedHintVi,
    };

    for (final candidate in lookupCandidates) {
      final found = await VocabularyService.instance.findVocabularyIdByMeaning(
        candidate,
      );
      if (found != null && found.isNotEmpty) {
        return found;
      }
    }

    var vocabularyId =
        await VocabularyService.instance.findVocabularyIdByMeaning(
          normalizedWord,
        ) ??
        '';
    if (vocabularyId.isNotEmpty) {
      return vocabularyId;
    }

    final maskedMeaning = normalizedWord.toLowerCase().replaceAll(
      RegExp(r'[aeiou]'),
      '*',
    );
    vocabularyId =
        await VocabularyService.instance.insertVocabularyHint(
          topic: topic,
          meaning: normalizedWord,
          hint: '',
          maskedMeaning: maskedMeaning,
          hintVi: hintVi,
        ) ??
        '';
    if (vocabularyId.isNotEmpty) {
      return vocabularyId;
    }

    // Fallback: insert may fail due duplicate/race or policy delay, so retry lookup.
    for (final candidate in lookupCandidates) {
      vocabularyId =
          await VocabularyService.instance.findVocabularyIdByMeaning(
            candidate,
          ) ??
          '';
      if (vocabularyId.isNotEmpty) {
        return vocabularyId;
      }
    }

    return '';
  }

  Future<String?> _findExistingWordInTable({
    required SupabaseClient client,
    required String tableName,
    required String firebaseUid,
    required String normalizedWord,
  }) async {
    final row = await _runWithSupabaseUserId(firebaseUid, (supabaseUid) {
      return client
          .from(tableName)
          .select('id, vocabulary_hints!inner(meaning)')
          .eq('user_id', supabaseUid)
          .ilike('vocabulary_hints.meaning', normalizedWord)
          .limit(1)
          .maybeSingle();
    });

    if (row != null && row['vocabulary_hints'] != null) {
      _resolvedCardsTableName = tableName;
      return row['vocabulary_hints']['meaning']?.toString();
    }

    return null;
  }

  Future<String?> findExistingWord(String normalizedWord) async {
    // Basic local check first
    if (containsWord(normalizedWord)) {
      return normalizedWord;
    }

    final client = _clientOrNull;
    if (client == null) {
      return null;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return null;
    }

    final candidates = _cardsTableCandidates();
    for (var index = 0; index < candidates.length; index++) {
      final tableName = candidates[index];
      try {
        final found = await _findExistingWordInTable(
          client: client,
          tableName: tableName,
          firebaseUid: uid,
          normalizedWord: normalizedWord,
        );
        if (found != null) {
          return found;
        }
      } on PostgrestException catch (error) {
        final canFallback =
            _isMissingTableError(error) && index < candidates.length - 1;
        if (canFallback) {
          continue;
        }
        return null;
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  Future<SavedCard?> saveResult(
    AnalysisResult result,
    Uint8List? imageBytes,
  ) async {
    final normalized = result.normalizedWord;
    if (normalized.isEmpty) {
      throw Exception('Không thể lưu thẻ thiếu từ vựng');
    }

    // Check if card already exists locally
    if (containsWord(normalized)) {
      return null;
    }

    final client = _clientOrNull;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    String vocabularyId = '';
    final timestamp = DateTime.now();
    String? imageUrl;

    if (client != null && uid != null && uid.isNotEmpty) {
      try {
        vocabularyId = await _resolveOrCreateVocabularyId(
          word: normalized,
          topic: result.topic,
          hintVi: result.vietnameseMeaning,
        );

        // Step 3: Upload image if present
        if (imageBytes != null && imageBytes.isNotEmpty) {
          try {
            imageUrl = await _uploadImage(client, imageBytes, normalized);
          } catch (_) {
            imageUrl = null;
          }
        }

        // Step 4: Insert to saved_cards only when vocabulary_id is available.
        final payloads = <Map<String, dynamic>>[
          if (vocabularyId.isNotEmpty)
            {
              'vocabulary_id': vocabularyId,
              'topic': result.topic,
              'image_url': imageUrl,
            },
          {
            'word': result.word,
            'meaning': result.vietnameseMeaning,
            'topic': result.topic,
            'phonetic': result.phonetic,
            'word_type': result.wordType,
            'example': result.exampleSentence,
            'image_url': imageUrl,
            'saved_at': timestamp.toIso8601String(),
          },
        ];
        await _insertRemoteCardRow(client, uid, payloads);
      } on StorageException catch (error) {
        throw Exception('Lỗi tải ảnh lên Supabase: ${error.message}');
      } on PostgrestException catch (error) {
        throw Exception('Lỗi lưu thẻ lên Supabase: ${error.message}');
      }
    }

    final card = SavedCard.fromAnalysisResult(
      result,
      vocabularyId,
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

    if (containsWord(normalized)) {
      throw Exception('Từ này đã có trong danh sách');
    }

    final client = _clientOrNull;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    String vocabularyId = '';
    String? imageUrl;

    if (client != null && uid != null && uid.isNotEmpty) {
      try {
        vocabularyId = await _resolveOrCreateVocabularyId(
          word: normalized,
          topic: topic,
          hintVi: meaning,
        );

        // Step 3: Upload image if present
        if (imageBytes != null && imageBytes.isNotEmpty) {
          try {
            imageUrl = await _uploadImage(client, imageBytes, normalized);
          } catch (_) {
            imageUrl = null;
          }
        }

        // Step 4: Insert to saved_cards only when vocabulary_id is available.
        final payloads = <Map<String, dynamic>>[
          if (vocabularyId.isNotEmpty)
            {
              'vocabulary_id': vocabularyId,
              'topic': topic,
              'image_url': imageUrl,
            },
          {
            'word': word.trim(),
            'meaning': meaning.trim(),
            'topic': topic,
            'phonetic': phonetic.trim(),
            'word_type': wordType?.trim(),
            'example': example.trim(),
            'image_url': imageUrl,
            'saved_at': DateTime.now().toIso8601String(),
          },
        ];
        await _insertRemoteCardRow(client, uid, payloads);
      } on PostgrestException catch (error) {
        if (error.message.toLowerCase().contains('user_id')) {
          throw Exception(
            'Lỗi: Bảng $_cardsTableName trong Supabase chưa được cấu hình đúng.',
          );
        }
        throw Exception('Lỗi lưu từ mới lên Supabase: ${error.message}');
      }
    }

    final topicCanonical = TopicClassifier.toVietnameseCanonical(
      topic.trim().isEmpty ? 'Từ mới' : topic.trim(),
    );

    final card = SavedCard(
      id: normalized,
      vocabularyId: vocabularyId,
      topic: topicCanonical,
      word: word.trim(),
      phonetic: phonetic.trim(),
      meaning: meaning.trim(),
      example: example.trim(),
      wordType: wordType?.trim().isEmpty == true ? null : wordType?.trim(),
      imageBytes: imageBytes,
      imageUrl: imageUrl,
      savedAt: DateTime.now(),
    );

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

    final client = _clientOrNull;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final timestamp = DateTime.now();
    var imageUrl = existingImageUrl?.trim();
    if (imageUrl != null && imageUrl.isEmpty) {
      imageUrl = null;
    }

    final localExistingIndex = _cards.indexWhere(
      (item) => item.id == normalized,
    );
    final localExisting = localExistingIndex >= 0
        ? _cards[localExistingIndex]
        : null;

    String vocabularyId = localExisting?.vocabularyId ?? '';

    if (removeImage) {
      imageBytes = null;
      imageUrl = null;
    }

    if (client != null && uid != null && uid.isNotEmpty) {
      try {
        if (vocabularyId.isEmpty) {
          vocabularyId = await _resolveOrCreateVocabularyId(
            word: normalized,
            topic: topic,
            hintVi: meaning,
          );
        }

        // Upload new image if provided
        if (!removeImage && imageBytes != null && imageBytes.isNotEmpty) {
          try {
            imageUrl = await _uploadImage(client, imageBytes, normalized);
          } catch (_) {
            imageUrl = null;
          }
        }

        // Update or insert saved_card
        if (localExisting != null) {
          if (vocabularyId.isNotEmpty) {
            await _updateRemoteCardRowById(client, uid, localExisting.id, {
              'vocabulary_id': vocabularyId,
              'topic': topic,
              if (removeImage) 'image_url': null,
              if (!removeImage && imageUrl != null) 'image_url': imageUrl,
            });
          } else {
            debugPrint(
              'Skip remote upsertManualCardFromReview(update): missing vocabulary_id for "$normalized".',
            );
          }
        } else {
          vocabularyId = await _resolveOrCreateVocabularyId(
            word: normalized,
            topic: topic,
            hintVi: meaning,
          );

          final payloads = <Map<String, dynamic>>[
            if (vocabularyId.isNotEmpty)
              {
                'vocabulary_id': vocabularyId,
                'topic': topic,
                'image_url': imageUrl,
              },
            {
              'word': word.trim(),
              'meaning': meaning.trim(),
              'topic': topic,
              'phonetic': phonetic.trim(),
              'word_type': wordType?.trim(),
              'example': example.trim(),
              'image_url': imageUrl,
              'saved_at': timestamp.toIso8601String(),
            },
          ];
          await _insertRemoteCardRow(client, uid, payloads);
        }
      } catch (_) {
        // Ignore remote issues and keep the local save.
      }
    }

    final topicCanonical = TopicClassifier.toVietnameseCanonical(
      topic.trim().isEmpty ? 'Từ mới' : topic.trim(),
    );

    final card = SavedCard(
      id: normalized,
      vocabularyId: vocabularyId,
      topic: topicCanonical,
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
    if (uid == null || uid.isEmpty) {
      throw Exception('Người dùng chưa đăng nhập');
    }

    final client = _clientOrNull;
    final timestamp = DateTime.now();
    String? imageUrl;
    String vocabularyId = '';

    if (client != null) {
      try {
        vocabularyId = await _resolveOrCreateVocabularyId(
          word: result.normalizedWord,
          topic: result.topic,
          hintVi: result.vietnameseMeaning,
        );

        if (imageBytes != null && imageBytes.isNotEmpty) {
          try {
            imageUrl = await _uploadImage(
              client,
              imageBytes,
              result.normalizedWord,
            );
          } catch (_) {
            imageUrl = null;
          }
        }

        if (vocabularyId.isNotEmpty) {
          await _updateRemoteCardRowById(client, uid, existingWord, {
            'vocabulary_id': vocabularyId,
            'topic': result.topic,
            if (imageUrl != null) 'image_url': imageUrl,
          });
        } else {
          debugPrint(
            'Skip remote replaceExistingWord: missing vocabulary_id for "${result.normalizedWord}".',
          );
        }
      } catch (_) {
        // Remote update is optional.
      }
    }

    final card = SavedCard.fromAnalysisResult(
      result,
      vocabularyId,
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
    final client = _clientOrNull;

    if (_watchingCards && _watchingScope == scope) {
      if (_remoteSubscription == null && client != null) {
        _ensureRemoteSubscription(client);
      }
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

    if (client != null) {
      unawaited(_loadRemoteCardsOnce(client));
      _ensureRemoteSubscription(client);
    }

    _publishCards();
    return _cardsController.stream;
  }
}
