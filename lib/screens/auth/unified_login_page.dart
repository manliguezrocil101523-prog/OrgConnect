import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../../core/app_state.dart';
import '../Student_Role/student_dashboard_screen.dart';
import '../Student_Role/student_dashboard_events.dart';
import '../Officer_Role/officer_rule_screen.dart';
import '../Admin_Role/admin_dashboard_screen.dart';

const _kBlue = Color(0xFF2563EB);
const _kBlueSoft = Color(0xFFEFF6FF);
const _kBg = Color(0xFFF8FAFF);
const _kText = Color(0xFF1E293B);
const _kSubText = Color(0xFF94A3B8);
const _kBorder = Color(0xFFCBD5E1);
const _kWhite = Colors.white;
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

  late final AnimationController _ac = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600))
    ..forward();
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ac, curve: Curves.easeOut);
  late final Animation<Offset> _slide =
      Tween(begin: const Offset(0, 0.06), end: Offset.zero)
          .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_validate);
    _passCtrl.addListener(_validate);
  }

  @override
  void dispose() {
    _ac.dispose();
    _emailCtrl
      ..removeListener(_validate)
      ..dispose();
    _passCtrl
      ..removeListener(_validate)
      ..dispose();
    super.dispose();
  }

  void _validate() {
    final v =
        _emailCtrl.text.trim().isNotEmpty && _passCtrl.text.trim().isNotEmpty;
    if (v != _isFormValid) setState(() => _isFormValid = v);
  }

  void _goBack() => Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (_) => const StudentDashboard()));

  Future<void> _signIn() async {
    if (!_isFormValid || _isLoading) return;
    setState(() => _isLoading = true);
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();

    try {
      final res = await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);
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
        _snack('Your account has been deactivated. Contact admin.',
            isError: true);
        return;
      }

      final role = profileData['role']?.toString() ?? 'student';
      if (!mounted) return;

      if (role == 'admin') {
        AppState.instance.setRole(UserRole.admin);
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const AdminDashboard()));
      } else if (role == 'officer') {
        final assignedOrgId = profileData['assigned_org_id']?.toString() ?? '';
        if (assignedOrgId.isEmpty) {
          await Supabase.instance.client.auth.signOut();
          _snack('You have not been assigned to an organization yet.',
              isError: true);
          return;
        }
        final orgs = AppState.instance.organizations;
        final orgIndex = orgs.indexWhere((o) => o.id == assignedOrgId);
        if (orgIndex == -1) {
          await Supabase.instance.client.auth.signOut();
          _snack('Assigned organization not found. Contact admin.',
              isError: true);
          return;
        }
        AppState.instance.setRole(UserRole.officer);
        AppState.instance.setCurrentOfficerOrgId(assignedOrgId);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BaseOfficerDashboard(
                orgId: orgs[orgIndex].id, orgName: orgs[orgIndex].name),
          ),
        );
      } else {
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
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const StudentDashboardScreen()));
      }
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('email not confirmed')) {
        _showEmailConfirmationDialog(email);
      } else {
        _snack(e.message, isError: true);
      }
    } catch (e) {
      _snack('Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _kError : const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showEmailConfirmationDialog(String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Email Not Confirmed'),
        content: Text('Your email ($email) has not been confirmed yet. '
            'Please check your inbox for a verification link.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK')),
          TextButton(
            onPressed: () async {
              try {
                await Supabase.instance.client.auth
                    .resend(type: OtpType.signup, email: email);
                if (!ctx.mounted) return;
                _snack('Confirmation email sent!');
                Navigator.of(ctx).pop();
              } catch (e) {
                _snack('Failed to resend: $e', isError: true);
              }
            },
            child: const Text('Resend Email'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          child: Stack(
            children: [
              // ── Back button ────────────────────────────────────
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, left: 8),
                  child: IconButton(
                    onPressed: _goBack,
                    style: IconButton.styleFrom(
                      backgroundColor: _kBlueSoft,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: _kBlue),
                  ),
                ),
              ),

              // ── Main content ───────────────────────────────────
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Title block ──────────────────────
                            const SizedBox(height: 32),
                            const Text(
                              'Sign In',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: _kBlue,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Welcome back! Please sign in to continue',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: _kSubText,
                              ),
                            ),

                            // ── Fields ───────────────────────────
                            const SizedBox(height: 44),
                            _LineField(
                              controller: _emailCtrl,
                              hint: 'Email Address',
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 28),
                            _LineField(
                              controller: _passCtrl,
                              hint: 'Password',
                              obscure: _obscure,
                              onToggle: () =>
                                  setState(() => _obscure = !_obscure),
                              onSubmitted: (_) => _signIn(),
                            ),

                            // ── Forgot password ──────────────────
                            const SizedBox(height: 14),
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () {},
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: _kText,
                                  ),
                                ),
                              ),
                            ),

                            // ── Login button ─────────────────────
                            const SizedBox(height: 36),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isFormValid && !_isLoading
                                    ? _signIn
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _kBlue,
                                  disabledBackgroundColor:
                                      _kBlue.withOpacity(0.45),
                                  foregroundColor: _kWhite,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.2, color: _kWhite),
                                      )
                                    : const Text(
                                        'Login',
                                        style: TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                              ),
                            ),

                            // ── Sign up link ─────────────────────
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Don't have an account?  ",
                                  style: TextStyle(
                                      fontSize: 13.5, color: _kSubText),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      Navigator.pushNamed(context, '/signup'),
                                  child: const Text(
                                    'Sign Up',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: _kBlue,
                                      decoration: TextDecoration.underline,
                                      decorationColor: _kBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
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
      ),
    );
  }
}

// ── Underline-style field (no validation needed for login) ────────────────────
class _LineField extends StatefulWidget {
  const _LineField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.onToggle,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType keyboardType;
  final VoidCallback? onToggle;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_LineField> createState() => _LineFieldState();
}

class _LineFieldState extends State<_LineField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focus,
      obscureText: widget.obscure,
      keyboardType: widget.keyboardType,
      onSubmitted: widget.onSubmitted,
      style: const TextStyle(
          fontSize: 15, color: _kText, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(
            color: _kSubText, fontSize: 14.5, fontWeight: FontWeight.w400),
        contentPadding: const EdgeInsets.only(bottom: 10),
        isDense: true,
        border:
            const UnderlineInputBorder(borderSide: BorderSide(color: _kBorder)),
        enabledBorder:
            const UnderlineInputBorder(borderSide: BorderSide(color: _kBorder)),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: _kBlue, width: 1.8)),
        suffixIcon: widget.onToggle != null
            ? GestureDetector(
                onTap: widget.onToggle,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Icon(
                    widget.obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 19,
                    color: _focused ? _kBlue : _kSubText,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
