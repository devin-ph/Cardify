import '../services/topic_classifier.dart';
import 'package:flutter/material.dart';

import '../models/saved_card.dart';
import '../services/saved_cards_repository.dart';

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

class _HomeScreenState extends State<HomeScreen> {
  static const List<Map<String, dynamic>> _dailyMissions = [
    {
      'title': 'Hoàn thành bài ôn tập',
      'xp': '+100 XP',
      'current': 3,
      'total': 3,
      'color': Color(0xFF06C0FF),
      'icon': Icons.style_rounded,
    },
    {
      'title': 'Quét 5 đồ vật mới',
      'xp': '+50 XP',
      'current': 2,
      'total': 5,
      'color': Color(0xFF7E6BFF),
      'icon': Icons.camera_alt_rounded,
    },
    {
      'title': 'Học 15 từ vựng mới',
      'xp': '+150 XP',
      'current': 10,
      'total': 15,
      'color': Color(0xFFFF7F45),
      'icon': Icons.menu_book_rounded,
    },
  ];

  static const List<Map<String, dynamic>> _mysteryObjectPool = [
    {
      'name': 'Đèn thần',
      'clue': 'Từ về ánh sáng và bóng tối',
      'icon': Icons.lightbulb_rounded,
      'rarity': 'Hiếm',
      'color': Color(0xFFFFB703),
    },
    {
      'name': 'Treasure Chest',
      'clue': 'Complete 2 scan quests to unlock',
      'icon': Icons.inventory_2_rounded,
      'rarity': 'Cực hiếm',
      'color': Color(0xFFFB8500),
    },
    {
      'name': 'Mini Fan',
      'clue': 'Learn 5 weather words today',
      'icon': Icons.toys_rounded,
      'rarity': 'Common',
      'color': Color(0xFF42B7FF),
    },
  ];

  static const List<Map<String, String>> _recentWords = [
    {
      'word': 'binoculars',
      'meaning': 'ống nhòm',
      'source': 'Scanned',
      'time': '2 phút trước',
    },
    {
      'word': 'blanket',
      'meaning': 'chăn',
      'source': 'Flashcard',
      'time': '14 phút trước',
    },
    {
      'word': 'ladder',
      'meaning': 'cái thang',
      'source': 'Scanned',
      'time': '1 giờ trước',
    },
  ];

  List<Map<String, dynamic>> _pickMysteryCards() {
    return _mysteryObjectPool.take(3).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final levelProgress = (widget.experience / widget.nextLevelExperience)
        .clamp(0.0, 1.0);

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
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  _SectionPanel(
                    title: 'Chào mừng, ${widget.userName}',
                    subtitle: 'Cùng tiếp tục hành trình học tiếng Anh',
                    actionLabel: 'Mở bộ từ',
                    onActionTap: widget.onOpenDictionary,
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF169A6E),
                            Color(0xFF28BE76),
                            Color(0xFFA6E65D),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text(
                                  'TÍNH NĂNG MỚI',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Quét Ảnh Cùng AI',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Chụp ảnh vật thể bất kỳ để tìm từ vựng trong tích tắc.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 84,
                            height: 84,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.document_scanner_rounded,
                              color: Color(0xFF0C8059),
                              size: 44,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          title: 'CHUỖI HỌC',
                          value: '${widget.streak} ngày',
                          icon: Icons.local_fire_department_rounded,
                          backgroundColor: const Color(0xFFFFF0DD),
                          iconColor: const Color(0xFFFF8C1A),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatTile(
                          title: 'CẤP ĐỘ ${widget.level}',
                          value:
                              '${widget.experience}/${widget.nextLevelExperience} XP',
                          icon: Icons.military_tech_rounded,
                          backgroundColor: const Color(0xFFEAF1FF),
                          iconColor: const Color(0xFF3269FF),
                          trailing: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              minHeight: 6,
                              value: levelProgress,
                              backgroundColor: Colors.white70,
                              valueColor: const AlwaysStoppedAnimation(
                                Color(0xFF4A81FF),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SectionPanel(
                    title: 'Nhiệm vụ hằng ngày',
                    subtitle: 'Hoàn thành để nhận thêm XP',
                    actionLabel: '',
                    onActionTap: null,
                    child: Column(
                      children: _dailyMissions.map((mission) {
                        final color = mission['color'] as Color;
                        final current = mission['current'] as int;
                        final total = mission['total'] as int;
                        final progress = (current / total).clamp(0.0, 1.0);
                        final done = current >= total;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  mission['icon'] as IconData,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mission['title'] as String,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        minHeight: 7,
                                        value: progress,
                                        backgroundColor: color.withOpacity(
                                          0.15,
                                        ),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              color,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                done ? 'Xong' : '$current/$total',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                mission['xp'] as String,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: done
                                      ? Colors.blueGrey.shade400
                                      : color,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SectionPanel(
                    title: 'Tiến trình Thẻ ghi nhớ',
                    subtitle: 'Theo dõi tiến trình các bộ thẻ đang học',
                    actionLabel: 'Mở bộ thẻ',
                    onActionTap: widget.onOpenDecks,
                    child: ValueListenableBuilder<List<SavedCard>>(
                      valueListenable:
                          SavedCardsRepository.instance.cardsNotifier,
                      builder: (context, cards, _) {
                        final total = cards.length;
                        final learned = cards
                            .where(
                              (card) => SavedCardsRepository.instance.isKnown(
                                card.id,
                                topic: TopicClassifier.normalizeTopic(
                                  card.topic,
                                ),
                              ),
                            )
                            .length;
                        final progress = total > 0 ? learned / total : 0.0;
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.78),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Đã thuộc $learned/$total thẻ',
                                style: TextStyle(
                                  color: Colors.blueGrey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  minHeight: 8,
                                  value: progress,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF45C4FF),
                                      ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Hoàn thành ${(progress * 100).round()}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF45C4FF),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SectionPanel(
                    title: 'Từ Bí Ẩn',
                    subtitle: 'Đoán từ tiếng Anh dựa trên gợi ý',
                    actionLabel: 'Đoán ngay',
                    onActionTap: widget.onOpenCameraQuest,
                    child: Column(
                      children: _pickMysteryCards().map((item) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.72),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
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
                                      item['name'] as String,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item['clue'] as String,
                                      style: TextStyle(
                                        color: Colors.blueGrey.shade600,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: (item['color'] as Color).withOpacity(
                                    0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  item['rarity'] as String,
                                  style: TextStyle(
                                    color: item['color'] as Color,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SectionPanel(
                    title: 'Từ Mới Gần Đây',
                    subtitle: 'Các từ bạn vừa học hoặc lưu lại',
                    actionLabel: 'Xem bộ từ',
                    onActionTap: widget.onOpenDictionary,
                    child: Column(
                      children: _recentWords.map((word) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.72),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF1FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.text_fields_rounded,
                                  color: Color(0xFF3269FF),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${word['word']} - ${word['meaning']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${word['source']} • ${word['time']}',
                                      style: TextStyle(
                                        color: Colors.blueGrey.shade600,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final Widget? trailing;

  const _StatTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: iconColor.withOpacity(0.8),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: Color(0xFF0B1C3D),
            ),
          ),
          if (trailing != null) ...[const SizedBox(height: 8), trailing!],
        ],
      ),
    );
  }
}

class _SectionPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onActionTap;
  final Widget child;

  const _SectionPanel({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onActionTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.95), width: 1.5),
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
              if (actionLabel.isNotEmpty)
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
    );
  }
}
