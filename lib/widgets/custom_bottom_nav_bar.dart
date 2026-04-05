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
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 5),
      child: BottomAppBar(
        shape: UpwardNotchedShape(notchHeight: 24), // notch nổi rõ quanh camera
        notchMargin: 6.0,
        color: const Color.fromARGB(255, 253, 253, 253),
        elevation: 8,
        child: SizedBox(
          height: 74,
          child: Row(
            children: [
              Expanded(
                child: _NavIconItem(
                  icon: Icons.home,
                  label: 'Trang chủ',
                  isSelected: currentIndex == 0,
                  onTap: () => onTap(0),
                ),
              ),
              Expanded(
                child: _NavIconItem(
                  icon: Icons.calendar_today,
                  label: 'Lịch',
                  isSelected: currentIndex == 1,
                  onTap: () => onTap(1),
                ),
              ),
              Expanded(
                child: _NavIconItem(
                  icon: Icons.menu_book,
                  label: 'Bộ sưu tập',
                  isSelected: currentIndex == 2,
                  onTap: () => onTap(2),
                ),
              ),
              Expanded(
                child: _NavIconItem(
                  icon: Icons.style,
                  label: 'Ôn tập',
                  isSelected: currentIndex == 3,
                  onTap: () => onTap(3),
                ),
              ),
              Expanded(
                child: _NavIconItem(
                  icon: Icons.emoji_events,
                  label: 'Thành tích',
                  isSelected: currentIndex == 4,
                  onTap: () => onTap(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIconItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavIconItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF8B5CF6);
    const inactiveColor = Color(0xFF9CA3AF);

    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.black12,
            highlightColor: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              height: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    width: isSelected ? 55 : 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isSelected ? activeColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? Colors.white : inactiveColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: isSelected ? activeColor : inactiveColor,
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
