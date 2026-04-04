import 'package:cardify_ai_english_learning_app/screens/deck_list_screen.dart';
import 'package:flutter/material.dart';
import '../widgets/ai_voice_chat_dialog.dart';
import '../widgets/profile_icon.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import 'achievements_screen.dart';
import 'image_capture_screen.dart';
import 'calendar_screen.dart';
import 'home_screen.dart';
import 'dictionary_screen.dart';
import 'profile_screen.dart';
import 'profile_settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  String _userName = 'Explorer';
  bool _pushReminderEnabled = true;
  bool _autoPlayPronunciation = true;
  bool _aiHintsEnabled = true;
  bool _compactLayoutEnabled = false;

  void _setScreenIndex(int index) {
    if (_currentIndex == index) {
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  void _onNavTap(int index) {
    _setScreenIndex(index);
  }

  void _onCameraTap() {
    _setScreenIndex(-1); // Special index for camera
  }

  Future<void> _onProfileTap() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => ProfileSettingsScreen(
          name: _userName,
          email: 'explorer@cardify.ai',
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }
    final updatedName = result['name']?.toString().trim();
    if (updatedName != null && updatedName.isNotEmpty) {
      setState(() {
        _userName = updatedName;
      });
    }
  }

  void _onProfileMenuAction(_ProfileMenuAction action) {
    switch (action) {
      case _ProfileMenuAction.profile:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ProfileScreen(
              name: 'Explorer',
              email: 'explorer@cardify.ai',
            ),
          ),
        );
        break;
      case _ProfileMenuAction.settings:
        _openQuickSettingsSheet();
        break;
      case _ProfileMenuAction.logout:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bạn đã chọn đăng xuất.')));
        break;
    }
  }

  Future<void> _openQuickSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 4,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cài đặt nhanh',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Cá nhân hóa trải nghiệm học tiếng Anh với AI',
                      style: TextStyle(color: Color(0xFF5C6F8C)),
                    ),
                    const SizedBox(height: 14),
                    _SettingsSection(
                      title: 'Học tập',
                      children: [
                        _SettingsSwitchTile(
                          icon: Icons.auto_awesome_rounded,
                          label: 'Gợi ý AI theo ngữ cảnh',
                          value: _aiHintsEnabled,
                          onChanged: (value) {
                            setSheetState(() => _aiHintsEnabled = value);
                            setState(() => _aiHintsEnabled = value);
                          },
                        ),
                        _SettingsSwitchTile(
                          icon: Icons.record_voice_over_rounded,
                          label: 'Tự động phát phát âm',
                          value: _autoPlayPronunciation,
                          onChanged: (value) {
                            setSheetState(() => _autoPlayPronunciation = value);
                            setState(() => _autoPlayPronunciation = value);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _SettingsSection(
                      title: 'Ứng dụng',
                      children: [
                        _SettingsSwitchTile(
                          icon: Icons.notifications_active_rounded,
                          label: 'Nhắc lịch học hằng ngày',
                          value: _pushReminderEnabled,
                          onChanged: (value) {
                            setSheetState(() => _pushReminderEnabled = value);
                            setState(() => _pushReminderEnabled = value);
                          },
                        ),
                        _SettingsSwitchTile(
                          icon: Icons.view_compact_rounded,
                          label: 'Bố cục cô đọng',
                          value: _compactLayoutEnabled,
                          onChanged: (value) {
                            setSheetState(() => _compactLayoutEnabled = value);
                            setState(() => _compactLayoutEnabled = value);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Lưu cài đặt'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onChatTap() {
    showDialog(
      context: context,
      builder: (context) => const AiVoiceChatDialog(),
    );
  }

  Widget _getBody() {
    switch (_currentIndex) {
      case 0:
        return HomeScreen(
          userName: _userName,
          streak: 12,
          level: 5,
          experience: 800,
          nextLevelExperience: 1000,
          onOpenDecks: () => _onNavTap(3),
          onOpenDictionary: () => _onNavTap(2),
          onOpenCameraQuest: _onCameraTap,
        );
      case 1:
        return const CalendarScreen();
      case 2:
        return const DictionaryScreen();
      case 3:
        return DeckListScreen();
      case 4:
        return const AchievementsScreen();
      case -1:
        return const ImageCaptureScreen();
      default:
        return const Center(child: Text('Trang chủ'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI English Learning'),
        centerTitle: true,
        elevation: 0,
        actions: [ProfileIcon(onTap: _onProfileTap)],
      ),
      body: Stack(
        children: [
          _getBody(),
          Positioned(
            right: 16,
            bottom: 92,
            child: FloatingActionButton(
              heroTag: 'ai_chat_fab',
              mini: true,
              onPressed: _onChatTap,
              tooltip: 'Chat với AI',
              child: const Icon(Icons.chat_bubble),
            ),
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 3
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 28.0),
              child: FloatingActionButton(
                onPressed: _onCameraTap,
                child: const Icon(Icons.camera_alt),
                tooltip: 'Chụp ảnh',
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex < 0 ? 0 : _currentIndex,
        onTap: _onNavTap,
        onCameraTap: _onCameraTap,
      ),
    );
  }
}

enum _ProfileMenuAction { profile, settings, logout }

class _AnimatedProfileDrawer extends StatefulWidget {
  final String userName;
  final String userEmail;
  final void Function(_ProfileMenuAction) onAction;

  const _AnimatedProfileDrawer({
    required this.userName,
    required this.userEmail,
    required this.onAction,
  });

  @override
  State<_AnimatedProfileDrawer> createState() => _AnimatedProfileDrawerState();
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        value: value,
        onChanged: onChanged,
        secondary: Icon(icon, color: const Color(0xFF1E3A8A)),
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF243B5A),
          ),
        ),
      ),
    );
  }
}

class _AnimatedProfileDrawerState extends State<_AnimatedProfileDrawer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<double>(
      begin: 300.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withOpacity(0.1)
              : Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.redAccent : const Color(0xFF1E3A8A),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.redAccent : const Color(0xFF1E3A8A),
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black26),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withOpacity(0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 24),
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFF1E3A8A).withOpacity(0.1),
                    child: Text(
                      widget.userName.isNotEmpty
                          ? widget.userName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.userName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.userEmail,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        _buildMenuItem(
                          icon: Icons.person_rounded,
                          title: 'Hồ sơ',
                          onTap: () {
                            Navigator.pop(context);
                            widget.onAction(_ProfileMenuAction.profile);
                          },
                        ),
                        Divider(height: 1, indent: 64, color: Colors.grey[200]),
                        _buildMenuItem(
                          icon: Icons.settings_rounded,
                          title: 'Cài đặt',
                          onTap: () {
                            Navigator.pop(context);
                            widget.onAction(_ProfileMenuAction.settings);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red[100]!),
                    ),
                    child: _buildMenuItem(
                      icon: Icons.logout_rounded,
                      title: 'Đăng xuất',
                      isDestructive: true,
                      onTap: () {
                        Navigator.pop(context);
                        widget.onAction(_ProfileMenuAction.logout);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
