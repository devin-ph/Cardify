import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firestore_sync_status.dart';
import '../services/saved_cards_repository.dart';
import '../services/xp_service.dart';

class AchievementsScreen extends StatefulWidget {
  final bool isActive;

  const AchievementsScreen({super.key, this.isActive = false});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ambientController;
  late final AnimationController _progressController;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _leaderboardProfileSubscription;
  Timer? _oasisSyncDebounce;
  Timer? _leaderboardSyncDebounce;
  String _lastOasisSyncDigest = '';
  String _lastLeaderboardSyncDigest = '';
  bool _isSyncingOasis = false;
  bool _isSyncingLeaderboard = false;

  int get _userTotalCardsStudied => SavedCardsRepository
      .instance
      .cardsNotifier
      .value
      .where((c) => SavedCardsRepository.instance.isKnown(c.id, topic: c.topic))
      .length;
  int get _userTotalScans => SavedCardsRepository.instance.cardsNotifier.value
      .where((c) => c.imageBytes != null || c.imageUrl != null)
      .length;
  int get _currentStreak => XPService.instance.streakNotifier.value;
  int get _userTotalXp => XPService.instance.xpNotifier.value;

  bool _showAllBadges = false;
  List<Map<String, dynamic>> _leaderboardEntries = <Map<String, dynamic>>[];

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

  bool _isElementUnlocked(Map<String, dynamic> e) {
    if (e['reqType'] == 'scans') {
      return _userTotalScans >= e['reqValue'];
    } else if (e['reqType'] == 'cards') {
      return _userTotalCardsStudied >= e['reqValue'];
    } else if (e['reqType'] == 'Số ngày') {
      return _currentStreak >= e['reqValue'];
    } else if (e['reqType'] == 'xp') {
      return _userTotalXp >= e['reqValue'];
    }
    return false;
  }

  static const List<Map<String, dynamic>> _milestoneLeagues = [
    {'name': 'Chưa xếp hạng', 'xpReq': 0, 'color': Color(0xFF9E9E9E)},
    {'name': 'Đồng', 'xpReq': 200, 'color': Color(0xFFCD7F32)},
    {'name': 'Bạc', 'xpReq': 1000, 'color': Color(0xFFC0C0C0)},
    {'name': 'Vàng', 'xpReq': 3000, 'color': Color(0xFFFFD700)},
    {'name': 'Kim Cương', 'xpReq': 6000, 'color': Color(0xFF00BFFF)},
    {'name': 'Cao Thủ', 'xpReq': 10000, 'color': Color(0xFFFF00FF)},
  ];

  static const List<Map<String, dynamic>> _ghostProfiles = [
    {'name': 'Cú Chăm Chỉ', 'avatar': '🦉', 'baseXp': 1200, 'dailyGains': 80},
    {'name': 'Mèo Lười', 'avatar': '🐱', 'baseXp': 400, 'dailyGains': 20},
    {'name': 'Sói Cô Độc', 'avatar': '🐺', 'baseXp': 1800, 'dailyGains': 120},
    {'name': 'Gấu Bé', 'avatar': '🐻', 'baseXp': 700, 'dailyGains': 50},
  ];

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

  int? _dailyBaseXp;

  Future<void> _loadDailyBotBaseXp() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = '${now.year}_${now.month}_${now.day}';
    final savedKey = prefs.getString('bot_base_date');

    if (savedKey != todayKey) {
      int attempt = 0;
      // Đợi load XPService nếu XP đang bằng 0 (chưa kịp đồng bộ lúc mới mở app)
      while (_userTotalXp == 0 && attempt < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        attempt++;
      }
      final currentXp = _userTotalXp;
      await prefs.setString('bot_base_date', todayKey);
      await prefs.setInt('bot_base_xp', currentXp);
      if (mounted) setState(() => _dailyBaseXp = currentXp);
    } else {
      final val = prefs.getInt('bot_base_xp') ?? _userTotalXp;
      if (mounted) setState(() => _dailyBaseXp = val);
    }
  }

  List<Map<String, dynamic>> _getDailySeededGhosts() {
    final now = DateTime.now();

    List<Map<String, dynamic>> bots = _ghostProfiles.map((ghost) {
      int baseBotXp = ghost['baseXp'] as int;
      int dailyGain = ghost['dailyGains'] as int;

      // Seed dựa trên ngày hiện tại và tên bot để đảm bảo mỗi ngày bot được gán ngẫu nhiên hợp lý
      final todaySeed = now.year * 1000 + now.day + ghost['name'].hashCode;
      final random = Random(todaySeed);

      // Tính khoảng cách (gap) tiêu chuẩn cho từng bot. Bot nào baseXp và dailyGain cao thì khoảng cách xa hơn
      int gap = (baseBotXp * 0.4).round() + random.nextInt(dailyGain * 10);

      // Điều chỉnh lại thuộc tính cho các bot cụ thể
      if (dailyGain >= 100) {
        // Sói Cô Độc: Bỏ rất xa (có thể lên tới +1500 XP)
        gap = 500 + random.nextInt(1000);
      } else if (dailyGain >= 60) {
        // Cú Chăm Chỉ: Vượt ổn định (+300 đến +800 XP)
        gap = 300 + random.nextInt(500);
      } else if (dailyGain >= 40) {
        // Gấu Bé: Lúc tụt lúc lên (từ -200 đến +400 XP)
        gap = -200 + random.nextInt(600);
      } else {
        // Mèo Lười: Luôn lười (tụt so với user -400 đến -50 XP)
        gap = -400 + random.nextInt(350);
      }

      int botXp = (_dailyBaseXp ?? _userTotalXp) + gap;

      // Xử lý không cho âm và làm tròn đến hàng chục
      if (botXp <= 0) {
        botXp = random.nextInt(40) + 10;
      }
      botXp = (botXp / 10).round() * 10;

      return {
        'name': ghost['name'],
        'avatar': ghost['avatar'],
        'xp': botXp,
        'isMe': false,
      };
    }).toList();

    bots.add({'name': 'Bạn', 'avatar': '🧑', 'xp': _userTotalXp, 'isMe': true});

    bots.sort((a, b) => (b['xp'] as int).compareTo(a['xp'] as int));
    return bots;
  }

  List<Map<String, dynamic>> _parseFriendEntries(dynamic raw) {
    if (raw is! List) {
      return <Map<String, dynamic>>[];
    }

    final parsed = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final uid = item['uid']?.toString().trim() ?? '';
      if (uid.isEmpty || seen.contains(uid)) {
        continue;
      }
      seen.add(uid);
      parsed.add(<String, dynamic>{
        'uid': uid,
        'social_id': item['social_id']?.toString().trim() ?? '',
        'display_name': item['display_name']?.toString().trim() ?? '',
        'avatar_base64': item['avatar_base64']?.toString().trim() ?? '',
        'email': item['email']?.toString().trim() ?? '',
      });
    }
    return parsed;
  }

  Future<void> _refreshLeaderboardEntries(
    List<Map<String, dynamic>> friends,
    {String selfAvatarBase64 = '', String selfDisplayName = '',}
  ) async {
    if (_isSyncingLeaderboard) {
      return;
    }

    final signature = jsonEncode(<String, dynamic>{
      'friends': friends.map((friend) => friend['uid']?.toString() ?? '').toList(),
      'me_xp': _userTotalXp,
      'me_avatar': selfAvatarBase64,
      'me_name': selfDisplayName,
    });

    if (signature == _lastLeaderboardSyncDigest && _leaderboardEntries.isNotEmpty) {
      return;
    }

    _isSyncingLeaderboard = true;
    try {
      final fetchedFriends = <Map<String, dynamic>>[];
      for (final friend in friends) {
        final uid = friend['uid']?.toString().trim() ?? '';
        if (uid.isEmpty) {
          continue;
        }

        try {
          final snap = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          final data = snap.data() ?? <String, dynamic>{};
          final xp = (data['xp'] as num?)?.toInt() ?? 0;
          final displayName =
              data['display_name']?.toString().trim().isNotEmpty == true
              ? data['display_name'].toString().trim()
              : (friend['display_name']?.toString().trim().isNotEmpty == true
                  ? friend['display_name'].toString().trim()
                  : friend['social_id']?.toString().trim() ?? 'Bạn bè');
          final avatarBase64 =
              data['avatar_base64']?.toString().trim().isNotEmpty == true
              ? data['avatar_base64'].toString().trim()
              : friend['avatar_base64']?.toString().trim() ?? '';

          fetchedFriends.add(<String, dynamic>{
            'uid': uid,
            'name': displayName,
            'avatarBase64': avatarBase64,
            'avatar': '👤',
            'xp': xp,
            'isMe': false,
          });
        } catch (_) {
          fetchedFriends.add(<String, dynamic>{
            'uid': uid,
            'name': friend['display_name']?.toString().trim().isNotEmpty == true
                ? friend['display_name'].toString().trim()
                : friend['social_id']?.toString().trim() ?? 'Bạn bè',
            'avatarBase64': friend['avatar_base64']?.toString().trim() ?? '',
            'avatar': '👤',
            'xp': 0,
            'isMe': false,
          });
        }
      }

      final fillCount = (5 - (fetchedFriends.length + 1)).clamp(0, 4);
      final fakeBots = _getDailySeededGhosts()
          .where((entry) => entry['isMe'] != true)
          .take(fillCount)
          .toList();

      final combined = <Map<String, dynamic>>[
        ...fetchedFriends,
        ...fakeBots,
        <String, dynamic>{
          'name': selfDisplayName.trim().isNotEmpty
              ? selfDisplayName.trim()
              : 'Bạn',
          'avatar': '🧑',
          'avatarBase64': selfAvatarBase64,
          'xp': _userTotalXp,
          'isMe': true,
        },
      ];

      combined.sort((a, b) => (b['xp'] as int).compareTo(a['xp'] as int));

      if (!mounted) {
        return;
      }
      setState(() {
        _leaderboardEntries = combined.take(5).toList();
        _lastLeaderboardSyncDigest = signature;
      });
    } finally {
      _isSyncingLeaderboard = false;
    }
  }

  Widget _buildLeaderboardAvatar(Map<String, dynamic> entry) {
    final avatarBase64 = entry['avatarBase64']?.toString().trim() ?? '';
    if (avatarBase64.isNotEmpty) {
      try {
        final avatarBytes = base64Decode(avatarBase64);
        if (avatarBytes.isNotEmpty) {
          return CircleAvatar(
            radius: 14,
            backgroundColor: Colors.white,
            backgroundImage: MemoryImage(avatarBytes),
          );
        }
      } catch (_) {
        // Fall back below.
      }
    }

    final avatarText = entry['avatar']?.toString() ?? '👤';
    return Text(avatarText, style: const TextStyle(fontSize: 24));
  }

  void _scheduleLeaderboardRefresh(
    List<Map<String, dynamic>> friends, {
    String selfAvatarBase64 = '',
    String selfDisplayName = '',
  }) {
    _leaderboardSyncDebounce?.cancel();
    _leaderboardSyncDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(
        _refreshLeaderboardEntries(
          friends,
          selfAvatarBase64: selfAvatarBase64,
          selfDisplayName: selfDisplayName,
        ),
      );
    });
  }

  void _bindLeaderboardStream() {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      _leaderboardProfileSubscription?.cancel();
      _leaderboardProfileSubscription = null;
      return;
    }

    if (_leaderboardProfileSubscription != null) {
      return;
    }

    _leaderboardProfileSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
          final data = snapshot.data() ?? <String, dynamic>{};
          final friends = _parseFriendEntries(data['friends']);
          final selfAvatarBase64 = data['avatar_base64']?.toString().trim() ?? '';
          final selfDisplayName = data['display_name']?.toString().trim() ?? 'Bạn';
          _scheduleLeaderboardRefresh(
            friends,
            selfAvatarBase64: selfAvatarBase64,
            selfDisplayName: selfDisplayName,
          );
        });
  }

  DocumentReference<Map<String, dynamic>>? _profileDoc() {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      return null;
    }
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  int _progressForElement(Map<String, dynamic> e) {
    if (e['reqType'] == 'scans') {
      return _userTotalScans;
    }
    if (e['reqType'] == 'cards') {
      return _userTotalCardsStudied;
    }
    if (e['reqType'] == 'Số ngày') {
      return _currentStreak;
    }
    if (e['reqType'] == 'xp') {
      return _userTotalXp;
    }
    return 0;
  }

  Map<String, dynamic> _buildOasisCollectionAchievementsPayload() {
    final entries = _oasisElements.map((e) {
      return <String, dynamic>{
        'id': e['id'],
        'name': e['name'],
        'desc': e['desc'],
        'icon': e['icon'],
        'req_type': e['reqType'],
        'req_value': e['reqValue'],
        'progress_value': _progressForElement(e),
        'unlocked': _isElementUnlocked(e),
      };
    }).toList();

    final unlockedIds = entries
        .where((e) => e['unlocked'] == true)
        .map((e) => e['id'].toString())
        .toList();

    return <String, dynamic>{
      'entries': entries,
      'unlocked_ids': unlockedIds,
      'unlocked_count': unlockedIds.length,
      'total_count': _oasisElements.length,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _buildMagicalOasisStatePayload() {
    final unlockedElements = _oasisElements
        .where((e) => _isElementUnlocked(e))
        .toList();
    final unlockedIds = unlockedElements
        .map((e) => e['id'].toString())
        .toList();

    return <String, dynamic>{
      'is_barren': unlockedElements.isEmpty,
      'unlocked_elements': unlockedIds,
      'has_magic': unlockedIds.contains('magic'),
      'stats': <String, dynamic>{
        'streak': _currentStreak,
        'total_scans': _userTotalScans,
        'cards_studied': _userTotalCardsStudied,
        'total_xp': _userTotalXp,
        'current_league': _currentLeague['name'],
      },
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  int _fallbackStatValue(dynamic localValue, dynamic remoteValue) {
    final local = localValue is num ? localValue.toInt() : 0;
    if (local > 0) {
      return local;
    }
    final remote = remoteValue is num ? remoteValue.toInt() : 0;
    return remote;
  }

  Map<String, dynamic> _remoteStatsFromSnapshot(
    Map<String, dynamic>? data,
  ) {
    final oasisState = data?['magical_oasis_state'];
    if (oasisState is! Map) {
      return <String, dynamic>{};
    }

    final stats = oasisState['stats'];
    if (stats is! Map) {
      return <String, dynamic>{};
    }

    return Map<String, dynamic>.from(stats.cast<String, dynamic>());
  }

  void _scheduleOasisSync({bool immediate = false}) {
    if (!widget.isActive) {
      return;
    }

    _oasisSyncDebounce?.cancel();
    if (immediate) {
      unawaited(_syncOasisDataToFirebase());
      return;
    }

    _oasisSyncDebounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(_syncOasisDataToFirebase());
    });
  }

  Future<void> _syncOasisDataToFirebase() async {
    if (!widget.isActive) {
      return;
    }

    if (_isSyncingOasis) {
      return;
    }

    final docRef = _profileDoc();
    if (docRef == null) {
      return;
    }

    Map<String, dynamic> remoteData = <String, dynamic>{};
    try {
      final snapshot = await docRef.get();
      remoteData = snapshot.data() ?? <String, dynamic>{};
    } catch (_) {
      remoteData = <String, dynamic>{};
    }

    final remoteStats = _remoteStatsFromSnapshot(remoteData);
    final remoteCollection = remoteData['oasis_collection_achievements'];
    final remoteOasis = remoteData['magical_oasis_state'];

    final remoteCollectionUnlockedCount = remoteCollection is Map
        ? (remoteCollection['unlocked_count'] as num?)?.toInt() ?? 0
        : 0;

    final localCardsStudied = _userTotalCardsStudied;
    final localScans = _userTotalScans;
    final localStreak = _currentStreak;
    final localXp = _userTotalXp;

    if (remoteCollectionUnlockedCount > 0 &&
        localCardsStudied == 0 &&
        localScans == 0 &&
        localStreak == 0 &&
        localXp == 0) {
      final remoteStatsCards = remoteStats['cards_studied'] is num
          ? (remoteStats['cards_studied'] as num).toInt()
          : 0;
      final remoteStatsScans = remoteStats['total_scans'] is num
          ? (remoteStats['total_scans'] as num).toInt()
          : 0;
      final remoteStatsStreak = remoteStats['streak'] is num
          ? (remoteStats['streak'] as num).toInt()
          : 0;
      final remoteStatsXp = remoteStats['total_xp'] is num
          ? (remoteStats['total_xp'] as num).toInt()
          : 0;
      if (remoteStatsCards > 0 ||
          remoteStatsScans > 0 ||
          remoteStatsStreak > 0 ||
          remoteStatsXp > 0 ||
          remoteOasis is Map) {
        return;
      }
    }

    final collectionPayload = _buildOasisCollectionAchievementsPayload();
    final oasisPayload = _buildMagicalOasisStatePayload();
    final mergedCollectionPayload = <String, dynamic>{
      ...collectionPayload,
      if (remoteCollection is Map &&
          collectionPayload['unlocked_count'] == 0 &&
          (remoteCollection['unlocked_count'] as num?)?.toInt() != null &&
          (remoteCollection['unlocked_count'] as num?)!.toInt() > 0)
        ...Map<String, dynamic>.from(remoteCollection.cast<String, dynamic>()),
    };
    final mergedStats = <String, dynamic>{
      'streak': _fallbackStatValue(
        _currentStreak,
        remoteStats['streak'],
      ),
      'total_scans': _fallbackStatValue(
        _userTotalScans,
        remoteStats['total_scans'],
      ),
      'cards_studied': _fallbackStatValue(
        _userTotalCardsStudied,
        remoteStats['cards_studied'],
      ),
      'total_xp': _fallbackStatValue(
        _userTotalXp,
        remoteStats['total_xp'],
      ),
      'current_league': (_userTotalXp > 0)
          ? _currentLeague['name']
          : (remoteStats['current_league']?.toString() ?? _currentLeague['name']),
    };
    final mergedOasisPayload = <String, dynamic>{
      ...oasisPayload,
      'stats': mergedStats,
      if (remoteOasis is Map &&
          oasisPayload['is_barren'] == true &&
          remoteOasis['is_barren'] == false)
        ...Map<String, dynamic>.from(remoteOasis.cast<String, dynamic>()),
    };
    final syncDigest = jsonEncode(<String, dynamic>{
      'collection': mergedCollectionPayload,
      'oasis': mergedOasisPayload,
    });

    if (syncDigest == _lastOasisSyncDigest) {
      return;
    }

    _isSyncingOasis = true;
    try {
      FirestoreSyncStatus.instance.reportWriting(
        path: 'users/${docRef.id}',
        reason: 'đồng bộ tiến độ bộ sưu tập và ốc đảo kỳ diệu',
      );
      await docRef.set({
        'oasis_collection_achievements': mergedCollectionPayload,
        'magical_oasis_state': mergedOasisPayload,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _lastOasisSyncDigest = syncDigest;
      FirestoreSyncStatus.instance.reportSuccess(
        path: 'users/${docRef.id}',
        message: 'Đã đồng bộ dữ liệu ốc đảo lên Firestore',
      );
    } catch (error) {
      FirestoreSyncStatus.instance.reportError(
        path: 'users/${docRef.id}',
        operation: 'sync oasis achievement data',
        error: error,
      );
    } finally {
      _isSyncingOasis = false;
    }
  }

  void _onOasisProgressSourcesChanged() {
    if (!widget.isActive) {
      return;
    }
    _scheduleOasisSync();
  }

  @override
  void didUpdateWidget(covariant AchievementsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.isActive && widget.isActive) {
      _scheduleOasisSync();
      return;
    }

    if (oldWidget.isActive && !widget.isActive) {
      _oasisSyncDebounce?.cancel();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDailyBotBaseXp();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    XPService.instance.xpNotifier.addListener(_onOasisProgressSourcesChanged);
    XPService.instance.streakNotifier.addListener(
      _onOasisProgressSourcesChanged,
    );
    SavedCardsRepository.instance.cardsNotifier.addListener(
      _onOasisProgressSourcesChanged,
    );
    XPService.instance.xpNotifier.addListener(_onLeaderboardProgressChanged);
    _bindLeaderboardStream();
  }

  @override
  void dispose() {
    _oasisSyncDebounce?.cancel();
    _leaderboardSyncDebounce?.cancel();
    XPService.instance.xpNotifier.removeListener(_onOasisProgressSourcesChanged);
    XPService.instance.streakNotifier.removeListener(
      _onOasisProgressSourcesChanged,
    );
    SavedCardsRepository.instance.cardsNotifier.removeListener(
      _onOasisProgressSourcesChanged,
    );
    XPService.instance.xpNotifier.removeListener(_onLeaderboardProgressChanged);
    _leaderboardProfileSubscription?.cancel();
    _ambientController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _onLeaderboardProgressChanged() {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get()
        .then((snap) {
          final data = snap.data() ?? <String, dynamic>{};
          final friends = _parseFriendEntries(data['friends']);
          final selfAvatarBase64 = data['avatar_base64']?.toString().trim() ?? '';
          final selfDisplayName = data['display_name']?.toString().trim() ?? 'Bạn';
          _scheduleLeaderboardRefresh(
            friends,
            selfAvatarBase64: selfAvatarBase64,
            selfDisplayName: selfDisplayName,
          );
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        XPService.instance.xpNotifier,
        XPService.instance.streakNotifier,
        SavedCardsRepository.instance.cardsNotifier,
      ]),
      builder: (context, _) {
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
      },
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
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
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
                    SizedBox(height: 6),
                    Text(
                      'THÀNH TỰU',
                      style: TextStyle(
                        color: Color(0xFF102956),
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Mở khóa huy hiệu, leo hạng và trở thành nhà vô địch!',
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
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                    ),
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

    final int unlockedCount = _oasisElements
        .where((e) => _isElementUnlocked(e))
        .length;

    return _GlassPanel(
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
                      current['name'],
                      style: TextStyle(
                        color: leagueColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      next != null
                          ? '$_userTotalXp/${next['xpReq']} XP để lên bậc tiếp theo'
                          : 'Bạn đã đạt cấp cao nhất!',
                      style: const TextStyle(
                        color: Color(0xFF42516E),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: leagueColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: leagueColor.withValues(alpha: 0.3)),
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
                icon: Icons.star_rounded,
                label: 'Thành tựu',
                value: '$unlockedCount',
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
    final leaderboard = _leaderboardEntries.isNotEmpty
        ? _leaderboardEntries
        : _getDailySeededGhosts();
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
            style: TextStyle(
              color: Color(0xFF42516E),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...leaderboard.map((g) {
            final isMe = g['isMe'] == true;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isMe
                      ? [const Color(0xFFDBEAFE), const Color(0xFFEFF6FF)]
                      : [
                          Colors.white.withValues(alpha: 0.9),
                          Colors.white.withValues(alpha: 0.5),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isMe
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.8),
                  width: isMe ? 2 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isMe
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildLeaderboardAvatar(g),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      g['name'],
                      style: TextStyle(
                        color: isMe
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFF102956),
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${g['xp']} XP',
                      style: TextStyle(
                        color: isMe
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFF64748B),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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
    final unlockedElements = _oasisElements
        .where((e) => _isElementUnlocked(e))
        .toList();
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
                        bottom:
                            -15 + sin(_ambientController.value * pi * 2) * 8,
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
                  // Sun
                  const Positioned(
                    top: 16,
                    right: 24,
                    child: Text('☀️', style: TextStyle(fontSize: 40)),
                  ),
                  // Animated clouds
                  AnimatedBuilder(
                    animation: _ambientController,
                    builder: (context, child) {
                      return Positioned(
                        left: -30 + (_ambientController.value * 40),
                        top: 30,
                        child: const Text(
                          '☁️',
                          style: TextStyle(
                            fontSize: 35,
                            color: Color(0xFF42516E),
                          ),
                        ),
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
                        color: isBarren
                            ? const Color(0xFFD4A373)
                            : const Color(0xFF4ADE80),
                        borderRadius: const BorderRadius.all(
                          Radius.elliptical(350, 140),
                        ),
                        border: Border.all(
                          color: Color(0xFF42516E).withValues(alpha: 0.5),
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
                  // Barren Mode
                  if (isBarren) ...[
                    // Hòn đá 1
                    const Positioned(
                      bottom: 30,
                      left: 110,
                      child: Text('🪨', style: TextStyle(fontSize: 32)),
                    ),
                    // Khúc gỗ khô
                    const Positioned(
                      bottom: 25,
                      right: 120,
                      child: Text('🪵', style: TextStyle(fontSize: 36)),
                    ),
                    // Xương rồng 1
                    const Positioned(
                      bottom: 50,
                      left: 45,
                      child: Text('🌵', style: TextStyle(fontSize: 60)),
                    ),
                    // Xương rồng 2
                    const Positioned(
                      bottom: 45,
                      right: 50,
                      child: Text('🌵', style: TextStyle(fontSize: 45)),
                    ),
                    // Hòn đá nhỏ
                    const Positioned(
                      bottom: 60,
                      right: 100,
                      child: Text('🪨', style: TextStyle(fontSize: 24)),
                    ),
                  ],
                  // Organized Elements by Depth Layers
                  if (!isBarren) ...[
                    // BACK LAYER
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
                            bottom:
                                80 +
                                sin(_ambientController.value * pi * 2) * 10,
                            left: 80,
                            child: const Text(
                              '🦋',
                              style: TextStyle(fontSize: 20),
                            ),
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

                    // FRONT LAYER
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
                    if (unlockedElements.any(
                      (e) => e['id'] == 'mushrooms',
                    )) ...[
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

                    // WATER (SHORE) LAYER
                    if (unlockedElements.any((e) => e['id'] == 'lighthouse'))
                      const Positioned(
                        bottom: 0,
                        right: 20,
                        child: Text('🗼', style: TextStyle(fontSize: 45)),
                      ),
                    if (unlockedElements.any((e) => e['id'] == 'tent')) ...[
                      const Positioned(
                        bottom: -5,
                        left: 30,
                        child: Text('⛺', style: TextStyle(fontSize: 40)),
                      ),
                    ],

                    // SKY LAYER
                    if (unlockedElements.any((e) => e['id'] == 'airballoon'))
                      AnimatedBuilder(
                        animation: _ambientController,
                        builder: (context, child) {
                          return Positioned(
                            bottom:
                                130 + sin(_ambientController.value * pi) * 15,
                            left: 20,
                            child: const Text(
                              '🎈',
                              style: TextStyle(fontSize: 40),
                            ),
                          );
                        },
                      ),
                    if (unlockedElements.any((e) => e['id'] == 'space'))
                      AnimatedBuilder(
                        animation: _ambientController,
                        builder: (context, child) {
                          return Positioned(
                            top:
                                20 +
                                sin(_ambientController.value * pi * 2) * 10,
                            right: 60,
                            child: const Text(
                              '🚀',
                              style: TextStyle(fontSize: 35),
                            ),
                          );
                        },
                      ),
                    if (unlockedElements.any((e) => e['id'] == 'magic'))
                      AnimatedBuilder(
                        animation: _ambientController,
                        builder: (context, child) {
                          return Positioned(
                            bottom:
                                110 +
                                sin(_ambientController.value * pi * 2) * 20,
                            left:
                                170 +
                                cos(_ambientController.value * pi * 2) * 40,
                            child: const Text(
                              '✨',
                              style: TextStyle(fontSize: 30),
                            ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
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
            style: TextStyle(
              color: Color(0xFF42516E),
              fontWeight: FontWeight.w600,
            ),
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

                int currentProgress = 0;
                if (e['reqType'] == 'scans') {
                  currentProgress = _userTotalScans;
                } else if (e['reqType'] == 'cards') {
                  currentProgress = _userTotalCardsStudied;
                } else if (e['reqType'] == 'Số ngày') {
                  currentProgress = _currentStreak;
                } else if (e['reqType'] == 'xp') {
                  currentProgress = _userTotalXp;
                }

                return _OasisItemCard(
                  delayMs: 120 * (index % 4),
                  title: e['name'] as String,
                  desc: e['desc'] as String,
                  iconStr: e['icon'] as String,
                  unlocked: _isElementUnlocked(e),
                  color: e['color'] as Color,
                  reqXp: e['reqValue'] as int,
                  reqType: e['reqType'] as String,
                  currentProgress: currentProgress,
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
  final int currentProgress;

  const _OasisItemCard({
    required this.delayMs,
    required this.title,
    required this.desc,
    required this.iconStr,
    required this.unlocked,
    required this.color,
    required this.reqXp,
    required this.reqType,
    required this.currentProgress,
  });

  @override
  Widget build(BuildContext context) {
    final background = unlocked
        ? color.withValues(alpha: 0.16)
        : Color(0xFFFFFFFF).withValues(alpha: 0.6);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.8, end: 1.0),
      duration: Duration(milliseconds: 600 + delayMs),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        clipBehavior: Clip.hardEdge,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: unlocked
                ? [Colors.white.withValues(alpha: 0.95), color.withValues(alpha: 0.05)]
                : [
                    Colors.white.withValues(alpha: 0.8),
                    Colors.white.withValues(alpha: 0.4),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: unlocked
                ? color.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            if (unlocked)
              BoxShadow(
                color: color.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
          ],
        ),
        child: Stack(
          children: [
            if (unlocked)
              Positioned(
                right: -10,
                bottom: -15,
                child: Transform.rotate(
                  angle: -0.2,
                  child: Text(
                    iconStr,
                    style: TextStyle(
                      fontSize: 65,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              ),
            Column(
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
                            color: unlocked
                                ? null
                                : Color(0xFF42516E).withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      unlocked ? Icons.verified_rounded : Icons.lock_rounded,
                      color: unlocked
                          ? const Color(0xFF6EE7B7)
                          : Color(0xFF42516E).withValues(alpha: 0.5),
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
                Text(
                  desc,
                  style: TextStyle(
                    color: Color(0xFF0B1C3D).withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                if (!unlocked && reqType != 'xp')
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (currentProgress / reqXp).clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: color.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              color.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${currentProgress > reqXp ? reqXp : currentProgress}/$reqXp',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF42516E).withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
              ],
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
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
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
        clipBehavior: Clip.hardEdge,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.9),
              Colors.white.withValues(alpha: 0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -12,
              bottom: -12,
              child: Transform.rotate(
                angle: -0.2,
                child: Icon(icon, size: 70, color: color.withValues(alpha: 0.12)),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          value,
                          style: const TextStyle(
                            color: Color(0xFF0B1C3D),
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            height: 1.1,
                          ),
                        ),
                      ),
                      Text(
                        label,
                        style: TextStyle(
                          color: color.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
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
              colors: [color.withValues(alpha: 0.36), color.withValues(alpha: 0.0)],
            ),
          ),
        ),
      ),
    );
  }
}
