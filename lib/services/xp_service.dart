import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firestore_sync_status.dart';

class XPService {
  static final XPService instance = XPService._();
  XPService._() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _listenToProfileChanges(user);
        unawaited(_syncFromFirebase(user));
      } else {
        _profileSubscription?.cancel();
        _profileSubscription = null;
        learningDayKeysNotifier.value = <String>{};
      }
    });
  }

  final ValueNotifier<int> xpNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> levelNotifier = ValueNotifier<int>(1);
  final ValueNotifier<int> streakNotifier = ValueNotifier<int>(0);
  final ValueNotifier<Set<String>> learningDayKeysNotifier =
      ValueNotifier<Set<String>>(<String>{});
  bool _isSyncing = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _profileSubscription;
  static const String _learningCompletedDaysKey = 'learning_completed_days_v1';

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _profileDoc(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  DocumentReference<Map<String, dynamic>> _learningStateDoc(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('learning_state')
        .doc('state');
  }

  void _listenToProfileChanges(User user) {
    _profileSubscription?.cancel();
    _profileSubscription = _profileDoc(user.uid).snapshots().listen((snapshot) {
      if (!snapshot.exists) {
        return;
      }
      final data = snapshot.data() ?? <String, dynamic>{};
      xpNotifier.value = _readInt(data, 'xp', xpNotifier.value);
      levelNotifier.value = _readInt(data, 'level', levelNotifier.value);
      streakNotifier.value = _readInt(data, 'streak', streakNotifier.value);
      unawaited(_persistLocal());
      FirestoreSyncStatus.instance.reportSuccess(
        path: 'users/${user.uid}',
        message: 'Đã nhận cập nhật hồ sơ Firestore realtime',
      );
    }, onError: (Object error) {
      FirestoreSyncStatus.instance.reportError(
        path: 'users/${user.uid}',
        operation: 'listen profile snapshots',
        error: error,
      );
    });
  }

  int _readInt(Map<String, dynamic> data, String key, int fallback) {
    final value = data[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return fallback;
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_xp', xpNotifier.value);
    await prefs.setInt('user_level', levelNotifier.value);
    await prefs.setInt('user_streak', streakNotifier.value);
  }

  String _dateKey(DateTime date) {
    final local = date.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  DateTime _dateOnly(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  String? _normalizeLearningDayKey(dynamic rawValue) {
    final raw = rawValue?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }

    final directMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
    if (directMatch != null) {
      final year = int.tryParse(directMatch.group(1)!);
      final month = int.tryParse(directMatch.group(2)!);
      final day = int.tryParse(directMatch.group(3)!);
      if (year != null && month != null && day != null) {
        final parsed = DateTime(year, month, day);
        if (parsed.year == year && parsed.month == month && parsed.day == day) {
          return raw;
        }
      }
      return null;
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return null;
    }
    return _dateKey(parsed);
  }

  Set<String> _parseLearningDayKeys(dynamic raw) {
    if (raw is! List) {
      return <String>{};
    }
    final result = <String>{};
    for (final item in raw) {
      final normalized = _normalizeLearningDayKey(item);
      if (normalized != null) {
        result.add(normalized);
      }
    }
    return result;
  }

  Future<Set<String>> _loadLocalLearningDayKeys({
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final local = store.getStringList(_learningCompletedDaysKey) ??
        const <String>[];
    return _parseLearningDayKeys(local);
  }

  Future<void> _persistLocalLearningDayKeys(
    Set<String> dayKeys, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final sorted = dayKeys.toList()..sort();
    await store.setStringList(_learningCompletedDaysKey, sorted);
    learningDayKeysNotifier.value = Set<String>.from(sorted);
  }

  int _calculateStreakFromDayKeys(
    Set<String> dayKeys, {
    DateTime? fromDate,
  }) {
    if (dayKeys.isEmpty) {
      return 0;
    }

    var cursor = _dateOnly(fromDate ?? DateTime.now());
    var streak = 0;
    while (dayKeys.contains(_dateKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<void> _syncLearningDaysFromFirebase(User user) async {
    final docRef = _learningStateDoc(user.uid);
    final localDayKeys = await _loadLocalLearningDayKeys();

    try {
      FirestoreSyncStatus.instance.reportReading(
        path: 'users/${user.uid}/learning_state/state',
        reason: 'đọc completed_learning_days khi đăng nhập',
      );
      final snapshot = await docRef.get();
      final remoteDayKeys = _parseLearningDayKeys(
        snapshot.data()?['completed_learning_days'],
      );

      final merged = <String>{...localDayKeys, ...remoteDayKeys};
      await _persistLocalLearningDayKeys(merged);

      FirestoreSyncStatus.instance.reportSuccess(
        path: 'users/${user.uid}/learning_state/state',
        message: 'Đã đồng bộ completed_learning_days từ Firestore',
      );
    } catch (error) {
      await _persistLocalLearningDayKeys(localDayKeys);
      FirestoreSyncStatus.instance.reportError(
        path: 'users/${user.uid}/learning_state/state',
        operation: 'read completed_learning_days',
        error: error,
      );
    }
  }

  Future<void> _initializeProfileOnFirstLogin(User user) async {
    /// Initialize user profile only on first login (when document doesn't exist)
    try {
      final docRef = _profileDoc(user.uid);
      
      // Check if profile already exists
      final existingSnapshot = await docRef.get();
      if (existingSnapshot.exists) {
        final data = existingSnapshot.data() ?? <String, dynamic>{};
        xpNotifier.value = _readInt(data, 'xp', xpNotifier.value);
        levelNotifier.value = _readInt(data, 'level', levelNotifier.value);
        streakNotifier.value = _readInt(data, 'streak', streakNotifier.value);
        await _persistLocal();
        FirestoreSyncStatus.instance.reportSuccess(
          path: 'users/${user.uid}',
          message: 'Đã đọc hồ sơ XP từ Firestore (đăng nhập quay lại)',
        );
        return;
      }

      // Check for legacy profile
      final legacySnapshot = await _firestore.collection('user_profiles').doc(user.uid).get();
      if (legacySnapshot.exists) {
        final legacyData = legacySnapshot.data() ?? <String, dynamic>{};
        xpNotifier.value = _readInt(legacyData, 'xp', xpNotifier.value);
        levelNotifier.value = _readInt(legacyData, 'level', levelNotifier.value);
        streakNotifier.value = _readInt(legacyData, 'streak', streakNotifier.value);
        await docRef.set({
          'xp': xpNotifier.value,
          'level': levelNotifier.value,
          'streak': streakNotifier.value,
          'next_level_xp': levelNotifier.value * 1000,
          'display_name': legacyData['display_name']?.toString() ?? user.displayName ?? 'Explorer',
          'email': legacyData['email']?.toString() ?? user.email,
          'onboarding_seen': legacyData['onboarding_seen'],
          'app_started_at': legacyData['app_started_at'],
          'settings_ai_hints_enabled': legacyData['settings_ai_hints_enabled'],
          'settings_auto_play_enabled': legacyData['settings_auto_play_enabled'],
          'settings_ai_chat_narrator_enabled': legacyData['settings_ai_chat_narrator_enabled'],
          'settings_daily_reminder': legacyData['settings_daily_reminder'],
          'settings_compact_layout': legacyData['settings_compact_layout'],
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await _persistLocal();
        FirestoreSyncStatus.instance.reportSuccess(
          path: 'users/${user.uid}',
          message: 'Đã migrate hồ sơ cũ sang Firestore',
        );
        return;
      }

      // This is first login - create default profile
      FirestoreSyncStatus.instance.reportWriting(
        path: 'users/${user.uid}',
        reason: 'khởi tạo hồ sơ người dùng lần đầu đăng nhập',
      );
      await docRef.set({
        'xp': 0,
        'level': 1,
        'streak': 0,
        'next_level_xp': 1000,
        'display_name': user.displayName ?? 'Explorer',
        'email': user.email,
        'cards_studied': 0,
        'total_scans': 0,
        'updated_at': FieldValue.serverTimestamp(),
      });
      xpNotifier.value = 0;
      levelNotifier.value = 1;
      streakNotifier.value = 0;
      await _persistLocal();
      FirestoreSyncStatus.instance.reportSuccess(
        path: 'users/${user.uid}',
        message: 'Đã khởi tạo hồ sơ mặc định trên Firestore (lần đầu)',
      );
    } catch (e) {
      debugPrint('Khởi tạo hồ sơ lần đầu lỗi: $e');
      FirestoreSyncStatus.instance.reportError(
        path: 'users/${user.uid}',
        operation: 'initialize profile on first login',
        error: e,
      );
    }
  }

  Future<void> _syncFromFirebase(User user) async {
    if (kIsWeb) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    if (_isSyncing) {
      return;
    }

    _isSyncing = true;
    try {
      FirestoreSyncStatus.instance.reportReading(
        path: 'users/${user.uid}',
        reason: 'đồng bộ hồ sơ từ Firestore khi login',
      );
      await _initializeProfileOnFirstLogin(user);
      await _syncLearningDaysFromFirebase(user);
    } catch (e) {
      debugPrint('Sync XP từ Firebase lỗi: $e');
      FirestoreSyncStatus.instance.reportError(
        path: 'users/${user.uid}',
        operation: 'sync xp from firestore',
        error: e,
      );
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _pushToFirebase(User user) async {
    try {
      if (kIsWeb) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }

      FirestoreSyncStatus.instance.reportWriting(
        path: 'users/${user.uid}',
        reason: 'cập nhật XP/level/streak',
      );
      await _profileDoc(user.uid).set({
        'xp': xpNotifier.value,
        'level': levelNotifier.value,
        'streak': streakNotifier.value,
        'next_level_xp': levelNotifier.value * 1000,
        'display_name': user.displayName,
        'email': user.email,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      FirestoreSyncStatus.instance.reportSuccess(
        path: 'users/${user.uid}',
        message: 'Đã ghi XP/level/streak lên Firestore',
      );
    } catch (e) {
      debugPrint('Cập nhật XP lên Firebase lỗi: $e');
      FirestoreSyncStatus.instance.reportError(
        path: 'users/${user.uid}',
        operation: 'push xp to firestore',
        error: e,
      );
    }
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Load local first for fast display
    xpNotifier.value = prefs.getInt('user_xp') ?? 0;
    levelNotifier.value = prefs.getInt('user_level') ?? 1;
    streakNotifier.value = prefs.getInt('user_streak') ?? 0;
    learningDayKeysNotifier.value = await _loadLocalLearningDayKeys(
      prefs: prefs,
    );

    // Then sync with Firebase if a user is logged in.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _syncFromFirebase(user);
    }
  }

  Future<void> addXP(int amount) async {
    final newXp = xpNotifier.value + amount;
    final newLevel = (newXp ~/ 1000) + 1;

    xpNotifier.value = newXp;
    levelNotifier.value = newLevel;

    await _persistLocal();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _pushToFirebase(user);
    }
  }

  Future<void> syncStreak(int streak) async {
    if (streak < 0 || streak == streakNotifier.value) {
      return;
    }

    streakNotifier.value = streak;
    await _persistLocal();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _pushToFirebase(user);
    }
  }

  Future<void> recordLearningActivity({
    DateTime? occurredAt,
    String source = 'study',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final activityDate = _dateOnly(occurredAt ?? DateTime.now());
    final activityDayKey = _dateKey(activityDate);
    var mergedDayKeys = await _loadLocalLearningDayKeys();
    final docRef = _learningStateDoc(user.uid);

    try {
      FirestoreSyncStatus.instance.reportReading(
        path: 'users/${user.uid}/learning_state/state',
        reason: 'kiểm tra ngày học trước khi cập nhật streak',
      );
      final snapshot = await docRef.get();
      final remoteDayKeys = _parseLearningDayKeys(
        snapshot.data()?['completed_learning_days'],
      );
      mergedDayKeys = <String>{...mergedDayKeys, ...remoteDayKeys};
    } catch (error) {
      FirestoreSyncStatus.instance.reportError(
        path: 'users/${user.uid}/learning_state/state',
        operation: 'read learning days before write',
        error: error,
      );
    }

    if (mergedDayKeys.contains(activityDayKey)) {
      await _persistLocalLearningDayKeys(mergedDayKeys);
      final syncedStreak = _calculateStreakFromDayKeys(mergedDayKeys);
      if (syncedStreak != streakNotifier.value) {
        await syncStreak(syncedStreak);
      }
      return;
    }

    mergedDayKeys.add(activityDayKey);
    await _persistLocalLearningDayKeys(mergedDayKeys);

    try {
      final safeSource = source.trim().isEmpty ? 'study' : source.trim();
      FirestoreSyncStatus.instance.reportWriting(
        path: 'users/${user.uid}/learning_state/state',
        reason: 'đánh dấu ngày học mới từ $safeSource',
      );
      final sorted = mergedDayKeys.toList()..sort();
      await docRef.set({
        'completed_learning_days': sorted,
        'last_learning_day': activityDayKey,
        'last_learning_source': safeSource,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      FirestoreSyncStatus.instance.reportSuccess(
        path: 'users/${user.uid}/learning_state/state',
        message: 'Đã cập nhật ngày học mới',
      );
    } catch (error) {
      FirestoreSyncStatus.instance.reportError(
        path: 'users/${user.uid}/learning_state/state',
        operation: 'write learning day',
        error: error,
      );
    }

    final nextStreak = _calculateStreakFromDayKeys(mergedDayKeys);
    await syncStreak(nextStreak);
  }
}
