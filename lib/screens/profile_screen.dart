import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String name;
  final String email;
  const ProfileScreen({
    super.key,
    this.name = 'Người dùng',
    this.email = 'user@email.com',
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isDarkMode = false;
  late String name;
  late String email;

  @override
  void initState() {
    super.initState();
    name = widget.name;
    email = widget.email;
  }

  void _toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isDarkMode ? 'Đã chuyển sang Dark Mode' : 'Đã chuyển sang Light Mode',
        ),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đăng xuất.')),
      );
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

  Future<void> _editProfile() async {
    final result = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(name: name, email: email),
      ),
    );
    if (result != null) {
      setState(() {
        name = result['name'] ?? name;
        email = result['email'] ?? email;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        backgroundColor: Colors.blue[400],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 44,
              backgroundColor: Colors.blue[200],
              child: const Icon(Icons.person, size: 54, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              email,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _editProfile,
              icon: const Icon(Icons.edit),
              label: const Text('Sửa hồ sơ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[400],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _toggleTheme,
              icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
              label: Text(
                isDarkMode ? 'Chuyển sang Light Mode' : 'Chuyển sang Dark Mode',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode
                    ? Colors.grey[800]
                    : Colors.blue[400],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Đăng xuất'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
