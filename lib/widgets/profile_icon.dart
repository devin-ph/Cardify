import 'package:flutter/material.dart';

class ProfileIcon extends StatelessWidget {
  final VoidCallback onTap;
  const ProfileIcon({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings_rounded, size: 30, color: Colors.blue),
      onPressed: onTap,
      tooltip: 'Cài đặt',
    );
  }
}
