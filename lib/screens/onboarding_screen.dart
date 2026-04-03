import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingSlideData> _slides = [
    _OnboardingSlideData(
      stepLabel: 'BƯỚC 1/3',
      title: 'Học tiếng Anh qua những đồ vật xung quanh',
      highlight: 'đồ vật',
      subtitle:
          'Dùng camera để khám phá từ vựng. Chỉ cần hướng máy, chụp và học từ mới ngay lập tức.',
      primaryActionLabel: 'Bắt đầu',
      illustration: _SlideOneIllustration(),
      background: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF7EDF8), Color(0xFFF8F3FF), Color(0xFFFFF4F8)],
      ),
    ),
    _OnboardingSlideData(
      stepLabel: 'BƯỚC 2',
      title: 'Xây dựng thư viện cá nhân.',
      subtitle:
          'Mỗi đồ vật bạn quét sẽ được thêm vào bộ sưu tập để ôn tập dễ dàng. Biến mọi thứ quanh bạn thành vốn từ vựng.',
      primaryActionLabel: 'Tiếp theo',
      illustration: _SlideTwoIllustration(),
      background: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFD8E6FF), Color(0xFFE8FBF1), Color(0xFFDDF4EA)],
      ),
    ),
    _OnboardingSlideData(
      stepLabel: 'BƯỚC CUỐI',
      title: 'Mở khóa thành tích',
      subtitle:
          'Giữ động lực để chinh phục mục tiêu. Nhận huy hiệu, duy trì chuỗi học và ăn mừng từng cột mốc.',
      primaryActionLabel: 'Bắt đầu',
      illustration: _SlideThreeIllustration(),
      background: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFD0E5), Color(0xFFF7F0FF), Color(0xFFE7E5FF)],
      ),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    widget.onFinished();
  }

  void _finish() => widget.onFinished();

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentPage];

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(gradient: slide.background),
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(child: _AtmosphereLayer()),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
                    child: Row(
                      children: [
                        Text(
                          'Cardify',
                          style: TextStyle(
                            fontSize: 20.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.deepPurple.shade400,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _finish,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF7457F0),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          child: const Text('Bỏ qua'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _slides.length,
                      onPageChanged: (value) {
                        setState(() {
                          _currentPage = value;
                        });
                      },
                      itemBuilder: (context, index) {
                        return _OnboardingPage(slide: _slides[index]);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PageIndicator(currentIndex: _currentPage),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: _PrimaryActionButton(
                            label: slide.primaryActionLabel,
                            onPressed: _goToNextPage,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingSlideData slide;

  const _OnboardingPage({required this.slide});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            slide.illustration,
            const SizedBox(height: 24),
            Text(
              slide.stepLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6C43F2),
                fontWeight: FontWeight.w800,
                letterSpacing: 3.0,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 18),
            _OnboardingTitle(text: slide.title, highlight: slide.highlight),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                slide.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20.5,
                  height: 1.45,
                  color: Color(0xFF666666),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingTitle extends StatelessWidget {
  final String text;
  final String? highlight;

  const _OnboardingTitle({required this.text, this.highlight});

  @override
  Widget build(BuildContext context) {
    final lines = text.split(' ');

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 40.5,
          height: 0.95,
          fontWeight: FontWeight.w900,
          letterSpacing: -2.2,
          color: Color(0xFF222222),
        ),
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const TextSpan(text: ' '),
            if (highlight != null && lines[i].contains(highlight!))
              () {
                final parts = lines[i].split(highlight!);
                return TextSpan(
                  children: [
                    TextSpan(text: parts.first),
                    TextSpan(
                      text: highlight,
                      style: TextStyle(color: Colors.deepPurple.shade400),
                    ),
                    if (parts.length > 1)
                      TextSpan(text: parts.sublist(1).join(highlight!)),
                  ],
                );
              }()
            else
              TextSpan(text: lines[i]),
          ],
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int currentIndex;

  const _PageIndicator({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          height: 12,
          width: isActive ? 44 : 12,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF6D3BF5) : const Color(0xFFD8D8D8),
            borderRadius: BorderRadius.circular(999),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF6D3BF5).withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PrimaryActionButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          colors: [Color(0xFF6D3BF5), Color(0xFFAF87FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D3BF5).withOpacity(0.25),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(34),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AtmosphereLayer extends StatelessWidget {
  const _AtmosphereLayer();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _AtmospherePainter()));
  }
}

class _AtmospherePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42);

    paint.color = const Color(0x66FFD0E5);
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.18),
      size.width * 0.18,
      paint,
    );

    paint.color = const Color(0x552F80FF);
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.22),
      size.width * 0.17,
      paint,
    );

    paint.color = const Color(0x55C9F8D9);
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.78),
      size.width * 0.2,
      paint,
    );

    paint.color = const Color(0x44B58BFF);
    canvas.drawCircle(
      Offset(size.width * 0.26, size.height * 0.86),
      size.width * 0.24,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SlideOneIllustration extends StatelessWidget {
  const _SlideOneIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 330,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 18,
            child: _FrostedCard(
              width: 310,
              height: 310,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: Image.asset(
                  'assets/onboarding/anh.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return DecoratedBox(
                      decoration: const BoxDecoration(
                        color: Color.fromARGB(255, 237, 237, 237),
                      ),
                      child: Icon(
                        Icons.backpack_rounded,
                        size: 110,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideTwoIllustration extends StatelessWidget {
  const _SlideTwoIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 330,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 12,
            top: 34,
            child: Transform.rotate(
              angle: -0.08,
              child: _FrostedCard(
                width: 168,
                height: 230,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ObjectCardArt(
                      background: const LinearGradient(
                        colors: [
                          Color.fromARGB(255, 250, 250, 250),
                          Color.fromARGB(255, 255, 255, 255),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Image.asset(
                          'assets/onboarding/camera.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.photo_camera_rounded,
                              size: 82,
                              color: Colors.grey.shade700,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'ĐÃ QUÉT',
                      style: TextStyle(
                        color: Color(0xFFD81B73),
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Máy ảnh',
                      style: TextStyle(
                        fontSize: 22.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Máy ảnh',
                      style: TextStyle(
                        color: Color(0xFF6B6B6B),
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 26,
            child: Transform.rotate(
              angle: 0.05,
              child: _FrostedCard(
                width: 174,
                height: 230,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ObjectCardArt(
                      background: const LinearGradient(
                        colors: [
                          Color.fromARGB(255, 255, 255, 255),
                          Color.fromARGB(255, 255, 255, 255),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Image.asset(
                          'assets/onboarding/book.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.menu_book_rounded,
                              size: 82,
                              color: Colors.amber.shade200,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(height: 4),
                    const Text(
                      'Sách',
                      style: TextStyle(
                        fontSize: 22.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            child: Transform.translate(
              offset: const Offset(0, 12),
              child: _FrostedCard(
                width: 180,
                height: 196,
                borderRadius: 34,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ObjectCardArt(
                      background: const LinearGradient(
                        colors: [
                          Color.fromARGB(255, 246, 246, 246),
                          Color.fromARGB(255, 243, 242, 242),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Image.asset(
                          'assets/onboarding/coffee.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.coffee_rounded,
                              size: 88,
                              color: Colors.brown.shade200,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Cốc cà phê',
                      style: TextStyle(
                        fontSize: 22.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideThreeIllustration extends StatelessWidget {
  const _SlideThreeIllustration();

  static const double _designWidth = 360;
  static const double _designHeight = 366;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _designWidth;
        final scale = (availableWidth / _designWidth).clamp(0.82, 1.12);
        final scaledHeight = _designHeight * scale;

        return SizedBox(
          height: scaledHeight,
          child: Center(
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: _designWidth,
                height: _designHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 5,
                      top: 8,
                      child: Transform.rotate(
                        angle: -0.03,
                        child: _AchievementCard(
                          icon: Icons.local_fire_department_rounded,
                          iconColor: const Color(0xFFD31E7A),
                          title: 'Chuỗi học 7 ngày',
                          subtitle: 'Vua kiên trì',
                        ),
                      ),
                    ),
                    Positioned(
                      right: 5,
                      top: 22,
                      child: Transform.rotate(
                        angle: 0.03,
                        child: _AchievementCard(
                          icon: Icons.workspace_premium_rounded,
                          iconColor: const Color(0xFF7D55F4),
                          title: 'Bậc thầy từ vựng',
                          subtitle: '100 từ mới',
                        ),
                      ),
                    ),
                    Positioned(
                      left: 15,
                      bottom: 14,
                      child: Transform.rotate(
                        angle: 0.02,
                        child: _AchievementCard(
                          icon: Icons.star_rounded,
                          iconColor: const Color(0xFF0E7C58),
                          title: 'Học viên xuất sắc',
                          subtitle: 'Điểm quiz tuyệt đối',
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      bottom: 2,
                      child: Transform.rotate(
                        angle: -0.04,
                        child: _AchievementCard(
                          icon: Icons.trending_up_rounded,
                          iconColor: const Color(0xFF7A52F3),
                          title: 'Cấp độ 12',
                          subtitle: 'Học giả tinh anh',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FrostedCard extends StatelessWidget {
  final double width;
  final double height;
  final Widget child;
  final double borderRadius;

  const _FrostedCard({
    required this.width,
    required this.height,
    required this.child,
    this.borderRadius = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ObjectCardArt extends StatelessWidget {
  final Gradient background;
  final Widget child;

  const _ObjectCardArt({required this.background, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      height: 122,
      decoration: BoxDecoration(
        gradient: background,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Center(child: child),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _AchievementCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 147,
      height: 170,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.09),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF666666)),
          ),
        ],
      ),
    );
  }
}

class _DiagonalHatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;

    const spacing = 10.0;
    for (var i = -size.height; i < size.width; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OnboardingSlideData {
  final String stepLabel;
  final String title;
  final String? highlight;
  final String subtitle;
  final String primaryActionLabel;
  final Widget illustration;
  final LinearGradient background;

  const _OnboardingSlideData({
    required this.stepLabel,
    required this.title,
    required this.subtitle,
    required this.primaryActionLabel,
    required this.illustration,
    required this.background,
    this.highlight,
  });
}
