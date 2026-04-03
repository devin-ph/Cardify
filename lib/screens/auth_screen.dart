import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

String _authErrorMessage(FirebaseAuthException error) {
  switch (error.code) {
    case 'channel-error':
      return 'Firebase Auth chưa kết nối với app. Hay tắt app đang chạy và chạy lại.';
    case 'internal-error':
      if ((error.message ?? '').contains('FirebaseAuthHostApi')) {
        return 'Firebase Auth chưa tải plugin native. Hay chạy lại app từ đầu sau khi flutter clean và flutter pub get.';
      }
      return ' lỗi hệ thống tạm thời, vui lòng thử lại.';
    case 'invalid-email':
      return 'Email không hợp lệ.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Email hoặc mật khẩu chưa đúng.';
    case 'email-already-in-use':
      return 'Email này đã được sử dụng.';
    case 'weak-password':
      return 'Mật khẩu quá yếu, hay dùng ít nhất 6 ký tự.';
    case 'too-many-requests':
      return 'Bạn thao tác quá nhiều lần, hay thử lại sau ít phút.';
    case 'network-request-failed':
      return 'Không có kết nối mạng. Vui lòng thử lại.';
    default:
      return error.message ?? 'Đã có lỗi xác thực, vui lòng thử lại.';
  }
}

Future<void> _googleSignIn() async {
  if (kIsWeb) {
    await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
    return;
  }

  final googleUser = await GoogleSignIn(scopes: <String>['email']).signIn();
  if (googleUser == null) {
    return;
  }

  final googleAuth = await googleUser.authentication;
  final credential = GoogleAuthProvider.credential(
    accessToken: googleAuth.accessToken,
    idToken: googleAuth.idToken,
  );

  await FirebaseAuth.instance.signInWithCredential(credential);
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
  bool _hidePassword = true;

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
      _showMessage('Vui lòng nhập email và mật khẩu.', isError: true);
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
      _showMessage(
        'Không thể đăng nhập lúc này, vui lòng thử lại.',
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

  Future<void> _signInWithGoogle() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _googleSignIn();
    } on FirebaseAuthException catch (error) {
      _showMessage(_authErrorMessage(error), isError: true);
    } catch (_) {
      _showMessage(
        'Đăng nhập Google thất bại, vui lòng thử lại.',
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

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage(
        'Vui lòng nhập email trước khi đặt lại mật khẩu.',
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
        'Không thể gửi email đặt lại mật khẩu, vui lòng thử lại',
        isError: true,
      );
    }
  }

  void _openRegister() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CardifyRegisterScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),
              const _JourneyHeader(),
              const SizedBox(height: 18),
              _AuthCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Đăng nhập để tiếp tục chuỗi học của bạn.',
                      style: _AuthStyles.subtitle,
                    ),
                    const SizedBox(height: 26),
                    const _LabelRow(label: 'Địa chỉ email'),
                    const SizedBox(height: 20),
                    _AuthInput(
                      controller: _emailController,
                      hint: 'scholar@cardify.edu',
                      icon: Icons.alternate_email_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 33),
                    _LabelRow(
                      label: 'Mật khẩu',
                      actionText: 'Quên mật khẩu',

                      onActionTap: _resetPassword,
                    ),
                    const SizedBox(height: 10),
                    _AuthInput(
                      controller: _passwordController,
                      hint: '••••••••••',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _hidePassword,
                      suffix: IconButton(
                        onPressed: () =>
                            setState(() => _hidePassword = !_hidePassword),
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: _AuthColors.inputHint,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _PrimaryButton(
                      label: _isSubmitting ? 'Đăng nhập...' : 'Đăng nhập',
                      onTap: _isSubmitting ? null : _login,
                    ),
                    const SizedBox(height: 24),
                    const _OrDivider(text: 'HOẶC ĐĂNG NHẬP VỚI'),
                    const SizedBox(height: 24),
                    _SocialButton(
                      onTap: _isSubmitting ? null : _signInWithGoogle,
                    ),
                    const SizedBox(height: 24),

                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Chưa có tài khoản? ',
                            style: _AuthStyles.bottomText,
                          ),
                          GestureDetector(
                            onTap: _openRegister,
                            child: const Text(
                              'Đăng ký',
                              style: _AuthStyles.bottomAction,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
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

  Future<void> _register() async {
    if (_isSubmitting) {
      return;
    }

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage('Vui lòng nhập đầy đủ thông tin đăng ký.', isError: true);
      return;
    }

    if (password.length < 6) {
      _showMessage('Mật khẩu phải có ít nhất 6 ký tự.', isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      await credential.user?.updateDisplayName(username);
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

  Future<void> _registerWithGoogle() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _googleSignIn();
    } on FirebaseAuthException catch (error) {
      _showMessage(_authErrorMessage(error), isError: true);
    } catch (_) {
      _showMessage(
        'Đăng ký bằng Google thất bại, vui lòng thử lại.',
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
    return _AuthScaffold(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const _JourneyHeader(),
              const SizedBox(height: 18),
              _AuthCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _LabelRow(label: 'Tên người dùng'),
                    const SizedBox(height: 10),
                    _AuthInput(
                      controller: _usernameController,
                      hint: 'fluent_speaker',
                      icon: Icons.person_rounded,
                    ),
                    const SizedBox(height: 16),
                    const _LabelRow(label: 'Địa chỉ email'),
                    const SizedBox(height: 10),
                    _AuthInput(
                      controller: _emailController,
                      hint: 'hello@example.com',
                      icon: Icons.email_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    const _LabelRow(label: 'Mật khẩu'),
                    const SizedBox(height: 10),
                    _AuthInput(
                      controller: _passwordController,
                      hint: '••••••••',
                      icon: Icons.lock_rounded,
                      obscureText: _hidePassword,
                      suffix: IconButton(
                        onPressed: () =>
                            setState(() => _hidePassword = !_hidePassword),
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: _AuthColors.inputHint,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    _PrimaryButton(
                      label: _isSubmitting
                          ? 'Đang tạo tài khoản...'
                          : 'Tạo tài khoản',
                      onTap: _isSubmitting ? null : _register,
                    ),
                    SizedBox(height: 24),
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Đã có tài khoản? ',
                            style: _AuthStyles.bottomText,
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: const Text(
                              'Đăng nhập',
                              style: _AuthStyles.bottomAction,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  final Widget child;

  const _AuthScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFDDEAF3), Color(0xFFF2ECEF), Color(0xFFDDF0E8)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  22,
                  14,
                  22,
                  20 + media.viewPadding.bottom + media.viewInsets.bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: child,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _JourneyHeader extends StatelessWidget {
  const _JourneyHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('BẮT ĐẦU HÀNH TRÌNH', style: _AuthStyles.kicker),
        SizedBox(height: 8),
        Text('Chào mừng đến\nCardify', style: _AuthStyles.registerTitle),

        SizedBox(height: 10),
        Text(
          'Học ngôn ngữ theo cách của riêng bạn',
          style: _AuthStyles.subtitle,
        ),
      ],
    );
  }
}

class _BrandBlock extends StatelessWidget {
  final String tagline;

  const _BrandBlock({required this.tagline});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF6A38F5), Color(0xFF9A84F4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x4D6A38F5),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(height: 10),
        const Text('Cardify', style: _AuthStyles.logo),
        const SizedBox(height: 4),
        Text(tagline, style: _AuthStyles.tagline),
      ],
    );
  }
}

class _AuthCard extends StatelessWidget {
  final Widget child;

  const _AuthCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
      decoration: BoxDecoration(
        color: _AuthColors.card,
        borderRadius: BorderRadius.circular(38),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LabelRow extends StatelessWidget {
  final String label;
  final String? actionText;
  final VoidCallback? onActionTap;

  const _LabelRow({required this.label, this.actionText, this.onActionTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: _AuthStyles.label),
        const Spacer(),
        if (actionText != null)
          GestureDetector(
            onTap: onActionTap,
            child: Text(actionText!, style: _AuthStyles.forgot),
          ),
      ],
    );
  }
}

class _AuthInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? suffix;

  const _AuthInput({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: _AuthStyles.input,
      decoration: InputDecoration(
        filled: true,
        fillColor: _AuthColors.input,
        prefixIcon: Icon(icon, color: _AuthColors.inputHint),
        suffixIcon: suffix,
        hintText: hint,
        hintStyle: _AuthStyles.inputHint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.6 : 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : (MediaQuery.sizeOf(context).width - 44);
          final buttonWidth = (availableWidth * 0.50).clamp(160.0, 250.0);

          return Center(
            child: SizedBox(
              width: buttonWidth,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6A38F5), Color(0xFF9A84F4)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x336A38F5),
                      blurRadius: 22,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(32),
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              style: _AuthStyles.primaryButton,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _SocialButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (MediaQuery.sizeOf(context).width - 44);
        final buttonWidth = (availableWidth * 0.28).clamp(110.0, 180.0);

        return Center(
          child: SizedBox(
            width: buttonWidth,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD9D9DF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                backgroundColor: Colors.white.withOpacity(0.42),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.g_mobiledata_rounded,
                    size: 28,
                    color: Color(0xFF4285F4),
                  ),
                  const SizedBox(width: 4, height: 24),
                  Text('Google', style: _AuthStyles.socialButton),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OrDivider extends StatelessWidget {
  final String text;

  const _OrDivider({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFCDD2D9), height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(text, style: _AuthStyles.dividerText),
        ),
        const Expanded(child: Divider(color: Color(0xFFCDD2D9), height: 1)),
      ],
    );
  }
}

class _AuthColors {
  static const Color card = Color(0xFFF9FAFC);
  static const Color input = Color(0xFFF1F4F8);
  static const Color inputHint = Color(0xFF98A0A9);
}

class _AuthStyles {
  static const TextStyle kicker = TextStyle(
    color: Color(0xFF6D7480),
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.8,
  );

  static const TextStyle registerTitle = TextStyle(
    color: Color(0xFF19212D),
    fontSize: 32,
    height: 1.05,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle h1 = TextStyle(
    color: Color(0xFF19212D),
    fontSize: 25,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle subtitle = TextStyle(
    color: Color(0xFF738091),
    fontSize: 16,
    height: 1.45,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle label = TextStyle(
    color: Color(0xFF6F7784),
    fontSize: 14,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.5,
  );

  static const TextStyle forgot = TextStyle(
    color: Color(0xFF7B52F8),
    fontSize: 13,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle input = TextStyle(
    color: Color(0xFF18202D),
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle inputHint = TextStyle(
    color: Color(0xFF98A0A9),
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle primaryButton = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.4,
  );

  static const TextStyle socialButton = TextStyle(
    color: Color(0xFF1E2430),
    fontSize: 13,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle dividerText = TextStyle(
    color: Color(0xFF98A0A9),
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
  );

  static const TextStyle logo = TextStyle(
    color: Color(0xFF18202D),
    fontSize: 28,
    fontWeight: FontWeight.w900,
  );

  static const TextStyle tagline = TextStyle(
    color: Color(0xFF738091),
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bottomText = TextStyle(
    color: Color(0xFF6F7784),
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bottomAction = TextStyle(
    color: Color(0xFF7B52F8),
    fontSize: 14,
    fontWeight: FontWeight.w800,
  );
}
