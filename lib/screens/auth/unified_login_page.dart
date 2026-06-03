import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

import '../../core/app_state.dart';
import '../Student_Role/student_dashboard_screen.dart';
import '../Officer_Role/officer_rule_screen.dart';
import '../Admin_Role/admin_dashboard_screen.dart';

const _kPrimaryBlue = Color(0xFF0D5BD7);
const _kBorderColor = Color(0xFFE5E7EB);
const _kHintColor = Color(0xFF9CA3AF);
const _kTextColor = Color(0xFF111827);
const _kBackground = Color(0xFFF8FAFC);
const _kError = Color(0xFFDC2626);

class UnifiedLoginPage extends StatefulWidget {
  const UnifiedLoginPage({super.key});

  @override
  State<UnifiedLoginPage> createState() => _UnifiedLoginPageState();
}

class _UnifiedLoginPageState extends State<UnifiedLoginPage>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _isFormValid = false;
  bool _isLoading = false;
  bool _obscure = true;

  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  late final Animation<double> _fadeAnimation = CurvedAnimation(
    parent: _animationController,
    curve: Curves.easeOut,
  );

  late final Animation<Offset> _slideAnimation = Tween<Offset>(
    begin: const Offset(0, 0.05),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ),
  );

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_validate);
    _passCtrl.addListener(_validate);
  }

  @override
  void dispose() {
    _animationController.dispose();

    _emailCtrl
      ..removeListener(_validate)
      ..dispose();

    _passCtrl
      ..removeListener(_validate)
      ..dispose();

    super.dispose();
  }

  void _validate() {
    final valid =
        _emailCtrl.text.trim().isNotEmpty && _passCtrl.text.trim().isNotEmpty;

    if (valid != _isFormValid) {
      setState(() => _isFormValid = valid);
    }
  }

  Future<void> _signIn() async {
    if (!_isFormValid || _isLoading) return;

    setState(() => _isLoading = true);

    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();

    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (res.user == null) {
        _snack('Invalid email or password.', isError: true);
        return;
      }

      final profileData = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', res.user!.id)
          .single();

      final isActive = profileData['active'] ?? true;

      if (!isActive) {
        await Supabase.instance.client.auth.signOut();

        _snack(
          'Your account has been deactivated. Contact admin.',
          isError: true,
        );

        return;
      }

      final role = profileData['role']?.toString() ?? 'student';

      if (!mounted) return;

      // ================= ADMIN =================
      if (role == 'admin') {
        AppState.instance.setRole(UserRole.admin);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminDashboard(),
          ),
        );
      }

      // ================= OFFICER =================
      else if (role == 'officer') {
        final assignedOrgId = profileData['assigned_org_id']?.toString() ?? '';

        if (assignedOrgId.isEmpty) {
          await Supabase.instance.client.auth.signOut();

          _snack(
            'You have not been assigned to an organization yet.',
            isError: true,
          );

          return;
        }

        final orgs = AppState.instance.organizations;

        final orgIndex = orgs.indexWhere((o) => o.id == assignedOrgId);

        if (orgIndex == -1) {
          await Supabase.instance.client.auth.signOut();

          _snack(
            'Assigned organization not found. Contact admin.',
            isError: true,
          );

          return;
        }

        AppState.instance.setRole(UserRole.officer);
        AppState.instance.setCurrentOfficerOrgId(assignedOrgId);

        await AppState.instance.fetchApplications();
        await AppState.instance.fetchMembers();

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BaseOfficerDashboard(
              orgId: orgs[orgIndex].id,
              orgName: orgs[orgIndex].name,
            ),
          ),
        );
      }

      // ================= STUDENT =================
      else {
        final rawJoined = profileData['joined_org_ids'];

        final joinedOrgIds = switch (rawJoined) {
          null => <String>[],
          String s => List<String>.from(jsonDecode(s) as List),
          List l => List<String>.from(l),
          _ => <String>[],
        };

        final profile = StudentProfile(
          id: profileData['id'],
          name: profileData['name'] ?? '',
          email: profileData['email'] ?? '',
          studentId: profileData['student_id'] ?? '',
          contact: profileData['contact'] ?? '',
          facebook: profileData['facebook'] ?? '',
          avatarUrl: profileData['avatar_url'] ?? '',
          joinedOrgIds: joinedOrgIds,
        );

        AppState.instance.setRole(UserRole.student);

        await AppState.instance.setStudentProfile(profile);
        await AppState.instance.fetchNotifications();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const StudentDashboardScreen(),
          ),
        );
      }
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('email not confirmed')) {
        _showEmailConfirmationDialog(email);
      } else {
        _snack(e.message, isError: true);
      }
    } catch (e) {
      _snack(
        'Something went wrong. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _kError : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  void _showEmailConfirmationDialog(String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
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

                _snack('Confirmation email sent!');
                Navigator.of(ctx).pop();
              } catch (e) {
                _snack(
                  'Failed to resend: $e',
                  isError: true,
                );
              }
            },
            child: const Text('Resend Email'),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    bool isSending = false;

    showDialog(
      context: context,
      barrierDismissible: !isSending,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Text(
                'Reset Password',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your email address and we\'ll send you a link to reset your password.',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Email address',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: isSending
                      ? null
                      : () async {
                          final email = emailCtrl.text.trim();
                          if (email.isEmpty || !email.contains('@')) {
                            _snack('Please enter a valid email.',
                                isError: true);
                            return;
                          }

                          setDialogState(() => isSending = true);

                          try {
                            await Supabase.instance.client.auth
                                .resetPasswordForEmail(
                              email,
                              // No redirectTo needed — Supabase handles it
                            );

                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop();

                            // Always show success — never confirm if email exists (security)
                            _snack(
                              'If that email is registered, a reset link has been sent.',
                            );
                          } catch (e) {
                            setDialogState(() => isSending = false);
                            _snack(
                              'Something went wrong. Please try again.',
                              isError: true,
                            );
                          }
                        },
                  child: isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Send Link',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenW = mq.size.width;
    final screenH = mq.size.height;

    // Responsive scale factor — clamps between small (320dp) and large (428dp) phones
    final scale = (screenW / 390).clamp(0.82, 1.18);

    // Responsive spacing helpers
    final hPad = (screenW * 0.062).clamp(16.0, 32.0);
    final cardHPad = (screenW * 0.062).clamp(16.0, 28.0);
    final cardVPad = (screenH * 0.032).clamp(20.0, 36.0);
    final logoHeight = (screenH * 0.28).clamp(200.0, 360.0);
    final btnHeight = (screenH * 0.072).clamp(50.0, 62.0);
    final fieldSpacing = (screenH * 0.022).clamp(12.0, 22.0);
    final sectionSpacing = (screenH * 0.020).clamp(10.0, 20.0);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        backgroundColor: _kBackground,
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: hPad,
                vertical: (screenH * 0.025).clamp(12.0, 24.0),
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: cardHPad,
                        vertical: cardVPad,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          (screenW * 0.085).clamp(24.0, 36.0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // ================= LOGO =================
                              
                               Transform.translate(
                                    offset: const Offset(0, 35),
                                    child: Center(
                                    child: Image.asset(
                                    'assets/OrgConnectLogo.png',
                                    height: logoHeight * 1.75,
                                    fit: BoxFit.contain,
                           ),
                    ),
                  ),

                            Transform.translate(
                                  offset: const Offset(0, -45),
                                  child: Column(
                                  children: [
                        // ================= TITLE =================
                      
                            Text(
                                'Welcome!',
                                style: TextStyle(
                                fontSize: (34 * scale).clamp(26.0, 38.0),
                                fontWeight: FontWeight.w800,
                                color: _kTextColor,
                                letterSpacing: -0.5,
                            ),
                          ),

                            SizedBox(height: (8 * scale).clamp(5.0, 10.0)),

                            Text(
                                  'Log in to your existing account',
                                   textAlign: TextAlign.center,
                                   style: TextStyle(
                                   fontSize: (15 * scale).clamp(12.0, 16.0),
                                   color: const Color(0xFF6B7280),
                                   fontWeight: FontWeight.w400,
                             ),
                        ),
                     ],
                   ),
                ),

                          SizedBox(height: sectionSpacing),

                          // ================= EMAIL FIELD =================
                          _ModernField(
                            controller: _emailCtrl,
                            hint: 'Email',
                            icon: Icons.person_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            scale: scale,
                          ),

                          SizedBox(height: fieldSpacing),

                          // ================= PASSWORD FIELD =================
                          _ModernField(
                            controller: _passCtrl,
                            hint: 'Password',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscure,
                            scale: scale,
                            onToggle: () {
                              setState(() {
                                _obscure = !_obscure;
                              });
                            },
                            onSubmitted: (_) => _signIn(),
                          ),

                          SizedBox(
                            height: (fieldSpacing * 0.75).clamp(8.0, 16.0),
                          ),

                          // ================= FORGOT PASSWORD =================
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () => _showForgotPasswordDialog(),
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  fontSize: (14 * scale).clamp(11.0, 15.0),
                                  fontWeight: FontWeight.w500,
                                  color: _kTextColor,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: sectionSpacing),

                          // ================= LOGIN BUTTON =================
                          SizedBox(
                            width: double.infinity,
                            height: btnHeight,
                            child: ElevatedButton(
                              onPressed:
                                  _isFormValid && !_isLoading ? _signIn : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _kPrimaryBlue,
                                disabledBackgroundColor:
                                    _kPrimaryBlue.withOpacity(0.45),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(40),
                                ),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      width: (24 * scale).clamp(18.0, 26.0),
                                      height: (24 * scale).clamp(18.0, 26.0),
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'LOG IN',
                                      style: TextStyle(
                                        fontSize: (17 * scale).clamp(
                                          14.0,
                                          19.0,
                                        ),
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),

                          SizedBox(height: fieldSpacing),

                          // ================= SIGNUP =================
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: TextStyle(
                                  color: const Color(0xFF6B7280),
                                  fontSize: (14 * scale).clamp(11.0, 15.0),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/signup',
                                  );
                                },
                                child: Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    color: _kPrimaryBlue,
                                    fontWeight: FontWeight.w700,
                                    fontSize: (14 * scale).clamp(11.0, 15.0),
                                  ),
                                ),
                              ),
                            ],
                          ),
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

class _ModernField extends StatefulWidget {
  const _ModernField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.onToggle,
    this.onSubmitted,
    this.scale = 1.0,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboardType;
  final VoidCallback? onToggle;
  final ValueChanged<String>? onSubmitted;
  final double scale;

  @override
  State<_ModernField> createState() => _ModernFieldState();
}

class _ModernFieldState extends State<_ModernField> {
  final FocusNode _focusNode = FocusNode();

  bool _focused = false;

  @override
  void initState() {
    super.initState();

    _focusNode.addListener(() {
      setState(() {
        _focused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    final vertPad = (20 * s).clamp(14.0, 22.0);
    final horzPad = (22 * s).clamp(16.0, 24.0);
    final fontSize = (15 * s).clamp(12.0, 16.0);
    final iconSize = (22 * s).clamp(18.0, 24.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: _focused ? _kPrimaryBlue : _kBorderColor,
          width: _focused ? 2 : 1.2,
        ),
        color: Colors.white,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscure,
        keyboardType: widget.keyboardType,
        onSubmitted: widget.onSubmitted,
        style: TextStyle(
          fontSize: fontSize,
          color: _kTextColor,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: horzPad,
            vertical: vertPad,
          ),
          hintText: widget.hint,
          hintStyle: TextStyle(
            color: _kHintColor,
            fontSize: fontSize,
          ),
          prefixIcon: Icon(
            widget.icon,
            color: _focused ? _kPrimaryBlue : _kHintColor,
            size: iconSize,
          ),
          suffixIcon: widget.onToggle != null
              ? GestureDetector(
                  onTap: widget.onToggle,
                  child: Icon(
                    widget.obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: _focused ? _kPrimaryBlue : _kHintColor,
                    size: iconSize,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
