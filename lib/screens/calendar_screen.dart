import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/class_schedule_notification_service.dart';
import '../services/firestore_sync_status.dart';
import '../services/saved_cards_repository.dart';
import '../services/topic_classifier.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const String _scheduleStorageKey = 'calendar_scheduled_decks_by_day';
  static const String _scheduleTimeStorageKey =
      'calendar_scheduled_time_by_day';
  static const String _scheduleStyleStorageKey =
      'calendar_scheduled_style_by_day';
  static const String _appStartedAtKey = 'app_started_at_v1';
  static const List<String> _flashcardUnlockedDecks = [
    'Đồ điện tử',
    'Đồ nội thất',
    'Động vật',
    'Thiên nhiên',
    'Công nghệ',
    'Học tập',
    'Đồ ăn',
    'Phương tiện',
  ];

  static const List<List<Color>> _upcomingScheduleGradients = [
    [Color(0xFFFFE8D9), Color(0xFFFFD7E6), Color(0xFFF4ECFF)],
    [Color(0xFFDDF7EA), Color(0xFFCFE9FF), Color(0xFFEDE3FF)],
    [Color(0xFFFFE7B8), Color(0xFFFFD7C8), Color(0xFFF6E7FF)],
    [Color(0xFFD9ECFF), Color(0xFFBFDFFF), Color(0xFF8FC4FF)],
    [Color(0xFFF2E1FF), Color(0xFFD9F2EA), Color(0xFFFFE6C7)],
  ];

  final SavedCardsRepository _repository = SavedCardsRepository.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateUtils.dateOnly(DateTime.now());
  DateTime? _appStartedAt;
  late List<int> _studiedDays;
  late int _currentStreak;
  late List<String> _availableDecks;
  Map<String, List<String>> _scheduledDecksByDay = <String, List<String>>{};
  Map<String, String> _scheduledTimeByDay = <String, String>{};
  Map<String, int> _scheduledStyleByDay = <String, int>{};
  int _lastSyncedStreak = -1;
  Timer? _countdownTicker;
  OverlayEntry? _underFifteenMessageEntry;

  @override
  void initState() {
    super.initState();
    _studiedDays = <int>[];
    _currentStreak = 0;
    _availableDecks = <String>[];
    _repository.watchCards();
    _repository.cardsNotifier.addListener(_onCardsChanged);
    _onCardsChanged();
    _loadAppStartDate();
    _loadSchedules();
    _startCountdownTicker();
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    _underFifteenMessageEntry?.remove();
    _repository.cardsNotifier.removeListener(_onCardsChanged);
    super.dispose();
  }

  void _showUnderFifteenMinutesToast() {
    if (!mounted) {
      return;
    }

    _underFifteenMessageEntry?.remove();
    _underFifteenMessageEntry = null;

    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        final topPadding = MediaQuery.of(overlayContext).padding.top;
        return Positioned(
          top: topPadding + 14,
          left: 16,
          right: 16,
          child: IgnorePointer(
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 520),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B2F3A).withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_active_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Lịch học còn dưới 15 phút',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _underFifteenMessageEntry = entry;
    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted || !identical(_underFifteenMessageEntry, entry)) {
        return;
      }
      entry.remove();
      _underFifteenMessageEntry = null;
    });
  }

  void _startCountdownTicker() {
    _countdownTicker?.cancel();

    final now = DateTime.now();
    final initialDelay = Duration(
      seconds: 60 - now.second,
      milliseconds: 1000 - now.millisecond,
    );

    _countdownTicker = Timer(initialDelay, () {
      if (!mounted) {
        return;
      }
      setState(() {});
      _countdownTicker = Timer.periodic(const Duration(minutes: 1), (_) {
        if (!mounted) {
          return;
        }
        setState(() {});
      });
    });
  }

  DocumentReference<Map<String, dynamic>>? _learningStateDoc() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return null;
    }
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('learning_state')
        .doc('state');
  }

  DocumentReference<Map<String, dynamic>>? _profileDoc() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return null;
    }
    return _firestore.collection('users').doc(user.uid);
  }

  Future<void> _persistStreakToProfile() async {
    final docRef = _profileDoc();
    if (docRef == null || _currentStreak == _lastSyncedStreak) {
      return;
    }

    try {
      FirestoreSyncStatus.instance.reportWriting(
        path: 'users/${docRef.id}',
        reason: 'ghi streak từ cập nhật lịch học',
      );
      await docRef.set({
        'streak': _currentStreak,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _lastSyncedStreak = _currentStreak;
      FirestoreSyncStatus.instance.reportSuccess(
        path: 'users/${docRef.id}',
        message: 'Đã cập nhật streak vào hồ sơ Firestore',
      );
    } catch (error) {
      FirestoreSyncStatus.instance.reportError(
        path: 'users/${docRef.id}',
        operation: 'write streak from calendar',
        error: error,
      );
    }
  }

  Future<void> _persistAppStartToFirebase(DateTime value) async {
    final docRef = _learningStateDoc();
    if (docRef == null) {
      return;
    }

    try {
      FirestoreSyncStatus.instance.reportWriting(
        path: 'users/${docRef.parent.parent?.id}/learning_state/state',
        reason: 'ghi app_started_at',
      );
      await docRef.set({
        'app_started_at': value.toIso8601String(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      FirestoreSyncStatus.instance.reportSuccess(
        path: 'users/${docRef.parent.parent?.id}/learning_state/state',
        message: 'Đã ghi app_started_at lên Firestore',
      );
    } catch (error) {
      // Ignore cloud sync failures to keep UX responsive.
      FirestoreSyncStatus.instance.reportError(
        path: 'users/${docRef.parent.parent?.id}/learning_state/state',
        operation: 'write app_started_at',
        error: error,
      );
    }
  }

  Future<void> _persistSchedulesToFirebase() async {
    final docRef = _learningStateDoc();
    if (docRef == null) {
      return;
    }

    try {
      FirestoreSyncStatus.instance.reportWriting(
        path: 'users/${docRef.parent.parent?.id}/learning_state/state',
        reason: 'ghi lịch học',
      );
      await docRef.set({
        'scheduled_decks_by_day': _scheduledDecksByDay,
        'scheduled_time_by_day': _scheduledTimeByDay,
        'scheduled_style_by_day': _scheduledStyleByDay,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      FirestoreSyncStatus.instance.reportSuccess(
        path: 'users/${docRef.parent.parent?.id}/learning_state/state',
        message: 'Đã ghi lịch học lên Firestore',
      );
    } catch (error) {
      // Ignore cloud sync failures to keep UX responsive.
      FirestoreSyncStatus.instance.reportError(
        path: 'users/${docRef.parent.parent?.id}/learning_state/state',
        operation: 'write schedules',
        error: error,
      );
    }
  }

  Future<void> _deleteScheduleDayFromFirebase(String dayKey) async {
    final normalizedKey = dayKey.trim();
    if (normalizedKey.isEmpty) {
      return;
    }

    final docRef = _learningStateDoc();
    if (docRef == null) {
      return;
    }

    final userId = docRef.parent.parent?.id ?? '{uid}';
    try {
      FirestoreSyncStatus.instance.reportWriting(
        path: 'users/$userId/learning_state/state',
        reason: 'xóa lịch học ngày $normalizedKey',
      );

      await docRef.update({
        'scheduled_decks_by_day.$normalizedKey': FieldValue.delete(),
        'scheduled_time_by_day.$normalizedKey': FieldValue.delete(),
        'scheduled_style_by_day.$normalizedKey': FieldValue.delete(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      FirestoreSyncStatus.instance.reportSuccess(
        path: 'users/$userId/learning_state/state',
        message: 'Đã xóa lịch học ngày $normalizedKey trên Firestore',
      );
    } on FirebaseException catch (error) {
      if (error.code != 'not-found') {
        FirestoreSyncStatus.instance.reportError(
          path: 'users/$userId/learning_state/state',
          operation: 'delete schedule day',
          error: error,
        );
      }
    } catch (error) {
      FirestoreSyncStatus.instance.reportError(
        path: 'users/$userId/learning_state/state',
        operation: 'delete schedule day',
        error: error,
      );
    }
  }

  bool _isFlashcardDeck(String deck) {
    return _flashcardUnlockedDecks.contains(deck.trim());
  }

  int _deckOrder(String deck) {
    final idx = _flashcardUnlockedDecks.indexOf(deck.trim());
    return idx < 0 ? 1 << 20 : idx;
  }

  bool _isAvailableDeck(String deck) {
    return _availableDecks.contains(deck.trim());
  }

  List<String> _sanitizeDeckList(
    Iterable<dynamic> rawDecks, {
    bool onlyAvailable = false,
  }) {
    final sanitized =
        rawDecks
            .map(
              (item) => TopicClassifier.toVietnameseCanonical(item.toString()),
            )
            .map((item) => item.trim())
            .where(
              (item) =>
                  item.isNotEmpty &&
                  _isFlashcardDeck(item) &&
                  (!onlyAvailable || _isAvailableDeck(item)),
            )
            .toSet()
            .toList()
          ..sort((a, b) => _deckOrder(a).compareTo(_deckOrder(b)));
    return sanitized;
  }

  String _dateKey(DateTime date) {
    final normalized = DateUtils.dateOnly(date);
    return DateFormat('yyyy-MM-dd').format(normalized);
  }

  DateTime _keyToDate(String key) {
    return DateUtils.dateOnly(DateTime.parse(key));
  }

  String _timeToStorage(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  TimeOfDay? _timeFromStorage(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final parts = raw.split(':');
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
    return TimeOfDay(hour: hour, minute: minute);
  }

  int _gradientIndexForKey(String key) {
    if (_upcomingScheduleGradients.isEmpty) {
      return 0;
    }
    return Random(key.hashCode).nextInt(_upcomingScheduleGradients.length);
  }

  int _normalizedGradientIndex(int index) {
    if (_upcomingScheduleGradients.isEmpty) {
      return 0;
    }
    return index % _upcomingScheduleGradients.length;
  }

  List<Color> _gradientForScheduleKey(String key) {
    final index = _scheduledStyleByDay[key] ?? _gradientIndexForKey(key);
    return _upcomingScheduleGradients[_normalizedGradientIndex(index)];
  }

  String _formatTimeLabel(String? raw) {
    final parsed = _timeFromStorage(raw);
    if (parsed == null) {
      return 'Chưa chọn giờ';
    }
    return _timeToStorage(parsed);
  }

  DateTime _scheduleDateTime(DateTime date, String? rawTime) {
    final parsedTime = _timeFromStorage(rawTime);
    if (parsedTime == null) {
      return DateTime(date.year, date.month, date.day, 23, 59);
    }
    return DateTime(
      date.year,
      date.month,
      date.day,
      parsedTime.hour,
      parsedTime.minute,
    );
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    final normalizedDate = DateUtils.dateOnly(date);
    return DateTime(
      normalizedDate.year,
      normalizedDate.month,
      normalizedDate.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _syncNotificationReminders() async {
    try {
      await ClassScheduleNotificationService.instance.syncSchedules(
        scheduledDecksByDay: _scheduledDecksByDay,
        scheduledTimeByDay: _scheduledTimeByDay,
      );
    } catch (_) {
      // Notification support is best-effort and must not block the calendar.
    }
  }

  Future<void> _loadAppStartDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_appStartedAtKey);
      final parsed = raw == null || raw.isEmpty
          ? DateUtils.dateOnly(DateTime.now())
          : DateUtils.dateOnly(DateTime.parse(raw));

      if (raw == null || raw.isEmpty) {
        await prefs.setString(_appStartedAtKey, parsed.toIso8601String());
        await _persistAppStartToFirebase(parsed);
      }

      if (!mounted) {
        _appStartedAt = parsed;
        _refreshCalendarStats();
        return;
      }

      setState(() {
        _appStartedAt = parsed;
        _refreshCalendarStats();
      });

      final docRef = _learningStateDoc();
      if (docRef == null) {
        return;
      }

      FirestoreSyncStatus.instance.reportReading(
        path: 'users/${docRef.parent.parent?.id}/learning_state/state',
        reason: 'đọc app_started_at',
      );
      final snap = await docRef.get();
      final remoteRaw = snap.data()?['app_started_at'];
      if (remoteRaw is String && remoteRaw.trim().isNotEmpty) {
        final remoteDate = DateUtils.dateOnly(DateTime.parse(remoteRaw));
        if (!mounted) {
          return;
        }
        setState(() {
          _appStartedAt = remoteDate;
          _refreshCalendarStats();
        });
        await prefs.setString(_appStartedAtKey, remoteDate.toIso8601String());
        FirestoreSyncStatus.instance.reportSuccess(
          path: 'users/${docRef.parent.parent?.id}/learning_state/state',
          message: 'Đã đọc app_started_at từ Firestore',
        );
      } else {
        await _persistAppStartToFirebase(parsed);
      }
    } catch (error) {
      final fallback = DateUtils.dateOnly(DateTime.now());
      if (!mounted) {
        return;
      }
      setState(() {
        _appStartedAt = fallback;
        _refreshCalendarStats();
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_appStartedAtKey, fallback.toIso8601String());
      await _persistAppStartToFirebase(fallback);
      FirestoreSyncStatus.instance.reportError(
        path: 'users/{uid}/learning_state/state',
        operation: 'read app_started_at',
        error: error,
      );
    }
  }

  bool _isBeforeAppStart(DateTime date) {
    final appStart = _appStartedAt;
    if (appStart == null) {
      return false;
    }
    return DateUtils.dateOnly(date).isBefore(appStart);
  }

  void _onCardsChanged() {
    final unlockedDecks = _flashcardUnlockedDecks
        .where((deck) {
          final normalizedTopic = TopicClassifier.normalizeTopic(deck);
          return _repository.imageCountForTopic(normalizedTopic) > 0;
        })
        .toList(growable: false);

    if (!mounted) {
      _availableDecks = unlockedDecks;
      _refreshCalendarStats();
      return;
    }

    setState(() {
      _availableDecks = unlockedDecks;
      _refreshCalendarStats();
    });
  }

  Future<void> _loadSchedules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_scheduleStorageKey);
      final parsed = <String, List<String>>{};
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final key = entry.key.toString();
            final value = entry.value;
            if (value is List) {
              final decks = _sanitizeDeckList(value);
              if (decks.isNotEmpty) {
                parsed[key] = decks;
              }
            }
          }
        }
      }

      final rawTimes = prefs.getString(_scheduleTimeStorageKey);
      final parsedTimes = <String, String>{};
      if (rawTimes != null && rawTimes.isNotEmpty) {
        final decodedTimes = jsonDecode(rawTimes);
        if (decodedTimes is Map) {
          for (final entry in decodedTimes.entries) {
            final key = entry.key.toString();
            final value = entry.value?.toString();
            if (_timeFromStorage(value) != null) {
              parsedTimes[key] = value!;
            }
          }
        }
      }

      final rawStyles = prefs.getString(_scheduleStyleStorageKey);
      final parsedStyles = <String, int>{};
      if (rawStyles != null && rawStyles.isNotEmpty) {
        final decodedStyles = jsonDecode(rawStyles);
        if (decodedStyles is Map) {
          for (final entry in decodedStyles.entries) {
            final key = entry.key.toString();
            final value = int.tryParse(entry.value.toString());
            if (value != null) {
              parsedStyles[key] = _normalizedGradientIndex(value);
            }
          }
        }
      }

      if (!mounted) {
        _scheduledDecksByDay = parsed;
        _scheduledTimeByDay = parsedTimes;
        _scheduledStyleByDay = parsedStyles;
        _refreshCalendarStats();
        await _syncNotificationReminders();
        return;
      }

      setState(() {
        _scheduledDecksByDay = parsed;
        _scheduledTimeByDay = parsedTimes;
        _scheduledStyleByDay = parsedStyles;
        _refreshCalendarStats();
      });
      await _syncNotificationReminders();

      final docRef = _learningStateDoc();
      if (docRef == null) {
        return;
      }

      FirestoreSyncStatus.instance.reportReading(
        path: 'users/${docRef.parent.parent?.id}/learning_state/state',
        reason: 'đọc lịch học',
      );
      final snap = await docRef.get();
      final data = snap.data();
      if (data == null) {
        final legacySnap = await _firestore
            .collection('user_learning_state')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .get();
        final legacyData = legacySnap.data();
        if (legacyData != null) {
          final legacyDecksRaw = legacyData['scheduled_decks_by_day'];
          final legacyTimesRaw = legacyData['scheduled_time_by_day'];
          final legacyStylesRaw = legacyData['scheduled_style_by_day'];
          final migratedDecks = <String, List<String>>{};
          if (legacyDecksRaw is Map) {
            for (final entry in legacyDecksRaw.entries) {
              final key = entry.key.toString();
              final value = entry.value;
              if (value is List) {
                final decks = _sanitizeDeckList(value);
                if (decks.isNotEmpty) {
                  migratedDecks[key] = decks;
                }
              }
            }
          }
          final migratedTimes = <String, String>{};
          if (legacyTimesRaw is Map) {
            for (final entry in legacyTimesRaw.entries) {
              final key = entry.key.toString();
              final value = entry.value?.toString();
              if (_timeFromStorage(value) != null) {
                migratedTimes[key] = value!;
              }
            }
          }
          final migratedStyles = <String, int>{};
          if (legacyStylesRaw is Map) {
            for (final entry in legacyStylesRaw.entries) {
              final key = entry.key.toString();
              final rawValue = entry.value;
              final parsedValue = rawValue is int
                  ? rawValue
                  : (rawValue is num ? rawValue.toInt() : null);
              if (parsedValue != null) {
                migratedStyles[key] = _normalizedGradientIndex(parsedValue);
              }
            }
          }
          if (migratedDecks.isNotEmpty ||
              migratedTimes.isNotEmpty ||
              migratedStyles.isNotEmpty) {
            _scheduledDecksByDay = migratedDecks;
            _scheduledTimeByDay = migratedTimes;
            _scheduledStyleByDay = migratedStyles;
            _refreshCalendarStats();
            await _persistSchedulesToFirebase();
            await _syncNotificationReminders();
          }
          FirestoreSyncStatus.instance.reportSuccess(
            path: 'users/${docRef.parent.parent?.id}/learning_state/state',
            message: 'Đã đọc/migrate lịch học từ Firestore',
          );
          return;
        }

        if (_scheduledDecksByDay.isNotEmpty ||
            _scheduledTimeByDay.isNotEmpty ||
            _scheduledStyleByDay.isNotEmpty) {
          await _persistSchedulesToFirebase();
        }
        await _syncNotificationReminders();
        FirestoreSyncStatus.instance.reportSuccess(
          path: 'users/${docRef.parent.parent?.id}/learning_state/state',
          message: 'Đã xử lý lịch học khi chưa có dữ liệu cloud',
        );
        return;
      }

      final remoteDecksRaw = data['scheduled_decks_by_day'];
      final remoteTimesRaw = data['scheduled_time_by_day'];
      final remoteStylesRaw = data['scheduled_style_by_day'];

      final remoteDecks = <String, List<String>>{};
      if (remoteDecksRaw is Map) {
        for (final entry in remoteDecksRaw.entries) {
          final key = entry.key.toString();
          final value = entry.value;
          if (value is List) {
            final decks = _sanitizeDeckList(value);
            if (decks.isNotEmpty) {
              remoteDecks[key] = decks;
            }
          }
        }
      }

      final remoteTimes = <String, String>{};
      if (remoteTimesRaw is Map) {
        for (final entry in remoteTimesRaw.entries) {
          final key = entry.key.toString();
          final value = entry.value?.toString();
          if (_timeFromStorage(value) != null) {
            remoteTimes[key] = value!;
          }
        }
      }

      final remoteStyles = <String, int>{};
      if (remoteStylesRaw is Map) {
        for (final entry in remoteStylesRaw.entries) {
          final key = entry.key.toString();
          final rawValue = entry.value;
          final parsedValue = rawValue is int
              ? rawValue
              : (rawValue is num ? rawValue.toInt() : null);
          if (parsedValue != null) {
            remoteStyles[key] = _normalizedGradientIndex(parsedValue);
          }
        }
      }

      if (remoteDecks.isNotEmpty ||
          remoteTimes.isNotEmpty ||
          remoteStyles.isNotEmpty) {
        if (!mounted) {
          await _syncNotificationReminders();
          return;
        }
        setState(() {
          _scheduledDecksByDay = remoteDecks;
          _scheduledTimeByDay = remoteTimes;
          _scheduledStyleByDay = remoteStyles;
          _refreshCalendarStats();
        });

        await prefs.setString(
          _scheduleStorageKey,
          jsonEncode(_scheduledDecksByDay),
        );
        await prefs.setString(
          _scheduleTimeStorageKey,
          jsonEncode(_scheduledTimeByDay),
        );
        await prefs.setString(
          _scheduleStyleStorageKey,
          jsonEncode(_scheduledStyleByDay),
        );
        await _syncNotificationReminders();
      } else if (_scheduledDecksByDay.isNotEmpty ||
          _scheduledTimeByDay.isNotEmpty ||
          _scheduledStyleByDay.isNotEmpty) {
        await _persistSchedulesToFirebase();
        await _syncNotificationReminders();
      }
      FirestoreSyncStatus.instance.reportSuccess(
        path: 'users/${docRef.parent.parent?.id}/learning_state/state',
        message: 'Đã đọc lịch học từ Firestore',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(_refreshCalendarStats);
      FirestoreSyncStatus.instance.reportError(
        path: 'users/{uid}/learning_state/state',
        operation: 'read schedules',
        error: error,
      );
    }
  }

  Future<void> _persistSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scheduleStorageKey,
      jsonEncode(_scheduledDecksByDay),
    );
    await prefs.setString(
      _scheduleTimeStorageKey,
      jsonEncode(_scheduledTimeByDay),
    );
    await prefs.setString(
      _scheduleStyleStorageKey,
      jsonEncode(_scheduledStyleByDay),
    );
    await _persistSchedulesToFirebase();
    await _syncNotificationReminders();
  }

  bool _hasScheduleOnDate(DateTime date) {
    final decks = _scheduledDecksByDay[_dateKey(date)];
    return decks != null && decks.isNotEmpty;
  }

  bool _hasLearningActivityOnDate(DateTime date) {
    final target = DateUtils.dateOnly(date);
    return _repository.cardsNotifier.value.any((card) {
      final savedDate = DateUtils.dateOnly(card.savedAt.toLocal());
      return DateUtils.isSameDay(savedDate, target);
    });
  }

  List<String> _decksForDate(DateTime date) {
    return _sanitizeDeckList(_scheduledDecksByDay[_dateKey(date)] ?? const []);
  }

  void _refreshCalendarStats() {
    final daysInMonth = DateUtils.getDaysInMonth(
      _focusedDay.year,
      _focusedDay.month,
    );

    _studiedDays = List.generate(daysInMonth, (index) => index + 1).where((
      day,
    ) {
      final date = DateTime(_focusedDay.year, _focusedDay.month, day);
      return !_isBeforeAppStart(date) && _hasLearningActivityOnDate(date);
    }).toList();
    _currentStreak = _calculateCurrentStreak();
    _persistStreakToProfile();
  }

  int _calculateCurrentStreak() {
    int streak = 0;
    var cursor = DateUtils.dateOnly(DateTime.now());
    while (!_isBeforeAppStart(cursor) && _hasLearningActivityOnDate(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  List<DateTime> _recentLearningDays({int limit = 7}) {
    final today = DateUtils.dateOnly(DateTime.now());
    final start = _appStartedAt ?? today;
    final learned = <DateTime>[];
    var cursor = today;

    while (!cursor.isBefore(start) && learned.length < limit) {
      if (_hasLearningActivityOnDate(cursor)) {
        learned.add(cursor);
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return learned.reversed.toList();
  }

  void _changeMonth(int offset) {
    final next = DateTime(_focusedDay.year, _focusedDay.month + offset);
    setState(() {
      _focusedDay = next;
      _selectedDay = DateTime(next.year, next.month, 1);
      _refreshCalendarStats();
    });
  }

  Future<void> _saveSelectedDayDecks(
    List<String> selectedDecks, {
    TimeOfDay? selectedTime,
  }) async {
    final sanitizedSelectedDecks = _sanitizeDeckList(
      selectedDecks,
      onlyAvailable: true,
    );
    final key = _dateKey(_selectedDay);
    setState(() {
      if (sanitizedSelectedDecks.isEmpty) {
        _scheduledDecksByDay.remove(key);
        _scheduledTimeByDay.remove(key);
        _scheduledStyleByDay.remove(key);
      } else {
        _scheduledDecksByDay[key] = sanitizedSelectedDecks;
        if (selectedTime != null) {
          _scheduledTimeByDay[key] = _timeToStorage(selectedTime);
        } else {
          _scheduledTimeByDay.remove(key);
        }
        _scheduledStyleByDay.putIfAbsent(
          key,
          () => Random().nextInt(_upcomingScheduleGradients.length),
        );
      }
      _refreshCalendarStats();
    });
    await _persistSchedules();
  }

  Future<void> _deleteScheduledDay(DateTime date) async {
    final key = _dateKey(date);
    setState(() {
      _scheduledDecksByDay.remove(key);
      _scheduledTimeByDay.remove(key);
      _scheduledStyleByDay.remove(key);
      _refreshCalendarStats();
    });
    await _deleteScheduleDayFromFirebase(key);
    await _persistSchedules();
  }

  Future<void> _confirmDeleteScheduledDay(_UpcomingSchedule schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFF4E8),
                  Color(0xFFF8E9FF),
                  Color(0xFFEAF6FF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE5D4E1), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9CB9D4).withValues(alpha: 0.24),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: const Color(0xFFC89FB9).withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8AD4FF), Color(0xFFB68CFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Xoá lịch này?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D3557),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Xoá toàn bộ bộ thẻ đã gán cho ${DateFormat('dd/MM/yyyy').format(schedule.date)}. Thao tác này không thể hoàn tác.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0xFF5D738A),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.tonal(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.72),
                        foregroundColor: const Color(0xFF1D3557),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text('Hủy'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE45757),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text('Xoá lịch'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      await _deleteScheduledDay(schedule.date);
    }
  }

  Future<void> _openDeckPickerForSelectedDay() async {
    final initialSelected = _decksForDate(
      _selectedDay,
    ).where(_isAvailableDeck).toSet();
    final dayKey = _dateKey(_selectedDay);
    final initialTime = _timeFromStorage(_scheduledTimeByDay[dayKey]);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final selected = <String>{...initialSelected};
        TimeOfDay? selectedTime = initialTime;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              titlePadding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              contentPadding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              title: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.edit_calendar_rounded,
                      size: 19,
                      color: Color(0xFF1D3557),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Kế hoạch ngày ${DateFormat('dd/MM/yyyy').format(_selectedDay)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1D3557),
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F9FE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE0E8F3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 18,
                            color: Color(0xFF1D3557),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Giờ học: ${selectedTime == null ? 'Chưa chọn giờ' : _timeToStorage(selectedTime!)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1D3557),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: selectedTime ?? TimeOfDay.now(),
                              );
                              if (picked == null) {
                                return;
                              }
                              setDialogState(() {
                                selectedTime = picked;
                              });
                            },
                            child: const Text('Chọn giờ'),
                          ),
                          if (selectedTime != null)
                            IconButton(
                              tooltip: 'Xóa giờ',
                              onPressed: () {
                                setDialogState(() {
                                  selectedTime = null;
                                });
                              },
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_availableDecks.isEmpty)
                      const Text('Chưa có bộ thẻ để chọn.')
                    else ...[
                      const Text(
                        'Chọn bộ thẻ',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1D3557),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableDecks.map((deck) {
                              final checked = selected.contains(deck);
                              return FilterChip(
                                selected: checked,
                                label: Text(deck),
                                showCheckmark: false,
                                selectedColor: const Color(0xFFEAF3FE),
                                backgroundColor: const Color(0xFFF7FAFC),
                                side: BorderSide(
                                  color: checked
                                      ? const Color(0xFF9ABADD)
                                      : const Color(0xFFDDE5EE),
                                ),
                                labelStyle: TextStyle(
                                  fontWeight: checked
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: const Color(0xFF1D3557),
                                ),
                                onSelected: (value) {
                                  setDialogState(() {
                                    if (value) {
                                      selected.add(deck);
                                    } else {
                                      selected.remove(deck);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (selected.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Hãy chọn ít nhất một bộ thẻ.'),
                        ),
                      );
                      return;
                    }
                    if (selectedTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Hãy chọn giờ học cho lịch này.'),
                        ),
                      );
                      return;
                    }

                    final scheduleAt = _combineDateAndTime(
                      _selectedDay,
                      selectedTime!,
                    );
                    final now = DateTime.now();
                    if (!scheduleAt.isAfter(now)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Không thể chọn giờ học trước thời điểm hiện tại.',
                          ),
                        ),
                      );
                      return;
                    }

                    final isUnderFifteenMinutes =
                        scheduleAt.difference(now).inMinutes < 15;
                    await _saveSelectedDayDecks(
                      selected.toList(),
                      selectedTime: selectedTime,
                    );

                    if (isUnderFifteenMinutes) {
                      if (!context.mounted) {
                        return;
                      }
                      _showUnderFifteenMinutesToast();
                      await HapticFeedback.heavyImpact();
                      await ClassScheduleNotificationService.instance
                          .showImmediateUnderFifteenMinutesAlert(
                            decks: selected.toList(),
                            timeLabel: _timeToStorage(selectedTime!),
                          );
                    }

                    if (!dialogContext.mounted) {
                      return;
                    }
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  int _daysUntil(DateTime targetDate) {
    final today = DateUtils.dateOnly(DateTime.now());
    return DateUtils.dateOnly(targetDate).difference(today).inDays;
  }

  String _weekdayVi(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'Thứ Hai';
      case DateTime.tuesday:
        return 'Thứ Ba';
      case DateTime.wednesday:
        return 'Thứ Tư';
      case DateTime.thursday:
        return 'Thứ Năm';
      case DateTime.friday:
        return 'Thứ Sáu';
      case DateTime.saturday:
        return 'Thứ Bảy';
      case DateTime.sunday:
        return 'Chủ nhật';
      default:
        return 'Không rõ';
    }
  }

  String _upcomingCountdownLabel(_UpcomingSchedule schedule) {
    final now = DateTime.now();
    final target = _scheduleDateTime(schedule.date, schedule.time);
    final diff = target.difference(now);

    if (diff.isNegative) {
      return 'Quá hạn';
    }

    if (diff.inMinutes >= 0 && diff.inHours < 24) {
      if (diff.inMinutes < 60) {
        final mins = diff.inMinutes <= 0 ? 1 : diff.inMinutes;
        return 'Còn $mins phút';
      }
      final hours = diff.inMinutes ~/ 60;
      final roundedHours = (diff.inMinutes % 60) == 0 ? hours : hours + 1;
      return 'Còn $roundedHours giờ';
    }

    final daysLeft = _daysUntil(schedule.date);
    if (daysLeft == 0) {
      return 'Hôm nay';
    }
    return 'Còn $daysLeft ngày';
  }

  List<_UpcomingSchedule> _getUpcomingSchedules() {
    final today = DateUtils.dateOnly(DateTime.now());
    final schedules = <_UpcomingSchedule>[];

    for (final entry in _scheduledDecksByDay.entries) {
      if (entry.value.isEmpty) {
        continue;
      }
      final date = _keyToDate(entry.key);
      if (date.isBefore(today)) {
        continue;
      }
      schedules.add(
        _UpcomingSchedule(
          date: date,
          decks: entry.value,
          time: _scheduledTimeByDay[entry.key],
          styleIndex:
              _scheduledStyleByDay[entry.key] ??
              _gradientIndexForKey(entry.key),
        ),
      );
    }

    schedules.sort((a, b) => a.date.compareTo(b.date));
    return schedules;
  }

  Future<void> _openMonthYearPicker() async {
    int selectedMonth = _focusedDay.month;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              titlePadding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
              contentPadding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
              title: const Text(
                'Đổi tháng học',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 2.25,
                          ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final month = index + 1;
                        final isSelected = month == selectedMonth;
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () =>
                              setDialogState(() => selectedMonth = month),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF1D3557)
                                  : const Color(0xFFF4F7FB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF1D3557)
                                    : const Color(0xFFDDE5EE),
                              ),
                            ),
                            child: Text(
                              'Tháng $month',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF1D3557),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _focusedDay = DateTime(_focusedDay.year, selectedMonth);
                      _selectedDay = DateTime(
                        _focusedDay.year,
                        selectedMonth,
                        1,
                      );
                      _refreshCalendarStats();
                    });
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Áp dụng'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    int daysInMonth = DateUtils.getDaysInMonth(
      _focusedDay.year,
      _focusedDay.month,
    );
    final selectedDateDecks = _decksForDate(_selectedDay);
    final upcomingSchedules = _getUpcomingSchedules();
    DateTime firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    int startWeekday = firstDayOfMonth.weekday; // 1 (Mon) -> 7 (Sun)
    int totalCells = daysInMonth + (startWeekday - 1);
    int rows = ((totalCells) / 7).ceil();
    int gridCount = rows * 7;
    final monthLabel = DateFormat('MMMM yyyy').format(_focusedDay);
    final totalStudyDays = _studiedDays.length;
    final recentLearningDays = _recentLearningDays(limit: 7);

    return Scaffold(
      body: Container(
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
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Lịch học',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1D3557),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD7EEFF), Color(0xFFE4F6E9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFB8D3EE),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF7FA7C6,
                          ).withValues(alpha: 0.26),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.local_fire_department_rounded,
                              color: Color(0xFFFF7B2F),
                              size: 21,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Chuỗi ngày học: $_currentStreak ngày',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Color(0xFF183153),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$totalStudyDays ngày trong tháng',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4A6077),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (recentLearningDays.isEmpty)
                          const Text(
                            'Chưa có ngày học nào.',
                            style: TextStyle(color: Color(0xFF627485)),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: recentLearningDays.map((date) {
                              final today = DateUtils.dateOnly(DateTime.now());
                              final isToday = DateUtils.isSameDay(date, today);
                              final scheduled = _hasScheduleOnDate(date);
                              final fillColor = scheduled
                                  ? const Color(
                                      0xFFEAF8F2,
                                    ).withValues(alpha: 0.78)
                                  : const Color(
                                      0xFFEAF8F2,
                                    ).withValues(alpha: 0.78);
                              final borderColor = scheduled
                                  ? const Color(
                                      0xFF74C69D,
                                    ).withValues(alpha: 0.95)
                                  : const Color(
                                      0xFF74C69D,
                                    ).withValues(alpha: 0.95);

                              return Container(
                                width: 36,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: fillColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isToday
                                        ? const Color(0xFF183153)
                                        : borderColor,
                                    width: isToday ? 2 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF7FA7C6,
                                      ).withValues(alpha: 0.26),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      DateFormat(
                                        'E',
                                      ).format(date).substring(0, 2),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF516476),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${date.day}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF183153),
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    const Icon(
                                      Icons.check_circle,
                                      size: 12,
                                      color: Color(0xFF2CB67D),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => _changeMonth(-1),
                          icon: const Icon(Icons.chevron_left_rounded),
                          tooltip: 'Tháng trước',
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: _openMonthYearPicker,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.calendar_month_rounded,
                                    size: 18,
                                    color: Color(0xFF1D3557),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    monthLabel,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1D3557),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _changeMonth(1),
                          icon: const Icon(Icons.chevron_right_rounded),
                          tooltip: 'Tháng sau',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _GlassCard(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: const [
                            Text(
                              'T2',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'T3',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'T4',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'T5',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'T6',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'T7',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'CN',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                mainAxisSpacing: 5,
                                crossAxisSpacing: 5,
                                childAspectRatio: 1.12,
                              ),
                          itemCount: gridCount,
                          itemBuilder: (context, index) {
                            int dayNum = index - (startWeekday - 1) + 1;
                            bool isValidDay =
                                dayNum > 0 && dayNum <= daysInMonth;
                            final dayDate = DateUtils.dateOnly(
                              DateTime(
                                _focusedDay.year,
                                _focusedDay.month,
                                dayNum,
                              ),
                            );
                            final today = DateUtils.dateOnly(DateTime.now());
                            final scheduled =
                                isValidDay && _hasScheduleOnDate(dayDate);
                            final beforeAppStart =
                                isValidDay && _isBeforeAppStart(dayDate);
                            final isToday =
                                isValidDay &&
                                DateUtils.isSameDay(dayDate, today);
                            final studiedToday =
                                isToday && _hasLearningActivityOnDate(dayDate);
                            final isCompleted = scheduled || studiedToday;
                            final isPast =
                                isValidDay && dayDate.isBefore(today);
                            final isFuture =
                                isValidDay && dayDate.isAfter(today);
                            final fillColor = isFuture && scheduled
                                ? const Color(
                                    0xFFFFF3C4,
                                  ).withValues(alpha: 0.65)
                                : (isPast || isToday) && isCompleted
                                ? const Color(
                                    0xFFE9F8F1,
                                  ).withValues(alpha: 0.72)
                                : isPast && !beforeAppStart
                                ? const Color(
                                    0xFFFDECEC,
                                  ).withValues(alpha: 0.72)
                                : const Color(
                                    0xFFF7FAFC,
                                  ).withValues(alpha: 0.55);
                            final borderColor = isFuture && scheduled
                                ? const Color(0xFFE1B100).withValues(alpha: 0.7)
                                : (isPast || isToday) && isCompleted
                                ? const Color(
                                    0xFF8FDDBD,
                                  ).withValues(alpha: 0.85)
                                : isPast && !beforeAppStart
                                ? const Color(0xFFF3A2A2).withValues(alpha: 0.8)
                                : const Color(
                                    0xFFE4EAF1,
                                  ).withValues(alpha: 0.8);
                            final icon = isFuture && scheduled
                                ? Icons.local_offer_rounded
                                : (isPast || isToday) && isCompleted
                                ? Icons.check_circle
                                : isPast && !beforeAppStart
                                ? Icons.remove_circle_outline
                                : Icons.circle_outlined;
                            final iconColor = isFuture && scheduled
                                ? const Color(0xFFE1B100)
                                : (isPast || isToday) && isCompleted
                                ? const Color(0xFF2CB67D)
                                : isPast && !beforeAppStart
                                ? const Color(0xFFE45757)
                                : const Color(0xFFB4C2CF);
                            final isSelected =
                                isValidDay &&
                                DateUtils.isSameDay(dayDate, _selectedDay);

                            return InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: isValidDay
                                  ? () {
                                      setState(() {
                                        _selectedDay = dayDate;
                                      });
                                    }
                                  : null,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                decoration: BoxDecoration(
                                  color: isValidDay
                                      ? fillColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: isValidDay
                                      ? Border.all(
                                          color: isToday
                                              ? const Color(0xFF1D3557)
                                              : isSelected
                                              ? const Color(0xFF1D3557)
                                              : borderColor,
                                          width: isToday
                                              ? 2
                                              : isSelected
                                              ? 1.5
                                              : 1,
                                        )
                                      : null,
                                ),
                                child: isValidDay
                                    ? Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '$dayNum',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: beforeAppStart
                                                  ? const Color(0xFF98A6B8)
                                                  : const Color(0xFF1D3557),
                                            ),
                                          ),
                                          const SizedBox(height: 0),
                                          Icon(
                                            icon,
                                            size: 12,
                                            color: iconColor,
                                          ),
                                        ],
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFFFEFE0).withValues(alpha: 0.94),
                                const Color(0xFFF8E7FF).withValues(alpha: 0.9),
                                const Color(0xFFE7F4FF).withValues(alpha: 0.88),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(
                                0xFFE4C8D5,
                              ).withValues(alpha: 0.9),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFC89FB9,
                                ).withValues(alpha: 0.2),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: const Color(
                                  0xFF7EA7C9,
                                ).withValues(alpha: 0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                  child: Image.asset(
                                    'assets/onboarding/test.png',
                                    height: 54,
                                    width: 54,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Bộ thẻ ngày',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1D3557),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat(
                                        'dd/MM/yyyy',
                                      ).format(_selectedDay),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF5D738A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: _openDeckPickerForSelectedDay,
                                style: TextButton.styleFrom(
                                  backgroundColor: const Color(0xFF1D3557),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(
                                  Icons.edit_calendar_rounded,
                                  size: 17,
                                ),
                                label: const Text('Chọn'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Các bộ thẻ đã gán',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF637A90),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (selectedDateDecks.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFF7FAFC,
                              ).withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(
                                  0xFFE4EAF1,
                                ).withValues(alpha: 0.8),
                              ),
                            ),
                            child: const Text(
                              'Chưa có bộ thẻ nào cho ngày này. Hãy thêm để tạo kế hoạch học.',
                              style: TextStyle(color: Color(0xFF627485)),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: selectedDateDecks
                                .map(
                                  (deck) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(
                                            0xFFEAF3FE,
                                          ).withValues(alpha: 0.92),
                                          const Color(
                                            0xFFF1ECFF,
                                          ).withValues(alpha: 0.9),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: const Color(
                                          0xFFD8E7F6,
                                        ).withValues(alpha: 0.92),
                                      ),
                                    ),
                                    child: Text(
                                      deck,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1D3557),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lịch sắp tới',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1D3557),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (upcomingSchedules.isEmpty)
                          const Text(
                            'Bạn chưa có lịch học sắp tới.',
                            style: TextStyle(color: Color(0xFF627485)),
                          )
                        else
                          Column(
                            children: upcomingSchedules.map((schedule) {
                              final dayLabel = _upcomingCountdownLabel(
                                schedule,
                              );
                              final shortMonth = DateFormat(
                                'MM',
                              ).format(schedule.date);
                              final scheduleGradient = _gradientForScheduleKey(
                                _dateKey(schedule.date),
                              );
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: scheduleGradient
                                        .map(
                                          (color) =>
                                              color.withValues(alpha: 0.86),
                                        )
                                        .toList(),
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: scheduleGradient.first.withValues(
                                      alpha: 0.86,
                                    ),
                                    width: 1.1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: scheduleGradient.last.withValues(
                                        alpha: 0.24,
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, 9),
                                    ),
                                    BoxShadow(
                                      color: const Color(
                                        0xFF2B4A62,
                                      ).withValues(alpha: 0.08),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 52,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFEAF3FE,
                                        ).withValues(alpha: 0.86),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFFD4E5F7),
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${schedule.date.day}',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1D3557),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Thg $shortMonth',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF5D738A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _weekdayVi(schedule.date),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF1D3557),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFEAF3FE,
                                                  ).withValues(alpha: 0.72),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  dayLabel,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF1D3557),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                width: 30,
                                                height: 30,
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.82),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFFE8D7DE,
                                                    ),
                                                  ),
                                                ),
                                                child: IconButton(
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                  iconSize: 16,
                                                  tooltip: 'Xoá lịch',
                                                  onPressed: () =>
                                                      _confirmDeleteScheduledDay(
                                                        schedule,
                                                      ),
                                                  icon: const Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    color: Color(0xFFE45757),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          if (schedule.time != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 6,
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.schedule,
                                                    size: 14,
                                                    color: Color(0xFF5D738A),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Giờ học: ${_formatTimeLabel(schedule.time)}',
                                                    style: const TextStyle(
                                                      color: Color(0xFF5D738A),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: [
                                              ...schedule.decks
                                                  .take(4)
                                                  .map(
                                                    (deck) => Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            const Color(
                                                              0xFFE9F8F1,
                                                            ).withValues(
                                                              alpha: 0.82,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              999,
                                                            ),
                                                        border: Border.all(
                                                          color: const Color(
                                                            0xFFBEE9D2,
                                                          ),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        deck,
                                                        style: const TextStyle(
                                                          color: Color(
                                                            0xFF2B4A62,
                                                          ),
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              if (schedule.decks.length > 4)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFF1F5FB,
                                                    ).withValues(alpha: 0.85),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '+${schedule.decks.length - 4}',
                                                    style: const TextStyle(
                                                      color: Color(0xFF516476),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${schedule.decks.length} bộ thẻ',
                                            style: const TextStyle(
                                              color: Color(0xFF637A90),
                                              fontSize: 11,
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UpcomingSchedule {
  final DateTime date;
  final List<String> decks;
  final String? time;
  final int styleIndex;

  const _UpcomingSchedule({
    required this.date,
    required this.decks,
    this.time,
    this.styleIndex = 0,
  });
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.58),
            borderRadius: borderRadius,
            border: Border.all(
              color: const Color(0xFFE3EAF2).withValues(alpha: 0.95),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8BB3D6).withValues(alpha: 0.16),
                blurRadius: 18,
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
