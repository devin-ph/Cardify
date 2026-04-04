import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileSettingsScreen extends StatefulWidget {
  final String name;
  final String email;

  const ProfileSettingsScreen({
    super.key,
    required this.name,
    required this.email,
  });

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  static const String _nameKey = 'profile_settings_name';
  static const String _avatarKey = 'profile_settings_avatar_base64';
  static const String _aiHintsKey = 'profile_settings_ai_hints_enabled';
  static const String _autoPlayKey = 'profile_settings_auto_play_enabled';
  static const String _aiChatNarratorKey =
      'profile_settings_ai_chat_narrator_enabled';
  static const String _dailyReminderKey = 'profile_settings_daily_reminder';
  static const String _compactLayoutKey = 'profile_settings_compact_layout';

  final ImagePicker _imagePicker = ImagePicker();
  late String _name;
  late String _email;
  Uint8List? _avatarBytes;
  bool _aiHintsEnabled = true;
  bool _autoPlayPronunciation = true;
  bool _aiChatNarratorEnabled = true;
  bool _dailyReminderEnabled = true;
  bool _compactLayoutEnabled = false;

  @override
  void initState() {
    super.initState();
    _name = widget.name;
    _email = widget.email;
    _loadPersistedSettings();
  }

  Future<void> _loadPersistedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final persistedName = prefs.getString(_nameKey);
    final persistedAvatarBase64 = prefs.getString(_avatarKey);
    final persistedAiHints = prefs.getBool(_aiHintsKey);
    final persistedAutoPlay = prefs.getBool(_autoPlayKey);
    final persistedAiChatNarrator = prefs.getBool(_aiChatNarratorKey);
    final persistedReminder = prefs.getBool(_dailyReminderKey);
    final persistedCompactLayout = prefs.getBool(_compactLayoutKey);

    Uint8List? restoredAvatar;
    if (persistedAvatarBase64 != null && persistedAvatarBase64.isNotEmpty) {
      try {
        restoredAvatar = base64Decode(persistedAvatarBase64);
      } catch (_) {
        restoredAvatar = null;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _name = (persistedName != null && persistedName.trim().isNotEmpty)
          ? persistedName.trim()
          : _name;
      _avatarBytes = restoredAvatar;
      _aiHintsEnabled = persistedAiHints ?? _aiHintsEnabled;
      _autoPlayPronunciation = persistedAutoPlay ?? _autoPlayPronunciation;
      _aiChatNarratorEnabled =
          persistedAiChatNarrator ?? _aiChatNarratorEnabled;
      _dailyReminderEnabled = persistedReminder ?? _dailyReminderEnabled;
      _compactLayoutEnabled = persistedCompactLayout ?? _compactLayoutEnabled;
    });
  }

  Future<void> _persistSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, _name);
    await prefs.setBool(_aiHintsKey, _aiHintsEnabled);
    await prefs.setBool(_autoPlayKey, _autoPlayPronunciation);
    await prefs.setBool(_aiChatNarratorKey, _aiChatNarratorEnabled);
    await prefs.setBool(_dailyReminderKey, _dailyReminderEnabled);
    await prefs.setBool(_compactLayoutKey, _compactLayoutEnabled);

    if (_avatarBytes == null || _avatarBytes!.isEmpty) {
      await prefs.remove(_avatarKey);
    } else {
      await prefs.setString(_avatarKey, base64Encode(_avatarBytes!));
    }
  }

  Future<void> _closeWithResult() async {
    await _persistSettings();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(<String, dynamic>{'name': _name});
  }

  Future<void> _openEditNameDialog() async {
    final controller = TextEditingController(text: _name);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Đổi tên hiển thị'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 30,
            decoration: const InputDecoration(
              hintText: 'Nhập tên mới',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, controller.text.trim());
              },
              child: const Text('Cập nhật'),
            ),
          ],
        );
      },
    );

    if (newName == null || newName.isEmpty) {
      return;
    }
    setState(() {
      _name = newName;
    });
    await _persistSettings();
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1080,
      );
      if (image == null) {
        return;
      }
      final bytes = await image.readAsBytes();
      setState(() {
        _avatarBytes = bytes;
      });
      await _persistSettings();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tải ảnh. Vui lòng thử lại.')),
      );
    }
  }

  Future<void> _openAvatarPickerSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Cập nhật ảnh đại diện',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Chọn từ thư viện'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _pickAvatar(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Chụp bằng camera'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _pickAvatar(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _changePassword() async {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    String? errorText;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Đổi mật khẩu'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    enabled: !isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu mới',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    enabled: !isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'Nhập lại mật khẩu mới',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(errorText!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final newPassword = newPasswordController.text.trim();
                          final confirmPassword = confirmPasswordController.text
                              .trim();

                          if (newPassword.length < 6) {
                            setDialogState(() {
                              errorText = 'Mật khẩu phải có ít nhất 6 ký tự.';
                            });
                            return;
                          }
                          if (newPassword != confirmPassword) {
                            setDialogState(() {
                              errorText = 'Mật khẩu xác nhận không khớp.';
                            });
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            errorText = null;
                          });

                          try {
                            final user =
                                firebase_auth.FirebaseAuth.instance.currentUser;

                            if (user != null) {
                              await user.updatePassword(newPassword);
                            } else {
                              await firebase_auth.FirebaseAuth.instance
                                  .sendPasswordResetEmail(email: _email);
                            }

                            if (!mounted) {
                              return;
                            }
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  user != null
                                      ? 'Đổi mật khẩu thành công.'
                                      : 'Đã gửi email đặt lại mật khẩu.',
                                ),
                              ),
                            );
                          } on firebase_auth.FirebaseAuthException catch (e) {
                            String message = 'Không thể đổi mật khẩu.';
                            if (e.code == 'requires-recent-login') {
                              message =
                                  'Phiên đăng nhập đã cũ. Vui lòng đăng nhập lại rồi thử lại.';
                            } else if (e.code == 'weak-password') {
                              message = 'Mật khẩu mới chưa đủ mạnh.';
                            }
                            setDialogState(() {
                              isSubmitting = false;
                              errorText = message;
                            });
                          } catch (_) {
                            setDialogState(() {
                              isSubmitting = false;
                              errorText = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
                            });
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Xác nhận'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Đăng xuất'),
          content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    try {
      await firebase_auth.FirebaseAuth.instance.signOut();
      await Supabase.instance.client.auth.signOut();

      if (!mounted) {
        return;
      }
      // Return to the root route and let AuthGate react to authStateChanges.
      final rootNavigator = Navigator.of(context, rootNavigator: true);
      rootNavigator.popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đăng xuất thất bại, vui lòng thử lại.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _closeWithResult();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hồ sơ & Cài đặt'),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () async {
              await _closeWithResult();
            },
          ),
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDDEBFF), Color(0xFFEFF7EC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFD5E4F8)),
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: const Color(
                            0xFF1E3A8A,
                          ).withOpacity(0.12),
                          backgroundImage: _avatarBytes != null
                              ? MemoryImage(_avatarBytes!)
                              : null,
                          child: _avatarBytes == null
                              ? Text(
                                  _name.isNotEmpty
                                      ? _name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: _openAvatarPickerSheet,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A8A),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _email,
                            style: const TextStyle(color: Color(0xFF4F617B)),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openEditNameDialog,
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Sửa'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SettingsBlock(
                title: 'Học tập với AI',
                children: [
                  SwitchListTile(
                    value: _aiHintsEnabled,
                    onChanged: (value) {
                      setState(() => _aiHintsEnabled = value);
                      _persistSettings();
                    },
                    title: const Text('Gợi ý AI theo ngữ cảnh'),
                    subtitle: const Text(
                      'Hiện gợi ý từ vựng và cách dùng phù hợp',
                    ),
                    secondary: const Icon(Icons.auto_awesome_rounded),
                  ),
                  SwitchListTile(
                    value: _autoPlayPronunciation,
                    onChanged: (value) {
                      setState(() => _autoPlayPronunciation = value);
                      _persistSettings();
                    },
                    title: const Text('Tự động phát phát âm'),
                    subtitle: const Text('Tự động đọc từ khi mở thẻ học'),
                    secondary: const Icon(Icons.record_voice_over_rounded),
                  ),
                  SwitchListTile(
                    value: _aiChatNarratorEnabled,
                    onChanged: (value) {
                      setState(() => _aiChatNarratorEnabled = value);
                      _persistSettings();
                    },
                    title: const Text('Narrator cho chat AI'),
                    subtitle: const Text(
                      'Bật/tắt giọng đọc phản hồi trong chat AI',
                    ),
                    secondary: const Icon(Icons.mic_external_on_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _SettingsBlock(
                title: 'Ứng dụng',
                children: [
                  SwitchListTile(
                    value: _dailyReminderEnabled,
                    onChanged: (value) {
                      setState(() => _dailyReminderEnabled = value);
                      _persistSettings();
                    },
                    title: const Text('Nhắc lịch học hằng ngày'),
                    subtitle: const Text(
                      'Thông báo theo giờ học bạn thường dùng',
                    ),
                    secondary: const Icon(Icons.notifications_active_rounded),
                  ),
                  SwitchListTile(
                    value: _compactLayoutEnabled,
                    onChanged: (value) {
                      setState(() => _compactLayoutEnabled = value);
                      _persistSettings();
                    },
                    title: const Text('Bố cục cô đọng'),
                    subtitle: const Text('Tối ưu màn hình nhỏ và học nhanh'),
                    secondary: const Icon(Icons.view_compact_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _SettingsBlock(
                title: 'Tài khoản',
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_outline_rounded),
                    title: const Text('Đổi mật khẩu'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _changePassword,
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Đăng xuất',
                      style: TextStyle(color: Colors.red),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _logout,
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

class _SettingsBlock extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsBlock({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E3A8A),
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
} // ALMOST DONE
