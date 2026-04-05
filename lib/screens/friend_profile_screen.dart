import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/magic_oasis_scene.dart';

class FriendProfileScreen extends StatelessWidget {
  final String friendUid;
  final String fallbackName;
  final String fallbackSocialId;

  const FriendProfileScreen({
    super.key,
    required this.friendUid,
    required this.fallbackName,
    required this.fallbackSocialId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ bạn bè'),
        backgroundColor: const Color(0xFFEEF3FF),
        foregroundColor: const Color(0xFF1A2755),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF3F6FF),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(friendUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final displayName =
              data['display_name']?.toString().trim().isNotEmpty == true
              ? data['display_name'].toString().trim()
              : (fallbackName.trim().isNotEmpty ? fallbackName.trim() : 'Bạn bè');
          final email = data['email']?.toString().trim() ?? '';
          final socialId =
              data['social_id']?.toString().trim().isNotEmpty == true
              ? data['social_id'].toString().trim()
              : fallbackSocialId;

          final streak = (data['streak'] as num?)?.toInt() ?? 0;
          final xp = (data['xp'] as num?)?.toInt() ?? 0;
          final level = (data['level'] as num?)?.toInt() ?? 1;

          final magicalOasisState = data['magical_oasis_state'];
          final oasisCollection = data['oasis_collection_achievements'];
          final oasisEntriesRaw = oasisCollection is Map
              ? oasisCollection['entries']
              : null;
          final unlockedEntries = <Map<String, dynamic>>[];
          if (oasisEntriesRaw is List) {
            for (final item in oasisEntriesRaw) {
              if (item is! Map) {
                continue;
              }
              final isUnlocked = item['unlocked'] == true;
              if (!isUnlocked) {
                continue;
              }
              unlockedEntries.add(<String, dynamic>{
                'id': item['id']?.toString() ?? '',
                'name': item['name']?.toString() ?? '',
                'desc': item['desc']?.toString() ?? '',
                'icon': item['icon']?.toString() ?? '',
                'progress_value': (item['progress_value'] as num?)?.toInt() ?? 0,
                'req_value': (item['req_value'] as num?)?.toInt() ?? 0,
                'req_type': item['req_type']?.toString() ?? '',
              });
            }
          }
          final unlockedElementIds = unlockedEntries
              .map((entry) => entry['id'].toString())
              .where((id) => id.trim().isNotEmpty)
              .toList();
          final oasisUnlockedCount = oasisCollection is Map
              ? ((oasisCollection['unlocked_count'] as num?)?.toInt() ?? 0)
              : 0;
          final oasisTotalCount = oasisCollection is Map
              ? ((oasisCollection['total_count'] as num?)?.toInt() ?? 0)
              : 0;
          final hasMagic = magicalOasisState is Map
              ? magicalOasisState['has_magic'] == true
              : false;

          final avatarBase64 = data['avatar_base64']?.toString().trim() ?? '';
          Uint8List? avatarBytes;
          if (avatarBase64.isNotEmpty) {
            try {
              avatarBytes = base64Decode(avatarBase64);
            } catch (_) {
              avatarBytes = null;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
            child: Column(
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
                        radius: 30,
                        backgroundColor: const Color(0xFF1E3A8A).withValues(
                          alpha: 0.12,
                        ),
                        backgroundImage: avatarBytes != null
                            ? MemoryImage(avatarBytes)
                            : null,
                        child: avatarBytes == null
                            ? Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : 'U',
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              email.isEmpty ? 'Chưa cập nhật email' : email,
                              style: const TextStyle(
                                color: Color(0xFF4F617B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              socialId.isEmpty ? 'ID: Đang cập nhật...' : 'ID: $socialId',
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
                      child: _MetricCard(
                        icon: Icons.local_fire_department_rounded,
                        label: 'Chuỗi học',
                        value: '$streak ngay',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.shield_rounded,
                        label: 'Cấp bậc',
                        value: 'cấp $level',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.bolt_rounded,
                        label: 'Tổng XP',
                        value: '$xp',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ốc đảo kỳ diệu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2740),
                  ),
                ),
                const SizedBox(height: 8),
                MagicOasisScene(
                  unlockedElementIds: unlockedElementIds,
                  isBarren: unlockedElementIds.isEmpty,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD8E5FB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Thành tựu ốc đảo đã đạt',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2740),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        oasisTotalCount > 0
                            ? 'Đã mở khoá $oasisUnlockedCount/$oasisTotalCount thành tựu'
                            : 'Chưa có dữ liệu thành tựu ốc đảo',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF556987),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const SizedBox(height: 12),
                      if (unlockedEntries.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFD8E5FB),
                            ),
                          ),
                          child: const Text(
                            'Chưa có thành tựu nào được mở khóa từ ốc đảo này.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF556987),
                            ),
                          ),
                        )
                      else
                        Column(
                          children: unlockedEntries.map((entry) {
                            final icon = entry['icon'].toString();
                            final name = entry['name'].toString();
                            final desc = entry['desc'].toString();
                            final progressValue = entry['progress_value'] as int;
                            final reqValue = entry['req_value'] as int;
                            final reqType = entry['req_type'].toString();

                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFD8E5FB),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    icon.isEmpty ? '🏆' : icon,
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name.isEmpty ? 'Thành tựu' : name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF1F2740),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          desc.isEmpty
                                              ? 'Đã mở khóa trên Firebase'
                                              : desc,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF556987),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.verified_rounded,
                                    color: Color(0xFF0B8F5D),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD7E3F8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1E3A8A)),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF5A6A80),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
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
    );
  }
}
