import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '/screens/notifications/notification_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
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
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () {
                AppState.instance.setRole(null);
                Navigator.pushReplacementNamed(context, '/role');
              },
            ),
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
                      // ── Section label ─────────────────────────────────────
                      const _SectionLabel(text: 'Quick Actions'),
                      const SizedBox(height: 16),

                      // ── RESTRUCTURED: 2-col top row ───────────────────────
                      // BEFORE: three identical full-width list rows stacked
                      //         vertically — monotonous, lots of dead space.
                      // AFTER:  My Profile + Organizations sit side-by-side in
                      //         a 2-column grid row (equal weight, scannable at
                      //         a glance), while Notifications spans full width
                      //         below (justified by its higher urgency / info
                      //         density — it is the primary feedback channel).
                      //         This breaks the repetitive stack and creates a
                      //         visual hierarchy: explore (top) → track (bottom).
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // My Profile tile
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
                          // Organizations tile
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

                      // Notifications — full width, primary feedback channel
                      _ActionCard(
                        label: 'Notifications',
                        subtitle: 'See updates on your applications',
                        icon: Icons.notifications_rounded,
                        accentColor: _notifAccent,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationScreen(),
                          ),
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
    );
  }
}

// =============================================================================
// _HeroHeader
// =============================================================================
// STRUCTURAL CHANGE: Two-zone layout replacing the single centered column.
//
// BEFORE: Avatar → name → subtitle stacked in the center of the gradient —
//         lots of empty gradient above and below, no visual anchor, felt
//         like a placeholder screen.
//
// AFTER:
//   • TOP ZONE (flex 1): Avatar in a side-by-side row with name + subtitle
//     text. Avatar is left-anchored and the text block fills the remaining
//     width. This gives the header a real "identity card" feel and eliminates
//     the orphaned centered circle.
//   • BOTTOM ZONE: A frosted summary strip pinned to the bottom edge of the
//     hero. Three stat chips (Applications / Orgs Joined / Notifications)
//     give the user an immediate activity snapshot and fill the dead space
//     that previously existed beneath the avatar. The strip also provides a
//     clean visual transition into the white card area below.
//
// All colors, gradient, orb decorations, SafeArea — UNCHANGED.
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
          // Decorative orb — top right (UNCHANGED)
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
          // Decorative orb — bottom left (UNCHANGED)
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

          // ── Main content — restructured into two zones ──────────────────
          SafeArea(
            child: Column(
              children: [
                // ── TOP ZONE: Identity row ────────────────────────────────
                // Avatar left-anchored + name/greeting text right of it.
                // Fills the vertical space that was previously wasted above
                // a centered avatar.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar ring — same layering as original
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
                                child: CircleAvatar(
                                  radius: avatarSize / 2,
                                  backgroundColor: const Color(0xFFE0E7FF),
                                  child: Icon(
                                    Icons.person_rounded,
                                    size: avatarSize * 0.50,
                                    color: const Color(0xFF4F46E5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Name + subtitle — moved from centered to beside avatar
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

                // ── BOTTOM ZONE: Frosted summary strip ───────────────────
                // Pinned to the bottom of the hero. Three stat chips give
                // the user an instant activity snapshot and eliminate the
                // dead space that sat below the avatar in the original.
                // The frosted surface also acts as a smooth visual bridge
                // into the white card content area below.
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
}

// =============================================================================
// _HeroStatChip
// =============================================================================
// New structural element — part of the hero bottom strip.
// Icon + label chip in the frosted hero footer. Uses only white/opacity
// so it inherits whatever gradient is behind it without hardcoding colors.
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
// _VerticalDividerChip
// =============================================================================
// Thin separator between hero stat chips. White/opacity only.
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
// _SectionLabel — UNCHANGED
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
// _ActionTile  (NEW — compact square tile for the 2-col grid row)
// =============================================================================
// STRUCTURAL CHANGE: replaces _ActionCard for the top two actions.
//
// BEFORE: My Profile + Organizations were full-width horizontal cards,
//         each ~70 dp tall, identical to Notifications — no visual
//         distinction, repetitive rhythm, poor use of horizontal space.
//
// AFTER:  Compact square tiles designed for the 2-col layout:
//   • Icon badge centered at the top
//   • Label + subtitle below it
//   • Same color tokens (accentColor, white surface, same shadow formula)
//   • Same InkWell + borderRadius tap feedback
//   • Same onTap navigation callbacks — 100% preserved
//
// All color values match the originals exactly (_profileAccent, _orgAccent).
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
              // Icon badge — same dimensions as _ActionCard
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

              // Bottom affordance row — icon + "Open" label
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
// _ActionCard — UNCHANGED (used for Notifications full-width row)
// =============================================================================
class _ActionCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _ActionCard({
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
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

              const SizedBox(width: 14),

              // Label + subtitle
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

              // Chevron
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFCBD5E1),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
