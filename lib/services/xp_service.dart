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
      }
    });
  }

  final ValueNotifier<int> xpNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> levelNotifier = ValueNotifier<int>(1);
  final ValueNotifier<int> streakNotifier = ValueNotifier<int>(0);
  bool _isSyncing = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _profileSubscription;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _profileDoc(String uid) {
    return _firestore.collection('users').doc(uid);
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

  Future<void> _syncFromFirebase(User user) async {
    if (kIsWeb) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    if (_isSyncing) {
      return;
    }

    _isSyncing = true;
    try {
      final docRef = _profileDoc(user.uid);
      FirestoreSyncStatus.instance.reportReading(
        path: 'users/${user.uid}',
        reason: 'đồng bộ XP/level/streak lúc khởi tạo',
      );
      final snapshot = await docRef.get();

      if (snapshot.exists) {
        final data = snapshot.data() ?? <String, dynamic>{};
        xpNotifier.value = _readInt(data, 'xp', xpNotifier.value);
        levelNotifier.value = _readInt(data, 'level', levelNotifier.value);
        streakNotifier.value = _readInt(data, 'streak', streakNotifier.value);
        await _persistLocal();
        FirestoreSyncStatus.instance.reportSuccess(
          path: 'users/${user.uid}',
          message: 'Đã đọc hồ sơ XP từ Firestore',
        );
        return;
      }

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

      FirestoreSyncStatus.instance.reportWriting(
        path: 'users/${user.uid}',
        reason: 'khởi tạo hồ sơ người dùng mặc định',
      );
      await docRef.set({
        'xp': xpNotifier.value,
        'level': levelNotifier.value,
        'streak': streakNotifier.value,
        'next_level_xp': levelNotifier.value * 1000,
        'display_name': user.displayName ?? 'Explorer',
        'email': user.email,
        'updated_at': FieldValue.serverTimestamp(),
      });
      FirestoreSyncStatus.instance.reportSuccess(
        path: 'users/${user.uid}',
        message: 'Đã tạo hồ sơ mặc định trên Firestore',
      );
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
}
