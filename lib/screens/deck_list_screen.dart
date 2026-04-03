import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'flashcard_category_screen.dart';
import '../models/saved_card.dart';
import '../services/saved_cards_repository.dart';

class DeckListScreen extends StatefulWidget {
  const DeckListScreen({super.key});

  @override
  State<DeckListScreen> createState() => _DeckListScreenState();
}

class _DeckListScreenState extends State<DeckListScreen> {
  static const int _defaultTotalCardsPerTopic = 50;
  final SavedCardsRepository _repository = SavedCardsRepository.instance;
  final SpeechToText _speech = SpeechToText();
  final TextEditingController _searchController = TextEditingController();

  String search = '';
  int filterIndex = 0; // 0: All, 1: Recent, 2: Favorites
  bool _speechReady = false;
  bool _isListening = false;

  final List<Map<String, dynamic>> decks = [
    {
      'icon': Icons.home,
      'title': 'Đồ gia dụng',
      'desc': 'Từ vựng về các vật dụng trong nhà',
      'favorite': false,
    },
    {
      'icon': Icons.nature,
      'title': 'Thiên nhiên',
      'desc': 'Từ vựng liên quan đến thiên nhiên',
      'favorite': true,
    },
    {
      'icon': Icons.devices,
      'title': 'Công nghệ',
      'desc': 'Từ vựng về công nghệ và thiết bị',
      'favorite': false,
    },
    {
      'icon': Icons.restaurant,
      'title': 'Đồ ăn',
      'desc': 'Từ vựng về thức ăn và đồ uống',
      'favorite': false,
    },
    {
      'icon': Icons.pets,
      'title': 'Con vật',
      'desc': 'Từ vựng về các loài động vật',
      'favorite': true,
    },
    {
      'icon': Icons.directions_car,
      'title': 'Phương tiện',
      'desc': 'Từ vựng về phương tiện giao thông',
      'favorite': false,
    },
    {
      'icon': Icons.palette,
      'title': 'Màu sắc',
      'desc': 'Từ vựng về các màu sắc',
      'favorite': true,
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

  @override
  void initState() {
    super.initState();
    _repository.watchCards();
    _initSpeech();
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

  ({int remembered, int total, double progress}) _getDeckStats(
    String topic,
    List<SavedCard> cards,
  ) {
    final remembered = _repository.knownCountForTopic(topic);
    final savedCount = cards.where((card) => card.topic == topic).length;
    final total = _defaultTotalCardsPerTopic + savedCount;
    final progress = total == 0 ? 0.0 : remembered / total;
    return (remembered: remembered, total: total, progress: progress);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FF),
      body: SafeArea(
        child: ValueListenableBuilder<List<SavedCard>>(
          valueListenable: _repository.cardsNotifier,
          builder: (context, cards, _) {
            final filteredDecks = decks.where((deck) {
              final title = deck['title'] as String;
              final stats = _getDeckStats(title, cards);
              final normalizedTitle = _normalizeText(title);
              final normalizedSearch = _normalizeText(search);
              if (filterIndex == 1 && stats.progress == 0) {
                return false;
              }
              if (filterIndex == 2 && !(deck['favorite'] as bool)) {
                return false;
              }
              if (normalizedSearch.isNotEmpty &&
                  !normalizedTitle.contains(normalizedSearch)) {
                return false;
              }
              return true;
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: const [
                      Text(
                        'Bộ thẻ học',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm bộ thẻ...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        tooltip: _isListening
                            ? 'Dừng tìm kiếm bằng giọng nói'
                            : 'Tìm kiếm bằng giọng nói',
                        onPressed: _toggleVoiceSearch,
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _speechReady
                              ? const Color(0xFF0A5DB6)
                              : Colors.grey,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) => setState(() => search = val),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _buildFilterButton('Tất cả', 0),
                      const SizedBox(width: 8),
                      _buildFilterButton('Gần đây', 1),
                      const SizedBox(width: 8),
                      _buildFilterButton('Yêu thích', 2),
                    ],
                  ),
                ),
                Expanded(
                  child: filteredDecks.isEmpty
                      ? const Center(
                          child: Text(
                            'Không tìm thấy bộ thẻ phù hợp',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          itemCount: filteredDecks.length,
                          itemBuilder: (context, idx) {
                            final deck = filteredDecks[idx];
                            return _buildDeckCard(
                              deck,
                              cards,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FlashcardScreen(
                                      selectedTopic: deck['title'] as String,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
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
          height: 38,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0A5DB6) : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF0A5DB6),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeckCard(
    Map<String, dynamic> deck,
    List<SavedCard> cards, {
    required VoidCallback onTap,
  }) {
    final isFavorite = deck['favorite'] as bool;
    final title = deck['title'] as String;
    final stats = _getDeckStats(title, cards);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Icon(
                  deck['icon'],
                  color: const Color(0xFF0A5DB6),
                  size: 52,
                ),
              ),
              const SizedBox(width: 16),
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
                                deck['title'] as String,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                deck['desc'] as String,
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          '${stats.remembered}/${stats.total} thẻ đã ghi nhớ',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${(stats.progress * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF0A5DB6),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: stats.progress,
                      backgroundColor: const Color(0xFFE8F0FE),
                      color: const Color(0xFF0A5DB6),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
