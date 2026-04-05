import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'profile_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String name;
  final String email;
  final String socialId;
  final Uint8List? avatarBytes;

  const ProfileScreen({
    super.key,
    this.name = 'Người dùng',
    this.email = 'user@email.com',
    this.socialId = '',
    this.avatarBytes,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String name;
  late String email;
  late String socialId;
  Uint8List? avatarBytes;

  @override
  void initState() {
    super.initState();
    name = widget.name;
    email = widget.email;
    socialId = widget.socialId;
    avatarBytes = widget.avatarBytes;
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => ProfileSettingsScreen(
          name: name,
          email: email,
          userSocialId: socialId,
        ),
      ),
    );

    if (result != null) {
      final updatedName = result['name']?.toString().trim();
      if (updatedName == null || updatedName.isEmpty) {
        return;
      }

      setState(() {
        name = updatedName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        backgroundColor: const Color(0xFFEEF3FF),
        foregroundColor: const Color(0xFF1A2755),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF3F6FF),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFCFE0FF),
                Color(0xFFD7F0E3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFC2D5F8), width: 1.1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: const Color(0xFFC0D1F3),
                    backgroundImage: avatarBytes != null
                        ? MemoryImage(avatarBytes!)
                        : null,
                    child: avatarBytes == null
                        ? Text(
                            name.trim().isNotEmpty
                                ? name.trim()[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF233E8E),
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    right: -4,
                    bottom: -2,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2446A0),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: const Color(0xFFF4F7FF),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 37,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              color: Color(0xFF23408F),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF6E4D83),
                            visualDensity: const VisualDensity(
                              horizontal: -3,
                              vertical: -3,
                            ),
                          ),
                          onPressed: _openSettings,
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text(
                            'Sửa',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF496485),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      socialId.trim().isEmpty
                          ? 'ID: Đang cập nhật...'
                          : 'ID: $socialId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF425774),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
