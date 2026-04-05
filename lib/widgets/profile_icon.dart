import 'package:flutter/material.dart';
import 'dart:typed_data';

class ProfileIcon extends StatelessWidget {
  final VoidCallback onTap;
  final String? displayName;
  final String? photoUrl;
  final Uint8List? avatarBytes;

  const ProfileIcon({
    super.key,
    required this.onTap,
    this.displayName,
    this.photoUrl,
    this.avatarBytes,
  });

  String get _initial {
    final name = displayName?.trim() ?? '';
    if (name.isEmpty) {
      return 'U';
    }
    return name.characters.first.toUpperCase();
  }

  Widget _buildAvatar() {
    if (avatarBytes != null && avatarBytes!.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: const Color(0xFFE9EEFF),
        backgroundImage: MemoryImage(avatarBytes!),
      );
    }

    final normalizedPhotoUrl = photoUrl?.trim() ?? '';
    if (normalizedPhotoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: const Color(0xFFE9EEFF),
        backgroundImage: NetworkImage(normalizedPhotoUrl),
      );
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFF8B5CF6),
      child: Text(
        _initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: _buildAvatar(),
      onPressed: onTap,
      tooltip: 'Hồ sơ',
      splashRadius: 24,
      constraints: const BoxConstraints(minWidth: 46, minHeight: 46),
      padding: const EdgeInsets.all(4),
    );
  }
}
