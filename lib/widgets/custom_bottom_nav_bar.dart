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
            child: _NavIconItem(
              icon: Icons.home,
              color: currentIndex == 0
                  ? Colors.blue
                  : const Color.fromARGB(255, 47, 34, 34),
              tooltip: 'Trang chủ',
              onTap: () => onTap(0),
            ),
          ),
          Expanded(
            child: _NavIconItem(
              icon: Icons.calendar_today,
              color: currentIndex == 1
                  ? Colors.blue
                  : const Color.fromARGB(255, 47, 34, 34),
              tooltip: 'Lịch',
              onTap: () => onTap(1),
            ),
          ),
          const SizedBox(width: 00), // khoảng trống cho nút chụp ảnh
          Expanded(
            child: _NavIconItem(
              icon: Icons.menu_book,
              color: currentIndex == 2
                  ? Colors.blue
                  : const Color.fromARGB(255, 47, 34, 34),
              tooltip: 'Từ điển',
              onTap: () => onTap(2),
            ),
          ),
          Expanded(
            child: _NavIconItem(
              icon: Icons.style,
              color: currentIndex == 3
                  ? Colors.blue
                  : const Color.fromARGB(255, 58, 53, 53),
              tooltip: 'Ôn tập',
              onTap: () => onTap(3),
            ),
          ),
          Expanded(
            child: _NavIconItem(
              icon: Icons.emoji_events,
              color: currentIndex == 4
                  ? Colors.blue
                  : const Color.fromARGB(255, 47, 34, 34),
              tooltip: 'Thành tích',
              onTap: () => onTap(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavIconItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _NavIconItem({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: tooltip,
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.black12,
            highlightColor: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              height: 48,
              child: Center(child: Icon(icon, color: color)),
            ),
          ),
        ),
      ),
    );
  }
}
