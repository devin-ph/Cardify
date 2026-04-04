import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class XPService {
  static final XPService instance = XPService._();
  XPService._();

  final ValueNotifier<int> xpNotifier = ValueNotifier<int>(0);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    xpNotifier.value = prefs.getInt('user_xp') ?? 0;
  }

  Future<void> addXP(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final newXp = xpNotifier.value + amount;
    await prefs.setInt('user_xp', newXp);
    xpNotifier.value = newXp;
  }
}
