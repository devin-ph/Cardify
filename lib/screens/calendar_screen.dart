import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/saved_cards_repository.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const String _scheduleStorageKey = 'calendar_scheduled_decks_by_day';
  static const List<String> _defaultDeckNames = [
    'Đồ gia dụng',
    'Thiên nhiên',
    'Công nghệ',
    'Đồ ăn',
    'Con vật',
    'Phương tiện',
    'Hoạt động',
    'Màu sắc',
    'Không gian',
    'Thời gian',
  ];

  final SavedCardsRepository _repository = SavedCardsRepository.instance;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateUtils.dateOnly(DateTime.now());
  late List<int> _studiedDays;
  late int _currentStreak;
  late List<String> _availableDecks;
  Map<String, List<String>> _scheduledDecksByDay = <String, List<String>>{};

  @override
  void initState() {
    super.initState();
    _studiedDays = <int>[];
    _currentStreak = 0;
    _availableDecks = List<String>.from(_defaultDeckNames);
    _repository.watchCards();
    _repository.cardsNotifier.addListener(_onCardsChanged);
    _onCardsChanged();
    _loadSchedules();
  }

  @override
  void dispose() {
    _repository.cardsNotifier.removeListener(_onCardsChanged);
    super.dispose();
  }

  String _dateKey(DateTime date) {
    final normalized = DateUtils.dateOnly(date);
    return DateFormat('yyyy-MM-dd').format(normalized);
  }

  DateTime _keyToDate(String key) {
    return DateUtils.dateOnly(DateTime.parse(key));
  }

  void _onCardsChanged() {
    final cards = _repository.cardsNotifier.value;
    final topics = cards
        .map((card) => card.topic.trim())
        .where((topic) => topic.isNotEmpty)
        .toSet();

    final merged = <String>{..._defaultDeckNames, ...topics}.toList()..sort();

    if (!mounted) {
      _availableDecks = merged;
      return;
    }

    setState(() {
      _availableDecks = merged;
    });
  }

  Future<void> _loadSchedules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_scheduleStorageKey);
      if (raw == null || raw.isEmpty) {
        _refreshCalendarStats();
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _refreshCalendarStats();
        return;
      }

      final parsed = <String, List<String>>{};
      for (final entry in decoded.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is List) {
          final decks =
              value
                  .map((item) => item.toString().trim())
                  .where((item) => item.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
          if (decks.isNotEmpty) {
            parsed[key] = decks;
          }
        }
      }

      if (!mounted) {
        _scheduledDecksByDay = parsed;
        _refreshCalendarStats();
        return;
      }

      setState(() {
        _scheduledDecksByDay = parsed;
        _refreshCalendarStats();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(_refreshCalendarStats);
    }
  }

  Future<void> _persistSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scheduleStorageKey,
      jsonEncode(_scheduledDecksByDay),
    );
  }

  bool _hasScheduleOnDate(DateTime date) {
    final decks = _scheduledDecksByDay[_dateKey(date)];
    return decks != null && decks.isNotEmpty;
  }

  List<String> _decksForDate(DateTime date) {
    return List<String>.from(_scheduledDecksByDay[_dateKey(date)] ?? const []);
  }

  void _refreshCalendarStats() {
    final daysInMonth = DateUtils.getDaysInMonth(
      _focusedDay.year,
      _focusedDay.month,
    );

    _studiedDays = List.generate(daysInMonth, (index) => index + 1)
        .where(
          (day) => _hasScheduleOnDate(
            DateTime(_focusedDay.year, _focusedDay.month, day),
          ),
        )
        .toList();
    _currentStreak = _calculateCurrentStreak();
  }

  int _calculateCurrentStreak() {
    int streak = 0;
    var cursor = DateUtils.dateOnly(DateTime.now());
    while (_hasScheduleOnDate(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  void _changeMonth(int offset) {
    final next = DateTime(_focusedDay.year, _focusedDay.month + offset);
    setState(() {
      _focusedDay = next;
      _selectedDay = DateTime(next.year, next.month, 1);
      _refreshCalendarStats();
    });
  }

  Future<void> _saveSelectedDayDecks(List<String> selectedDecks) async {
    final key = _dateKey(_selectedDay);
    setState(() {
      if (selectedDecks.isEmpty) {
        _scheduledDecksByDay.remove(key);
      } else {
        final uniqueSorted = selectedDecks.toSet().toList()..sort();
        _scheduledDecksByDay[key] = uniqueSorted;
      }
      _refreshCalendarStats();
    });
    await _persistSchedules();
  }

  Future<void> _openDeckPickerForSelectedDay() async {
    final initialSelected = _decksForDate(_selectedDay).toSet();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final selected = <String>{...initialSelected};
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                'Bộ thẻ ngày ${DateFormat('dd/MM/yyyy').format(_selectedDay)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SizedBox(
                width: 360,
                child: _availableDecks.isEmpty
                    ? const Text('Chưa có bộ thẻ để chọn.')
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _availableDecks.length,
                        itemBuilder: (context, index) {
                          final deck = _availableDecks[index];
                          final checked = selected.contains(deck);
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: checked,
                            title: Text(deck),
                            onChanged: (value) {
                              setDialogState(() {
                                if (value == true) {
                                  selected.add(deck);
                                } else {
                                  selected.remove(deck);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () async {
                    await _saveSelectedDayDecks(selected.toList());
                    if (!mounted) {
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
      schedules.add(_UpcomingSchedule(date: date, decks: entry.value));
    }

    schedules.sort((a, b) => a.date.compareTo(b.date));
    return schedules;
  }

  Future<void> _openMonthYearPicker() async {
    int selectedYear = _focusedDay.year;
    int selectedMonth = _focusedDay.month;
    final currentYear = DateTime.now().year;
    final years = List.generate(9, (index) => currentYear - 4 + index);

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
                    DropdownButtonFormField<int>(
                      initialValue: selectedYear,
                      decoration: const InputDecoration(
                        labelText: 'Năm',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: years
                          .map(
                            (year) => DropdownMenuItem<int>(
                              value: year,
                              child: Text('$year'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() => selectedYear = value);
                      },
                    ),
                    const SizedBox(height: 12),
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
                      _focusedDay = DateTime(selectedYear, selectedMonth);
                      _selectedDay = DateTime(selectedYear, selectedMonth, 1);
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

    return Scaffold(
      body: SafeArea(
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
                      colors: [Color(0xFFCEE9FF), Color(0xFFE3F5EA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFD4E6F7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            color: Color(0xFFFF7B2F),
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Chuỗi ngày học: $_currentStreak ngày',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1D3557),
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
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(7, (index) {
                          final today = DateUtils.dateOnly(DateTime.now());
                          final date = today.subtract(
                            Duration(days: 6 - index),
                          );
                          final scheduled = _hasScheduleOnDate(date);
                          final isToday = DateUtils.isSameDay(date, today);
                          final isPast = date.isBefore(today);
                          final isFuture = date.isAfter(today);
                          final fillColor = isToday
                              ? const Color(0xFF1D3557)
                              : isFuture && scheduled
                              ? const Color(0xFFFFF3C4)
                              : isPast && scheduled
                              ? const Color(0xFFE9F8F1)
                              : isPast
                              ? const Color(0xFFFDECEC)
                              : Colors.white;
                          final borderColor = isToday
                              ? const Color(0xFF1D3557)
                              : isFuture && scheduled
                              ? const Color(0xFFE1B100)
                              : isPast && scheduled
                              ? const Color(0xFF8FDDBD)
                              : isPast
                              ? const Color(0xFFF3A2A2)
                              : const Color(0xFFD8E1EA);
                          final icon = isToday
                              ? Icons.star_rounded
                              : isFuture && scheduled
                              ? Icons.local_offer_rounded
                              : isPast && scheduled
                              ? Icons.check_circle
                              : isPast
                              ? Icons.remove_circle_outline
                              : Icons.circle_outlined;
                          final iconColor = isToday
                              ? Colors.white
                              : isFuture && scheduled
                              ? const Color(0xFFE1B100)
                              : isPast && scheduled
                              ? const Color(0xFF2CB67D)
                              : isPast
                              ? const Color(0xFFE45757)
                              : const Color(0xFFB4C2CF);

                          return Container(
                            width: 36,
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            decoration: BoxDecoration(
                              color: fillColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormat('E').format(date).substring(0, 2),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isToday ||
                                            isFuture && scheduled ||
                                            isPast && scheduled
                                        ? Colors.white
                                        : const Color(0xFF516476),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color:
                                        isToday ||
                                            isFuture && scheduled ||
                                            isPast && scheduled
                                        ? Colors.white
                                        : const Color(0xFF1D3557),
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Icon(icon, size: 12, color: iconColor),
                              ],
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE1E7EE)),
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
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFF1D3557),
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
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE1E7EE)),
                  ),
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
                              mainAxisSpacing: 6,
                              crossAxisSpacing: 6,
                              childAspectRatio: 1.05,
                            ),
                        itemCount: gridCount,
                        itemBuilder: (context, index) {
                          int dayNum = index - (startWeekday - 1) + 1;
                          bool isValidDay = dayNum > 0 && dayNum <= daysInMonth;
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
                          final isToday =
                              isValidDay && DateUtils.isSameDay(dayDate, today);
                          final isPast = isValidDay && dayDate.isBefore(today);
                          final isFuture = isValidDay && dayDate.isAfter(today);
                          final fillColor = isToday
                              ? const Color(0xFF1D3557)
                              : isFuture && scheduled
                              ? const Color(0xFFFFF3C4)
                              : isPast && scheduled
                              ? const Color(0xFFE9F8F1)
                              : isPast
                              ? const Color(0xFFFDECEC)
                              : const Color(0xFFF7FAFC);
                          final borderColor = isToday
                              ? const Color(0xFF1D3557)
                              : isFuture && scheduled
                              ? const Color(0xFFE1B100)
                              : isPast && scheduled
                              ? const Color(0xFF8FDDBD)
                              : isPast
                              ? const Color(0xFFF3A2A2)
                              : const Color(0xFFE4EAF1);
                          final icon = isToday
                              ? Icons.star_rounded
                              : isFuture && scheduled
                              ? Icons.local_offer_rounded
                              : isPast && scheduled
                              ? Icons.check_circle
                              : isPast
                              ? Icons.remove_circle_outline
                              : Icons.circle_outlined;
                          final iconColor = isToday
                              ? Colors.white
                              : isFuture && scheduled
                              ? const Color(0xFFE1B100)
                              : isPast && scheduled
                              ? const Color(0xFF2CB67D)
                              : isPast
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
                                        color: isSelected
                                            ? const Color(0xFF1D3557)
                                            : borderColor,
                                        width: isSelected ? 1.5 : 1,
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
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color:
                                                isToday ||
                                                    isFuture && scheduled ||
                                                    isPast && scheduled
                                                ? Colors.white
                                                : const Color(0xFF1D3557),
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Icon(icon, size: 13, color: iconColor),
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    const _LegendDot(
                      color: Color(0xFFE45757),
                      label: 'Chưa học',
                    ),
                    const SizedBox(width: 14),
                    const _LegendDot(
                      color: Color(0xFF1D3557),
                      label: 'Hôm nay',
                    ),
                    const SizedBox(width: 14),
                    const _LegendDot(
                      color: Color(0xFFE1B100),
                      label: 'Đã gắn thẻ',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE1E7EE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Bộ thẻ ngày ${DateFormat('dd/MM/yyyy').format(_selectedDay)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1D3557),
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _openDeckPickerForSelectedDay,
                            icon: const Icon(
                              Icons.edit_calendar_rounded,
                              size: 18,
                            ),
                            label: const Text('Chọn bộ thẻ'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (selectedDateDecks.isEmpty)
                        const Text(
                          'Chưa có bộ thẻ nào cho ngày này. Hãy thêm để tạo kế hoạch học.',
                          style: TextStyle(color: Color(0xFF627485)),
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
                                    color: const Color(0xFFEAF3FE),
                                    borderRadius: BorderRadius.circular(999),
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
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE1E7EE)),
                  ),
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
                            final daysLeft = _daysUntil(schedule.date);
                            final dayLabel = daysLeft == 0
                                ? 'Hôm nay'
                                : 'Còn $daysLeft ngày';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE4EAF1),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.event_note_rounded,
                                    size: 18,
                                    color: Color(0xFF1D3557),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat(
                                            'EEEE, dd/MM/yyyy',
                                          ).format(schedule.date),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1D3557),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          schedule.decks.join(' • '),
                                          style: const TextStyle(
                                            color: Color(0xFF516476),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAF3FE),
                                      borderRadius: BorderRadius.circular(20),
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
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF516476),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _UpcomingSchedule {
  final DateTime date;
  final List<String> decks;

  const _UpcomingSchedule({required this.date, required this.decks});
}
