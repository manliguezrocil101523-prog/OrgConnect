import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_state.dart';

import '/screens/notifications/notification_screen.dart';
// ── ADD THIS IMPORT (line 5) ─────────────────────────────────────────────────
import '/screens/Student_Role/student_dashboard_events.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  // ─── Color tokens — MUST match ProfileScreen exactly ─────────────────────
  static const Color _primary = Color(0xFF4F46E5);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _background = Color(0xFFF8FAFC);

  // Per-action accent colors — all within the permitted palette
  static const Color _profileAccent = Color(0xFF4F46E5);
  static const Color _orgAccent = Color(0xFF06B6D4);
  static const Color _notifAccent = Color(0xFF22C55E);

  // ─── Double-tap-to-exit state tracker ────────────────────────────────────
  DateTime? _lastBackPressed;

  // ─── AppState listener so badge refreshes when notifications change ───────
  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Unread count for the notification badge
    final unreadCount = AppState.instance.notifications
        .where((n) =>
            (n.studentId == AppState.instance.currentStudent?.id ||
                n.studentId == AppState.instance.currentStudent?.studentId) &&
            !n.read)
        .length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        final now = DateTime.now();

        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;

          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Tap again to exit',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height - 140,
                left: 40,
                right: 40,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).clearSnackBars();
          SystemChannels.platform.invokeMethod('SystemNavigator.pop');
        }
      },
      child: Scaffold(
        backgroundColor: _background,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ─── HERO SLIVER APP BAR ──────────────────────────────────────────
            SliverAppBar(
              expandedHeight: size.height * 0.40,
              pinned: true,
              stretch: true,
              backgroundColor: _primary,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: const Text(
                'Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  letterSpacing: 0.4,
                ),
              ),
              centerTitle: true,
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.blurBackground],
                background: _HeroHeader(
                  primary: _primary,
                  secondary: _secondary,
                ),
              ),
            ),

            // ─── BODY CONTENT ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── SECTION: Quick Actions ─────────────────────────
                        const _SectionLabel(text: 'Quick Actions'),
                        const SizedBox(height: 16),

                        // ── ROW 1: My Profile + Organizations (unchanged) ──
                        // ── ROW 1: My Profile + Organizations ──────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _ActionTile(
                                label: 'My Profile',
                                subtitle: 'View & update info',
                                icon: Icons.person_rounded,
                                accentColor: _profileAccent,
                                onTap: () =>
                                    Navigator.pushNamed(context, '/profile'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionTile(
                                label: 'Organizations',
                                subtitle: 'Browse & apply',
                                icon: Icons.groups_rounded,
                                accentColor: _orgAccent,
                                onTap: () =>
                                    Navigator.pushNamed(context, '/orglist'),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // ── ROW 2: Notifications + Events ──────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _ActionTileWithBadge(
                                label: 'Notifications',
                                subtitle: 'App updates',
                                icon: Icons.notifications_rounded,
                                accentColor: _notifAccent,
                                badgeCount: unreadCount,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NotificationScreen(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionTile(
                                label: 'Events',
                                subtitle: 'View schedule',
                                icon: Icons.calendar_month_rounded,
                                accentColor: Color(0xFF4F46E5),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const StudentDashboard(),
                                  ),
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
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _CalendarCard
// Embeds the StudentDashboard (student_dashboard_events.dart) calendar widget
// directly into the dashboard page as a card.
// =============================================================================

// =============================================================================
// _HeroHeader  (UNCHANGED)
// =============================================================================
class _HeroHeader extends StatelessWidget {
  final Color primary;
  final Color secondary;

  const _HeroHeader({
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final avatarSize = (size.width * 0.18).clamp(60.0, 84.0);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative orb — top right
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          // Decorative orb — bottom left
          Positioned(
            bottom: 10,
            left: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // TOP ZONE: Identity row
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar ring
                        Container(
                          width: avatarSize + 10,
                          height: avatarSize + 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.18),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: _buildAvatar(avatarSize),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Name + subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Welcome Back 👋',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.1,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Manage your applications\n& organizations',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.1,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // BOTTOM ZONE: Frosted summary strip
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.18),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _HeroStatChip(
                        label: 'Applications',
                        icon: Icons.assignment_rounded,
                      ),
                      _VerticalDividerChip(),
                      _HeroStatChip(
                        label: 'Orgs Joined',
                        icon: Icons.groups_rounded,
                      ),
                      _VerticalDividerChip(),
                      _HeroStatChip(
                        label: 'Notifications',
                        icon: Icons.notifications_rounded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // paste here ↓
  Widget _buildAvatar(double avatarSize) {
    final student = AppState.instance.currentStudent;
    final avatarUrl = student?.avatarUrl ?? '';

    ImageProvider? bgImage;
    Widget? fallbackChild;

    if (avatarUrl.startsWith('data:')) {
      try {
        final base64Str = avatarUrl.substring(avatarUrl.indexOf(',') + 1);
        bgImage = MemoryImage(base64Decode(base64Str));
      } catch (_) {}
    } else if (avatarUrl.isNotEmpty) {
      bgImage = NetworkImage(avatarUrl);
    }

    fallbackChild = bgImage == null
        ? Icon(
            Icons.person_rounded,
            size: avatarSize * 0.50,
            color: const Color(0xFF4F46E5),
          )
        : null;

    return CircleAvatar(
      radius: avatarSize / 2,
      backgroundColor: const Color(0xFFE0E7FF),
      backgroundImage: bgImage,
      child: fallbackChild,
    );
  }
} // ← this is the original closing brace of _HeroHeader

// =============================================================================
// _HeroStatChip  (UNCHANGED)
// =============================================================================
class _HeroStatChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _HeroStatChip({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.20),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// _VerticalDividerChip  (UNCHANGED)
// =============================================================================
class _VerticalDividerChip extends StatelessWidget {
  const _VerticalDividerChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withOpacity(0.20),
    );
  }
}

// =============================================================================
// _SectionLabel  (UNCHANGED)
// =============================================================================
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// _ActionTile — compact square tile for the 2-col grid row (UNCHANGED)
// =============================================================================
class _ActionTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      shadowColor: accentColor.withOpacity(0.12),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        splashColor: accentColor.withOpacity(0.07),
        highlightColor: accentColor.withOpacity(0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon badge
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),

              const SizedBox(height: 14),

              // Label
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),

              // Subtitle
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF94A3B8),
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 10),

              // Bottom affordance row
              Row(
                children: [
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 13,
                    color: accentColor.withOpacity(0.70),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Open',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accentColor.withOpacity(0.70),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _ActionTileWithBadge
// Same visual as _ActionTile but adds an unread-count badge in the top-right
// corner.  Replaces the old full-width _ActionCard for Notifications so the
// card height/width matches My Profile and Organizations exactly.
// =============================================================================
class _ActionTileWithBadge extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final int badgeCount;

  const _ActionTileWithBadge({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    required this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final showBadge = badgeCount > 0;
    final badgeLabel = badgeCount > 9 ? '9+' : '$badgeCount';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Tile body — identical layout to _ActionTile ───────────────────
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          shadowColor: accentColor.withOpacity(0.12),
          elevation: 3,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            splashColor: accentColor.withOpacity(0.07),
            highlightColor: accentColor.withOpacity(0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon badge
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accentColor, size: 20),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),

                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF94A3B8),
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: accentColor.withOpacity(0.70),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Open',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: accentColor.withOpacity(0.70),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Unread badge — top-right corner of the tile ───────────────────
        if (showBadge)
          Positioned(
            top: -8,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withOpacity(0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                badgeLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// _ActionCard — KEPT for reference / future use but no longer used on screen
// =============================================================================
class _ActionCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final int? badgeCount;

  const _ActionCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final showBadge = badgeCount != null && badgeCount! > 0;
    final badgeLabel =
        (badgeCount != null && badgeCount! > 9) ? '9+' : '$badgeCount';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          shadowColor: accentColor.withOpacity(0.12),
          elevation: 3,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            splashColor: accentColor.withOpacity(0.07),
            highlightColor: accentColor.withOpacity(0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accentColor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFCBD5E1),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showBadge)
          Positioned(
            top: -10,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withOpacity(0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                badgeLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
