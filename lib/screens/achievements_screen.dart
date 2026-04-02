import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ambientController;
  late final AnimationController _progressController;

  static const int _userTotalCardsStudied = 120; // Mock current user total cards
  static const int _userTotalSetsCompleted = 4;   // Mock user total sets
  static const int _currentStreak = 8;

  bool _showAllBadges = false;

  static const List<Map<String, dynamic>> _oasisElements = [
    {'id': 'mushrooms', 'name': 'Hạt mầm', 'desc': 'Học 10 thẻ', 'icon': '🌱', 'reqType': 'cards', 'reqValue': 10, 'color': Color(0xFF34D399)},
    {'id': 'flowers', 'name': 'Bụi hoa', 'desc': 'Hoàn thành 1 bộ thẻ', 'icon': '🌺', 'reqType': 'sets', 'reqValue': 1, 'color': Color(0xFFF472B6)},
    {'id': 'trees', 'name': 'Cây xanh', 'desc': 'Hoàn thành 3 bộ thẻ', 'icon': '🌳', 'reqType': 'sets', 'reqValue': 3, 'color': Color(0xFF4ADE80)},
    {'id': 'animals', 'name': 'Động vật', 'desc': 'Hoàn thành 5 bộ thẻ', 'icon': '🦌', 'reqType': 'sets', 'reqValue': 5, 'color': Color(0xFF10B981)},
    {'id': 'household', 'name': 'Nhà nấm', 'desc': 'Hoàn thành 8 bộ thẻ', 'icon': '🍄', 'reqType': 'sets', 'reqValue': 8, 'color': Color(0xFFF87171)},
    {'id': 'tent', 'name': 'Lều trại', 'desc': 'Học 50 thẻ', 'icon': '⛺', 'reqType': 'cards', 'reqValue': 50, 'color': Color(0xFF60A5FA)},
    {'id': 'lighthouse', 'name': 'Hải đăng', 'desc': 'Học 100 thẻ', 'icon': '🗼', 'reqType': 'cards', 'reqValue': 100, 'color': Color(0xFF2563EB)},
    {'id': 'castle', 'name': 'Lâu đài', 'desc': 'Học 200 thẻ', 'icon': '🏰', 'reqType': 'cards', 'reqValue': 200, 'color': Color(0xFFA78BFA)},
    {'id': 'airballoon', 'name': 'Khí cầu', 'desc': 'Học 300 thẻ', 'icon': '🎈', 'reqType': 'cards', 'reqValue': 300, 'color': Color(0xFFFBBF24)},
    {'id': 'space', 'name': 'Vũ trụ', 'desc': 'Học 500 thẻ', 'icon': '🚀', 'reqType': 'cards', 'reqValue': 500, 'color': Color(0xFFC084FC)},
    {'id': 'rabbit', 'name': 'Thỏ trắng', 'desc': 'Chuỗi học 7 ngày', 'icon': '🐇', 'reqType': 'Số ngày', 'reqValue': 7, 'color': Color(0xFFDC2626)},
    {'id': 'magic', 'name': 'Pháp thuật', 'desc': 'Chuỗi học 14 ngày', 'icon': '✨', 'reqType': 'Số ngày', 'reqValue': 14, 'color': Color(0xFFFDE047)},
  ];

  bool _isElementUnlocked(Map<String, dynamic> e) {
    if (e['reqType'] == 'sets') {
      return _userTotalSetsCompleted >= e['reqValue'];
    } else if (e['reqType'] == 'cards') {
      return _userTotalCardsStudied >= e['reqValue'];
    } else if (e['reqType'] == 'Số ngày') {
      return _currentStreak >= e['reqValue'];
    }
    return false;
  }

  static const int _userTotalXp = 3450; // Mock current user XP

  static const List<Map<String, dynamic>> _milestoneLeagues = [
    {'name': 'Đồng (Bronze)', 'xpReq': 0, 'color': Color(0xFFCD7F32)},
    {'name': 'Bạc (Silver)', 'xpReq': 1000, 'color': Color(0xFFC0C0C0)},
    {'name': 'Vàng (Gold)', 'xpReq': 3000, 'color': Color(0xFFFFD700)},
    {'name': 'Kim Cương (Diamond)', 'xpReq': 6000, 'color': Color(0xFF00BFFF)},
    {'name': 'Cao Thủ (Master)', 'xpReq': 10000, 'color': Color(0xFFFF00FF)},
  ];

  static const List<Map<String, dynamic>> _ghostProfiles = [
    {'name': 'Cú Chăm Chỉ', 'avatar': '🦉', 'xpOffset': 150},
    {'name': 'Mèo Lười', 'avatar': '🐱', 'xpOffset': -200},
    {'name': 'Sói Cô Độc', 'avatar': '🐺', 'xpOffset': 50},
    {'name': 'Gấu Bé', 'avatar': '🐻', 'xpOffset': -80},
  ];

  int get _userLevel => (_userTotalXp / 500).floor() + 1;
  int get _xpForNextLevel => _userLevel * 500;

  Map<String, dynamic> get _currentLeague {
    Map<String, dynamic> current = _milestoneLeagues.first;
    for (var league in _milestoneLeagues) {
      if (_userTotalXp >= league['xpReq']) {
        current = league;
      } else {
        break;
      }
    }
    return current;
  }

  Map<String, dynamic>? get _nextLeague {
    for (var league in _milestoneLeagues) {
      if (_userTotalXp < league['xpReq']) {
        return league;
      }
    }
    return null;
  }

  double get _leagueProgress {
    final next = _nextLeague;
    if (next == null) return 1.0;
    final current = _currentLeague;
    double xpInCurrentRank = (_userTotalXp - current['xpReq']).toDouble();
    double xpNeededForNext = (next['xpReq'] - current['xpReq']).toDouble();
    return (xpInCurrentRank / xpNeededForNext).clamp(0.0, 1.0);
  }

  List<Map<String, dynamic>> _getDailySeededGhosts() {
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final random = Random(seed);
    
    List<Map<String, dynamic>> bots = _ghostProfiles.map((ghost) {
      final dailyVar = random.nextInt(60) - 30; // Random variance -30 to 30 XP
      int botXp = _userTotalXp + (ghost['xpOffset'] as int) + dailyVar;
      if (botXp < 0) botXp = 0;
      
      return {
        'name': ghost['name'],
        'avatar': ghost['avatar'],
        'xp': botXp,
        'isMe': false,
      };
    }).toList();
    
    bots.add({
      'name': 'Bạn',
      'avatar': '🧑',
      'xp': _userTotalXp,
      'isMe': true,
    });
    
    bots.sort((a, b) => (b['xp'] as int).compareTo(a['xp'] as int));
    return bots;
  }

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE9F4FF), Color(0xFFDFF0FF), Color(0xFFF4EBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _ambientController,
            builder: (context, child) {
              final value = _ambientController.value;
              return Stack(
                children: [
                  _AmbientOrb(
                    top: -50 + value * 30,
                    left: -40,
                    size: 220,
                    color: const Color(0xFF38BDF8),
                  ),
                  _AmbientOrb(
                    top: 220 - value * 24,
                    right: -70,
                    size: 260,
                    color: const Color(0xFF8B5CF6),
                  ),
                  _AmbientOrb(
                    bottom: 60 + value * 20,
                    left: -40,
                    size: 180,
                    color: const Color(0xFFFF4D95),
                  ),
                ],
              );
            },
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildHeader(),
                      const SizedBox(height: 14),
                      _buildLeaguePanel(), // Leo Tháp
                      const SizedBox(height: 14),
                      _buildGhostPanel(), // Bóng ma
                      const SizedBox(height: 14),
                      _buildOasisPanel(), // Khu vườn
                      const SizedBox(height: 14),
                      _buildBadgePanel(), // Bộ sưu tập
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.65),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.9)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'THÀNH TỰU',
                      style: TextStyle(
                        color: Color(0xFF3B82F6),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Đại sảnh Danh vọng',
                      style: TextStyle(
                        color: Color(0xFF102956),
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Mở khóa huy hiệu, leo bậc xếp hạng và trở thành nhà vô địch!',   
                      style: TextStyle(
                        color: Color(0xFF42516E),
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.92, end: 1.06),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeInOut,
                builder: (context, scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF3B82F6).withOpacity(0.12),
                    border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xFFF59E0B),
                    size: 44,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaguePanel() {
    final current = _currentLeague;
    final next = _nextLeague;
    final leagueColor = current['color'] as Color;

    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  current['name'],
                  style: TextStyle(
                    color: leagueColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: leagueColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Thành tích Cá nhân',
                  style: TextStyle(
                    color: Color(0xFF42516E),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            next != null
                ? '${_userTotalXp}/${next['xpReq']} XP để lên bậc tiếp theo'
                : 'Bạn đã đạt cấp cao nhất!',
            style: const TextStyle(color: Color(0xFF42516E), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AnimatedBuilder(
              animation: _progressController,
              builder: (context, child) {
                return LinearProgressIndicator(
                  minHeight: 10,
                  value: _leagueProgress * _progressController.value,
                  backgroundColor: Colors.black12,
                  valueColor: AlwaysStoppedAnimation<Color>(leagueColor),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _QuickStat(
                icon: Icons.local_fire_department_rounded,
                label: 'Chuỗi',
                value: '12',
                color: const Color(0xFFFFA94D),
              ),
              const SizedBox(width: 10),
              _QuickStat(
                icon: Icons.bolt_rounded,
                label: 'Tổng XP',
                value: '$_userTotalXp',
                color: const Color(0xFF5EEAD4),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGhostPanel() {
    final ghosts = _getDailySeededGhosts();
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bảng xếp hạng',
            style: TextStyle(
              color: Color(0xFF0B1C3D),
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Học bài mỗi ngày và thi đua với những người khác',
            style: TextStyle(color: Color(0xFF42516E), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...ghosts.map((g) {
            final isMe = g['isMe'] == true;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFFE9F4FF).withOpacity(0.9) : const Color(0xFFFFFFFF).withOpacity(0.72),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isMe ? const Color(0xFF3B82F6).withOpacity(0.4) : Colors.black12,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    g['avatar'],
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      g['name'],
                      style: TextStyle(
                        color: isMe ? const Color(0xFF1D4ED8) : const Color(0xFF102956),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    '${g['xp']} XP',
                    style: TextStyle(color: isMe ? const Color(0xFF1D4ED8) : const Color(0xFF42516E), fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOasisPanel() {
    final unlockedElements = _oasisElements.where((e) => _isElementUnlocked(e)).toList();
    final isBarren = unlockedElements.isEmpty;

    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Ốc đảo kỳ diệu',
                style: TextStyle(
                  color: Color(0xFF0B1C3D),
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.amberAccent,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isBarren 
                ? 'Hoàn thành bộ thẻ để gieo sự sống trên đảo hoang!' 
                : 'Thiên đường nhỏ từ sự nỗ lực của bạn!',
            style: const TextStyle(color: Color(0xFF42516E), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 280, // Taller structure to afford breathing space
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Animated sea waves background
                  AnimatedBuilder(
                    animation: _ambientController,
                    builder: (context, child) {
                      return Positioned(
                        bottom: -15 + sin(_ambientController.value * pi * 2) * 8,
                        left: -50,
                        right: -50,
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.lightBlueAccent.withOpacity(0.4),
                            borderRadius: const BorderRadius.all(Radius.elliptical(500, 80)),
                          ),
                        ),
                      );
                    },
                  ),
                  // Sun
                  const Positioned(
                    top: 16, right: 24,
                    child: Text('☀️', style: TextStyle(fontSize: 40)),
                  ),
                  // Animated clouds
                  AnimatedBuilder(
                    animation: _ambientController,
                    builder: (context, child) {
                      return Positioned(
                        left: -30 + (_ambientController.value * 40),
                        top: 30,
                        child: const Text('☁️', style: TextStyle(fontSize: 35, color: Color(0xFF42516E))),
                      );
                    },
                  ),
                  // Wide Island Base
                  Positioned(
                    bottom: -30,
                    left: -20,
                    right: -20,
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: isBarren ? const Color(0xFFD4A373) : const Color(0xFF4ADE80),
                        borderRadius: const BorderRadius.all(Radius.elliptical(350, 140)),
                        border: Border.all(color: Color(0xFF42516E).withOpacity(0.5), width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6))
                        ],
                      ),
                    ),
                  ),
                  // Barren Mode
                  if (isBarren)
                    Positioned(
                      bottom: 40, left: 0, right: 0,
                      child: Center(
                        child: Transform.scale(
                          scale: 1.5,
                          child: const Text('🏜️', style: TextStyle(fontSize: 50)),
                        ),
                      ),
                    ),
                  // Organized Elements by Depth Layers
                  if (!isBarren) ...[
                    // BACK LAYER
                    if (unlockedElements.any((e) => e['id'] == 'castle')) 
                      const Positioned(bottom: 75, left: 0, right: 0, child: Center(child: Text('🏰', style: TextStyle(fontSize: 70)))),
                    if (unlockedElements.any((e) => e['id'] == 'trees')) 
                      const Positioned(bottom: 60, left: 40, child: Text('🌳', style: TextStyle(fontSize: 55))),
                    if (unlockedElements.any((e) => e['id'] == 'household')) 
                      const Positioned(bottom: 55, right: 50, child: Text('🍄', style: TextStyle(fontSize: 45))),
                    if (unlockedElements.any((e) => e['id'] == 'animals')) ...[
                      const Positioned(bottom: 40, right: 110, child: Text('🦌', style: TextStyle(fontSize: 35))),
                      AnimatedBuilder(
                        animation: _ambientController,
                        builder: (context, child) {
                          return Positioned(
                            bottom: 80 + sin(_ambientController.value * pi * 2) * 10, 
                            left: 80, 
                            child: const Text('🦋', style: TextStyle(fontSize: 20))
                          );
                        }
                      ),
                    ],
                    if (unlockedElements.any((e) => e['id'] == 'rabbit')) 
                      const Positioned(bottom: 30, left: 80, child: Text('🐇', style: TextStyle(fontSize: 35))),

                    // FRONT LAYER
                    if (unlockedElements.any((e) => e['id'] == 'flowers')) ...[
                      const Positioned(bottom: 15, left: 160, child: Text('🌺', style: TextStyle(fontSize: 14))),
                      const Positioned(bottom: 35, right: 90, child: Text('🌺', style: TextStyle(fontSize: 16))),
                      const Positioned(bottom: 20, left: 60, child: Text('🌼', style: TextStyle(fontSize: 14))),
                      const Positioned(bottom: 8, right: 45, child: Text('🌻', style: TextStyle(fontSize: 14))),
                    ],
                    if (unlockedElements.any((e) => e['id'] == 'mushrooms')) ...[
                      const Positioned(bottom: 25, right: 60, child: Text('🌱', style: TextStyle(fontSize: 16))),
                      const Positioned(bottom: 10, right: 120, child: Text('🌱', style: TextStyle(fontSize: 14))),
                      const Positioned(bottom: 30, left: 90, child: Text('🌱', style: TextStyle(fontSize: 15))),
                      const Positioned(bottom: 15, left: 50, child: Text('🌱', style: TextStyle(fontSize: 12))),
                      const Positioned(bottom: 20, right: 20, child: Text('🌱', style: TextStyle(fontSize: 14))),
                    ],
                    
                    // WATER (SHORE) LAYER
                    if (unlockedElements.any((e) => e['id'] == 'lighthouse'))
                      const Positioned(
                        bottom: 0, 
                        right: 20, 
                        child: Text('🗼', style: TextStyle(fontSize: 45))
                      ),
                    if (unlockedElements.any((e) => e['id'] == 'tent')) ...[
                      const Positioned(bottom: -5, left: 30, child: Text('⛺', style: TextStyle(fontSize: 40))),
                    ],

                    // SKY LAYER
                    if (unlockedElements.any((e) => e['id'] == 'airballoon')) 
                      AnimatedBuilder(
                        animation: _ambientController,
                        builder: (context, child) {
                          return Positioned(
                            bottom: 130 + sin(_ambientController.value * pi) * 15, 
                            left: 20, 
                            child: const Text('🎈', style: TextStyle(fontSize: 40))
                          );
                        }
                      ),
                    if (unlockedElements.any((e) => e['id'] == 'space')) 
                      AnimatedBuilder(
                        animation: _ambientController,
                        builder: (context, child) {
                          return Positioned(
                            top: 20 + sin(_ambientController.value * pi * 2) * 10, 
                            right: 60, 
                            child: const Text('🚀', style: TextStyle(fontSize: 35))
                          );
                        }
                      ),
                    if (unlockedElements.any((e) => e['id'] == 'magic')) 
                      AnimatedBuilder(
                        animation: _ambientController,
                        builder: (context, child) {
                          return Positioned(
                            bottom: 110 + sin(_ambientController.value * pi * 2) * 20, 
                            left: 170 + cos(_ambientController.value * pi * 2) * 40, 
                            child: const Text('✨', style: TextStyle(fontSize: 30))
                          );
                        }
                      ),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgePanel() {
    List<Map<String, dynamic>> sortedElements = List.from(_oasisElements);
    sortedElements.sort((a, b) {
      bool aUnl = _isElementUnlocked(a);
      bool bUnl = _isElementUnlocked(b);
      if (aUnl && !bUnl) return -1;
      if (!aUnl && bUnl) return 1;
      return 0; // maintain original order otherwise
    });

    List<Map<String, dynamic>> displayElements = _showAllBadges 
        ? sortedElements 
        : sortedElements.where((e) => !_isElementUnlocked(e)).take(4).toList();

    if (displayElements.isEmpty && !_showAllBadges) {
      displayElements = sortedElements.take(4).toList();
    }

    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Bộ sưu tập Ốc đảo',
                  style: TextStyle(
                    color: Color(0xFF0B1C3D),
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAllBadges = !_showAllBadges;
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6EE7B7),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _showAllBadges ? 'Thu gọn' : 'Xem tất cả',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Hoàn thành các mốc thử thách để thêm các sinh vật và cảnh quan đến ốc đảo!',
            style: TextStyle(color: Color(0xFF42516E), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: GridView.builder(
              key: ValueKey(_showAllBadges),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayElements.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 140,
              ),
              itemBuilder: (context, index) {
                final e = displayElements[index];
                return _OasisItemCard(
                  delayMs: 120 * (index % 4),
                  title: e['name'] as String,
                  desc: e['desc'] as String,
                  iconStr: e['icon'] as String,
                  unlocked: _isElementUnlocked(e),
                  color: e['color'] as Color,
                  reqXp: e['reqValue'] as int,
                  reqType: e['reqType'] as String,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OasisItemCard extends StatelessWidget {
  final int delayMs;
  final String title;
  final String desc;
  final String iconStr;
  final bool unlocked;
  final Color color;
  final int reqXp;
  final String reqType;

  const _OasisItemCard({
    required this.delayMs,
    required this.title,
    required this.desc,
    required this.iconStr,
    required this.unlocked,
    required this.color,
    required this.reqXp,
    required this.reqType,
  });

  @override
  Widget build(BuildContext context) {
    final background = unlocked
        ? color.withOpacity(0.16)
        : Color(0xFFFFFFFF).withOpacity(0.6);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 540 + delayMs),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 24),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(0xFFFFFFFF).withOpacity(0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: unlocked ? color.withOpacity(0.6) : Colors.black12,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      iconStr,
                      style: TextStyle(
                        fontSize: 20,
                        color: unlocked ? null : Color(0xFF42516E).withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  unlocked ? Icons.verified_rounded : Icons.lock_rounded,
                  color: unlocked ? const Color(0xFF6EE7B7) : Color(0xFF42516E).withOpacity(0.5),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: unlocked ? Color(0xFF0B1C3D) : Color(0xFF42516E),
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                desc,
                style: TextStyle(
                  color: Color(0xFF0B1C3D).withOpacity(0.6),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  height: 1.2,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;

  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.85)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _QuickStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Color(0xFFFFFFFF).withOpacity(0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0B1C3D),
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF42516E),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double size;
  final Color color;

  const _AmbientOrb({
    required this.size,
    required this.color,
    this.top,
    this.left,
    this.right,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withOpacity(0.36), color.withOpacity(0.0)],
            ),
          ),
        ),
      ),
    );
  }
}


