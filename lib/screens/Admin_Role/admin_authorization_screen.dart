import 'package:flutter/material.dart';
import 'admin_dashboard_screen.dart';

// ── Palette (matches design system) ──────────────────────────────────────────
const _kIndigo = Color(0xFF4F46E5);
const _kCyan = Color(0xFF06B6D4);
const _kIndigoSoft = Color(0xFFEEF2FF);
const _kBg = Color(0xFFF5F7FF);
const _kText = Color(0xFF1E1B4B);
const _kSubText = Color(0xFF6366F1);
const _kWhite = Colors.white;

// ── Screen ────────────────────────────────────────────────────────────────────
class AdminAuthorizationScreen extends StatefulWidget {
  const AdminAuthorizationScreen({super.key});

  @override
  State<AdminAuthorizationScreen> createState() =>
      _AdminAuthorizationScreenState();
}

class _AdminAuthorizationScreenState extends State<AdminAuthorizationScreen>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscure = true;
  String _error = '';

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: Curves.elasticIn,
      ),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Auth logic (unchanged) ────────────────────────────────────────────────
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    await Future.delayed(const Duration(milliseconds: 600));

    if (_passwordController.text == '0000') {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboard()),
      );
    } else {
      _shakeController.forward(from: 0);
      setState(() {
        _isLoading = false;
        _error = 'Incorrect password. Please try again.';
        _passwordController.clear();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Authentication Failed'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _BackButton(),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: child,
                      ),
                      child: Column(
                        children: [
                          _IconBadge(),
                          const SizedBox(height: 24),
                          _HeaderText(),
                          const SizedBox(height: 36),
                          _FormCard(
                            passwordController: _passwordController,
                            obscure: _obscure,
                            error: _error,
                            isLoading: _isLoading,
                            onToggleObscure: () =>
                                setState(() => _obscure = !_obscure),
                            onLogin: _login,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Back button ───────────────────────────────────────────────────────────────
class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
            ),
            color: _kIndigo,
            style: IconButton.styleFrom(
              backgroundColor: _kIndigoSoft,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

// ── Icon badge ────────────────────────────────────────────────────────────────
class _IconBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kIndigo, _kCyan],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _kIndigo.withOpacity(0.30),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.admin_panel_settings_rounded,
        color: _kWhite,
        size: 38,
      ),
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
          'Admin Access',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: _kText,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter your credentials to continue',
          style: TextStyle(
            fontSize: 14,
            color: _kSubText.withOpacity(0.80),
          ),
        ),
      ],
    );
  }
}

// ── Form card ─────────────────────────────────────────────────────────────────
class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.passwordController,
    required this.obscure,
    required this.error,
    required this.isLoading,
    required this.onToggleObscure,
    required this.onLogin,
  });

  final TextEditingController passwordController;
  final bool obscure;
  final String error;
  final bool isLoading;
  final VoidCallback onToggleObscure;
  final VoidCallback onLogin;

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
            color: _kIndigo.withOpacity(0.08),
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
      child: Column(
        children: [
          // Divider label
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'PASSWORD',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kSubText.withOpacity(0.60),
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 20),

          // Password field
          TextField(
            controller: passwordController,
            obscureText: obscure,
            style: const TextStyle(
              fontSize: 15,
              color: _kText,
              letterSpacing: 2,
            ),
            decoration: InputDecoration(
              hintText: 'Enter password',
              hintStyle: TextStyle(
                color: _kSubText.withOpacity(0.50),
                letterSpacing: 0,
                fontSize: 14,
              ),
              filled: true,
              fillColor: _kIndigoSoft,
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
                size: 20,
                color: _kSubText,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: _kSubText,
                ),
                onPressed: onToggleObscure,
              ),
              errorText: error.isNotEmpty ? error : null,
              errorStyle: const TextStyle(fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _kIndigo, width: 1.6),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                  width: 1.4,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                  width: 1.6,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Login button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kIndigo, _kCyan],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _kIndigo.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: isLoading ? null : onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: _kWhite,
                  disabledBackgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: _kWhite,
                        ),
                      )
                    : const Text(
                        'Authenticate',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
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