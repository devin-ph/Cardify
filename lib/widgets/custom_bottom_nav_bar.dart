import 'package:flutter/material.dart';

// Custom NotchedShape để notch nhích lên trên
class UpwardNotchedShape extends NotchedShape {
  final double notchHeight;
  const UpwardNotchedShape({this.notchHeight = -12});

  @override
  Path getOuterPath(Rect host, Rect? guest) {
    if (guest == null || !host.overlaps(guest)) {
      return Path()..addRect(host);
    }
    final notchRadius = guest.width / 2.0;
    final s1 = 7.0;
    final s2 = 6.0;
    final r = notchRadius;
    final a = notchHeight + 3; // notch nhích lên trên
    final b = guest.center.dx;
    final t = host.top;
    final l = host.left;
    final rHost = host.right;
    final bHost = host.bottom;

    final path = Path();
    path.moveTo(l, t);
    // Đoạn bên trái đến notch
    path.lineTo(b - r - s1, t);
    // Bézier lên trên tạo notch
    path.cubicTo(b - r - s2, t, b - r, t + a, b, t + a);
    path.cubicTo(b + r, t + a, b + r + s2, t, b + r + s1, t);
    // Đoạn bên phải notch
    path.lineTo(rHost, t);
    path.lineTo(rHost, bHost);
    path.lineTo(l, bHost);
    path.close();
    return path;
  }
}

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback onCameraTap;
  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onCameraTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: UpwardNotchedShape(notchHeight: 18), // notch nhích lên trên
      notchMargin: 0.0,
      color: Color.fromARGB(255, 255, 243, 255),
      child: Row(
        children: [
          Expanded(
            child: IconButton(
              icon: Icon(
                Icons.home,
                color: currentIndex == 0
                    ? Colors.blue
                    : const Color.fromARGB(255, 47, 34, 34),
              ),
              onPressed: () => onTap(0),
              tooltip: 'Trang chủ',
            ),
          ),
          Expanded(
            child: IconButton(
              icon: Icon(
                Icons.calendar_today,
                color: currentIndex == 1
                    ? Colors.blue
                    : const Color.fromARGB(255, 47, 34, 34),
              ),
              onPressed: () => onTap(1),
              tooltip: 'Lịch',
            ),
          ),
          const SizedBox(width: 00), // khoảng trống cho nút chụp ảnh
          Expanded(
            child: IconButton(
              icon: Icon(
                Icons.menu_book,
                color: currentIndex == 2
                    ? Colors.blue
                    : const Color.fromARGB(255, 47, 34, 34),
              ),
              onPressed: () => onTap(2),
              tooltip: 'Từ điển',
            ),
          ),
          Expanded(
            child: IconButton(
              icon: Icon(
                Icons.style,
                color: currentIndex == 3
                    ? Colors.blue
                    : const Color.fromARGB(255, 58, 53, 53),
              ),
              onPressed: () => onTap(3),
              tooltip: 'Ôn Tập',
            ),
          ),
          Expanded(
            child: IconButton(
              icon: Icon(
                Icons.emoji_events,
                color: currentIndex == 4
                    ? Colors.blue
                    : const Color.fromARGB(255, 47, 34, 34),
              ),
              onPressed: () => onTap(4),
              tooltip: 'Thành tựu',
            ),
          ),
        ],
      ),
    );
  }
}
