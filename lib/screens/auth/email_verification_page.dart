import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _kBlue = Color(0xFF2563EB);
const _kBg = Color(0xFFF8FAFF);
const _kText = Color(0xFF1E293B);
const _kSubText = Color(0xFF94A3B8);
const _kBorderColor = Color(0xFFE5E7EB);
const _kError = Color(0xFFDC2626);
const _kSuccess = Color(0xFF059669);

class EmailVerificationPage extends StatefulWidget {
  final String email;

  const EmailVerificationPage({
    super.key,
    required this.email,
  });

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _otpCtrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;

  late final AnimationController _animCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..forward();

  late final Animation<double> _fadeAnim = CurvedAnimation(
    parent: _animCtrl,
    curve: Curves.easeOut,
  );

  late final Animation<Offset> _slideAnim = Tween<Offset>(
    begin: const Offset(0, 0.05),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _animCtrl.dispose();
    for (final c in _otpCtrl) c.dispose();
    for (final f in _otpFocus) f.dispose();
    super.dispose();
  }

  // ── Verify OTP ────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    final code = _otpCtrl.map((c) => c.text.trim()).join();

    if (code.length < 6) {
      _snack('Please enter the complete 6-digit code.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: code,
        type: OtpType.signup, // ← signup type, different from forgot password
      );

      if (res.session == null) {
        _snack('Invalid or expired code. Please try again.', isError: true);
        return;
      }

      if (!mounted) return;

      // Sign out immediately — force them to login fresh with verified account
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;

      _snack('Email verified successfully! Please log in.', isError: false);

      // Go to login and clear entire stack
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } on AuthException catch (e) {
      _snack(e.message, isError: true);
    } catch (_) {
      _snack('Invalid or expired code. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Resend OTP ────────────────────────────────────────────────
  Future<void> _resendCode() async {
    setState(() => _isResending = true);

    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );

      if (!mounted) return;
      _snack('A new code has been sent to ${widget.email}');

      // Clear all boxes
      for (final c in _otpCtrl) c.clear();
      FocusScope.of(context).requestFocus(_otpFocus[0]);
    } on AuthException catch (e) {
      _snack(e.message, isError: true);
    } catch (_) {
      _snack('Could not resend code. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? _kError : _kSuccess,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: BackButton(color: _kText),
        title: const Text(
          'Verify Email',
          style: TextStyle(
            color: _kText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Icon ───────────────────────────────────
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _kBlue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.mark_email_unread_outlined,
                            color: _kBlue,
                            size: 38,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Title ──────────────────────────────────
                      const Text(
                        'Check your email',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: _kText,
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ── Subtitle ───────────────────────────────
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 14,
                            color: _kSubText,
                            height: 1.6,
                          ),
                          children: [
                            const TextSpan(
                                text:
                                    'We sent a 6-digit verification code to '),
                            TextSpan(
                              text: widget.email,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _kText,
                              ),
                            ),
                            const TextSpan(
                                text:
                                    '. Enter it below to verify your account.'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // ── OTP Boxes ──────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (i) => _buildOtpBox(i)),
                      ),

                      const SizedBox(height: 16),

                      // ── Resend ─────────────────────────────────
                      Center(
                        child: TextButton(
                          onPressed:
                              (_isLoading || _isResending) ? null : _resendCode,
                          child: _isResending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _kBlue,
                                  ),
                                )
                              : const Text(
                                  "Didn't receive a code? Resend",
                                  style: TextStyle(
                                    color: _kBlue,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Verify Button ──────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kBlue,
                            disabledBackgroundColor: _kBlue.withOpacity(0.45),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'VERIFY ACCOUNT',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── OTP Box Widget ────────────────────────────────────────────
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
            color: _otpFocus[index].hasFocus ? _kBlue : _kBorderColor,
            width: _otpFocus[index].hasFocus ? 2 : 1.2,
          ),
          boxShadow: _otpFocus[index].hasFocus
              ? [
                  BoxShadow(
                    color: _kBlue.withOpacity(0.12),
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
            // Auto-submit when all 6 digits filled
            if (_otpCtrl.every((c) => c.text.isNotEmpty)) {
              _verifyOtp();
            }
            setState(() {});
          },
        ),
      ),
    );
  }
}
