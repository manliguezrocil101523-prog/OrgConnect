import 'package:flutter/material.dart';
import '../core/app_state.dart';
import 'role_router.dart';
import 'Officer_Role/officer_authorization_screen.dart';
import 'Admin_Role/admin_authorization_screen.dart';

// ── Palette (matches sign_in_page) ────────────────────────────────────────────
const _kIndigo = Color(0xFF4F46E5);
const _kCyan = Color(0xFF06B6D4);
const _kIndigoSoft = Color(0xFFEEF2FF);
const _kBg = Color(0xFFF5F7FF);
const _kText = Color(0xFF1E1B4B);
const _kSubText = Color(0xFF6366F1);
const _kWhite = Colors.white;

// ── Role meta ─────────────────────────────────────────────────────────────────
class _RoleMeta {
  const _RoleMeta({
    required this.role,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
  });

  final UserRole role;
  final String label;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
}

const _roles = [
  _RoleMeta(
    role: UserRole.student,
    label: 'Student',
    subtitle: 'Browse orgs & events',
    icon: Icons.school_rounded,
    gradientColors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
  ),
  _RoleMeta(
    role: UserRole.officer,
    label: 'Organization Officer',
    subtitle: 'Manage your organization',
    icon: Icons.badge_rounded,
    gradientColors: [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
  ),
  _RoleMeta(
    role: UserRole.admin,
    label: 'Admin',
    subtitle: 'Full system access',
    icon: Icons.admin_panel_settings_rounded,
    gradientColors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppState.instance.selectedRole != null) {
      return const RoleRouter();
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          _BackgroundDecor(),
          SafeArea(
            child: Column(
              children: [
                _TopBar(context),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 24,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _HeaderSection(),
                            const SizedBox(height: 36),
                            ..._roles.map(
                              (meta) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _RoleCard(meta: meta),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar(this.context);
  final BuildContext context;

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: _kIndigo,
            style: IconButton.styleFrom(
              backgroundColor: _kIndigoSoft,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () =>
                Navigator.pushReplacementNamed(ctx, '/calendar'),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _HeaderSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Icon badge
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kIndigo, _kCyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _kIndigo.withOpacity(0.30),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.people_alt_rounded,
            color: _kWhite,
            size: 34,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Choose Your Role',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: _kText,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select how you want to use OrgConnect',
          style: TextStyle(
            fontSize: 14,
            color: _kSubText,
          ),
        ),
      ],
    );
  }
}

// ── Role card ─────────────────────────────────────────────────────────────────
class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.meta});
  final _RoleMeta meta;

  void _handleTap(BuildContext context) {
    AppState.instance.setRole(meta.role);
    switch (meta.role) {
      case UserRole.student:
        Navigator.pushReplacementNamed(context, '/signin');
        break;
      case UserRole.officer:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const OfficerAuthorizationScreen(),
          ),
        );
        break;
      case UserRole.admin:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminAuthorizationScreen(),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleTap(context),
        borderRadius: BorderRadius.circular(20),
        splashColor: meta.gradientColors.first.withOpacity(0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: _kWhite,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: meta.gradientColors.first.withOpacity(0.10),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: meta.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: meta.gradientColors.first.withOpacity(0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(meta.icon, color: _kWhite, size: 24),
              ),
              const SizedBox(width: 16),
              // Labels
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: _kSubText.withOpacity(0.75),
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _kIndigoSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: meta.gradientColors.first,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Background decoration ─────────────────────────────────────────────────────
class _BackgroundDecor extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -60,
          right: -60,
          child: _Circle(size: 220, color: _kIndigo.withOpacity(0.12)),
        ),
        Positioned(
          bottom: -80,
          left: -50,
          child: _Circle(size: 260, color: _kCyan.withOpacity(0.10)),
        ),
        Positioned(
          top: 140,
          left: -30,
          child: _Circle(size: 100, color: _kIndigo.withOpacity(0.07)),
        ),
      ],
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}