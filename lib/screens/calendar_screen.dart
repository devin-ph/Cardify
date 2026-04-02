import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  // Fake study days for the current month
  late List<int> _studiedDays;

  @override
  void initState() {
    super.initState();
    _generateFakeStudyDays();
  }

  void _generateFakeStudyDays() {
    // Ví dụ: các ngày chia hết cho 2 hoặc 3 là có học
    int daysInMonth = DateUtils.getDaysInMonth(
      _focusedDay.year,
      _focusedDay.month,
    );
    _studiedDays = List.generate(
      daysInMonth,
      (i) => i + 1,
    ).where((d) => d % 2 == 0 || d % 3 == 0).toList();
  }

  void _onNextMonth() async {
    int currentYear = _focusedDay.year;
    int currentMonth = _focusedDay.month;
    int minYear = currentYear - 2;
    int maxYear = currentYear + 2;
    int selectedYear = currentYear;
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SizedBox(
              height: 420,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Select month & year',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  // Năm
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_left),
                        onPressed: selectedYear > minYear
                            ? () => setModalState(() => selectedYear--)
                            : null,
                      ),
                      Text(
                        '$selectedYear',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.arrow_right),
                        onPressed: selectedYear < maxYear
                            ? () => setModalState(() => selectedYear++)
                            : null,
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  // Tháng
                  Expanded(
                    child: ListView.builder(
                      itemCount: 12,
                      itemBuilder: (context, idx) {
                        final month = idx + 1;
                        return ListTile(
                          title: Text(
                            DateFormat(
                              'MMMM',
                            ).format(DateTime(selectedYear, month)),
                          ),
                          selected:
                              month == currentMonth &&
                              selectedYear == currentYear,
                          onTap: () {
                            setState(() {
                              _focusedDay = DateTime(selectedYear, month);
                              _generateFakeStudyDays();
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
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
    DateTime firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    int startWeekday = firstDayOfMonth.weekday; // 1 (Mon) -> 7 (Sun)
    int totalCells = daysInMonth + (startWeekday - 1);
    int rows = ((totalCells) / 7).ceil();
    int gridCount = rows * 7;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header — removed close and arrow; title is tappable to open month selector
              Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        'Study calendar',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: GestureDetector(
                      onTap: _onNextMonth,
                      child: Icon(Icons.arrow_forward_ios, size: 24),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  DateFormat('MMMM yyyy').format(_focusedDay),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Days of week
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  Text('Mon', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Tue', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Wed', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Thu', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Fri', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Sat', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Sun', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              // Calendar grid đồng bộ với tháng thực tế
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: gridCount,
                  itemBuilder: (context, index) {
                    int dayNum = index - (startWeekday - 1) + 1;
                    bool isValidDay = dayNum > 0 && dayNum <= daysInMonth;
                    bool studied = isValidDay && _studiedDays.contains(dayNum);
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: isValidDay
                          ? FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$dayNum',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 2),
                                  studied
                                      ? Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                          size: 18,
                                        )
                                      : Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.grey,
                                          size: 18,
                                        ),
                                ],
                              ),
                            )
                          : null,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Monthly progress card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.pink[100],
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Monthly progress',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'You studied for 25 days!',
                            style: TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                    // Placeholder for face icon
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.pink[200],
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
