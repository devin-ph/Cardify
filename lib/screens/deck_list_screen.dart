import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'flashcard_category_screen.dart';
import '../models/saved_card.dart';
import '../services/saved_cards_repository.dart';
import '../services/topic_classifier.dart';

class DeckListScreen extends StatefulWidget {
  const DeckListScreen({super.key});

  @override
  State<DeckListScreen> createState() => _DeckListScreenState();
}

class _DeckListScreenState extends State<DeckListScreen> {
  static const int _defaultTotalCardsPerTopic = 50;
  static const String _recentAccessHistoryKey = 'deck_recent_access_history_v1';
  final SavedCardsRepository _repository = SavedCardsRepository.instance;
  final SpeechToText _speech = SpeechToText();
  final TextEditingController _searchController = TextEditingController();

  Map<String, int> _hintsCountCache = {};

  final Map<
    String,
    ({int lastAccessAt, bool practiced, int practiceDurationSeconds})
  >
  _recentAccessByTopic =
      <
        String,
        ({int lastAccessAt, bool practiced, int practiceDurationSeconds})
      >{};

  String search = '';
  int filterIndex = 0; // 0: All, 1: Recent, 2: Favorites
  bool _speechReady = false;
  bool _isListening = false;

  final List<Map<String, dynamic>> decks = [
    {
      'icon': Icons.electrical_services,
      'title': 'Electronics',
      'desc': 'Từ vựng về thiết bị điện tử thông dụng',
      'favorite': false,
    },
    {
      'icon': Icons.chair_alt,
      'title': 'Furniture',
      'desc': 'Từ vựng về nội thất và vật dụng trong nhà',
      'favorite': false,
    },
    {
      'icon': Icons.pets,
      'title': 'Animals',
      'desc': 'Từ vựng về các loài động vật',
      'favorite': true,
    },
    {
      'icon': Icons.nature,
      'title': 'Nature',
      'desc': 'Từ vựng liên quan đến thiên nhiên',
      'favorite': false,
    },
    {
      'icon': Icons.memory,
      'title': 'Technology',
      'desc': 'Từ vựng về phần mềm, dữ liệu và internet',
      'favorite': false,
    },
    {
      'icon': Icons.school,
      'title': 'Learning',
      'desc': 'Từ vựng liên quan đến trường lớp và học tập',
      'favorite': true,
    },
    {
      'icon': Icons.restaurant,
      'title': 'Food',
      'desc': 'Từ vựng về thức ăn và đồ uống',
      'favorite': false,
    },
    {
      'icon': Icons.directions_car,
      'title': 'Vehicles',
      'desc': 'Từ vựng về phương tiện giao thông',
      'favorite': false,
    },
  ];

  String _normalizeText(String value) {
    final lower = value.toLowerCase().trim();
    const from =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const to =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuuuyyyyyd';
    var result = lower;
    for (var i = 0; i < from.length; i++) {
      result = result.replaceAll(from[i], to[i]);
    }
    return result;
  }

  bool _matchesDeckByVocabulary(
    Map<String, dynamic> deck,
    String normalizedSearch,
    List<SavedCard> cards,
  ) {
    if (normalizedSearch.isEmpty) {
      return true;
    }

    final title = deck['title'] as String;
    final desc = deck['desc'] as String;
    if (_normalizeText(title).contains(normalizedSearch) ||
        _normalizeText(desc).contains(normalizedSearch)) {
      return true;
    }

    final keywords = TopicClassifier.keywords[title] ?? const <String>[];
    final keywordMatched = keywords.any(
      (keyword) => _normalizeText(keyword).contains(normalizedSearch),
    );
    if (keywordMatched) {
      return true;
    }

    // Fallback: classify the query itself to a topic (works well for English terms
    // such as "mountain", "keyboard", etc.) and compare against this deck title.
    final classifiedTopic = TopicClassifier.classifyWord(normalizedSearch, '');
    if (classifiedTopic == title) {
      return true;
    }

    final topicCards = cards.where(
      (card) => TopicClassifier.normalizeTopic(card.topic) == title,
    );
    for (final card in topicCards) {
      final searchableText = _normalizeText(
        '${card.word} ${card.meaning} ${card.phonetic} ${card.example}',
      );
      if (searchableText.contains(normalizedSearch)) {
        return true;
      }
    }

    return false;
  }

  @override
  void initState() {
    super.initState();
    _repository.watchCards();
    _loadRecentAccessHistory();
    _initSpeech();
    _loadHintCounts();
  }

  Future<void> _loadHintCounts() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/data/vocabulary_hints_vi.json',
      );
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final counts = <String, int>{};
      for (final item in decoded) {
        if (item is! Map) continue;
        final meaning = item['meaning']?.toString() ?? '';
        final topicOverride = item['topic']?.toString();
        final actualTopic =
            topicOverride ?? TopicClassifier.classifyWord(meaning, '');
        counts[actualTopic] = (counts[actualTopic] ?? 0) + 1;
      }

      if (mounted) {
        setState(() {
          _hintsCountCache = counts;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRecentAccessHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawEntries =
          prefs.getStringList(_recentAccessHistoryKey) ?? const <String>[];

      final loaded =
          <
            String,
            ({int lastAccessAt, bool practiced, int practiceDurationSeconds})
          >{};
      for (final entry in rawEntries) {
        final parts = entry.split('|');
        if (parts.length < 2) {
          continue;
        }

        final topic = parts[0].trim();
        final timestamp = int.tryParse(parts[1].trim());
        if (topic.isEmpty || timestamp == null) {
          continue;
        }

        final practiced = parts.length >= 3 && parts[2].trim() == '1';
        final durationSeconds = parts.length >= 4
            ? int.tryParse(parts[3].trim()) ?? 0
            : 0;
        loaded[topic] = (
          lastAccessAt: timestamp,
          practiced: practiced,
          practiceDurationSeconds: durationSeconds,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _recentAccessByTopic
          ..clear()
          ..addAll(loaded);
      });
    } catch (_) {
      // Ignore persistence errors and keep recent tab functional in-memory.
    }
  }

  Future<void> _persistRecentAccessHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = _recentAccessByTopic.entries
          .map(
            (entry) =>
                '${entry.key}|${entry.value.lastAccessAt}|${entry.value.practiced ? 1 : 0}|${entry.value.practiceDurationSeconds}',
          )
          .toList();
      await prefs.setStringList(_recentAccessHistoryKey, entries);
    } catch (_) {
      // Ignore persistence errors so opening a deck is never blocked.
    }
  }

  void _recordTopicAccess(
    String topic, {
    required int timestamp,
    required bool practiced,
    required int practiceDurationSeconds,
  }) {
    final normalizedTopic = topic.trim();
    if (normalizedTopic.isEmpty) {
      return;
    }

    setState(() {
      _recentAccessByTopic[normalizedTopic] = (
        lastAccessAt: timestamp,
        practiced: practiced,
        practiceDurationSeconds: practiceDurationSeconds,
      );
    });

    _persistRecentAccessHistory();
  }

  String _formatRecentAccessTime(int timestamp) {
    final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(time.day)}/${twoDigits(time.month)}/${time.year} ${twoDigits(time.hour)}:${twoDigits(time.minute)}';
  }

  String _formatPracticeDuration(int totalSeconds) {
    if (totalSeconds <= 0) {
      return '0 giây';
    }

    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    if (minutes == 0) {
      return '$seconds giây';
    }
    if (seconds == 0) {
      return '$minutes phút';
    }
    return '$minutes phút $seconds giây';
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) {
          return;
        }
        if (status == 'notListening' && _isListening) {
          setState(() {
            _isListening = false;
          });
        }
      },
      onError: (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isListening = false;
        });
      },
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _speechReady = available;
    });
  }

  Future<void> _toggleVoiceSearch() async {
    if (!_speechReady) {
      return;
    }

    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
      return;
    }

    setState(() {
      _isListening = true;
    });

    await _speech.listen(
      localeId: 'vi_VN',
      listenMode: ListenMode.confirmation,
      partialResults: true,
      onResult: _onSpeechResult,
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) {
      return;
    }

    final recognized = result.recognizedWords.trim();
    setState(() {
      search = recognized;
      _searchController.value = TextEditingValue(
        text: recognized,
        selection: TextSelection.collapsed(offset: recognized.length),
      );
      if (result.finalResult) {
        _isListening = false;
      }
    });
  }

  @override
  void dispose() {
    _speech.stop();
    _searchController.dispose();
    super.dispose();
  }

  ({int imageAdded, int total, double progress}) _getDeckStats(
    String topic,
    List<SavedCard> cards,
  ) {
    final imageAdded = _repository.imageCountForTopic(topic);
    final totalInDataset =
        _hintsCountCache[topic] ?? _defaultTotalCardsPerTopic;
    final total = totalInDataset;
    final progress = total == 0 ? 0.0 : (imageAdded / total).clamp(0.0, 1.0);
    return (imageAdded: imageAdded, total: total, progress: progress);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FF),
      body: SafeArea(
        child: ValueListenableBuilder<List<SavedCard>>(
          valueListenable: _repository.cardsNotifier,
          builder: (context, cards, _) {
            final normalizedSearch = _normalizeText(search);
            final filteredDecks = decks.where((deck) {
              final title = deck['title'] as String;
              if (filterIndex == 1 && !_recentAccessByTopic.containsKey(title)) {
                return false;
              }
              if (filterIndex == 2 && !(deck['favorite'] as bool)) {
                return false;
              }
              if (filterIndex != 1 &&
                  normalizedSearch.isNotEmpty &&
                  !_matchesDeckByVocabulary(deck, normalizedSearch, cards)) {
                return false;
              }
              return true;
            }).toList()
              ..sort((a, b) {
                if (filterIndex != 1) {
                  return 0;
                }
                final titleA = a['title'] as String;
                final titleB = b['title'] as String;
                final timeA = _recentAccessByTopic[titleA]?.lastAccessAt ?? 0;
                final timeB = _recentAccessByTopic[titleB]?.lastAccessAt ?? 0;
                return timeB.compareTo(timeA);
              });

            return Stack(
              children: [
                Positioned(
                  top: -40,
                  left: -50,
                  child: _DeckAmbientBlob(
                    size: 190,
                    color: const Color(0xFF8AD4FF).withValues(alpha: 0.16),
                  ),
                ),
                Positioned(
                  top: 120,
                  right: -60,
                  child: _DeckAmbientBlob(
                    size: 230,
                    color: const Color(0xFFF472B6).withValues(alpha: 0.10),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.78),
                              const Color(0xFFF8FBFF).withValues(alpha: 0.72),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7EA7C9).withValues(alpha: 0.14),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF8AD4FF),
                                    Color(0xFFB68CFF),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.view_agenda_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bộ thẻ học',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF1F2740),
                                        ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${filteredDecks.length} chủ đề đang hiển thị',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF627485),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF3FE)
                                    .withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'AI English Learning',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1D3557),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (filterIndex != 1)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.90),
                                const Color(0xFFF6FAFF).withValues(alpha: 0.78),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFDCE7F4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7EA7C9)
                                    .withValues(alpha: 0.10),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Tìm bộ thẻ...',
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF8AD4FF),
                                        Color(0xFFB68CFF),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.search_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                              suffixIcon: Container(
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2ECFF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  tooltip: _isListening
                                      ? 'Dừng tìm kiếm bằng giọng nói'
                                      : 'Tìm kiếm bằng giọng nói',
                                  onPressed: _toggleVoiceSearch,
                                  icon: Icon(
                                    _isListening ? Icons.mic : Icons.mic_none,
                                    color: _speechReady
                                        ? const Color(0xFF0A5DB6)
                                        : const Color(0xFF9AA8BB),
                                  ),
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.transparent,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                              border: InputBorder.none,
                              hintStyle: const TextStyle(
                                color: Color(0xFF8B96A8),
                                fontSize: 16,
                              ),
                            ),
                            onChanged: (val) => setState(() => search = val),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _buildFilterButton('Tất cả', 0),
                          const SizedBox(width: 10),
                          _buildFilterButton('Gần đây', 1),
                          const SizedBox(width: 10),
                          _buildFilterButton('Yêu thích', 2),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filteredDecks.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.view_agenda_outlined,
                                    size: 64,
                                    color: Color(0xFFB8C4D4),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Không tìm thấy bộ thẻ phù hợp',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF627485),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                              itemCount: filteredDecks.length,
                              itemBuilder: (context, idx) {
                                final deck = filteredDecks[idx];
                                return _buildDeckCard(
                                  deck,
                                  cards,
                                  recentMeta: _recentAccessByTopic[
                                    deck['title'] as String
                                  ],
                                  showRecentMeta: filterIndex == 1,
                                  onTap: () async {
                                    final selectedTopic = deck['title'] as String;
                                    final isViewingRecentHistory = filterIndex == 1;
                                    final accessedAt = DateTime.now()
                                        .millisecondsSinceEpoch;
                                    final result = await Navigator.push<dynamic>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => FlashcardScreen(
                                          selectedTopic: selectedTopic,
                                          showOnlyTrackedWords:
                                              isViewingRecentHistory,
                                        ),
                                      ),
                                    );

                                    var practiced = false;
                                    var practiceDurationSeconds = 0;
                                    if (result is bool) {
                                      practiced = result;
                                    } else if (result is Map) {
                                      practiced = result['practiced'] == true;
                                      final rawDuration =
                                          result['practiceDurationSeconds'];
                                      if (rawDuration is int) {
                                        practiceDurationSeconds = rawDuration;
                                      } else if (rawDuration is num) {
                                        practiceDurationSeconds = rawDuration.toInt();
                                      }
                                    }

                                    if (!mounted) {
                                      return;
                                    }

                                    if (isViewingRecentHistory) {
                                      return;
                                    }

                                    _recordTopicAccess(
                                      selectedTopic,
                                      timestamp: accessedAt,
                                      practiced: practiced,
                                      practiceDurationSeconds: practiced
                                          ? practiceDurationSeconds
                                          : 0,
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterButton(String label, int idx) {
    final selected = filterIndex == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => filterIndex = idx),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF0A5DB6), Color(0xFF377DFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFF6FAFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? Colors.transparent : const Color(0xFFDCE7F4),
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? const Color(0xFF0A5DB6).withValues(alpha: 0.24)
                    : const Color(0xFF7EA7C9).withValues(alpha: 0.10),
                blurRadius: selected ? 14 : 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF0A5DB6),
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeckCard(
    Map<String, dynamic> deck,
    List<SavedCard> cards, {
    ({int lastAccessAt, bool practiced, int practiceDurationSeconds})?
    recentMeta,
    bool showRecentMeta = false,
    required VoidCallback onTap,
  }) {
    final isFavorite = deck['favorite'] as bool;
    final title = deck['title'] as String;
    final stats = _getDeckStats(title, cards);
    final isLocked = stats.imageAdded == 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLocked
              ? [const Color(0xFFF7F2F6), const Color(0xFFF0F4FB)]
              : [Colors.white, const Color(0xFFF8FBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLocked ? const Color(0xFFE7DDE6) : const Color(0xFFDCE7F4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7EA7C9).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Opacity(
            opacity: isLocked ? 0.52 : 1.0,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: isLocked
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Vui lòng chụp ít nhất 1 thẻ để mở khóa chủ đề này!',
                          ),
                        ),
                      );
                    }
                  : onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isLocked
                              ? [
                                  const Color(0xFFE8F0FE),
                                  const Color(0xFFF1ECFF),
                                ]
                              : [
                                  const Color(0xFFEAF3FE),
                                  const Color(0xFFF1ECFF),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        deck['icon'],
                        color: const Color(0xFF0A5DB6),
                        size: 48,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      TopicClassifier.getVietnameseTopic(
                                        deck['title'] as String,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1F2740),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      deck['desc'] as String,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.4,
                                        color: Color(0xFF6A7486),
                                      ),
                                    ),
                                    if (showRecentMeta && recentMeta != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Truy cập: ${_formatRecentAccessTime(recentMeta.lastAccessAt)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6A7486),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        recentMeta.practiced
                                            ? 'Trạng thái: Đã luyện tập ${_formatPracticeDuration(recentMeta.practiceDurationSeconds)}'
                                            : 'Trạng thái: Chỉ mở rồi thoát',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: recentMeta.practiced
                                              ? const Color(0xFF1B8A3A)
                                              : const Color(0xFF6A7486),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      deck['favorite'] = !isFavorite;
                                    });
                                  },
                                  splashRadius: 22,
                                  icon: Icon(
                                    isFavorite ? Icons.star : Icons.star_border,
                                    color: isFavorite
                                        ? const Color(0xFFF4B400)
                                        : const Color(0xFF0A5DB6),
                                  ),
                                  tooltip: isFavorite
                                      ? 'Bỏ khỏi yêu thích'
                                      : 'Thêm vào yêu thích',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  stats.imageAdded == 0
                                      ? 'Có ${stats.total} thẻ mới chờ được quét'
                                      : 'Còn ${stats.total - stats.imageAdded} thẻ chưa mở',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF2E3445),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${(stats.progress * 100).toInt()}%',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF0A5DB6),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: stats.progress,
                              backgroundColor: const Color(0xFFE8F0FE),
                              color: const Color(0xFF0A5DB6),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isLocked)
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.56),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DeckAmbientBlob extends StatelessWidget {
  const _DeckAmbientBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
