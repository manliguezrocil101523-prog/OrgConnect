import 'package:flutter/material.dart';
import 'package:my_app/screens/Student_Role/student_dashboard_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_state.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
const _kTeal = Color(0xFF4F46E5); // indigo-600
const _kTealLight = Color(0xFF06B6D4); // cyan-500
const _kTealSoft = Color(0xFFEEF2FF); // indigo-50
const _kBg = Color(0xFFF5F7FF); // near-white indigo tint
const _kText = Color(0xFF1E1B4B); // indigo-950
const _kSubText = Color(0xFF6366F1); // indigo-400
const _kWhite = Colors.white;

// ── Sign-In Page ─────────────────────────────────────────────────────────────
class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isFormValid = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _fadeAnim = CurvedAnimation(
      parent: _fadeCtrl,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeCtrl,
      curve: Curves.easeOut,
    ));

    _emailController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
    WidgetsBinding.instance.addPostFrameCallback((_) => _validateForm());
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _emailController
      ..removeListener(_validateForm)
      ..dispose();
    _passwordController
      ..removeListener(_validateForm)
      ..dispose();
    super.dispose();
  }

  void _validateForm() {
    final valid = _emailController.text.trim().isNotEmpty &&
        _passwordController.text.trim().isNotEmpty;
    if (valid != _isFormValid) setState(() => _isFormValid = valid);
  }

  Future<void> _signIn() async {
    if (!_isFormValid) return;
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (mounted && res.user == null) {
        _showSnack('Invalid email or password', isError: true);
        return;
      }

      final profileData = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('email', email)
          .single();

      final profile = StudentProfile(
        id: profileData['email'],
        name: profileData['name'] ?? '',
        email: profileData['email'] ?? '',
        studentId: profileData['student_id'] ?? '',
        contact: profileData['contact'] ?? '',
        facebook: profileData['facebook'] ?? '',
        avatarUrl: profileData['avatar_url'] ?? '',
        joinedOrgIds: List<String>.from(profileData['joined_org_ids'] ?? []),
      );

      AppState.instance.setStudentProfile(profile);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const StudentDashboardScreen(),
        ),
      );
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('email not confirmed')) {
        _showEmailConfirmationDialog(email);
      } else {
        _showSnack(e.message, isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showEmailConfirmationDialog(String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Email Not Confirmed'),
        content: Text(
          'Your email ($email) has not been confirmed yet. '
          'Please check your inbox for a verification link.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await Supabase.instance.client.auth.resend(
                  type: OtpType.signup,
                  email: email,
                );
                if (!ctx.mounted) return;
                _showSnack('Confirmation email sent!');
                Navigator.of(ctx).pop();
              } catch (e) {
                _showSnack('Failed to resend: $e', isError: true);
              }
            },
            child: const Text('Resend Email'),
          ),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 32,
                ),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        _LogoBadge(),
                        const SizedBox(height: 32),
                        _HeaderText(),
                        const SizedBox(height: 36),
                        _Card(
                          child: Column(
                            children: [
                              _InputField(
                                controller: _emailController,
                                hint: 'Email address',
                                icon: Icons.mail_outline_rounded,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 16),
                              _PasswordField(
                                controller: _passwordController,
                                obscure: _obscurePassword,
                                onToggle: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                              const SizedBox(height: 28),
                              _SignInButton(
                                enabled: _isFormValid && !_isLoading,
                                loading: _isLoading,
                                onPressed: _signIn,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _SignUpRow(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Logo ──────────────────────────────────────────────────────────────────────
class _LogoBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        color: _kWhite,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _kTeal.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Image.asset('assets/orgconnectLogo.jpg', fit: BoxFit.contain),
    );
  }
}

// ── Header text ───────────────────────────────────────────────────────────────
class _HeaderText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Welcome back',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: _kText,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sign in to continue to OrgConnect',
          style: TextStyle(
            fontSize: 14,
            color: _kSubText,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ── Card container ────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: _kWhite,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _kTeal.withOpacity(0.08),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Input field ───────────────────────────────────────────────────────────────
class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, color: _kText),
      decoration: _buildDecoration(
        hint,
        prefixIcon: Icon(icon, size: 20, color: _kSubText),
      ),
    );
  }
}

// ── Password field ────────────────────────────────────────────────────────────
class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.onToggle,
  });

  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(fontSize: 15, color: _kText),
      decoration: _buildDecoration(
        'Password',
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          size: 20,
          color: _kSubText,
        ),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 20,
            color: _kSubText,
          ),
        ),
      ),
    );
  }
}

// ── Shared decoration factory ─────────────────────────────────────────────────
InputDecoration _buildDecoration(
  String hint, {
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  const radius = Radius.circular(16);
  const borderRadius = BorderRadius.all(radius);

  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _kSubText, fontSize: 14),
    filled: true,
    fillColor: _kTealSoft,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 16,
    ),
    border: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: const BorderSide(color: _kTeal, width: 1.6),
    ),
  );
}

// ── Sign-in button ────────────────────────────────────────────────────────────
class _SignInButton extends StatelessWidget {
  const _SignInButton({
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: enabled
              ? const LinearGradient(
                  colors: [_kTeal, _kTealLight],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: enabled ? null : const Color(0xFFD0DEDE),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: _kTeal.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: _kWhite,
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: _kWhite,
                  ),
                )
              : const Text(
                  'Sign In',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Sign-up row ───────────────────────────────────────────────────────────────
class _SignUpRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Don't have an account? ",
          style: TextStyle(color: _kSubText, fontSize: 14),
        ),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/signup'),
          child: const Text(
            'Sign up',
            style: TextStyle(
              color: _kTeal,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
