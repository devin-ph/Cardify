import 'package:app_btl/screens/deck_list_screen.dart';
import 'package:flutter/material.dart';
import '../models/analysis_result.dart';
import '../services/saved_cards_repository.dart';
import '../widgets/ai_voice_chat_dialog.dart';
import '../widgets/profile_icon.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import 'achievements_screen.dart';
import 'image_capture_screen.dart';
import 'calendar_screen.dart';
import 'home_screen.dart';
import 'dictionary_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _previousIndex = 0;
  final String _userName = 'Explorer';
  final String _userEmail = 'explorer.cardify@example.com';
  final SavedCardsRepository _cardsRepository = SavedCardsRepository.instance;

  void _setScreenIndex(int index) {
    if (_currentIndex == index) {
      return;
    }
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
    });
  }

  void _onNavTap(int index) {
    _setScreenIndex(index);
  }

  void _onCameraTap() {
    _setScreenIndex(-1); // Special index for camera
  }

  void _onDrawerNavTap(int index) {
    Navigator.of(context).pop();
    if (index == -1) {
      _onCameraTap();
      return;
    }
    _onNavTap(index);
  }

  void _onProfileTap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ProfileScreen(),
      ),
    );
  }

  void _onChatTap() {
    showDialog(
      context: context,
      builder: (context) => const AiVoiceChatDialog(),
    );
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
                savedWords.add(candidate.word);
              }

              if (!mounted) {
                return;
              }

              setModalState(() {
                pending.removeWhere(
                  (item) => item.normalizedWord == candidate.normalizedWord,
                );
              });

              if (pending.isEmpty && Navigator.of(dialogContext).canPop()) {
                Navigator.of(dialogContext).pop();
              }
            }

            Future<void> saveAll() async {
              final toSave = List<ChatVocabularyCandidate>.from(pending);
              for (final item in toSave) {
                await saveOne(item);
              }
              if (Navigator.of(dialogContext).canPop()) {
                Navigator.of(dialogContext).pop();
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
                  child: const Text('Thoát'),
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
        return HomeScreen(
          userName: _userName,
          streak: 12,
          level: 5,
          experience: 820,
          nextLevelExperience: 1200,
          onOpenDecks: () => _onNavTap(3),
          onOpenDictionary: () => _onNavTap(2),
          onOpenCameraQuest: _onCameraTap,
        );
      case 1:
        return const CalendarScreen();
      case 2:
        return const DictionaryScreen();
      case 3:
        return DeckListScreen();
      case 4:
        return const AchievementsScreen();
      case -1:
        return const ImageCaptureScreen();
      default:
        return const Center(child: Text('Trang chủ'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI English Learning'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble),
            onPressed: _onChatTap,
            tooltip: 'Chat với AI',
          ),
          ProfileIcon(onTap: _onProfileTap),
        ],
      ),
        body: _getBody(),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 28.0),
          child: FloatingActionButton(
            onPressed: _onCameraTap,
            child: const Icon(Icons.camera_alt),
            tooltip: 'Chụp ảnh',
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
