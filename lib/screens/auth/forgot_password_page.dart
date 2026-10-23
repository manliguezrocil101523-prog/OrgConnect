import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _kGreen = Color(0xFF16A34A);
const _kBg = Color(0xFFF8FAFF);
const _kText = Color(0xFF1E293B);
const _kSubText = Color(0xFF94A3B8);
const _kError = Color(0xFFDC2626);
const _kSuccess = Color(0xFF059669);
const _kLogo = 'assets/icon/login_logo.png';

enum _DeviceType { mobile, tablet, desktop }

_DeviceType _getDeviceType(double width) {
  if (width >= 1024) return _DeviceType.desktop;
  if (width >= 600) return _DeviceType.tablet;
  return _DeviceType.mobile;
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  int _step = 0;

  final _emailCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  final List<TextEditingController> _otpCtrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String _email = '';

  late final AnimationController _animCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward();

  late final Animation<double> _fadeAnim = CurvedAnimation(
    parent: _animCtrl,
    curve: Curves.easeOut,
  );

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    for (final c in _otpCtrl) {
      c.dispose();
    }
    for (final f in _otpFocus) {
      f.dispose();
    }
    super.dispose();
  }

  void _goToStep(int next) {
    _animCtrl.reverse().then((_) {
      setState(() => _step = next);
      _animCtrl.forward();
    });
  }

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _snack('Please enter a valid email address.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
        emailRedirectTo: null,
        data: {'type': 'otp'},
      );

      _email = email;

      if (!mounted) return;
      _snack('A 6-digit code has been sent to $email', ok: true);
      _goToStep(1);
    } on AuthException catch (e) {
      _snack(e.message, isError: true);
    } catch (_) {
      _email = email;
      if (!mounted) return;
      _snack('If that email is registered, a code has been sent.', ok: true);
      _goToStep(1);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpCtrl.map((c) => c.text.trim()).join();

    if (code.length < 6) {
      _snack('Please enter the complete 6-digit code.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await Supabase.instance.client.auth.verifyOTP(
        email: _email,
        token: code,
        type: OtpType.email,
      );

      if (res.session == null) {
        _snack('Invalid or expired code. Please try again.', isError: true);
        return;
      }

      if (!mounted) return;
      _goToStep(2);
    } on AuthException catch (e) {
      _snack(e.message, isError: true);
    } catch (_) {
      _snack('Invalid or expired code. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePassword() async {
    final newPass = _newPassCtrl.text.trim();
    final confirmPass = _confirmPassCtrl.text.trim();

    if (newPass.length < 8) {
      _snack('Password must be at least 8 characters.', isError: true);
      return;
    }

    if (newPass != confirmPass) {
      _snack('Passwords do not match.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPass),
      );

      if (!mounted) return;
      _snack('Password updated successfully!', ok: true);

      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } on AuthException catch (e) {
      _snack(e.message, isError: true);
    } catch (_) {
      _snack('Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, {bool isError = false, bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? _kError : (ok ? _kSuccess : _kText),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final device = _getDeviceType(constraints.maxWidth);
            final isMobile = device == _DeviceType.mobile;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 20 : 24,
                vertical: isMobile ? 16 : 28,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (isMobile ? 32 : 56),
                ),
                child: Center(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isMobile ? double.infinity : 480,
                      ),
                      child: Container(
                        padding: EdgeInsets.all(isMobile ? 16 : 36),
                        decoration: isMobile
                            ? const BoxDecoration(color: Colors.white)
                            : BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: _kGreen.withValues(alpha: 0.08),
                                    blurRadius: 32,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: _kText,
                                ),
                                onPressed: () {
                                  if (_step == 0) {
                                    Navigator.of(context).pop();
                                  } else {
                                    _goToStep(_step - 1);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: Image.asset(
                                _kLogo,
                                height: isMobile ? 60 : 68,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'OrgConnect',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: _kText,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildCurrentStep(),
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
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _buildEmailStep();
      case 1:
        return _buildOtpStep();
      case 2:
        return _buildNewPasswordStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Reset your password',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: _kText,
            letterSpacing: -.4,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Enter your registered email address and we'll send you a 6-digit verification code.",
          style: TextStyle(color: _kSubText, fontSize: 13.5, height: 1.45),
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _emailCtrl,
          hint: 'Email address',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 24),
        _buildPrimaryButton(
          label: 'SEND CODE',
          isLoading: _isLoading,
          onPressed: _sendOtp,
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Check your email',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: _kText,
            letterSpacing: -.4,
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              color: _kSubText,
              fontSize: 13.5,
              height: 1.45,
            ),
            children: [
              const TextSpan(text: 'We sent a 6-digit code to '),
              TextSpan(
                text: _email,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _kText,
                ),
              ),
              const TextSpan(text: '. Enter it below.'),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) => _buildOtpBox(i)),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: _isLoading ? null : _sendOtp,
            child: const Text(
              "Didn't receive a code? Resend",
              style: TextStyle(
                color: _kGreen,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildPrimaryButton(
          label: 'VERIFY CODE',
          isLoading: _isLoading,
          onPressed: _verifyOtp,
        ),
      ],
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 44,
      height: 52,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                _otpFocus[index].hasFocus ? _kGreen : const Color(0xFFD1D5DB),
            width: _otpFocus[index].hasFocus ? 1.8 : 1.2,
          ),
          boxShadow: _otpFocus[index].hasFocus
              ? [
                  BoxShadow(
                    color: _kGreen.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: TextField(
          controller: _otpCtrl[index],
          focusNode: _otpFocus[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _kText,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            counterText: '',
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (val) {
            if (val.isNotEmpty && index < 5) {
              FocusScope.of(context).requestFocus(_otpFocus[index + 1]);
            } else if (val.isEmpty && index > 0) {
              FocusScope.of(context).requestFocus(_otpFocus[index - 1]);
            }
            if (_otpCtrl.every((c) => c.text.isNotEmpty)) {
              _verifyOtp();
            }
            setState(() {});
          },
        ),
      ),
    );
  }

  Widget _buildNewPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Create a new password',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: _kText,
            letterSpacing: -.4,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your new password must be at least 8 characters.',
          style: TextStyle(color: _kSubText, fontSize: 13.5, height: 1.45),
        ),
        const SizedBox(height: 24),
        _buildPasswordField(
          controller: _newPassCtrl,
          hint: 'New Password',
          obscure: _obscureNew,
          onToggle: () => setState(() => _obscureNew = !_obscureNew),
        ),
        const SizedBox(height: 14),
        _buildPasswordField(
          controller: _confirmPassCtrl,
          hint: 'Confirm New Password',
          obscure: _obscureConfirm,
          onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
        ),
        const SizedBox(height: 24),
        _buildPrimaryButton(
          label: 'UPDATE PASSWORD',
          isLoading: _isLoading,
          onPressed: _updatePassword,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontSize: 15,
        color: _kText,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hoverColor: Colors.transparent,
        hintText: hint,
        hintStyle: const TextStyle(color: _kSubText, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 20),
        prefixIcon: Icon(icon, color: _kSubText, size: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: _kGreen, width: 1.8),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(
        fontSize: 15,
        color: _kText,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hoverColor: Colors.transparent,
        hintText: hint,
        hintStyle: const TextStyle(color: _kSubText, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 20),
        prefixIcon: const Icon(Icons.lock_outline, color: _kSubText, size: 20),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: _kGreen,
            size: 20,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: _kGreen, width: 1.8),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kGreen,
          disabledBackgroundColor: _kGreen.withValues(alpha: 0.4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: .8,
                ),
              ),
      ),
    );
  }
}
