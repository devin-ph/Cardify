import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class XPService {
  static final XPService instance = XPService._();
  XPService._();

  final ValueNotifier<int> xpNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> levelNotifier = ValueNotifier<int>(1);
  final ValueNotifier<int> streakNotifier = ValueNotifier<int>(0);

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Load local first for fast display
    xpNotifier.value = prefs.getInt('user_xp') ?? 0;
    levelNotifier.value = prefs.getInt('user_level') ?? 1;
    streakNotifier.value = prefs.getInt('user_streak') ?? 0;

    // Then sync from Supabase
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final data = await _supabase
            .from('user_profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (data != null) {
          xpNotifier.value = data['xp'] ?? xpNotifier.value;
          levelNotifier.value = data['level'] ?? levelNotifier.value;
          streakNotifier.value = data['streak'] ?? streakNotifier.value;

          await prefs.setInt('user_xp', xpNotifier.value);
          await prefs.setInt('user_level', levelNotifier.value);
          await prefs.setInt('user_streak', streakNotifier.value);
        } else {
          // If no profile exists, create one with current local data
          await _supabase.from('user_profiles').insert({
            'id': user.id,
            'username': user.userMetadata?['username'] ?? 'Explorer',
            'xp': xpNotifier.value,
            'level': levelNotifier.value,
            'streak': streakNotifier.value,
            'next_level_xp': 1000,
          });
        }
      }
    } catch (e) {
      debugPrint('Sync XP lỗi: $e');
    }
  }

  Future<void> addXP(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final newXp = xpNotifier.value + amount;
    final newLevel = (newXp ~/ 1000) + 1;

    xpNotifier.value = newXp;
    levelNotifier.value = newLevel;

    await prefs.setInt('user_xp', newXp);
    await prefs.setInt('user_level', newLevel);

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase
            .from('user_profiles')
            .update({
              'xp': newXp,
              'level': newLevel,
              'next_level_xp': (newLevel * 1000),
            })
            .eq('id', user.id);
      }
    } catch (e) {
      debugPrint('Cập nhật XP lên Supabase lỗi: $e');
    }
  }
}
