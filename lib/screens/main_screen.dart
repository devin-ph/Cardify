import 'package:cardify_ai_english_learning_app/screens/deck_list_screen.dart';
import 'package:flutter/material.dart';

import '../models/analysis_result.dart';
import '../services/saved_cards_repository.dart';
import '../services/xp_service.dart';
import '../widgets/ai_voice_chat_dialog.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../widgets/profile_icon.dart';
import 'achievements_screen.dart';
import 'calendar_screen.dart';
import 'dictionary_screen.dart';
import 'home_screen.dart';
import 'image_capture_screen.dart';
import 'profile_settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isDictionarySearching = false;
  String _userName = 'Explorer';
  final SavedCardsRepository _cardsRepository = SavedCardsRepository.instance;

  @override
  void initState() {
    super.initState();
  }

  void _setScreenIndex(int index) {
    if (_currentIndex == index) {
      return;
    }

    setState(() {
      if (_currentIndex == 2 && index != 2) {
        _isDictionarySearching = false;
      }
      _currentIndex = index;
    });
  }

  void _onDictionarySearchModeChanged(bool isSearching) {
    if (!mounted || _isDictionarySearching == isSearching) {
      return;
    }

    setState(() {
      _isDictionarySearching = isSearching;
    });
  }

  void _onNavTap(int index) {
    _setScreenIndex(index);
  }

  void _onCameraTap() {
    _setScreenIndex(-1);
  }

  Future<void> _onProfileTap() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => ProfileSettingsScreen(
          name: _userName,
          email: 'explorer@cardify.ai',
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    final updatedName = result['name']?.toString().trim();
    if (updatedName != null && updatedName.isNotEmpty) {
      setState(() {
        _userName = updatedName;
      });
    }
  }

  Future<void> _onChatTap() async {
    final result = await showDialog(
      context: context,
      builder: (context) => const AiVoiceChatDialog(),
    );

    if (result is List<ChatVocabularyCandidate> && result.isNotEmpty) {
      await _showChatVocabularySaveDialog(result);
    }
  }

  Future<List<String>> _showChatVocabularySaveDialog(
    List<ChatVocabularyCandidate> candidates,
  ) async {
    final pending = List<ChatVocabularyCandidate>.from(candidates);
    final savedWords = <String>[];

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> saveOne(ChatVocabularyCandidate candidate) async {
              try {
                final normalized = candidate.normalizedWord;
                final existing = await _cardsRepository.findExistingWord(
                  normalized,
                );
                if (existing == null) {
                  final analysis = AnalysisResult(
                    topic: candidate.topic,
                    word: candidate.word,
                    phonetic: candidate.phonetic,
                    vietnameseMeaning: candidate.vietnameseMeaning,
                    wordType: candidate.intentType,
                    exampleSentence: candidate.exampleSentence,
                    pronunciationGuide: candidate.pronunciationGuide,
                  );
                  await _cardsRepository.saveResult(analysis, null);
                  await XPService.instance.addXP(35);
                  savedWords.add(candidate.word);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã lưu từ vựng! +35 XP')),
                    );
                  }
                }

                if (!mounted) {
                  return;
                }

                setModalState(() {
                  pending.removeWhere(
                    (item) => item.normalizedWord == candidate.normalizedWord,
                  );
                });

                if (pending.isEmpty) {
                  Navigator.of(dialogContext).pop();
                }
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              }
            }

            Future<void> saveAll() async {
              final toSave = List<ChatVocabularyCandidate>.from(pending);
              for (final item in toSave) {
                await saveOne(item);
              }
            }

            return AlertDialog(
              title: const Text('Từ phát hiện trong đoạn chat'),
              content: SizedBox(
                width: 420,
                child: pending.isEmpty
                    ? const Text('Không còn từ nào cần lưu.')
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: pending.length,
                        separatorBuilder: (_, __) => const Divider(height: 16),
                        itemBuilder: (context, index) {
                          final item = pending[index];
                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.word,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(item.vietnameseMeaning),
                                    if (item.phonetic.isNotEmpty)
                                      Text(
                                        item.phonetic,
                                        style: const TextStyle(
                                          color: Colors.black54,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton(
                                onPressed: () => saveOne(item),
                                child: const Text('Lưu'),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Đóng'),
                ),
                if (pending.isNotEmpty)
                  FilledButton(
                    onPressed: saveAll,
                    child: const Text('Lưu tất cả'),
                  ),
              ],
            );
          },
        );
      },
    );

    return savedWords;
  }

  Widget _getBody() {
    switch (_currentIndex) {
      case 0:
        return ValueListenableBuilder<int>(
          valueListenable: XPService.instance.xpNotifier,
          builder: (context, xp, child) {
            return HomeScreen(
              userName: _userName,
              streak: 12,
              level: (xp ~/ 1000) + 1,
              experience: xp,
              nextLevelExperience: ((xp ~/ 1000) + 1) * 1000,
              onOpenDecks: () => _onNavTap(3),
              onOpenDictionary: () => _onNavTap(2),
              onOpenCameraQuest: _onCameraTap,
            );
          },
        );
      case 1:
        return const CalendarScreen();
      case 2:
        return DictionaryScreen(
          onSearchModeChanged: _onDictionarySearchModeChanged,
        );
      case 3:
        return DeckListScreen();
      case 4:
        return const AchievementsScreen();
      case -1:
        return ImageCaptureScreen(onDone: () => _onNavTap(2));
      default:
        return const Center(child: Text('Trang chủ'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final showFloatingButtons =
        _currentIndex != -1 && !(_currentIndex == 2 && _isDictionarySearching);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI English Learning'),
        centerTitle: true,
        elevation: 0,
        actions: [ProfileIcon(onTap: _onProfileTap)],
      ),
      body: Stack(
        children: [
          _getBody(),
          if (showFloatingButtons)
            Positioned(
              right: 16,
              bottom: 92,
              child: FloatingActionButton(
                heroTag: 'ai_chat_fab',
                mini: true,
                onPressed: _onChatTap,
                tooltip: 'Chat với AI',
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/onboarding/robot_icon.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton:
          _currentIndex == -1 || (_currentIndex == 2 && _isDictionarySearching)
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 28.0),
              child: FloatingActionButton(
                onPressed: _onCameraTap,
                tooltip: 'Chụp ảnh',
                child: const Icon(Icons.camera_alt),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex < 0 ? 0 : _currentIndex,
        onTap: _onNavTap,
        onCameraTap: _onCameraTap,
      ),
    );
  }
}
