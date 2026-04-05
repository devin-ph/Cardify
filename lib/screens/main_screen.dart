import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cardify_ai_english_learning_app/screens/deck_list_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/analysis_result.dart';
import '../services/firestore_sync_status.dart';
import '../services/saved_cards_repository.dart';
import '../services/topic_classifier.dart';
import '../services/xp_service.dart';
import '../widgets/ai_voice_chat_dialog.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../widgets/profile_icon.dart';
import 'achievements_screen.dart';
import 'calendar_screen.dart';
import 'dictionary_screen.dart';
import 'flashcard_category_screen.dart';
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
  static const String _scheduleStorageKey = 'calendar_scheduled_decks_by_day';
  static const String _scheduleTimeStorageKey = 'calendar_scheduled_time_by_day';
  static const String _completedDueDecksStorageKey =
      'calendar_completed_due_decks_by_day_v1';
  static const String _recentAccessHistoryKey = 'deck_recent_access_history_v1';

  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isDictionarySearching = false;
  String _userName = 'Explorer';
  String _userEmail = 'explorer@cardify.ai';
  int _streak = 0;
  int _experience = 0;
  int _level = 1;
  int _nextLevelExperience = 1000;
  Uint8List? _userAvatarBytes;
  final SavedCardsRepository _cardsRepository = SavedCardsRepository.instance;
  StreamSubscription<firebase_auth.User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _profileSubscription;
  String? _boundProfileUid;
  late final Widget _calendarTab;
  late final Widget _dictionaryTab;
  late final Widget _deckListTab;
  late final Widget _achievementsTab;
  Timer? _dueStudyCheckTimer;
  bool _isDueStudyDialogVisible = false;
  bool _isLaunchingDueDeck = false;

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

    _dueStudyCheckTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _checkAndPromptDueStudy(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptDueStudy();
    });

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

              final remoteAvatarBase64 = data['avatar_base64']
                  ?.toString()
                  .trim();
              if (remoteAvatarBase64 != null && remoteAvatarBase64.isNotEmpty) {
                try {
                  _userAvatarBytes = base64Decode(remoteAvatarBase64);
                } catch (_) {
                  _userAvatarBytes = null;
                }
              } else {
                _userAvatarBytes = null;
              }
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
    _dueStudyCheckTimer?.cancel();
    _profileSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  String _dateKey(DateTime date) {
    final normalized = DateUtils.dateOnly(date);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }

  Map<String, List<String>> _decodeStringListMap(String? raw) {
    final parsed = <String, List<String>>{};
    if (raw == null || raw.isEmpty) {
      return parsed;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return parsed;
    }

    for (final entry in decoded.entries) {
      final key = entry.key.toString().trim();
      if (key.isEmpty || entry.value is! List) {
        continue;
      }
      final values = (entry.value as List)
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();
      if (values.isNotEmpty) {
        parsed[key] = values;
      }
    }
    return parsed;
  }

  Map<String, String> _decodeStringMap(String? raw) {
    final parsed = <String, String>{};
    if (raw == null || raw.isEmpty) {
      return parsed;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return parsed;
    }

    for (final entry in decoded.entries) {
      final key = entry.key.toString().trim();
      final value = entry.value?.toString().trim() ?? '';
      if (key.isNotEmpty && value.isNotEmpty) {
        parsed[key] = value;
      }
    }
    return parsed;
  }

  DateTime? _parseScheduledDateTimeForToday(String? rawTime) {
    if (rawTime == null || rawTime.isEmpty) {
      return null;
    }

    final parts = rawTime.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  bool _isSameMinute(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day &&
        a.hour == b.hour &&
        a.minute == b.minute;
  }

  Set<String> _loadPracticedDecksTodayFromRecentHistory(
    SharedPreferences prefs,
  ) {
    final today = DateUtils.dateOnly(DateTime.now());
    final entries = prefs.getStringList(_recentAccessHistoryKey) ??
        const <String>[];
    final practicedDecks = <String>{};

    for (final rawEntry in entries) {
      final parts = rawEntry.split('|');
      if (parts.length < 4) {
        continue;
      }

      final rawTopic = parts[0].trim();
      final rawTimestamp = int.tryParse(parts[1].trim());
      final practiced = parts[2].trim() == '1';
      if (!practiced || rawTopic.isEmpty || rawTimestamp == null) {
        continue;
      }

      final practicedDate = DateUtils.dateOnly(
        DateTime.fromMillisecondsSinceEpoch(rawTimestamp),
      );
      if (!DateUtils.isSameDay(practicedDate, today)) {
        continue;
      }

      practicedDecks.add(TopicClassifier.toVietnameseCanonical(rawTopic));
    }

    return practicedDecks;
  }

  Future<void> _saveCompletedDueDecksByDay(
    SharedPreferences prefs,
    Map<String, List<String>> completed,
  ) async {
    await prefs.setString(_completedDueDecksStorageKey, jsonEncode(completed));
  }

  Future<void> _markDueDeckCompleted(String dayKey, String deck) async {
    final normalizedDeck = deck.trim();
    if (normalizedDeck.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final completed = _decodeStringListMap(
      prefs.getString(_completedDueDecksStorageKey),
    );
    final updated = <String>{...(completed[dayKey] ?? const <String>[])}
      ..add(normalizedDeck);
    completed[dayKey] = updated.toList();
    await _saveCompletedDueDecksByDay(prefs, completed);
  }

  Future<void> _checkAndPromptDueStudy() async {
    if (!mounted ||
        _isLoading ||
        _isDueStudyDialogVisible ||
        _isLaunchingDueDeck) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final todayKey = _dateKey(DateTime.now());

    final scheduledDecksByDay =
        _decodeStringListMap(prefs.getString(_scheduleStorageKey));
    final scheduledTimeByDay =
        _decodeStringMap(prefs.getString(_scheduleTimeStorageKey));
    final completedByDay =
        _decodeStringListMap(prefs.getString(_completedDueDecksStorageKey));

    final scheduledDecksToday = scheduledDecksByDay[todayKey] ??
        const <String>[];
    if (scheduledDecksToday.isEmpty) {
      return;
    }

    final scheduledAt = _parseScheduledDateTimeForToday(
      scheduledTimeByDay[todayKey],
    );
    if (scheduledAt == null) {
      return;
    }

    final now = DateTime.now();
    if (now.isBefore(scheduledAt) || !_isSameMinute(now, scheduledAt)) {
      return;
    }

    final practicedToday = _loadPracticedDecksTodayFromRecentHistory(prefs);
    final completedToday = <String>{
      ...(completedByDay[todayKey] ?? const <String>[]),
      ...practicedToday,
    };
    completedToday.removeWhere((deck) => !scheduledDecksToday.contains(deck));

    final previousCompletedLength =
        (completedByDay[todayKey] ?? const <String>[]).length;
    if (completedToday.length != previousCompletedLength) {
      completedByDay[todayKey] = completedToday.toList();
      await _saveCompletedDueDecksByDay(prefs, completedByDay);
    }

    final remainingDecks = scheduledDecksToday
        .where((deck) => !completedToday.contains(deck))
        .toList();
    if (remainingDecks.isEmpty) {
      return;
    }

    _isDueStudyDialogVisible = true;
    try {
      final chosenDeck = await _showDueStudyDialog(remainingDecks);
      if (chosenDeck == null || !mounted) {
        return;
      }

      _isLaunchingDueDeck = true;
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) => FlashcardScreen(selectedTopic: chosenDeck),
        ),
      );
      _isLaunchingDueDeck = false;

      final practiced = result?['practiced'] == true || result?['completed'] == true;
      final completedTopic =
          result?['completedTopic']?.toString().trim().isNotEmpty == true
          ? result!['completedTopic'].toString().trim()
          : chosenDeck;
      if (practiced) {
        await _markDueDeckCompleted(todayKey, completedTopic);
      }

      if (!mounted) {
        return;
      }

      if (practiced) {
        _setScreenIndex(3);
        await HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã hoàn thành: $completedTopic')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bạn chưa hoàn thành danh mục đã chọn. Vui lòng học để tiếp tục.',
            ),
          ),
        );
      }
    } finally {
      _isLaunchingDueDeck = false;
      _isDueStudyDialogVisible = false;
    }

    if (mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await _checkAndPromptDueStudy();
    }
  }

  Future<String?> _showDueStudyDialog(List<String> remainingDecks) async {
    String? selectedDeck = remainingDecks.first;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                title: const Text('Đến giờ học rồi!'),
                content: SizedBox(
                  width: 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chọn 1 danh mục để học ngay:',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 260),
                        child: SingleChildScrollView(
                          child: Column(
                            children: remainingDecks.map((deck) {
                              return RadioListTile<String>(
                                value: deck,
                                groupValue: selectedDeck,
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedDeck = value;
                                  });
                                },
                                title: Text(deck),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  FilledButton(
                    onPressed: selectedDeck == null
                        ? null
                        : () => Navigator.of(dialogContext).pop(selectedDeck),
                    child: const Text('Học ngay'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
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
    final userPhotoUrl =
        firebase_auth.FirebaseAuth.instance.currentUser?.photoURL;

    final mainContent = Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: const Text('Cardify'),
        titleTextStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 24,
          letterSpacing: 0.2,
          color: Color(0xFF2E1065),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 230, 220, 249),
                Color.fromARGB(255, 215, 248, 246),
                Color.fromARGB(255, 212, 226, 252),
              ],
              stops: [0.0, 0.5, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border(
              bottom: BorderSide(color: Color(0xFFE4E7F0), width: 1),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ProfileIcon(
              onTap: _onProfileTap,
              displayName: _userName,
              photoUrl: userPhotoUrl,
              avatarBytes: _userAvatarBytes,
            ),
          ),
        ],
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
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF7C3AED),
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: const BorderSide(color: Color(0xFFE2E8F5), width: 1),
                ),
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
