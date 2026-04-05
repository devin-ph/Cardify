import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/saved_cards_repository.dart';
import '../services/xp_service.dart';

class ProfileScreen extends StatefulWidget {
  final String name;
  final String email;
  final String socialId;
  final Uint8List? avatarBytes;

  const ProfileScreen({
    super.key,
    this.name = 'Người dùng',
    this.email = 'user@email.com',
    this.socialId = '',
    this.avatarBytes,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  static const List<Map<String, dynamic>> _oasisElements = [
    {
      'id': 'mushrooms',
      'name': 'Hạt mầm',
      'desc': 'Học 10 thẻ',
      'icon': '🌱',
      'reqType': 'cards',
      'reqValue': 10,
      'color': Color(0xFF34D399),
    },
    {
      'id': 'flowers',
      'name': 'Bụi hoa',
      'desc': 'Quét 1 đồ vật',
      'icon': '🌺',
      'reqType': 'scans',
      'reqValue': 1,
      'color': Color(0xFFF472B6),
    },
    {
      'id': 'trees',
      'name': 'Cây xanh',
      'desc': 'Quét 5 đồ vật',
      'icon': '🌳',
      'reqType': 'scans',
      'reqValue': 5,
      'color': Color(0xFF4ADE80),
    },
    {
      'id': 'animals',
      'name': 'Động vật',
      'desc': 'Quét 15 đồ vật',
      'icon': '🦌',
      'reqType': 'scans',
      'reqValue': 15,
      'color': Color(0xFF10B981),
    },
    {
      'id': 'household',
      'name': 'Nhà nấm',
      'desc': 'Quét 30 đồ vật',
      'icon': '🍄',
      'reqType': 'scans',
      'reqValue': 30,
      'color': Color(0xFFF87171),
    },
    {
      'id': 'tent',
      'name': 'Lều trại',
      'desc': 'Đạt hạng Đồng',
      'icon': '⛺',
      'reqType': 'xp',
      'reqValue': 200,
      'color': Color(0xFF60A5FA),
    },
    {
      'id': 'lighthouse',
      'name': 'Hải đăng',
      'desc': 'Đạt hạng Bạc',
      'icon': '🗼',
      'reqType': 'xp',
      'reqValue': 1000,
      'color': Color(0xFF2563EB),
    },
    {
      'id': 'castle',
      'name': 'Lâu đài',
      'desc': 'Đạt hạng Vàng',
      'icon': '🏰',
      'reqType': 'xp',
      'reqValue': 3000,
      'color': Color(0xFFA78BFA),
    },
    {
      'id': 'airballoon',
      'name': 'Khí cầu',
      'desc': 'Đạt hạng Kim Cương',
      'icon': '🎈',
      'reqType': 'xp',
      'reqValue': 6000,
      'color': Color(0xFFFBBF24),
    },
    {
      'id': 'space',
      'name': 'Vũ trụ',
      'desc': 'Đạt hạng Cao Thủ',
      'icon': '🚀',
      'reqType': 'xp',
      'reqValue': 10000,
      'color': Color(0xFFC084FC),
    },
    {
      'id': 'rabbit',
      'name': 'Thỏ trắng',
      'desc': 'Chuỗi học 7 ngày',
      'icon': '🐇',
      'reqType': 'Số ngày',
      'reqValue': 7,
      'color': Color(0xFFDC2626),
    },
    {
      'id': 'magic',
      'name': 'Pháp thuật',
      'desc': 'Chuỗi học 14 ngày',
      'icon': '✨',
      'reqType': 'Số ngày',
      'reqValue': 14,
      'color': Color(0xFFFDE047),
    },
  ];

  late String name;
  late String email;
  late String socialId;
  Uint8List? avatarBytes;
  late final AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    name = widget.name;
    email = widget.email;
    socialId = widget.socialId;
    avatarBytes = widget.avatarBytes;
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _ambientController.dispose();
    super.dispose();
  }

  int get _userTotalScans => SavedCardsRepository.instance.cardsNotifier.value
      .where((c) => c.imageBytes != null || c.imageUrl != null)
      .length;

  int get _currentStreak => XPService.instance.streakNotifier.value;

  bool _isElementUnlocked(Map<String, dynamic> e, int userXp) {
    if (e['reqType'] == 'scans') {
      return _userTotalScans >= e['reqValue'];
    }
    if (e['reqType'] == 'Số ngày') {
      return _currentStreak >= e['reqValue'];
    }
    if (e['reqType'] == 'xp') {
      return userXp >= e['reqValue'];
    }
    return false;
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD7E3F8)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1E3A8A)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF5A6A80),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOasisPanel(int userXp) {
    final unlockedElements = _oasisElements
        .where((e) => _isElementUnlocked(e, userXp))
        .toList();
    final isBarren = unlockedElements.isEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD8E5FB)),
      ),
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
                  color: Colors.amber.withValues(alpha: 0.2),
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
            style: const TextStyle(
              color: Color(0xFF42516E),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 280,
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
                            color: Colors.lightBlueAccent.withValues(alpha: 0.4),
                            borderRadius: const BorderRadius.all(
                              Radius.elliptical(500, 80),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const Positioned(
                    top: 16,
                    right: 24,
                    child: Text('☀️', style: TextStyle(fontSize: 40)),
                  ),
                  AnimatedBuilder(
                    animation: _ambientController,
                    builder: (context, child) {
                      return Positioned(
                        left: -30 + (_ambientController.value * 40),
                        top: 30,
                        child: const Text(
                          '☁️',
                          style: TextStyle(fontSize: 35, color: Color(0xFF42516E)),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    bottom: -30,
                    left: -20,
                    right: -20,
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: isBarren
                            ? const Color(0xFFD4A373)
                            : const Color(0xFF4ADE80),
                        borderRadius: const BorderRadius.all(
                          Radius.elliptical(350, 140),
                        ),
                        border: Border.all(
                          color: const Color(0xFF42516E).withValues(alpha: 0.5),
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isBarren) ...[
                    const Positioned(
                      bottom: 30,
                      left: 110,
                      child: Text('🪨', style: TextStyle(fontSize: 32)),
                    ),
                    const Positioned(
                      bottom: 25,
                      right: 120,
                      child: Text('🪵', style: TextStyle(fontSize: 36)),
                    ),
                    const Positioned(
                      bottom: 50,
                      left: 45,
                      child: Text('🌵', style: TextStyle(fontSize: 60)),
                    ),
                    const Positioned(
                      bottom: 45,
                      right: 50,
                      child: Text('🌵', style: TextStyle(fontSize: 45)),
                    ),
                    const Positioned(
                      bottom: 60,
                      right: 100,
                      child: Text('🪨', style: TextStyle(fontSize: 24)),
                    ),
                  ],
                  if (!isBarren) ...[
                    if (unlockedElements.any((e) => e['id'] == 'castle'))
                      const Positioned(
                        bottom: 75,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text('🏰', style: TextStyle(fontSize: 70)),
                        ),
                      ),
                    if (unlockedElements.any((e) => e['id'] == 'trees'))
                      const Positioned(
                        bottom: 60,
                        left: 40,
                        child: Text('🌳', style: TextStyle(fontSize: 55)),
                      ),
                    if (unlockedElements.any((e) => e['id'] == 'household'))
                      const Positioned(
                        bottom: 55,
                        right: 50,
                        child: Text('🍄', style: TextStyle(fontSize: 45)),
                      ),
                    if (unlockedElements.any((e) => e['id'] == 'animals')) ...[
                      const Positioned(
                        bottom: 40,
                        right: 110,
                        child: Text('🦌', style: TextStyle(fontSize: 35)),
                      ),
                      AnimatedBuilder(
                        animation: _ambientController,
                        builder: (context, child) {
                          return Positioned(
                            bottom: 80 + sin(_ambientController.value * pi * 2) * 10,
                            left: 80,
                            child: const Text('🦋', style: TextStyle(fontSize: 20)),
                          );
                        },
                      ),
                    ],
                    if (unlockedElements.any((e) => e['id'] == 'rabbit'))
                      const Positioned(
                        bottom: 30,
                        left: 80,
                        child: Text('🐇', style: TextStyle(fontSize: 35)),
                      ),
                    if (unlockedElements.any((e) => e['id'] == 'flowers')) ...[
                      const Positioned(
                        bottom: 15,
                        left: 160,
                        child: Text('🌺', style: TextStyle(fontSize: 14)),
                      ),
                      const Positioned(
                        bottom: 35,
                        right: 90,
                        child: Text('🌺', style: TextStyle(fontSize: 16)),
                      ),
                      const Positioned(
                        bottom: 20,
                        left: 60,
                        child: Text('🌼', style: TextStyle(fontSize: 14)),
                      ),
                      const Positioned(
                        bottom: 8,
                        right: 45,
                        child: Text('🌻', style: TextStyle(fontSize: 14)),
                      ),
                    ],
                    if (unlockedElements.any((e) => e['id'] == 'mushrooms')) ...[
                      const Positioned(
                        bottom: 25,
                        right: 60,
                        child: Text('🌱', style: TextStyle(fontSize: 16)),
                      ),
                      const Positioned(
                        bottom: 10,
                        right: 120,
                        child: Text('🌱', style: TextStyle(fontSize: 14)),
                      ),
                      const Positioned(
                        bottom: 30,
                        left: 90,
                        child: Text('🌱', style: TextStyle(fontSize: 15)),
                      ),
                      const Positioned(
                        bottom: 15,
                        left: 50,
                        child: Text('🌱', style: TextStyle(fontSize: 12)),
                      ),
                      const Positioned(
                        bottom: 20,
                        right: 20,
                        child: Text('🌱', style: TextStyle(fontSize: 14)),
                      ),
                    ],
                    if (unlockedElements.any((e) => e['id'] == 'lighthouse'))
                      const Positioned(
                        bottom: 0,
                        right: 20,
                        child: Text('🗼', style: TextStyle(fontSize: 45)),
                      ),
                    if (unlockedElements.any((e) => e['id'] == 'tent'))
                      const Positioned(
                        bottom: -5,
                        left: 30,
                        child: Text('⛺', style: TextStyle(fontSize: 40)),
                      ),
                    if (unlockedElements.any((e) => e['id'] == 'airballoon'))
                      AnimatedBuilder(
                        animation: _ambientController,
                        builder: (context, child) {
                          return Positioned(
                            bottom: 130 + sin(_ambientController.value * pi) * 15,
                            left: 20,
                            child: const Text('🎈', style: TextStyle(fontSize: 40)),
                          );
                        },
                      ),
                    if (unlockedElements.any((e) => e['id'] == 'space'))
                      AnimatedBuilder(
                        animation: _ambientController,
                        builder: (context, child) {
                          return Positioned(
                            top: 20 + sin(_ambientController.value * pi * 2) * 10,
                            right: 60,
                            child: const Text('🚀', style: TextStyle(fontSize: 35)),
                          );
                        },
                      ),
                    if (unlockedElements.any((e) => e['id'] == 'magic'))
                      AnimatedBuilder(
                        animation: _ambientController,
                        builder: (context, child) {
                          return Positioned(
                            bottom: 110 + sin(_ambientController.value * pi * 2) * 20,
                            left: 170 + cos(_ambientController.value * pi * 2) * 40,
                            child: const Text('✨', style: TextStyle(fontSize: 30)),
                          );
                        },
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        backgroundColor: const Color(0xFFEEF3FF),
        foregroundColor: const Color(0xFF1A2755),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF3F6FF),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 22),
        child: ValueListenableBuilder<List<dynamic>>(
          valueListenable: SavedCardsRepository.instance.cardsNotifier,
          builder: (context, _, __) {
            return ValueListenableBuilder<int>(
              valueListenable: XPService.instance.streakNotifier,
              builder: (context, streak, ___) {
                return ValueListenableBuilder<int>(
                  valueListenable: XPService.instance.levelNotifier,
                  builder: (context, level, ____) {
                    return ValueListenableBuilder<int>(
                      valueListenable: XPService.instance.xpNotifier,
                      builder: (context, xp, _____) {
                        return Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFDDEBFF), Color(0xFFEFF7EC)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFFD5E4F8)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: const Color(
                                      0xFF1E3A8A,
                                    ).withValues(alpha: 0.12),
                                    backgroundImage: avatarBytes != null
                                        ? MemoryImage(avatarBytes!)
                                        : null,
                                    child: avatarBytes == null
                                        ? Text(
                                            name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1E3A8A),
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF1E3A8A),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          email,
                                          style: const TextStyle(
                                            color: Color(0xFF4F617B),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          socialId.trim().isEmpty
                                              ? 'ID: Đang tạo...'
                                              : 'ID: $socialId',
                                          style: const TextStyle(
                                            color: Color(0xFF4F617B),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricChip(
                                    icon: Icons.local_fire_department_rounded,
                                    label: 'Chuỗi học',
                                    value: '$streak ngày',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildMetricChip(
                                    icon: Icons.document_scanner_rounded,
                                    label: 'Số từ đã quét',
                                    value: '$_userTotalScans từ',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildMetricChip(
                                    icon: Icons.shield_rounded,
                                    label: 'Cấp bậc',
                                    value: 'Cấp $level',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _buildOasisPanel(xp),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
