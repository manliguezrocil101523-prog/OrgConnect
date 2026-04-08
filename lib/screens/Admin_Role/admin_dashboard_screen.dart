import 'package:flutter/material.dart';
import 'admin_manage_accounts.dart';
import 'admin_reports.dart';
import 'admin_manage_organization.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM — centralised tokens so every widget stays consistent
// ─────────────────────────────────────────────────────────────────────────────
abstract class _DS {
  // ── BASE COLORS — page bg + header match admin_manage_organization.dart ─────
  static const Color bg        = Color(0xFFF5F7FA);
  static const Color surface   = Colors.white;         // [COLOR] white card surfaces
  static const Color primary   = Color(0xFF4F46E5);   // [COLOR] indigo-600 primary accent
  static const Color primaryDk = Color(0xFF4338CA);   // [COLOR] indigo-700 for gradients/headers
  /// Same as AdminOrganizationsScreen AppBar `primary` (slate header)
  static const Color chromeHeader = Color(0xFF1E293B);
  static const Color onPrimary = Colors.white;

  // ── TEXT COLORS ────────────────────────────────────────────────────────────
  static const Color textHd    = Color(0xFF1E293B);   // [COLOR] slate-800 primary text
  static const Color textSub   = Color(0xFF64748B);   // [COLOR] slate-500 secondary text

  // ── BORDER / DIVIDER ───────────────────────────────────────────────────────
  static const Color divider   = Color(0xFFE2E8F0);   // [COLOR] slate-200 borders

  // Radii (unchanged)
  static const double radiusCard   = 20;
  static const double radiusChip   = 40;

  // ── SHADOWS — tinted with indigo to match new accent ──────────────────────
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF4F46E5).withOpacity(0.08), // [COLOR] indigo shadow tint
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT — AdminDashboard (no logic changed, only UI rebuilt)
// ─────────────────────────────────────────────────────────────────────────────
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.bg,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(64 + MediaQuery.of(context).padding.top),
        child: _DashboardAppBar(),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isWide = constraints.maxWidth >= 640;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 40 : 20,
                vertical: 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _WelcomeBanner(),
                  const SizedBox(height: 28),
                  const _StatStrip(),
                  const SizedBox(height: 32),
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: _DS.textSub,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _NavGrid(isWide: isWide),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP BAR
// ─────────────────────────────────────────────────────────────────────────────
class _DashboardAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _DS.chromeHeader,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: MediaQuery.of(context).padding.top,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20), // [COLOR] frosted white
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.dashboard_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Admin Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          _AdminChip(),
        ],
      ),
    );
  }
}

class _AdminChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),   // [COLOR] semi-transparent white pill
        borderRadius: BorderRadius.circular(_DS.radiusChip),
        border: Border.all(color: Colors.white.withOpacity(0.30)), // [COLOR] subtle white border
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.white.withOpacity(0.35), // [COLOR] frosted white avatar bg
            child: const Icon(Icons.person_rounded,
                size: 14, color: Colors.white),
          ),
          const SizedBox(width: 7),
          const Text(
            'Admin',
            style: TextStyle(
              color: Colors.white, // [COLOR] white label on dark header
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WELCOME BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        color: _DS.chromeHeader,
        borderRadius: BorderRadius.circular(_DS.radiusCard),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Welcome back 👋',
                  style: TextStyle(
                    color: Colors.white70, // [COLOR] softened white for subtext
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'System Overview',
                  style: TextStyle(
                    color: Colors.white, // [COLOR] full white headline
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Manage your platform from one place.',
                  style: TextStyle(
                    color: Colors.white70, // [COLOR] muted white body copy
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15), // [COLOR] frosted icon circle
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAT STRIP — summary cards (UI only; plug in real data when available)
// ─────────────────────────────────────────────────────────────────────────────
class _StatStrip extends StatelessWidget {
  const _StatStrip();

  static const _stats = [
    // [COLOR] blue accent for Users stat
    _StatData(Icons.people_alt_outlined,  'Total Users',   '—', Color(0xFF3B82F6)),
    // [COLOR] violet accent for Orgs stat
    _StatData(Icons.apartment_outlined,   'Organizations', '—', Color(0xFF8B5CF6)),
    // [COLOR] amber/warning accent for Reports stat
    _StatData(Icons.bar_chart_rounded,    'Reports',       '—', Color(0xFFF59E0B)),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _stats.map((s) {
        final isLast = s == _stats.last;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 12),
            child: _StatCard(data: s),
          ),
        );
      }).toList(),
    );
  }
}

class _StatData {
  final IconData  icon;
  final String    label;
  final String    value;
  final Color     accent;
  const _StatData(this.icon, this.label, this.value, this.accent);
}

class _StatCard extends StatelessWidget {
  final _StatData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: _DS.surface, // [COLOR] #FFFFFF white card
        borderRadius: BorderRadius.circular(16),
        boxShadow: _DS.cardShadow,
        border: Border.all(color: _DS.divider), // [COLOR] #E2E8F0 hairline border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: data.accent.withOpacity(0.10), // [COLOR] tinted icon badge bg
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, size: 18, color: data.accent), // [COLOR] status accent icon
          ),
          const SizedBox(height: 10),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _DS.textHd, // [COLOR] #1E293B strong heading
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            style: const TextStyle(
              fontSize: 11,
              color: _DS.textSub, // [COLOR] #64748B muted label
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAVIGATION CARD GRID — 2-col on wide / 1-col on narrow
// ─────────────────────────────────────────────────────────────────────────────
class _NavGrid extends StatelessWidget {
  final bool isWide;
  const _NavGrid({required this.isWide});

  static const _items = [
    _NavItem(
      icon:        Icons.manage_accounts_outlined,
      title:       'Manage Accounts',
      description: 'Create, update, and deactivate user accounts across the platform.',
      accent:      _DS.primary,          // [COLOR] #4F46E5 indigo — primary action
      dest:        _NavDest.accounts,
    ),
    _NavItem(
      icon:        Icons.apartment_outlined,
      title:       'Manage Organizations',
      description: 'Oversee organisation profiles, memberships, and settings.',
      accent:      Color(0xFF8B5CF6),    // [COLOR] violet — secondary action
      dest:        _NavDest.orgs,
    ),
    _NavItem(
      icon:        Icons.insights_outlined,
      title:       'Reports',
      description: 'View analytics, activity logs, and export system reports.',
      accent:      Color(0xFFF59E0B),    // [COLOR] amber/warning — reports action
      dest:        _NavDest.reports,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (isWide) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   2,
          mainAxisSpacing:  16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.55,
        ),
        itemCount: _items.length,
        itemBuilder: (_, i) => _DashboardCard(item: _items[i]),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < _items.length; i++) ...[
          _DashboardCard(item: _items[i]),
          if (i < _items.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

enum _NavDest { accounts, orgs, reports }

class _NavItem {
  final IconData  icon;
  final String    title;
  final String    description;
  final Color     accent;
  final _NavDest  dest;
  const _NavItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.dest,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD CARD — reusable, animated, elevated navigation tile
// ─────────────────────────────────────────────────────────────────────────────
class _DashboardCard extends StatefulWidget {
  final _NavItem item;
  const _DashboardCard({required this.item});

  @override
  State<_DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<_DashboardCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
    lowerBound: 0.0,
    upperBound: 0.03,
  );

  double get _scale => 1.0 - _ctrl.value;

  void _navigate(BuildContext context) {
    final route = switch (widget.item.dest) {
      _NavDest.accounts => MaterialPageRoute(
          builder: (_) => const AdminAccountsScreen()),
      _NavDest.orgs => MaterialPageRoute(
          builder: (_) => const AdminOrganizationsScreen()),
      _NavDest.reports => MaterialPageRoute(
          builder: (_) => const AdminReportsScreen()),
    };
    Navigator.push(context, route);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight =
            constraints.hasBoundedHeight && constraints.maxHeight < double.infinity;

        return GestureDetector(
          onTapDown:   (_) => _ctrl.forward(),
          onTapUp:     (_) { _ctrl.reverse(); _navigate(context); },
          onTapCancel: ()  => _ctrl.reverse(),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) => Transform.scale(scale: _scale, child: child),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _DS.surface,         // [COLOR] #FFFFFF white card surface
                borderRadius: BorderRadius.circular(_DS.radiusCard),
                boxShadow: _DS.cardShadow,
                border: Border.all(color: _DS.divider), // [COLOR] #E2E8F0 hairline border
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: widget.item.accent.withOpacity(0.10), // [COLOR] tinted icon badge
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.item.icon,
                        size: 24, color: widget.item.accent), // [COLOR] per-card accent icon
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.item.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _DS.textHd,   // [COLOR] #1E293B strong card title
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.item.description,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: _DS.textSub,  // [COLOR] #64748B muted description
                      height: 1.5,
                    ),
                  ),
                  if (hasBoundedHeight) const Spacer() else const SizedBox(height: 18),
                  Row(
                    children: [
                      Text(
                        'Open',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: widget.item.accent, // [COLOR] per-card accent CTA label
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded,
                          size: 14, color: widget.item.accent), // [COLOR] per-card accent arrow
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}