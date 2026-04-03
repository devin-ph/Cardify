import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoginMode = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmailPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLoginMode) {
        await AuthService.signInWithEmailPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await AuthService.signUpWithEmailPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      _showErrorSnackBar(_mapFirebaseError(e));
    } catch (_) {
      _showErrorSnackBar('Đã có lỗi xảy ra. Vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService.signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      _showErrorSnackBar(_mapFirebaseError(e));
    } catch (e) {
      _showErrorSnackBar(_mapGoogleSignInError(e));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email không hợp lệ.';
      case 'user-disabled':
        return 'Tài khoản đã bị vô hiệu hóa.';
      case 'user-not-found':
        return 'Không tìm thấy tài khoản với email này.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Sai email hoặc mật khẩu.';
      case 'email-already-in-use':
        return 'Email đã được sử dụng.';
      case 'weak-password':
        return 'Mật khẩu quá yếu. Tối thiểu 6 ký tự.';
      case 'operation-not-allowed':
        return 'Phương thức đăng nhập chưa được bật trên Firebase.';
      case 'network-request-failed':
        return 'Mất kết nối mạng. Vui lòng thử lại.';
      default:
        return e.message ?? 'Xác thực thất bại. Vui lòng thử lại.';
    }
  }

  String _mapGoogleSignInError(Object error) {
    final String message = error.toString();
    if (message.contains('popup-blocked')) {
      return 'Trình duyệt đã chặn cửa sổ đăng nhập Google. Hãy cho phép popup rồi thử lại.';
    }
    if (message.contains('popup-closed-by-user')) {
      return 'Bạn đã đóng cửa sổ đăng nhập Google trước khi hoàn tất.';
    }
    if (message.contains('unauthorized-domain')) {
      return 'Domain hiện tại chưa được thêm vào Firebase Authentication > Authorized domains.';
    }
    if (message.contains('operation-not-allowed')) {
      return 'Google Sign-In chưa được bật trong Firebase Authentication.';
    }
    return 'Không thể đăng nhập Google: $message';
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8F3FF), Color(0xFFF8FBFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.school_rounded,
                            size: 52,
                            color: Color(0xFF1A73E8),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Cardify',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isLoginMode
                                ? 'Đăng nhập để tiếp tục học tập'
                                : 'Tạo tài khoản mới để bắt đầu',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 18),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment<bool>(
                                value: true,
                                label: Text('Đăng nhập'),
                              ),
                              ButtonSegment<bool>(
                                value: false,
                                label: Text('Đăng ký'),
                              ),
                            ],
                            selected: {_isLoginMode},
                            onSelectionChanged: (selection) {
                              setState(() {
                                _isLoginMode = selection.first;
                              });
                            },
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (value) {
                              final String text = (value ?? '').trim();
                              if (text.isEmpty) {
                                return 'Vui lòng nhập email';
                              }
                              if (!text.contains('@') || !text.contains('.')) {
                                return 'Email không hợp lệ';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Mật khẩu',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            validator: (value) {
                              final String text = value ?? '';
                              if (text.isEmpty) {
                                return 'Vui lòng nhập mật khẩu';
                              }
                              if (!_isLoginMode && text.length < 6) {
                                return 'Mật khẩu tối thiểu 6 ký tự';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _isLoading
                                  ? null
                                  : _submitEmailPassword,
                              child: Text(
                                _isLoginMode ? 'Đăng nhập' : 'Tạo tài khoản',
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text('hoặc'),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _signInWithGoogle,
                              icon: const Icon(
                                Icons.g_mobiledata_rounded,
                                size: 28,
                              ),
                              label: const Text('Đăng nhập bằng Google'),
                            ),
                          ),
                          if (_isLoading) ...[
                            const SizedBox(height: 16),
                            const CircularProgressIndicator(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
