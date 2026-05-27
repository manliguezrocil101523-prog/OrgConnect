import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../../core/app_state.dart';
import '../Student_Role/student_dashboard_screen.dart';
import '../Student_Role/student_dashboard_events.dart';
import '../Officer_Role/officer_rule_screen.dart';
import '../Admin_Role/admin_dashboard_screen.dart';
import 'unified_login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'get_started_screen.dart';

/// AuthGate — initial checkpoint of the app.
///
/// Checks for a cached Supabase session on launch and routes the user
/// directly to their correct dashboard without showing the login page again.
/// If no session exists, routes to [UnifiedLoginPage].
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color _kBg = Colors.white;
  static const Color _kTitle = Color(0xFF1E293B);
  static const Color _kSubtitle = Color(0xFF64748B);
  static const Color _kBorder = Color(0xFFE2E8F0);
  static const Color _kLoader = Color(0xFF1E293B);
  static const Color _kLogoShadow = Color(0x0A000000);

  @override
  void initState() {
    super.initState();
    // Run after first frame so Navigator is ready
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSession());
  }

  // ── Session Check ─────────────────────────────────────────────────────────
  Future<void> _checkSession() async {
    final session = Supabase.instance.client.auth.currentSession;

    // Scenario A — No active session → go to login
    // Scenario A — No active session → show calendar as guest
    // ✅ Correct
    // After
    if (session == null) {
      final prefs = await SharedPreferences.getInstance();
      final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;

      if (isFirstLaunch) {
        await prefs.setBool('is_first_launch', false);
        _goTo(const GetStartedScreen());
      } else {
        _goTo(const UnifiedLoginPage());
      }
      return;
    }

    // Scenario B — Active session → fetch role and route
    try {
      final userId = session.user.id;

      final profileData = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      final role = profileData['role']?.toString() ?? 'student';
      final isActive = profileData['active'] ?? true;

      // If account was deactivated, sign out and go to login
      if (!isActive) {
        await Supabase.instance.client.auth.signOut();
        _goTo(const UnifiedLoginPage());
        return;
      }

      if (role == 'admin') {
        // ── Admin ──────────────────────────────────────────────────────────
        AppState.instance.setRole(UserRole.admin);
        _goTo(const AdminDashboard());
      } else if (role == 'officer') {
        // ── Officer ────────────────────────────────────────────────────────
        final assignedOrgId = profileData['assigned_org_id']?.toString() ?? '';

        if (assignedOrgId.isEmpty) {
          // Officer not assigned yet — sign out and go to login
          await Supabase.instance.client.auth.signOut();
          _goTo(const UnifiedLoginPage());
          return;
        }

        // Find the org in AppState
        final orgs = AppState.instance.organizations;
        final orgIndex = orgs.indexWhere((o) => o.id == assignedOrgId);

        if (orgIndex == -1) {
          // Org not found — sign out and go to login
          await Supabase.instance.client.auth.signOut();
          _goTo(const UnifiedLoginPage());
          return;
        }

        AppState.instance.setRole(UserRole.officer);
        AppState.instance.setCurrentOfficerOrgId(assignedOrgId);

        _goTo(BaseOfficerDashboard(
          orgId: orgs[orgIndex].id,
          orgName: orgs[orgIndex].name,
        ));
      } else {
        // ── Student (default) ──────────────────────────────────────────────
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

        _goTo(const StudentDashboardScreen());
      }
    } catch (e) {
      // Something went wrong fetching profile — fall back to login safely
      await Supabase.instance.client.auth.signOut();
      _goTo(const UnifiedLoginPage());
    }
  }

  /// Replaces AuthGate completely in the navigation stack.
  /// User cannot press back to return to the loading screen.
  void _goTo(Widget page) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  // ── Loading UI ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Logo container ─────────────────────────────────────────────
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _kBorder, width: 1.0),
                boxShadow: const [
                  BoxShadow(
                    color: _kLogoShadow,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Image.asset(
                'assets/orgconnectLogo.jpg',
                fit: BoxFit.contain,
              ),
            ),

            const SizedBox(height: 28),

            // ── App name ───────────────────────────────────────────────────
            const Text(
              'OrgConnect',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _kTitle,
                letterSpacing: -0.4,
                height: 1.0,
              ),
            ),

            const SizedBox(height: 6),

            // ── Status label ───────────────────────────────────────────────
            const Text(
              'Loading your session...',
              style: TextStyle(
                fontSize: 13,
                color: _kSubtitle,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.1,
              ),
            ),

            const SizedBox(height: 36),

            // ── Divider accent ─────────────────────────────────────────────
            Container(
              width: 32,
              height: 1,
              color: _kBorder,
            ),

            const SizedBox(height: 28),

            // ── Slim loading indicator ─────────────────────────────────────
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                valueColor: AlwaysStoppedAnimation<Color>(_kLoader),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
