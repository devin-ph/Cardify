import 'dart:math' as math;
import 'package:flutter/material.dart';

class MainLoadingScreen extends StatefulWidget {
  const MainLoadingScreen({super.key});

  @override
  State<MainLoadingScreen> createState() => _MainLoadingScreenState();
}

class _MainLoadingScreenState extends State<MainLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _spinAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _pulseAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.15,
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.15,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
    ]).animate(_controller);

    _slideAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: -12.0,
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -12.0,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
    ]).animate(_controller);

    _spinAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.linear),
      ),
    );

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RepaintBoundary(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 1400),
                  curve: Curves.elasticOut,
                  builder: (context, loadValue, child) {
                    return Transform.scale(
                      scale: loadValue,
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          return Transform.translate(
                            offset: Offset(0, _slideAnimation.value),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Glowing background pulse
                                Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          const Color(
                                            0xFF0098D8,
                                          ).withValues(alpha: 0.3),
                                          const Color(
                                            0xFFF079B1,
                                          ).withValues(alpha: 0.1),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.2, 0.6, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                                // Spinning outer ring
                                Transform.rotate(
                                  angle: _spinAnimation.value,
                                  child: Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(
                                          0xFF0098D8,
                                        ).withValues(alpha: 0.15),
                                        width: 2,
                                        style: BorderStyle.solid,
                                      ),
                                    ),
                                  ),
                                ),
                                // Main Icon Container
                                Container(
                                  padding: const EdgeInsets.all(28),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF0098D8,
                                        ).withValues(alpha: 0.25),
                                        blurRadius: 28,
                                        spreadRadius: 8,
                                      ),
                                      BoxShadow(
                                        color: const Color(
                                          0xFFF079B1,
                                        ).withValues(alpha: 0.15),
                                        blurRadius: 16,
                                        spreadRadius: -4,
                                        offset: const Offset(4, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Color(0xFF0098D8),
                                    size: 64,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 52),
              RepaintBoundary(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 24 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: const Column(
                    children: [
                      Text(
                        'AI English Learning',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0B1C3D),
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Chào mừng bạn quay trở lại!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B5563),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 60),
              RepaintBoundary(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeInQuint,
                  builder: (context, value, child) {
                    return Opacity(opacity: value, child: child);
                  },
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      backgroundColor: Colors.white.withValues(alpha: 0.7),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF0098D8),
                      ),
                      strokeWidth: 4,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
