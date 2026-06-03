import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _kPrimaryBlue = Color(0xFF0D5BD7);
const _kBorderColor = Color(0xFFE5E7EB);
const _kHintColor = Color(0xFF9CA3AF);
const _kTextColor = Color(0xFF111827);
const _kBackground = Color(0xFFF8FAFC);
const _kError = Color(0xFFDC2626);

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  // ── Step tracking ─────────────────────────────────────────────
  // step 0 = enter email
  // step 1 = enter OTP
  // step 2 = enter new password
  int _step = 0;

  // ── Controllers ───────────────────────────────────────────────
  final _emailCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  // 6 separate controllers for each OTP digit box
  final List<TextEditingController> _otpCtrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String _email = '';

  // ── Animation ─────────────────────────────────────────────────
  late final AnimationController _animCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward();

  late Animation<double> _fadeAnim = CurvedAnimation(
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

  // ── Animate step transitions ───────────────────────────────────
  void _goToStep(int next) {
    _animCtrl.reverse().then((_) {
      setState(() => _step = next);
      _animCtrl.forward();
    });
  }

  // ── Step 0: Send OTP ──────────────────────────────────────────
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
      _snack('A 6-digit code has been sent to $email');
      _goToStep(1);
    } on AuthException catch (e) {
      _snack(e.message, isError: true);
    } catch (_) {
      // Always show generic success for security — don't leak if email exists
      _email = email;
      if (!mounted) return;
      _snack('If that email is registered, a code has been sent.');
      _goToStep(1);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Step 1: Verify OTP ────────────────────────────────────────
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

  // ── Step 2: Update Password ───────────────────────────────────
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
      _snack('Password updated successfully!');

      // Sign out after reset for security — forces fresh login
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

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _kError : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      appBar: AppBar(
        backgroundColor: _kBackground,
        elevation: 0,
        leading: BackButton(
          color: _kTextColor,
          onPressed: () {
            if (_step == 0) {
              Navigator.of(context).pop();
            } else {
              _goToStep(_step - 1);
            }
          },
        ),
        title: Text(
          _stepTitle(),
          style: const TextStyle(
            color: _kTextColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _buildCurrentStep(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _stepTitle() {
    switch (_step) {
      case 0:
        return 'Forgot Password';
      case 1:
        return 'Enter OTP Code';
      case 2:
        return 'Set New Password';
      default:
        return '';
    }
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

  // ─────────────────────────────────────────────────────────────
  // STEP 0 — Enter Email
  // ─────────────────────────────────────────────────────────────
  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reset your password',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: _kTextColor,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your registered email address and we\'ll send you a 6-digit verification code.',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
        ),
        const SizedBox(height: 32),

        // Email field
        _buildTextField(
          controller: _emailCtrl,
          hint: 'Email address',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),

        const SizedBox(height: 32),

        _buildPrimaryButton(
          label: 'SEND CODE',
          isLoading: _isLoading,
          onPressed: _sendOtp,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STEP 1 — Enter OTP
  // ─────────────────────────────────────────────────────────────
  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Check your email',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: _kTextColor,
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'We sent a 6-digit code to '),
              TextSpan(
                text: _email,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _kTextColor,
                ),
              ),
              const TextSpan(text: '. Enter it below.'),
            ],
          ),
        ),
        const SizedBox(height: 36),

        // OTP boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) => _buildOtpBox(i)),
        ),

        const SizedBox(height: 12),

        // Resend
        Center(
          child: TextButton(
            onPressed: _isLoading ? null : _sendOtp,
            child: const Text(
              'Didn\'t receive a code? Resend',
              style: TextStyle(
                color: _kPrimaryBlue,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

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
      width: 48,
      height: 58,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _otpFocus[index].hasFocus ? _kPrimaryBlue : _kBorderColor,
            width: _otpFocus[index].hasFocus ? 2 : 1.2,
          ),
          boxShadow: _otpFocus[index].hasFocus
              ? [
                  BoxShadow(
                    color: _kPrimaryBlue.withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
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
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _kTextColor,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            counterText: '',
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (val) {
            if (val.isNotEmpty && index < 5) {
              // Move to next box
              FocusScope.of(context).requestFocus(_otpFocus[index + 1]);
            } else if (val.isEmpty && index > 0) {
              // Move back on delete
              FocusScope.of(context).requestFocus(_otpFocus[index - 1]);
            }
            // Auto-submit when all 6 digits filled
            if (_otpCtrl.every((c) => c.text.isNotEmpty)) {
              _verifyOtp();
            }
            setState(() {}); // rebuild to update border focus color
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STEP 2 — New Password
  // ─────────────────────────────────────────────────────────────
  Widget _buildNewPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Create a new password',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: _kTextColor,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your new password must be at least 8 characters.',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
        ),
        const SizedBox(height: 32),

        // New password
        _buildPasswordField(
          controller: _newPassCtrl,
          hint: 'New Password',
          obscure: _obscureNew,
          onToggle: () => setState(() => _obscureNew = !_obscureNew),
        ),

        const SizedBox(height: 16),

        // Confirm password
        _buildPasswordField(
          controller: _confirmPassCtrl,
          hint: 'Confirm New Password',
          obscure: _obscureConfirm,
          onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
        ),

        const SizedBox(height: 32),

        _buildPrimaryButton(
          label: 'UPDATE PASSWORD',
          isLoading: _isLoading,
          onPressed: _updatePassword,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Shared widgets
  // ─────────────────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: _kBorderColor, width: 1.2),
        color: Colors.white,
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 15,
          color: _kTextColor,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          hintText: hint,
          hintStyle: const TextStyle(color: _kHintColor),
          prefixIcon: Icon(icon, color: _kHintColor),
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: _kBorderColor, width: 1.2),
        color: Colors.white,
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(
          fontSize: 15,
          color: _kTextColor,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          hintText: hint,
          hintStyle: const TextStyle(color: _kHintColor),
          prefixIcon:
              const Icon(Icons.lock_outline_rounded, color: _kHintColor),
          suffixIcon: GestureDetector(
            onTap: onToggle,
            child: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: _kHintColor,
            ),
          ),
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
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kPrimaryBlue,
          disabledBackgroundColor: _kPrimaryBlue.withOpacity(0.45),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
