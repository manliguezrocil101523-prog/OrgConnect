import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_state.dart';
import '../Student_Role/student_dashboard_screen.dart';
import '../Officer_Role/officer_rule_screen.dart';
import '../Admin_Role/admin_dashboard_screen.dart';
import '../Adviser_Role/adviser_dashboard_screen.dart';
import '../auth/forgot_password_page.dart';

const _green = Color(0xFF16A34A);
const _ink = Color(0xFF1E293B);
const _muted = Color(0xFF94A3B8);
const _line = Color(0xFFD1D5DB);
const _tint = Color(0xFFF8FAFF);
const _error = Color(0xFFDC2626);
const _logo = 'assets/icon/login_logo.png';

/// Explicitly applies Plus Jakarta Sans so login typography does not depend
/// on inherited theme styles.
TextStyle _t(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) =>
    GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: w,
      color: c,
    );

OutlineInputBorder _border(Color c, [double w = 1.2]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: c, width: w),
    );

class UnifiedLoginPage extends StatefulWidget {
  const UnifiedLoginPage({super.key});

  @override
  State<UnifiedLoginPage> createState() => _UnifiedLoginPageState();
}

class _UnifiedLoginPageState extends State<UnifiedLoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  // ───────────────────────── LOGIN LOGIC ─────────────────────────

  Future<void> _reject(String msg) async {
    await Supabase.instance.client.auth.signOut();
    _snack(msg, error: true);
  }

  Future<void> _signIn() async {
    final email = _email.text.trim();
    final password = _pass.text.trim();
    if (email.isEmpty || password.isEmpty || _loading) return;
    setState(() => _loading = true);

    final db = Supabase.instance.client;
    final app = AppState.instance;

    try {
      final res =
          await db.auth.signInWithPassword(email: email, password: password);
      if (!mounted) return;

      final user = res.user;
      if (user == null) return _reject('Invalid email or password.');

      final p = await db.from('profiles').select().eq('id', user.id).single();
      if (p['active'] == false) {
        return _reject('Your account has been deactivated. Contact admin.');
      }

      final role = p['role']?.toString() ?? 'student';
      final orgId = p['assigned_org_id']?.toString() ?? '';
      if (!mounted) return;

      final Widget page;
      if (role == 'admin') {
        app.setRole(UserRole.admin);
        page = const AdminDashboard();
      } else if (role == 'adviser' || role == 'officer') {
        if (orgId.isEmpty) {
          return _reject('You have not been assigned to an organization yet.');
        }
        final orgs = app.organizations;
        final i = orgs.indexWhere((o) => o.id == orgId);
        if (i == -1) {
          return _reject('Assigned organization not found. Contact admin.');
        }
        final org = orgs[i];

        if (role == 'officer') {
          // Every designated officer can enter the officer dashboard; individual actions remain permission-gated by designation.
          final m = await db
              .from('members')
              .select('position')
              .eq('org_id', orgId)
              .eq('profile_id', user.id)
              .maybeSingle();
          final pos = m?['position']?.toString().toLowerCase().trim() ?? '';
          if (!{
            'president',
            'vice president',
            'secretary',
            'assistant secretary',
            'treasurer',
            'officer',
          }.contains(pos)) {
            return _reject(
                'Officer access requires a valid organization designation. Please ask your adviser or admin to check your designation.');
          }
          app.setRole(UserRole.officer);
          app.setCurrentOfficerOrgId(orgId);
          await app.fetchApplications();
          await app.fetchMembers();
          page = BaseOfficerDashboard(orgId: org.id, orgName: org.name);
        } else {
          app.setRole(UserRole.adviser);
          app.setCurrentOfficerOrgId(orgId);
          page = AdviserDashboard(orgId: orgId, orgName: org.name);
        }
      } else {
        final raw = p['joined_org_ids'];
        final joined = switch (raw) {
          null => <String>[],
          String s => List<String>.from(jsonDecode(s) as List),
          List l => List<String>.from(l),
          _ => <String>[],
        };
        app.setRole(UserRole.student);
        await app.setStudentProfile(StudentProfile(
          id: p['id'],
          name: p['name'] ?? '',
          email: p['email'] ?? '',
          studentId: p['student_id'] ?? '',
          contact: p['contact'] ?? '',
          facebook: p['facebook'] ?? '',
          avatarUrl: p['avatar_url'] ?? '',
          joinedOrgIds: joined,
        ));
        await app.fetchNotifications();
        page = const StudentDashboardScreen();
      }

      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => page));
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('email not confirmed')) {
        _showConfirmDialog(email);
      } else {
        _snack(e.message, error: true);
      }
    } catch (_) {
      _snack('Something went wrong. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: _t(13.5, c: Colors.white)),
      backgroundColor: error ? _error : const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showConfirmDialog(String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Email not confirmed', style: _t(18, w: FontWeight.w700)),
        content: Text(
          'Your email ($email) has not been confirmed yet. '
          'Check your inbox for a verification link.',
          style: _t(14, c: _muted),
        ),
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
                _snack('Failed to resend: $e', error: true);
              }
            },
            child: const Text('Resend email'),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _tint,
        body: LayoutBuilder(builder: (context, c) {
          // Desktop / laptop / large tablet: split layout.
          if (c.maxWidth >= 900) {
            return Row(children: [
              Expanded(flex: 5, child: _brandPanel()),
              Expanded(
                flex: 4,
                child: Container(
                  color: Colors.white,
                  alignment: Alignment.center,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(48),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: _form(wide: true, screenH: c.maxHeight),
                    ),
                  ),
                ),
              ),
            ]);
          }
          // Phone / mini phone / small tablet: centered card.
          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    padding: EdgeInsets.all(c.maxWidth < 360 ? 20 : 28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: _green.withValues(alpha: 0.08),
                          blurRadius: 32,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _form(wide: false, screenH: c.maxHeight),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _brandPanel() {
    const points = [
      (Icons.groups_outlined, 'Organizations and memberships'),
      (Icons.event_outlined, 'Events and announcements'),
      (Icons.receipt_long_outlined, 'Reports and liquidation'),
    ];
    return Container(
      color: const Color(0xFFF8FAFF),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(_logo,
                height: 120,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high),
            const SizedBox(height: 20),
            Text('OrgConnect', style: _t(38, w: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              'One place to manage student organizations, events, and members.',
              style: _t(16, c: _muted).copyWith(height: 1.5),
            ),
            const SizedBox(height: 32),
            for (final p in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(p.$1, size: 20, color: _green),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                      child: Text(p.$2, style: _t(14.5, w: FontWeight.w600))),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _form({required bool wide, required double screenH}) {
    final ta = wide ? TextAlign.start : TextAlign.center;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!wide) ...[
          Image.asset(_logo,
              height: (screenH * 0.1).clamp(60.0, 96.0),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high),
          const SizedBox(height: 10),
          Text('OrgConnect', textAlign: ta, style: _t(22, w: FontWeight.w800)),
          const SizedBox(height: 24),
        ],
        Text('Welcome back',
            textAlign: ta, style: _t(wide ? 30 : 26, w: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Log in to your account to continue.',
            textAlign: ta, style: _t(14, c: _muted)),
        const SizedBox(height: 28),
        _field(_email, 'Email', Icons.person_outline_rounded),
        const SizedBox(height: 14),
        _field(_pass, 'Password', Icons.lock_outline_rounded, password: true),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
            ),
            child: Text('Forgot password?',
                style: _t(13, w: FontWeight.w600, c: _green)),
          ),
        ),
        const SizedBox(height: 6),
        ListenableBuilder(
          listenable: Listenable.merge([_email, _pass]),
          builder: (_, __) {
            final ready = _email.text.trim().isNotEmpty &&
                _pass.text.trim().isNotEmpty &&
                !_loading;
            return SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: ready ? _signIn : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  disabledBackgroundColor: _green.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text('Log in',
                        style: _t(15, w: FontWeight.w700, c: Colors.white)),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text("Don't have an account? ", style: _t(13.5, c: _muted)),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/signup'),
              child: Text('Sign up',
                  style: _t(13.5, w: FontWeight.w700, c: _green)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon,
      {bool password = false}) {
    return TextField(
      controller: ctrl,
      obscureText: password && _obscure,
      keyboardType:
          password ? TextInputType.visiblePassword : TextInputType.emailAddress,
      textInputAction: password ? TextInputAction.done : TextInputAction.next,
      autofillHints: [password ? AutofillHints.password : AutofillHints.email],
      onSubmitted: password ? (_) => _signIn() : null,
      style: _t(15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: _t(14, c: _muted),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 22),
        prefixIcon: Icon(icon, size: 20),
        prefixIconColor: WidgetStateColor.resolveWith(
            (s) => s.contains(WidgetState.focused) ? _green : _muted),
        suffixIcon: password
            ? IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: _muted,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
        border: _border(_line),
        enabledBorder: _border(_line),
        focusedBorder: _border(_green, 1.8),
      ),
    );
  }
}
