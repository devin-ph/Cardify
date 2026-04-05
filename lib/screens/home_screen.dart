import 'dart:math' as math;
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_card.dart';
import '../services/saved_cards_repository.dart';
import '../services/vocabulary_service.dart';
import '../services/xp_service.dart';
import '../services/topic_classifier.dart';
import 'flashcard_category_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  final int streak;
  final int level;
  final int experience;
  final int nextLevelExperience;
  final VoidCallback? onOpenDecks;
  final VoidCallback? onOpenDictionary;
  final VoidCallback? onOpenCameraQuest;

  const HomeScreen({
    super.key,
    this.userName = 'Explorer',
    this.streak = 8,
    this.level = 5,
    this.experience = 800,
    this.nextLevelExperience = 1000,
    this.onOpenDecks,
    this.onOpenDictionary,
    this.onOpenCameraQuest,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  static const List<Map<String, dynamic>> _bannerThemes = [
    {
      'tag': 'TÍNH NĂNG MỚI',
      'title': 'Khám Phá Thế Giới',
      'headline': 'Quét Ảnh Cùng AI',
      'message': 'Chụp ảnh vật thể bất kỳ để tìm từ vựng trong tích tắc.',
      'icon': Icons.document_scanner_rounded,
      'colors': [Color(0xFF169A6E), Color(0xFF28BE76), Color(0xFFA6E65D)],
      'chipColor': Color(0xFF0F6E4D),
      'iconColor': Color(0xFF0C8059),
    },
    {
      'tag': 'HỌC TẬP THÔNG MINH',
      'title': 'Ghi Nhớ Hiệu Quả',
      'headline': 'Flashcard Thuật Toán',
      'message': 'Lặp lại ngắt quãng giúp bạn thuộc bài lâu hơn.',
      'icon': Icons.psychology_rounded,
      'colors': [Color(0xFF3D46E8), Color(0xFF6656FF), Color(0xFF9B7BFF)],
      'chipColor': Color(0xFF2F2FAE),
      'iconColor': Color(0xFF3F42D5),
    },
    {
      'tag': 'THỬ THÁCH HẰNG NGÀY',
      'title': 'Thử Thách Bản Thân',
      'headline': 'Đấu Trường Thành Tựu',
      'message': 'Nhận XP mỗi ngày, thi đua cùng bạn bè vươn lên đỉnh!',
      'icon': Icons.emoji_events_rounded,
      'colors': [Color(0xFF0098D8), Color(0xFF1DB7F7), Color(0xFF73E3FF)],
      'chipColor': Color(0xFF006A99),
      'iconColor': Color(0xFF0A87C2),
    },
    {
      'tag': 'TỪ ĐIỂN SINH ĐỘNG',
      'title': 'Nâng Cao Vốn Từ',
      'headline': 'Kho Tàng Từ Vựng',
      'message': 'Hàng ngàn từ vựng đa chủ đề kèm phát âm thực tế.',
      'icon': Icons.menu_book_rounded,
      'colors': [Color(0xFFFF7A45), Color(0xFFFF5F6D), Color(0xFFFFB347)],
      'chipColor': Color(0xFFB93F49),
      'iconColor': Color(0xFFD54C3E),
    },
  ];

  late final PageController _bannerController;
  late final AnimationController _pulseController;
  late final AnimationController _shimmerController;
  Timer? _bannerTimer;
  int _bannerIndex = 0;
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier(0.0);
  static const String _dailyMissionClaimDateKey =
      'home_daily_mission_claim_date_v1';
  static const String _dailyMissionClaimedIdsKey =
      'home_daily_mission_claimed_ids_v1';
  Set<String> _claimedMissionIdsToday = <String>{};
  bool _missionStateLoaded = false;
  bool _isAutoClaimingMission = false;

  @override
  void initState() {
    super.initState();
    VocabularyService.instance.loadHints();
    _bannerController = PageController(viewportFraction: 1);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    _loadMissionState();
    _startBannerAutoSlide();
  }

  String _todayKey() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return '${now.year}-$mm-$dd';
  }

  Future<void> _loadMissionState() async {
    final todayKey = _todayKey();
    final prefs = await SharedPreferences.getInstance();

    final localDate = prefs.getString(_dailyMissionClaimDateKey);
    final localIds =
        prefs.getStringList(_dailyMissionClaimedIdsKey) ?? const <String>[];

    Set<String> claimed = <String>{};
    if (localDate == todayKey) {
      claimed = localIds.toSet();
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final profile = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = profile.data();
        final remoteDay = data?['daily_mission_claim_day'];
        final remoteIds = data?['daily_mission_claimed_ids'];
        if (remoteDay is String && remoteDay == todayKey && remoteIds is List) {
          claimed = remoteIds
              .map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toSet();
        }
      } catch (_) {
        // Keep mission reward flow using local state when cloud read fails.
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _claimedMissionIdsToday = claimed;
      _missionStateLoaded = true;
    });
  }

  Future<void> _persistMissionState() async {
    final todayKey = _todayKey();
    final values = _claimedMissionIdsToday.toList()..sort();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dailyMissionClaimDateKey, todayKey);
    await prefs.setStringList(_dailyMissionClaimedIdsKey, values);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'daily_mission_claim_day': todayKey,
        'daily_mission_claimed_ids': values,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Keep local mission rewards when cloud write fails.
    }
  }

  Future<void> _claimMissionReward(String missionId, int rewardXp) async {
    if (!_missionStateLoaded ||
        _isAutoClaimingMission ||
        _claimedMissionIdsToday.contains(missionId)) {
      return;
    }

    _isAutoClaimingMission = true;
    try {
      await XPService.instance.addXP(rewardXp);
      if (!mounted) {
        return;
      }
      setState(() {
        _claimedMissionIdsToday.add(missionId);
      });
      await _persistMissionState();
    } finally {
      _isAutoClaimingMission = false;
    }
  }

  void _startBannerAutoSlide() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!_bannerController.hasClients) {
        return;
      }
      final nextIndex = (_bannerIndex + 1) % _bannerThemes.length;
      _bannerController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _scrollOffsetNotifier.dispose();
    super.dispose();
  }

  static const List<Map<String, dynamic>> _unscannedHintsPool = [
    {
      'word': 'cell phone',
      'hint': 'Một thiết bị điện tử cầm tay dùng để nối mạng, gọi điện',
      'topic': 'Electronics',
    },
    {
      'word': 'chair',
      'hint': 'Đồ nội thất dùng để ngồi làm việc, thường có tựa lưng',
      'topic': 'Furniture',
    },
    {
      'word': 'cat',
      'hint': 'Loài động vật gần gũi với con người, thích bắt chuột',
      'topic': 'Animals',
    },
    {
      'word': 'potted plant',
      'hint':
          'Cây tỏa bóng xanh, thường được trồng trong chậu cảnh không gian hẹp',
      'topic': 'Nature',
    },
    {
      'word': 'laptop',
      'hint': 'Máy tính cá nhân có thể gập lại gọn gàng',
      'topic': 'Technology',
    },
    {
      'word': 'book',
      'hint': 'Nơi chứa đựng tri thức, gồm nhiều trang giấy',
      'topic': 'Learning',
    },
    {
      'word': 'banana',
      'hint': 'Loại trái cây màu vàng, thân dài, khỉ rất thích ăn',
      'topic': 'Food',
    },
    {
      'word': 'bicycle',
      'hint': 'Phương tiện di chuyển hai bánh, dùng sức người để đạp',
      'topic': 'Vehicles',
    },
    {
      'word': 'cup',
      'hint': 'Vật dụng dùng để uống nước hằng ngày',
      'topic': 'Household Items',
    },
    {
      'word': 'umbrella',
      'hint': 'Đồ vật che mưa, che nắng khi đi bộ ngoài trời',
      'topic': 'Household Items',
    },
  ];

  List<Map<String, dynamic>> _getDailyUnscannedHints(
    List<String> scannedWords,
  ) {
    // Để cho phong phú, ta có thể hiện luôn ra mà không cần lọc, hoặc lọc nếu cần
    // Nhưng vì ta chỉ hiện hint, người dùng chưa quét thì ta cứ lấy ngẫu nhiên 3 hint mỗi ngày.
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final random = math.Random(seed);

    final shuffled = List<Map<String, dynamic>>.from(_unscannedHintsPool)
      ..shuffle(random);
    return shuffled.take(3).toList();
  }

  static const List<Map<String, dynamic>> _milestoneLeagues = [
    {
      'name': 'Chưa xếp hạng',
      'xpReq': 0,
      'color': Color(0xFF4B5563),
      'icon': Icons.help_outline_rounded,
      'bgC': Color(0xFFF3F4F6),
      'gradC': [Color(0xFFFFFFFF), Color(0xFFE5E7EB)],
    },
    {
      'name': 'Đồng',
      'xpReq': 200,
      'color': Color(0xFFCD7F32),
      'icon': Icons.star_border_rounded,
      'bgC': Color(0xFFFFF6ED),
      'gradC': [Color(0xFFFFF0E6), Color(0xFFEDC9AF)],
    },
    {
      'name': 'Bạc',
      'xpReq': 1000,
      'color': Color(0xFF6B7280),
      'icon': Icons.shield_rounded,
      'bgC': Color(0xFFF3F4F6),
      'gradC': [Color(0xFFF8F9FA), Color(0xFFD1D5DB)],
    },
    {
      'name': 'Vàng',
      'xpReq': 3000,
      'color': Color(0xFFD97706),
      'icon': Icons.emoji_events_rounded,
      'bgC': Color(0xFFFFFBEB),
      'gradC': [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
    },
    {
      'name': 'Kim Cương',
      'xpReq': 6000,
      'color': Color(0xFF2563EB),
      'icon': Icons.diamond_rounded,
      'bgC': Color(0xFFEFF6FF),
      'gradC': [Color(0xFFDBEAFE), Color(0xFFBFDBFE)],
    },
    {
      'name': 'Cao Thủ',
      'xpReq': 10000,
      'color': Color(0xFF7C3AED),
      'icon': Icons.workspace_premium_rounded,
      'bgC': Color(0xFFF5F3FF),
      'gradC': [Color(0xFFEDE9FE), Color(0xFFDDD6FE)],
    },
  ];

  Map<String, dynamic> get _currentLeague {
    Map<String, dynamic> current = _milestoneLeagues.first;
    for (var league in _milestoneLeagues) {
      if (widget.experience >= league['xpReq']) {
        current = league;
      } else {
        break;
      }
    }
    return current;
  }

  Map<String, dynamic>? get _nextLeague {
    for (var league in _milestoneLeagues) {
      if (widget.experience < league['xpReq']) {
        return league;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currentL = _currentLeague;
    final nextL = _nextLeague;

    double progress = 1.0;
    if (nextL != null) {
      double xpInCurrentRank = (widget.experience - currentL['xpReq'])
          .toDouble();
      double xpNeededForNext = (nextL['xpReq'] - currentL['xpReq']).toDouble();
      progress = (xpInCurrentRank / xpNeededForNext).clamp(0.0, 1.0);
    }

    final levelProgress = progress;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFE2F3FF),
            Color(0xFFFFF4FA),
            Color(0xFFE4FAEF),
            Color(0xFFF3E5FF),
          ],
          stops: [0.0, 0.3, 0.6, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ValueListenableBuilder<double>(
        valueListenable: _scrollOffsetNotifier,
        builder: (context, scrollOffset, _) {
          return AnimatedBuilder(
            animation: _pulseController,
            child: NotificationListener<ScrollUpdateNotification>(
              onNotification: (notification) {
                final nextOffset = notification.metrics.pixels;
                if ((nextOffset - _scrollOffsetNotifier.value).abs() < 1.0) {
                  return false;
                }
                _scrollOffsetNotifier.value = nextOffset;
                return false;
              },
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _SectionReveal(
                            delayMs: 0,
                            child: _buildWelcomeBanner(),
                          ),
                          const SizedBox(height: 16),
                          _SectionReveal(
                            delayMs: 120,
                            child: _buildStatsRow(levelProgress),
                          ),
                          const SizedBox(height: 20),
                          _SectionReveal(
                            delayMs: 170,
                            child: _buildDailyMissionsSection(),
                          ),
                          const SizedBox(height: 20),
                          _SectionReveal(
                            delayMs: 220,
                            child: _buildFlashcardProgressSection(),
                          ),
                          const SizedBox(height: 20),
                          _SectionReveal(
                            delayMs: 320,
                            child: _buildMysterySuggestionsSection(),
                          ),
                          const SizedBox(height: 20),
                          _SectionReveal(
                            delayMs: 420,
                            child: _buildRecentWordsSection(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            builder: (context, child) {
              final wave = sin(_pulseController.value * pi * 2);
              final cloudParallax = scrollOffset * 0.16;
              final bubbleParallax = scrollOffset * 0.11;
              final stickerParallax = scrollOffset * 0.08;

              return Stack(
                children: [
                  Positioned(
                    top: 12,
                    left: -20,
                    child: Transform.translate(
                      offset: Offset(0, -cloudParallax),
                      child: const _GlowBubble(
                        color: Color(0xFF5EEAD4),
                        size: 200,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 180,
                    right: -40,
                    child: Transform.translate(
                      offset: Offset(0, -bubbleParallax),
                      child: const _GlowBubble(
                        color: Color(0xFFC084FC),
                        size: 240,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 80,
                    left: -30,
                    child: Transform.translate(
                      offset: Offset(0, bubbleParallax),
                      child: const _GlowBubble(
                        color: Color(0xFFC7E4FF),
                        size: 150,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 110,
                    right: 24,
                    child: Transform.translate(
                      offset: Offset(-wave * 8, -stickerParallax),
                      child: _ParallaxSticker(
                        icon: Icons.star_rounded,
                        color: const Color(0xFFFFC929),
                        size: 30,
                        angle: wave * 0.3,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 460,
                    left: 20,
                    child: Transform.translate(
                      offset: Offset(-wave * 6, -stickerParallax * 0.65),
                      child: _ParallaxSticker(
                        icon: Icons.auto_awesome_rounded,
                        color: const Color(0xFF52B6FF),
                        size: 28,
                        angle: -wave * 0.24,
                      ),
                    ),
                  ),
                  child!,
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    final activeTheme = _bannerThemes[_bannerIndex % _bannerThemes.length];
    final activeColors = activeTheme['colors'] as List<Color>;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: activeColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: activeColors[1].withValues(alpha: 0.42),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.46),
          width: 2,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          SizedBox(
            height: 168,
            child: PageView.builder(
              clipBehavior: Clip.none,
              controller: _bannerController,
              onPageChanged: (index) {
                setState(() {
                  _bannerIndex = index;
                });
              },
              itemCount: _bannerThemes.length,
              itemBuilder: (context, index) {
                final theme = _bannerThemes[index];
                final chipColor = theme['chipColor'] as Color;
                final iconColor = theme['iconColor'] as Color;

                return Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.94),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                theme['tag'] as String,
                                style: TextStyle(
                                  color: chipColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.35,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              theme['title'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(
                                    color: Colors.black12,
                                    offset: Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              theme['headline'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              theme['message'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 6, bottom: 4),
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.9, end: 1.1).animate(
                          CurvedAnimation(
                            parent: _pulseController,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.96),
                                Colors.white.withValues(alpha: 0.74),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.64),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.45),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(
                            theme['icon'] as IconData,
                            color: iconColor,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_bannerThemes.length, (index) {
              final selected = _bannerIndex == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: selected ? 24 : 8,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(double levelProgress) {
    final currentL = _currentLeague;
    final nextL = _nextLeague;
    final rankName = currentL['name'].toString().toUpperCase();
    final xpDisplay = nextL != null
        ? '${widget.experience}/${nextL['xpReq']} XP'
        : 'Đã đạt Cao Thủ';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 1,
            child: _StatCard(
              title: 'CHUỖI HỌC',
              value: '${widget.streak} ngày',
              valueSize: 24,
              icon: Icons.local_fire_department_rounded,
              backgroundColor: const Color(0xFFFFF0DD),
              iconColor: const Color(0xFFFF8C1A),
              gradientColors: const [Color(0xFFFFF4E5), Color(0xFFFFD19A)],
              animationDelay: 0,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: _StatCard(
              title: 'CẤP BẬC',
              value: '$rankName\n$xpDisplay',
              valueSize: 15,
              icon: currentL['icon'] as IconData,
              backgroundColor: currentL['bgC'] as Color,
              iconColor: currentL['color'] as Color,
              gradientColors: currentL['gradC'] as List<Color>,
              animationDelay: 100,
              trailing: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: levelProgress),
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.elasticOut,
                    builder: (context, animatedProgress, child) {
                      return LinearProgressIndicator(
                        minHeight: 6,
                        value: animatedProgress,
                        backgroundColor: Colors.white70,
                        valueColor: AlwaysStoppedAnimation(
                          currentL['color'] as Color,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyMissionsSection() {
    return ValueListenableBuilder<List<SavedCard>>(
      valueListenable: SavedCardsRepository.instance.cardsNotifier,
      builder: (context, cards, _) {
        final today = DateTime.now();

        final cardsToday = cards
            .where(
              (c) =>
                  c.savedAt.year == today.year &&
                  c.savedAt.month == today.month &&
                  c.savedAt.day == today.day,
            )
            .toList();

        final scannedToday = cardsToday
            .where((c) => c.imageBytes != null || c.imageUrl != null)
            .length;

        final wordsLearnedToday = cardsToday
            .where(
              (c) =>
                  SavedCardsRepository.instance.isKnown(c.id, topic: c.topic),
            )
            .length;

        final topicMap = <String, List<SavedCard>>{};
        for (final card in cards) {
          final topic = card.topic.trim().isNotEmpty ? card.topic : 'General';
          topicMap.putIfAbsent(topic, () => []).add(card);
        }
        int fullyLearnedSets = topicMap.entries
            .where(
              (e) => e.value.every(
                (c) =>
                    SavedCardsRepository.instance.isKnown(c.id, topic: e.key),
              ),
            )
            .length;

        final user = FirebaseAuth.instance.currentUser;
        final userSeed = user?.uid.hashCode ?? 0;
        final todaySeed =
            today.year * 10000 + today.month * 100 + today.day + userSeed;
        final random = Random(todaySeed);

        final scanTargets = [3, 5, 7, 10];
        final selectedScanTarget =
            scanTargets[random.nextInt(scanTargets.length)];

        final learnTargets = [5, 10, 15, 20];
        final selectedLearnTarget =
            learnTargets[random.nextInt(learnTargets.length)];

        final reviewTargets = [1, 2, 3];
        final selectedReviewTarget =
            reviewTargets[random.nextInt(reviewTargets.length)];

        final List<Map<String, dynamic>> dailyMissions = [
          {
            'id': 'review_$selectedReviewTarget',
            'title': selectedReviewTarget == 1
                ? 'Hoàn thành bài ôn tập'
                : 'Hoàn thành $selectedReviewTarget bài ôn tập',
            'xp': '+${selectedReviewTarget * 50} XP',
            'rewardXp': selectedReviewTarget * 50,
            'current': fullyLearnedSets,
            'total': selectedReviewTarget,
            'color': const Color(0xFF06C0FF),
            'icon': Icons.style_rounded,
          },
          {
            'id': 'scan_$selectedScanTarget',
            'title': 'Quét $selectedScanTarget đồ vật mới',
            'xp': '+${selectedScanTarget * 10} XP',
            'rewardXp': selectedScanTarget * 10,
            'current': scannedToday,
            'total': selectedScanTarget,
            'color': const Color(0xFF7E6BFF),
            'icon': Icons.camera_alt_rounded,
          },
          {
            'id': 'learn_$selectedLearnTarget',
            'title': 'Học thuộc $selectedLearnTarget từ vựng mới',
            'xp': '+${selectedLearnTarget * 10} XP',
            'rewardXp': selectedLearnTarget * 10,
            'current': wordsLearnedToday,
            'total': selectedLearnTarget,
            'color': const Color(0xFFFF7F45),
            'icon': Icons.menu_book_rounded,
          },
        ]..shuffle(random);

        if (_missionStateLoaded && !_isAutoClaimingMission) {
          final claimable = dailyMissions.where((mission) {
            final id = mission['id'] as String;
            final current = mission['current'] as int;
            final total = mission['total'] as int;
            return current >= total && !_claimedMissionIdsToday.contains(id);
          }).toList();

          if (claimable.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              for (final mission in claimable) {
                if (!mounted) {
                  return;
                }
                await _claimMissionReward(
                  mission['id'] as String,
                  mission['rewardXp'] as int,
                );
              }
            });
          }
        }

        return _FrostedPanel(
          title: 'Nhiệm vụ hằng ngày',
          subtitle: 'Hoàn thành để nhận thêm XP',
          actionLabel: '',
          onActionTap: null,
          child: Column(
            children: dailyMissions.map((mission) {
              final missionId = mission['id'] as String;
              final color = mission['color'] as Color;
              final current = mission['current'] as int;
              final total = mission['total'] as int;
              final isCompleted = current >= total;
              final isClaimed = _claimedMissionIdsToday.contains(missionId);
              final displayColor = isCompleted
                  ? const Color(0xFF6EE7B7)
                  : color;
              final progress = (current / total).clamp(0.0, 1.0);

              return _BounceTap(
                onTap: () {
                  if (isCompleted && !isClaimed) {
                    unawaited(
                      _claimMissionReward(
                        missionId,
                        mission['rewardXp'] as int,
                      ),
                    );
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFFE8FFF5)
                        : Colors.grey.shade50.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCompleted
                          ? displayColor.withValues(alpha: 0.5)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isCompleted
                              ? Icons.check_circle_rounded
                              : mission['icon'] as IconData,
                          color: isCompleted ? const Color(0xFF10B981) : color,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mission['title'] as String,
                              style: TextStyle(
                                color: isCompleted
                                    ? const Color(0xFF104A33)
                                    : const Color(0xFF2D3142),
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                decoration: isCompleted
                                    ? TextDecoration.none
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      minHeight: 7,
                                      value: progress,
                                      backgroundColor: isCompleted
                                          ? displayColor.withValues(alpha: 0.2)
                                          : color.withValues(alpha: 0.15),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        displayColor,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 36,
                                  child: Text(
                                    '${current > total ? total : current}/$total',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: displayColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 60,
                        child: Text(
                          isClaimed ? 'Đã nhận' : mission['xp'] as String,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: isClaimed
                                ? const Color(0xFF10B981)
                                : (isCompleted ? Colors.grey.shade500 : color),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Map<String, dynamic> _getDeckStyle(String rawTopic) {
    final norm = TopicClassifier.normalizeTopic(rawTopic);
    switch (norm) {
      case 'Electronics':
        return {
          'icon': Icons.electrical_services,
          'color': const Color(0xFF45C4FF),
        };
      case 'Furniture':
        return {'icon': Icons.chair_alt, 'color': const Color(0xFF8E7CFF)};
      case 'Animals':
        return {'icon': Icons.pets, 'color': const Color(0xFFFFA62A)};
      case 'Nature':
        return {'icon': Icons.nature, 'color': const Color(0xFF4ADE80)};
      case 'Technology':
        return {'icon': Icons.memory, 'color': const Color(0xFF06C0FF)};
      case 'Learning':
        return {'icon': Icons.school, 'color': const Color(0xFFFF7F45)};
      case 'Food':
        return {'icon': Icons.restaurant, 'color': const Color(0xFFEF4444)};
      case 'Vehicles':
        return {'icon': Icons.directions_car, 'color': const Color(0xFF8B5CF6)};
      case 'Household Items':
        return {'icon': Icons.kitchen, 'color': const Color(0xFF14B8A6)};
      default:
        return {'icon': Icons.style_rounded, 'color': const Color(0xFF0A5DB6)};
    }
  }

  Widget _buildFlashcardProgressSection() {
    return ValueListenableBuilder<List<SavedCard>>(
      valueListenable: SavedCardsRepository.instance.cardsNotifier,
      builder: (context, cards, _) {
        if (cards.isEmpty) {
          return _FrostedPanel(
            title: 'Thẻ ghi nhớ',
            subtitle: 'Theo dõi tiến trình các bộ thẻ đang học',
            actionLabel: 'Mở bộ thẻ',
            onActionTap: widget.onOpenDecks,
            child: SizedBox(
              height: 176,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.style_rounded,
                        size: 40,
                        color: Colors.blueGrey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Bạn chưa có bộ thẻ nào.\n Hãy chụp ảnh hoặc lưu từ mới vào thẻ ghi nhớ!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.blueGrey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final topicMap = <String, List<SavedCard>>{};
        for (final card in cards) {
          final topic = card.topic.trim().isNotEmpty ? card.topic : 'General';
          topicMap.putIfAbsent(topic, () => []).add(card);
        }

        final decks = topicMap.entries.toList().asMap().entries.map((entry) {
          final topic = entry.value.key;
          final topicCards = entry.value.value;

          final total = topicCards.length;
          final learned = topicCards
              .where(
                (card) => SavedCardsRepository.instance.isKnown(
                  card.id,
                  topic: topic,
                ),
              )
              .length;

          final progress = total > 0 ? learned / total : 0.0;
          final style = _getDeckStyle(topic);

          return {
            'name': topic,
            'progress': progress,
            'learned': learned,
            'total': total,
            'color': style['color'],
            'icon': style['icon'],
          };
        }).toList();

        return _FrostedPanel(
          title: 'Thẻ ghi nhớ',
          subtitle: 'Theo dõi tiến trình các bộ thẻ đang học',
          actionLabel: 'Mở bộ thẻ',
          onActionTap: widget.onOpenDecks,
          child: SizedBox(
            height: 176,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: decks.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final deck = decks[index];
                final progress = (deck['progress'] as double).clamp(0.0, 1.0);
                return _BounceTap(
                  onTap: () {
                    final selectedTopic = deck['name'] as String;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FlashcardScreen(
                          selectedTopic: TopicClassifier.normalizeTopic(
                            selectedTopic,
                          ),
                          showOnlyTrackedWords: false,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 210,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: (deck['color'] as Color).withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                deck['icon'] as IconData,
                                color: deck['color'] as Color,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                deck['name'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          "Đã thuộc ${deck['learned']}/${deck['total']} thẻ",
                          style: TextStyle(
                            color: Colors.blueGrey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: progress),
                            duration: Duration(milliseconds: 900 + index * 180),
                            curve: Curves.easeOut,
                            builder: (context, animatedProgress, child) {
                              return LinearProgressIndicator(
                                minHeight: 8,
                                value: animatedProgress,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  deck['color'] as Color,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hoàn thành ${(progress * 100).round()}%',
                          style: TextStyle(
                            color: (deck['color'] as Color).withValues(
                              alpha: 0.92,
                            ),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildMysterySuggestionsSection() {
    final List<Map<String, dynamic>> mysteryWords = [
      ..._getDailyUnscannedHints([]),
    ];

    return ValueListenableBuilder<List<SavedCard>>(
      valueListenable: SavedCardsRepository.instance.cardsNotifier,
      builder: (context, cards, _) {
        return _FrostedPanel(
          title: 'Từ Bí Ẩn',
          subtitle: 'Quét để khám phá từ mới',
          actionLabel: 'Quét ngay',
          onActionTap: widget.onOpenCameraQuest,
          child: Column(
            children: mysteryWords
                .map((item) {
                  final targetWord = item['word'] as String;

                  // Check if user has this card with an image
                  final foundCard = cards.cast<SavedCard?>().firstWhere(
                    (c) =>
                        c != null &&
                        c.word.toLowerCase() == targetWord.toLowerCase() &&
                        (c.imageBytes != null || c.imageUrl != null),
                    orElse: () => null,
                  );

                  final isFound = foundCard != null;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        if (isFound) {
                          widget.onOpenDictionary?.call();
                        } else {
                          widget.onOpenCameraQuest?.call();
                        }
                      },
                      child: Ink(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isFound
                              ? const Color(0xFFF0FDF4)
                              : Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isFound
                                ? const Color(0xFF86EFAC)
                                : Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              clipBehavior: Clip.hardEdge,
                              decoration: BoxDecoration(
                                color: isFound
                                    ? const Color(0xFFDCFCE7)
                                    : Colors.grey.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: isFound
                                  ? (foundCard.imageBytes != null
                                        ? Image.memory(
                                            foundCard.imageBytes!,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.network(
                                            foundCard.imageUrl!,
                                            fit: BoxFit.cover,
                                          ))
                                  : const Icon(
                                      Icons.question_mark_rounded,
                                      size: 32,
                                      color: Colors.blueGrey,
                                    ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isFound ? foundCard.word : '???',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: isFound
                                          ? const Color(0xFF065F46)
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isFound
                                        ? foundCard.meaning
                                        : 'Gợi ý: ${item['hint']}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isFound
                                          ? const Color(0xFF059669)
                                          : Colors.blueGrey.shade600,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      fontStyle: isFound
                                          ? FontStyle.normal
                                          : FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isFound
                                    ? const Color(0xFF10B981)
                                    : const Color(
                                        0xFFFB8500,
                                      ).withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isFound) ...[
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    isFound ? 'Đã thêm' : 'Chưa Tìm',
                                    style: TextStyle(
                                      color: isFound
                                          ? Colors.white
                                          : const Color(0xFFFB8500),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
        );
      },
    );
  }

  Widget _buildRecentWordsSection() {
    return ValueListenableBuilder<List<SavedCard>>(
      valueListenable: SavedCardsRepository.instance.cardsNotifier,
      builder: (context, cards, _) {
        final now = DateTime.now();
        final recentWords = cards
            .where(
              (c) =>
                  c.savedAt.year == now.year &&
                  c.savedAt.month == now.month &&
                  c.savedAt.day == now.day,
            )
            .toList();

        if (recentWords.isEmpty) {
          return _FrostedPanel(
            title: 'Từ mới',
            subtitle: 'Danh sách từ vựng bạn mới thêm trong hôm nay',
            actionLabel: 'Mở từ điển',
            onActionTap: widget.onOpenDictionary,
            child: SizedBox(
              height: 80,
              child: Center(
                child: Text(
                  'Hôm nay bạn chưa học hoặc quét từ vựng nào!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.blueGrey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }

        return _FrostedPanel(
          title: 'Từ mới',
          subtitle: 'Danh sách từ vựng bạn mới thêm trong hôm nay',
          actionLabel: 'Mở từ điển',
          onActionTap: widget.onOpenDictionary,
          child: SizedBox(
            height: 90,
            child: PageView.builder(
              clipBehavior: Clip.none,
              controller: PageController(
                viewportFraction: 0.85,
                initialPage: recentWords.length * 100,
              ),
              itemBuilder: (context, index) {
                final card = recentWords[index % recentWords.length];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE4EEFF)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF2FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: card.imageBytes != null
                            ? Image.memory(card.imageBytes!, fit: BoxFit.cover)
                            : card.imageUrl != null
                            ? Image.network(card.imageUrl!, fit: BoxFit.cover)
                            : const Icon(
                                Icons.psychology_rounded,
                                color: Color(0xFF3276FF),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              card.word,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Color(0xFF102956),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              card.meaning,
                              style: TextStyle(
                                color: Colors.blueGrey.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _GlowBubble extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowBubble({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.4),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParallaxSticker extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double angle;

  const _ParallaxSticker({
    required this.icon,
    required this.color,
    required this.size,
    required this.angle,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(size / 2.4),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Icon(icon, color: color, size: size * 0.7),
      ),
    );
  }
}

class _SectionReveal extends StatelessWidget {
  final Widget child;
  final int delayMs;

  const _SectionReveal({required this.child, required this.delayMs});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 540 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 40),
          child: animatedChild,
        );
      },
      child: child,
    );
  }
}

class _BounceTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _BounceTap({required this.child, required this.onTap});

  @override
  State<_BounceTap> createState() => _BounceTapState();
}

class _BounceTapState extends State<_BounceTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final double valueSize;
  final IconData icon;
  final Widget? trailing;
  final Color backgroundColor;
  final Color iconColor;
  final List<Color> gradientColors;
  final int animationDelay;

  const _StatCard({
    required this.title,
    required this.value,
    this.valueSize = 23,
    required this.icon,
    this.trailing,
    required this.backgroundColor,
    required this.iconColor,
    this.gradientColors = const [Colors.white, Colors.white],
    this.animationDelay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Transform.rotate(
              angle: -0.2,
              child: Icon(
                icon,
                size: 90,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ),
          Positioned(
            top: -30,
            right: -10,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.6),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: iconColor.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 20, color: iconColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: iconColor.withValues(alpha: 0.95),
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: valueSize,
                  color: const Color(0xFF0B1C3D),
                  height: 1.1,
                  shadows: [
                    Shadow(
                      color: Colors.white.withValues(alpha: 0.8),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(height: 8), trailing!],
            ],
          ),
        ],
      ),
    );
  }
}

class _FrostedPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onActionTap;
  final Widget child;

  const _FrostedPanel({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.child,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.95),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              color: Color(0xFF102956),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.blueGrey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: onActionTap,
                      child: Text(
                        actionLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1D74FF),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
