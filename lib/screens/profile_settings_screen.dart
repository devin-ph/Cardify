import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  final ImagePicker _imagePicker = ImagePicker();
  late String _name;
  late String _email;
  Uint8List? _avatarBytes;
  bool _aiHintsEnabled = true;
  bool _autoPlayPronunciation = true;
  bool _dailyReminderEnabled = true;
  bool _compactLayoutEnabled = false;

  @override
  void initState() {
    super.initState();
    _name = widget.name;
    _email = widget.email;
  }

  void _showSavedMessage() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Da luu cai dat thanh cong.')));
    Navigator.of(context).pop(<String, dynamic>{'name': _name});
  }

  Future<void> _openEditNameDialog() async {
    final controller = TextEditingController(text: _name);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Doi ten hien thi'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 30,
            decoration: const InputDecoration(
              hintText: 'Nhap ten moi',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Huy'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, controller.text.trim());
              },
              child: const Text('Cap nhat'),
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
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Khong the tai anh. Vui long thu lai.')),
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
                    'Cap nhat anh dai dien',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Chon tu thu vien'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _pickAvatar(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Chup bang camera'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ho so & Cai dat'), elevation: 0),
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
                                _name.isNotEmpty ? _name[0].toUpperCase() : '?',
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
                    label: const Text('Sua'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SettingsBlock(
              title: 'Hoc tap voi AI',
              children: [
                SwitchListTile(
                  value: _aiHintsEnabled,
                  onChanged: (value) {
                    setState(() => _aiHintsEnabled = value);
                  },
                  title: const Text('Goi y AI theo ngu canh'),
                  subtitle: const Text(
                    'Hien goi y tu vung va cach dung phu hop',
                  ),
                  secondary: const Icon(Icons.auto_awesome_rounded),
                ),
                SwitchListTile(
                  value: _autoPlayPronunciation,
                  onChanged: (value) {
                    setState(() => _autoPlayPronunciation = value);
                  },
                  title: const Text('Tu dong phat phat am'),
                  subtitle: const Text('Tu dong doc tu khi mo the hoc'),
                  secondary: const Icon(Icons.record_voice_over_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SettingsBlock(
              title: 'Ung dung',
              children: [
                SwitchListTile(
                  value: _dailyReminderEnabled,
                  onChanged: (value) {
                    setState(() => _dailyReminderEnabled = value);
                  },
                  title: const Text('Nhac lich hoc hang ngay'),
                  subtitle: const Text(
                    'Thong bao theo gio hoc ban thuong dung',
                  ),
                  secondary: const Icon(Icons.notifications_active_rounded),
                ),
                SwitchListTile(
                  value: _compactLayoutEnabled,
                  onChanged: (value) {
                    setState(() => _compactLayoutEnabled = value);
                  },
                  title: const Text('Bo cuc co dong'),
                  subtitle: const Text('Toi uu man hinh nho va hoc nhanh'),
                  secondary: const Icon(Icons.view_compact_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SettingsBlock(
              title: 'Tai khoan',
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: const Text('Doi mat khau'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mo doi mat khau.')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.red),
                  title: const Text(
                    'Dang xuat',
                    style: TextStyle(color: Colors.red),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ban da chon dang xuat.')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _showSavedMessage,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Luu thay doi'),
            ),
          ],
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
}
