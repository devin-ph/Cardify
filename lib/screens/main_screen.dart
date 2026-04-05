import 'dart:async';

import 'package:cardify_ai_english_learning_app/screens/deck_list_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import '../models/analysis_result.dart';
import '../services/firestore_sync_status.dart';
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
import 'main_loading_screen.dart';
import 'profile_settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isDictionarySearching = false;
  String _userName = 'Explorer';
  String _userEmail = 'explorer@cardify.ai';
  int _streak = 0;
  int _experience = 0;
  int _level = 1;
  int _nextLevelExperience = 1000;
  final SavedCardsRepository _cardsRepository = SavedCardsRepository.instance;
  StreamSubscription<firebase_auth.User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _profileSubscription;
  String? _boundProfileUid;
  late final Widget _calendarTab;
  late final Widget _dictionaryTab;
  late final Widget _deckListTab;
  late final Widget _achievementsTab;

  @override
  void initState() {
    super.initState();
    _calendarTab = const CalendarScreen();
    _dictionaryTab = DictionaryScreen(
      onSearchModeChanged: _onDictionarySearchModeChanged,
    );
    _deckListTab = DeckListScreen();
    _achievementsTab = const AchievementsScreen();

    _authSubscription = firebase_auth.FirebaseAuth.instance
        .authStateChanges()
        .listen((_) {
          _bindUserProfileStream();
        });
    _bindUserProfileStream();

    // Show a beautiful splash loading state
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _bindUserProfileStream() {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      _profileSubscription?.cancel();
      _profileSubscription = null;
      _boundProfileUid = null;
      return;
    }

    if (_boundProfileUid == user.uid && _profileSubscription != null) {
      return;
    }

    _profileSubscription?.cancel();
    _boundProfileUid = user.uid;

    FirestoreSyncStatus.instance.reportReading(
      path: 'users/${user.uid}',
      reason: 'theo dõi realtime hồ sơ người dùng',
    );

    _profileSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
          (snapshot) {
            if (!snapshot.exists) {
              return;
            }
            final data = snapshot.data() ?? <String, dynamic>{};
            if (!mounted) {
              return;
            }

            setState(() {
              _userName =
                  data['display_name']?.toString().trim().isNotEmpty == true
                  ? data['display_name'].toString().trim()
                  : 'Explorer';
              _userEmail = data['email']?.toString().trim().isNotEmpty == true
                  ? data['email'].toString().trim()
                  : (user.email ?? _userEmail);
              _streak = (data['streak'] as num?)?.toInt() ?? _streak;
              _experience = (data['xp'] as num?)?.toInt() ?? _experience;
              _level = (data['level'] as num?)?.toInt() ?? _level;
              _nextLevelExperience =
                  (data['next_level_xp'] as num?)?.toInt() ??
                  _nextLevelExperience;
            });

            FirestoreSyncStatus.instance.reportSuccess(
              path: 'users/${user.uid}',
              message: 'Đã cập nhật hồ sơ từ Firestore realtime',
            );
          },
          onError: (Object error) {
            FirestoreSyncStatus.instance.reportError(
              path: 'users/${user.uid}',
              operation: 'listen main profile',
              error: error,
            );
          },
        );
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
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
        builder: (context) =>
            ProfileSettingsScreen(name: _userName, email: _userEmail),
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
                        separatorBuilder: (_, _) => const Divider(height: 16),
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

  Widget _buildHomeTab() {
    return ValueListenableBuilder<int>(
      valueListenable: XPService.instance.xpNotifier,
      builder: (context, xp, child) {
        return ValueListenableBuilder<int>(
          valueListenable: XPService.instance.streakNotifier,
          builder: (context, streak, child) {
            return HomeScreen(
              userName: _userName,
              streak: streak,
              level: XPService.instance.levelNotifier.value,
              experience: xp,
              nextLevelExperience:
                  XPService.instance.levelNotifier.value * 1000,
              onOpenDecks: () => _onNavTap(3),
              onOpenDictionary: () => _onNavTap(2),
              onOpenCameraQuest: _onCameraTap,
            );
          },
        );
      },
    );
  }

  Widget _getBody() {
    if (_currentIndex == -1) {
      return ImageCaptureScreen(onDone: () => _onNavTap(2));
    }

    return IndexedStack(
      index: _currentIndex,
      children: [
        _buildHomeTab(),
        _calendarTab,
        _dictionaryTab,
        _deckListTab,
        _achievementsTab,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final showFloatingButtons =
        _currentIndex != -1 && !(_currentIndex == 2 && _isDictionarySearching);

    final mainContent = Scaffold(
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

    return Stack(
      children: [
        RepaintBoundary(child: mainContent),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 900),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            final isOut = child.key == const ValueKey('loading');
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: isOut
                    ? Tween<double>(begin: 1.4, end: 1.0).animate(animation)
                    : Tween<double>(begin: 0.98, end: 1.0).animate(animation),
                child: child,
              ),
            );
          },
          child: _isLoading
              ? const MainLoadingScreen(key: ValueKey('loading'))
              : const SizedBox.shrink(key: ValueKey('content')),
        ),
      ],
    );
  }
}
