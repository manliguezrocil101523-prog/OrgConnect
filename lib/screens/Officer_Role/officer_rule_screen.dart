import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import 'officer_applications_screen.dart';
import 'officer_members_screen.dart';
import 'officer_events_screen.dart';
import 'officer_authorization_screen.dart';
import '../auth/sign_in_page.dart';

class BaseOfficerDashboard extends StatelessWidget {
  final String orgId;
  final String orgName;

  const BaseOfficerDashboard({
    super.key,
    required this.orgId,
    required this.orgName,
  });

  static const Color _primary = Color(0xFF4F46E5);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _background = Color(0xFFF8FAFC);
  static const Color _cardSurface = Colors.white;
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _green = Color(0xFF22C55E);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final org =
        AppState.instance.organizations.firstWhere((o) => o.id == orgId);

    return Scaffold(
      backgroundColor: _background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App Bar ────────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: size.height * 0.22,
            backgroundColor: _primary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              tooltip: 'Back',
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const SignInPage(),
                ),
              ),
            ),
            title: const Text(
              'Officer Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17,
                letterSpacing: 0.3,
              ),
            ),
            centerTitle: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _OfficerHeroHeader(
                primary: _primary,
                secondary: _secondary,
                org: org,
              ),
            ),
          ),

          // ── Body ───────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Section Label ──────────────────────────────────
                      const _SectionLabel(text: 'Manage'),
                      const SizedBox(height: 16),

                      // ── Manage Applications ────────────────────────────
                      _ApplicationsCard(
                        color: _primary,
                        onTap: () => _showApplicationFilters(context),
                      ),

                      const SizedBox(height: 14),

                      // ── Members & Events Grid ──────────────────────────
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _GridActionCard(
                                icon: Icons.groups_rounded,
                                title: 'Members',
                                subtitle: 'View & update',
                                color: _secondary,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const OfficerMembersScreen(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _GridActionCard(
                                icon: Icons.event_available_rounded,
                                title: 'Events',
                                subtitle: 'Create & manage',
                                color: _green,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OfficerEventsScreen(
                                      orgId: orgId,
                                      orgName: orgName,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Footer hint ────────────────────────────────────
                      Center(
                        child: Text(
                          'Tap any card to get started',
                          style: TextStyle(
                            fontSize: 12,
                            // FIX 5: Darker grey for WCAG contrast compliance
                            color: Colors.grey[600],
                            letterSpacing: 0.2,
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

  void _showApplicationFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const _SectionLabel(text: 'Filter Applications'),
            const SizedBox(height: 16),
            _FilterRow(
              context: context,
              filters: const [
                _FilterDef(
                    'All', Icons.list_alt_rounded, null, Color(0xFF4F46E5)),
                _FilterDef('Pending', Icons.hourglass_top_rounded, 'pending',
                    Color(0xFFF59E0B)),
                _FilterDef('For Approval', Icons.approval_rounded,
                    'forApproval', Color(0xFF06B6D4)),
              ],
            ),
            const SizedBox(height: 10),
            _FilterRow(
              context: context,
              filters: const [
                _FilterDef('Interviewees', Icons.people_alt_rounded,
                    'interviewed', Color(0xFF8B5CF6)),
                _FilterDef('Approved', Icons.check_circle_rounded, 'approved',
                    Color(0xFF22C55E)),
                _FilterDef('Declined', Icons.cancel_rounded, 'declined',
                    Color(0xFFEF4444)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _OfficerHeroHeader — FIX 1: Corrected text, improved spacing & chip layout
// =============================================================================
class _OfficerHeroHeader extends StatelessWidget {
  final Color primary;
  final Color secondary;
  final Organization org;

  const _OfficerHeroHeader({
    required this.primary,
    required this.secondary,
    required this.org,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Proportional logo that never gets too big or too small
    final logoSize = (size.width * 0.14).clamp(52.0, 72.0);

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
          // Decorative orbs — keep subtle depth
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: -40,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),

          // Content row — centred vertically in the expanded area
          SafeArea(
            child: Padding(
              // Push content below the collapsed app bar title (~56 px)
              padding: const EdgeInsets.only(top: 56),
              child: Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── Circular Logo ──────────────────────────────────
                      _OrgLogoCircle(
                        logoAsset: org.logoAsset,
                        logoSize: logoSize,
                      ),

                      // FIX 1: Adequate gap between logo and text
                      const SizedBox(width: 16),

                      // ── Name + Officer chip ────────────────────────────
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // FIX 1: Corrected title-case spelling
                            Text(
                              'BCC Peers Facilitators Circles',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                                height: 1.3,
                              ),
                            ),

                            // FIX 1: 8 px breathing room before the chip
                            const SizedBox(height: 8),

                            _OfficerChip(),
                          ],
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
// _OrgLogoCircle — extracted for readability
// =============================================================================
class _OrgLogoCircle extends StatelessWidget {
  final String logoAsset;
  final double logoSize;

  const _OrgLogoCircle({
    required this.logoAsset,
    required this.logoSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: logoSize + 10,
      height: logoSize + 10,
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
            child: ClipOval(
              child: Image.asset(
                logoAsset,
                width: logoSize,
                height: logoSize,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => CircleAvatar(
                  radius: logoSize / 2,
                  backgroundColor: const Color(0xFFE0E7FF),
                  child: const Icon(
                    Icons.groups_rounded,
                    color: Color(0xFF4F46E5),
                    size: 28,
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

// =============================================================================
// _OfficerChip — extracted pill badge
// =============================================================================
class _OfficerChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.30),
          width: 1,
        ),
      ),
      child: const Text(
        'Officer',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// =============================================================================
// _ApplicationsCard — FIX 3: Replaced vague box with clear chevron + ListTile
// =============================================================================
class _ApplicationsCard extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _ApplicationsCard({
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      shadowColor: color.withOpacity(0.15),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withOpacity(0.07),
        highlightColor: color.withOpacity(0.04),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.85), color],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.list_alt_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),

              const SizedBox(width: 14),

              // Text
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Manage Applications',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Review and process student applications',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey[400],
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _GridActionCard — FIX 4: Proportional layout, full-card tap, balanced arrow
// =============================================================================
class _GridActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _GridActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      shadowColor: color.withOpacity(0.12),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withOpacity(0.07),
        highlightColor: color.withOpacity(0.04),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // FIX 4: Top row — icon left, arrow right (logical position)
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // FIX 4: Proportionally sized icon container (~32 px icon)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Title
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),

              const SizedBox(height: 4),

              // Subtitle
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                ),
              ),

              const Spacer(), // pushes the arrow to the bottom

              // 👇 Arrow moved HERE (bottom-right)
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: color,
                    size: 16,
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

// =============================================================================
// _FilterRow + _FilterDef (unchanged logic, minor padding tweak)
// =============================================================================
class _FilterDef {
  final String label;
  final IconData icon;
  final String? filter;
  final Color color;
  const _FilterDef(this.label, this.icon, this.filter, this.color);
}

class _FilterRow extends StatelessWidget {
  final BuildContext context;
  final List<_FilterDef> filters;

  const _FilterRow({required this.context, required this.filters});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: filters
          .map(
            (f) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            OfficerApplicationsScreen(filter: f.filter),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: f.color.withOpacity(0.25),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: f.color.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(f.icon, color: f.color, size: 18),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            f.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: f.color,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// =============================================================================
// _SectionLabel — FIX 2: Slightly bolder weight, balanced padding
// =============================================================================
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Accent bar
        Container(
          width: 3,
          height: 16,
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
        // FIX 2: w800 instead of w700 — reads more clearly as a section header
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color:
                Color(0xFF64748B), // slightly darker than before for contrast
          ),
        ),
      ],
    );
  }
}
