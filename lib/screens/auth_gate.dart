import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';
import 'main_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  String _resolveUserName(User user) {
    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }

    final String email = user.email ?? '';
    if (email.contains('@')) {
      return email.split('@').first;
    }

    return 'Explorer';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final User? user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        return MainScreen(
          userName: _resolveUserName(user),
          userEmail: user.email ?? 'Không có email',
          onLogout: AuthService.signOut,
        );
      },
    );
  }
}
