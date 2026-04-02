import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

String _authErrorMessage(FirebaseAuthException error) {
  switch (error.code) {
    case 'channel-error':
      return 'Firebase Auth chưa kết nối đúng với app. Hãy tắt app đang chạy và chạy lại (không dùng hot reload).';
    case 'internal-error':
      if ((error.message ?? '').contains('FirebaseAuthHostApi')) {
        return 'Firebase Auth chưa nạp plugin native. Hãy chạy lại app từ đầu sau khi flutter clean và flutter pub get.';
      }
      return 'Lỗi hệ thống tạm thời, vui lòng thử lại.';
    case 'invalid-email':
      return 'Email không hợp lệ.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Email hoặc mật khẩu chưa đúng.';
    case 'email-already-in-use':
      return 'Email này đã được sử dụng.';
    case 'weak-password':
      return 'Mật khẩu quá yếu, hãy dùng ít nhất 6 ký tự.';
    case 'too-many-requests':
      return 'Bạn thao tác quá nhiều lần, hãy thử lại sau ít phút.';
    case 'network-request-failed':
      return 'Không có kết nối mạng. Vui lòng thử lại.';
    default:
      return error.message ?? 'Đã có lỗi xác thực, vui lòng thử lại.';
  }
}

class CardifyLoginScreen extends StatefulWidget {
  const CardifyLoginScreen({super.key});

  @override
  State<CardifyLoginScreen> createState() => _CardifyLoginScreenState();
}

class _CardifyLoginScreenState extends State<CardifyLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  Future<void> _login() async {
    if (_isSubmitting) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Vui lòng nhập đầy đủ email và mật khẩu.', isError: true);
      return;
    }

    if (!email.contains('@')) {
      _showMessage('Vui lòng nhập email hợp lệ.', isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      _showMessage(_authErrorMessage(error), isError: true);
    } catch (_) {
      _showMessage('Không thể đăng nhập, vui lòng thử lại.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showMessage(
        'Nhập email hợp lệ trước khi đặt lại mật khẩu.',
        isError: true,
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showMessage('Đã gửi email đặt lại mật khẩu.');
    } on FirebaseAuthException catch (error) {
      _showMessage(_authErrorMessage(error), isError: true);
    } catch (_) {
      _showMessage(
        'Không thể gửi email đặt lại mật khẩu lúc này.',
        isError: true,
      );
    }
  }

  void _openRegister() {
    if (_isSubmitting) {
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CardifyRegisterScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _CardifyPalette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            children: [
              _CardifyTopBar(
                title: 'Cardify',
                trailing: const SizedBox(width: 44),
                showBackButton: false,
              ),
              const SizedBox(height: 12),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
                    decoration: BoxDecoration(
                      color: _CardifyPalette.card,
                      borderRadius: BorderRadius.circular(38),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              height: 1.15,
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              color: _CardifyPalette.text,
                            ),
                            children: [
                              TextSpan(text: 'Welcome back,\n'),
                              TextSpan(
                                text: 'Hero!',
                                style: TextStyle(
                                  color: _CardifyPalette.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          "Ready for today's language mission?",
                          style: TextStyle(
                            color: _CardifyPalette.secondaryText,
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _CardifyFieldLabel(text: 'EMAIL'),
                        const SizedBox(height: 10),
                        _CardifyInput(
                          controller: _emailController,
                          hintText: 'you@email.com',
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 18),
                        _CardifyFieldLabel(text: 'PASSWORD'),
                        const SizedBox(height: 10),
                        _CardifyInput(
                          controller: _passwordController,
                          hintText: '••••••••',
                          icon: Icons.key,
                          obscureText: true,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isSubmitting ? null : _resetPassword,
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                color: _CardifyPalette.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _PrimaryActionButton(
                          label: _isSubmitting
                              ? 'Signing in...'
                              : 'Jump In!  🚀',
                          onTap: _isSubmitting ? () {} : _login,
                        ),
                        const SizedBox(height: 22),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD7E7E9),
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'New to Cardify?',
                                style: TextStyle(
                                  color: _CardifyPalette.secondaryText,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _SecondaryActionButton(
                                label: 'Create an account  →',
                                onTap: _openRegister,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.public, color: Color(0x7A7D9396)),
                  SizedBox(width: 28),
                  Icon(Icons.sports_esports, color: Color(0x7A7D9396)),
                  SizedBox(width: 28),
                  Icon(Icons.auto_awesome, color: Color(0x7A7D9396)),
                  SizedBox(width: 28),
                  Icon(Icons.school, color: Color(0x7A7D9396)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CardifyRegisterScreen extends StatefulWidget {
  const CardifyRegisterScreen({super.key});

  @override
  State<CardifyRegisterScreen> createState() => _CardifyRegisterScreenState();
}

class _CardifyRegisterScreenState extends State<CardifyRegisterScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _openLogin() {
    Navigator.of(context).pop();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  Future<void> _register() async {
    if (_isSubmitting) {
      return;
    }

    final nickname = _nicknameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (nickname.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage('Vui lòng nhập đầy đủ thông tin đăng ký.', isError: true);
      return;
    }

    if (!email.contains('@')) {
      _showMessage('Vui lòng nhập email hợp lệ.', isError: true);
      return;
    }

    if (password.length < 6) {
      _showMessage('Mật khẩu cần có ít nhất 6 ký tự.', isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      await credential.user?.updateDisplayName(nickname);
      _showMessage('Tạo tài khoản thành công.');
    } on FirebaseAuthException catch (error) {
      _showMessage(_authErrorMessage(error), isError: true);
    } catch (_) {
      _showMessage(
        'Không thể đăng ký lúc này, vui lòng thử lại.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _CardifyPalette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          child: Column(
            children: [
              _CardifyTopBar(
                title: 'Cardify',
                trailing: const SizedBox(width: 44),
                onBackTap: _openLogin,
              ),
              const SizedBox(height: 18),
              const Text(
                'Start Your\nAdventure!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.08,
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: _CardifyPalette.text,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Join thousands of young explorers today.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _CardifyPalette.secondaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 26),
                decoration: BoxDecoration(
                  color: _CardifyPalette.card,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x16000000),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const _CardifyFieldLabel(text: 'NICKNAME'),
                    const SizedBox(height: 10),
                    _CardifyInput(
                      controller: _nicknameController,
                      hintText: 'What should we call you?',
                      icon: Icons.emoji_emotions_outlined,
                    ),
                    const SizedBox(height: 16),
                    const _CardifyFieldLabel(text: "PARENT'S EMAIL"),
                    const SizedBox(height: 10),
                    _CardifyInput(
                      controller: _emailController,
                      hintText: 'mom-or-dad@email.com',
                      icon: Icons.alternate_email_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    const _CardifyFieldLabel(text: 'PASSWORD'),
                    const SizedBox(height: 10),
                    _CardifyInput(
                      controller: _passwordController,
                      hintText: 'Create a secret code',
                      icon: Icons.lock_outline_rounded,
                      obscureText: true,
                    ),
                    const SizedBox(height: 18),
                    _PrimaryActionButton(
                      label: _isSubmitting
                          ? 'Creating account...'
                          : "Let's Go!  🚀",
                      onTap: _isSubmitting ? () {} : _register,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  const Text(
                    'Already have an account?',
                    style: TextStyle(
                      color: _CardifyPalette.secondaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: _openLogin,
                    child: const Text(
                      'Log in',
                      style: TextStyle(
                        color: _CardifyPalette.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Text(
                '© ${DateTime.now().year} CARDIFY INTERACTIVE',
                style: const TextStyle(
                  color: Color(0xA27D9396),
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardifyTopBar extends StatelessWidget {
  final String title;
  final Widget trailing;
  final VoidCallback? onBackTap;
  final bool showBackButton;

  const _CardifyTopBar({
    required this.title,
    required this.trailing,
    this.onBackTap,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBackButton)
          IconButton(
            onPressed: onBackTap ?? () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: _CardifyPalette.primary,
            ),
          )
        else
          const SizedBox(width: 48),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _CardifyPalette.primary,
              fontSize: 40,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    );
  }
}

class _CardifyFieldLabel extends StatelessWidget {
  final String text;

  const _CardifyFieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          color: _CardifyPalette.primary,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _CardifyInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final TextInputType keyboardType;

  const _CardifyInput({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: _CardifyPalette.text,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: _CardifyPalette.primary),
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0xFF99ABAE),
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: _CardifyPalette.input,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF6A2BEA), Color(0xFF8D6CEF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x6E3919B7),
            blurRadius: 8,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SecondaryActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4DCBEB),
          foregroundColor: const Color(0xFF013447),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _CardifyPalette {
  static const Color background = Color(0xFFD7EBEE);
  static const Color card = Color(0xFFDDECEF);
  static const Color input = Color(0xFFB8D3D8);
  static const Color primary = Color(0xFF5A2DE5);
  static const Color text = Color(0xFF112A2E);
  static const Color secondaryText = Color(0xFF4E6568);
}
