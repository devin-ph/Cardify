import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class ClassScheduleNotificationService {
  ClassScheduleNotificationService._();

  static final ClassScheduleNotificationService instance =
      ClassScheduleNotificationService._();

  static const String _channelId = 'class_schedule_reminders';
  static const String _channelName = 'Nhac lich hoc';
  static const String _channelDescription =
      'Thong bao nhac truoc 15 phut va rung 1 lan';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (kIsWeb || _initialized) {
      return;
    }

    tz.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(settings: initializationSettings);
    await _requestPermissions();
    _initialized = true;
  }

  Future<void> _requestPermissions() async {
    final androidImplementation =
        _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.requestExactAlarmsPermission();

    final iosImplementation = _plugin.resolvePlatformSpecificImplementation<
      IOSFlutterLocalNotificationsPlugin
    >();
    await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final macosImplementation = _plugin.resolvePlatformSpecificImplementation<
      MacOSFlutterLocalNotificationsPlugin
    >();
    await macosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  int _notificationIdFor(String scheduleKey) {
    return scheduleKey.hashCode & 0x7fffffff;
  }

  DateTime? _parseReminderTime(String dayKey, String? rawTime) {
    if (rawTime == null || rawTime.trim().isEmpty) {
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

    final date = DateTime.tryParse(dayKey);
    if (date == null) {
      return null;
    }

    final classDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
    return classDateTime.subtract(const Duration(minutes: 15));
  }

  String _buildTitle(List<String> decks) {
    if (decks.isEmpty) {
      return 'Giờ học sắp bắt đầu';
    }
    return decks.length == 1
        ? 'Sắp đến giờ học ${decks.first}'
        : 'Sắp đến giờ học';
  }

  String _buildBody(List<String> decks, String timeLabel) {
    if (decks.isEmpty) {
      return 'Buổi học bắt đầu lúc $timeLabel. Mời bạn mở ứng dụng để ôn tập .';
    }

    final topicText = decks.length == 1
        ? 'Chủ đề ${decks.first}'
        : 'Các chủ đề ${decks.join(', ')}';
    return '$topicText bắt đầu lúc $timeLabel. Mời bạn mở ứng dụng để ôn tập.';
  }

  NotificationDetails _notificationDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 800]),
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  Future<void> syncSchedules({
    required Map<String, List<String>> scheduledDecksByDay,
    required Map<String, String> scheduledTimeByDay,
  }) async {
    if (kIsWeb) {
      return;
    }

    if (!_initialized) {
      await initialize();
    }

    await _plugin.cancelAll();

    final now = DateTime.now();
    for (final entry in scheduledDecksByDay.entries) {
      if (entry.value.isEmpty) {
        continue;
      }

      final reminderTime = _parseReminderTime(
        entry.key,
        scheduledTimeByDay[entry.key],
      );
      if (reminderTime == null || !reminderTime.isAfter(now)) {
        continue;
      }

      final dayDate = DateTime.tryParse(entry.key);
      final timeLabel = scheduledTimeByDay[entry.key] ?? '';
      if (dayDate == null || timeLabel.isEmpty) {
        continue;
      }

      await _plugin.zonedSchedule(
        id: _notificationIdFor(entry.key),
        title: _buildTitle(entry.value),
        body: _buildBody(entry.value, timeLabel),
        scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
        notificationDetails: _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: entry.key,
      );
    }
  }

  Future<void> showImmediateUnderFifteenMinutesAlert({
    required List<String> decks,
    required String timeLabel,
  }) async {
    if (kIsWeb) {
      return;
    }

    if (!_initialized) {
      await initialize();
    }

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
      title: 'Lịch học sắp bắt đầu',
      body:
          'Lịch lúc $timeLabel chỉ còn dưới 15 phút. Hãy vào app để học ngay.',
      notificationDetails: _notificationDetails(),
      payload: 'immediate-under-15m-${decks.join(',')}',
    );
  }
}