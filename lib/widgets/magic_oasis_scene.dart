import 'dart:math';

import 'package:flutter/material.dart';

class MagicOasisScene extends StatelessWidget {
  final List<String> unlockedElementIds;
  final bool isBarren;
  final double height;

  const MagicOasisScene({
    super.key,
    required this.unlockedElementIds,
    required this.isBarren,
    this.height = 280,
  });

  bool _has(String id) => unlockedElementIds.contains(id);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: height,
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 16,
              right: 24,
              child: Text(
                '☀️',
                style: TextStyle(
                  fontSize: isBarren ? 38 : 40,
                ),
              ),
            ),
            Positioned(
              left: -30,
              top: 28,
              child: Text(
                '☁️',
                style: TextStyle(
                  fontSize: isBarren ? 32 : 35,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -20,
              right: -20,
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  color: isBarren ? const Color(0xFFD4A373) : const Color(0xFF4ADE80),
                  borderRadius: const BorderRadius.all(
                    Radius.elliptical(350, 140),
                  ),
                  border: Border.all(
                    color: const Color(0xFF42516E).withValues(alpha: 0.5),
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -10,
              left: -40,
              right: -40,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.lightBlueAccent.withValues(alpha: 0.35),
                  borderRadius: const BorderRadius.all(
                    Radius.elliptical(500, 80),
                  ),
                ),
              ),
            ),
            if (isBarren) ...[
              const Positioned(
                bottom: 30,
                left: 110,
                child: Text('🪨', style: TextStyle(fontSize: 32)),
              ),
              const Positioned(
                bottom: 25,
                right: 120,
                child: Text('🪵', style: TextStyle(fontSize: 36)),
              ),
              const Positioned(
                bottom: 50,
                left: 45,
                child: Text('🌵', style: TextStyle(fontSize: 60)),
              ),
              const Positioned(
                bottom: 45,
                right: 50,
                child: Text('🌵', style: TextStyle(fontSize: 45)),
              ),
              const Positioned(
                bottom: 60,
                right: 100,
                child: Text('🪨', style: TextStyle(fontSize: 24)),
              ),
            ],
            if (!isBarren) ...[
              if (_has('castle'))
                const Positioned(
                  bottom: 75,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text('🏰', style: TextStyle(fontSize: 70)),
                  ),
                ),
              if (_has('trees'))
                const Positioned(
                  bottom: 60,
                  left: 40,
                  child: Text('🌳', style: TextStyle(fontSize: 55)),
                ),
              if (_has('household'))
                const Positioned(
                  bottom: 55,
                  right: 50,
                  child: Text('🍄', style: TextStyle(fontSize: 45)),
                ),
              if (_has('animals')) ...[
                const Positioned(
                  bottom: 40,
                  right: 110,
                  child: Text('🦌', style: TextStyle(fontSize: 35)),
                ),
                Positioned(
                  bottom: 78 + sin(DateTime.now().millisecond / 1000 * pi * 2) * 10,
                  left: 80,
                  child: const Text('🦋', style: TextStyle(fontSize: 20)),
                ),
              ],
              if (_has('rabbit'))
                const Positioned(
                  bottom: 30,
                  left: 80,
                  child: Text('🐇', style: TextStyle(fontSize: 35)),
                ),
              if (_has('flowers')) ...[
                const Positioned(
                  bottom: 15,
                  left: 160,
                  child: Text('🌺', style: TextStyle(fontSize: 14)),
                ),
                const Positioned(
                  bottom: 35,
                  right: 90,
                  child: Text('🌺', style: TextStyle(fontSize: 16)),
                ),
                const Positioned(
                  bottom: 20,
                  left: 60,
                  child: Text('🌼', style: TextStyle(fontSize: 14)),
                ),
                const Positioned(
                  bottom: 8,
                  right: 45,
                  child: Text('🌻', style: TextStyle(fontSize: 14)),
                ),
              ],
              if (_has('mushrooms')) ...[
                const Positioned(
                  bottom: 25,
                  right: 60,
                  child: Text('🌱', style: TextStyle(fontSize: 16)),
                ),
                const Positioned(
                  bottom: 10,
                  right: 120,
                  child: Text('🌱', style: TextStyle(fontSize: 14)),
                ),
                const Positioned(
                  bottom: 30,
                  left: 90,
                  child: Text('🌱', style: TextStyle(fontSize: 15)),
                ),
                const Positioned(
                  bottom: 15,
                  left: 50,
                  child: Text('🌱', style: TextStyle(fontSize: 12)),
                ),
                const Positioned(
                  bottom: 20,
                  right: 20,
                  child: Text('🌱', style: TextStyle(fontSize: 14)),
                ),
              ],
              if (_has('lighthouse'))
                const Positioned(
                  bottom: 0,
                  right: 20,
                  child: Text('🗼', style: TextStyle(fontSize: 45)),
                ),
              if (_has('tent'))
                const Positioned(
                  bottom: -5,
                  left: 30,
                  child: Text('⛺', style: TextStyle(fontSize: 40)),
                ),
              if (_has('airballoon'))
                Positioned(
                  bottom: 130 + sin(DateTime.now().millisecond / 1000 * pi) * 15,
                  left: 20,
                  child: const Text('🎈', style: TextStyle(fontSize: 40)),
                ),
              if (_has('space'))
                Positioned(
                  top: 20 + sin(DateTime.now().millisecond / 1000 * pi * 2) * 10,
                  right: 60,
                  child: const Text('🚀', style: TextStyle(fontSize: 35)),
                ),
              if (_has('magic'))
                Positioned(
                  bottom: 110 + sin(DateTime.now().millisecond / 1000 * pi * 2) * 20,
                  left: 170 + cos(DateTime.now().millisecond / 1000 * pi * 2) * 40,
                  child: const Text('✨', style: TextStyle(fontSize: 30)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
