import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_state.dart';
import 'officer_applications_screen.dart';
import 'officer_members_screen.dart';
import 'officer_events_screen.dart';
import '../auth/unified_login_page.dart';
import 'officer_org_profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BaseOfficerDashboard extends StatefulWidget {
  final String orgId;
  final String orgName;

  const BaseOfficerDashboard({
    super.key,
    required this.orgId,
    required this.orgName,
  });

  @override
  State<BaseOfficerDashboard> createState() => _BaseOfficerDashboardState();
}

class _BaseOfficerDashboardState extends State<BaseOfficerDashboard> {
  static const Color _primary = Color(0xFF4F46E5);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _background = Color(0xFFF8FAFC);
  static const Color _cardSurface = Colors.white;
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _green = Color(0xFF22C55E);

  // ── Double-tap-to-exit state ───────────────────────────────────────────────
  DateTime? _lastBackPressed;

  // ── End drawer key ─────────────────────────────────────────────────────────
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

// ── Pending applications badge ─────────────────────────────────────────────
// ── Application counts per status ─────────────────────────────────────────
  int _pendingCount = 0;
  int _lastDismissedCount = -1;
  Map<String, int> _statusCounts = {};

  @override
  void initState() {
    super.initState();
    _initBadge();
    AppState.instance.fetchEvents();
  }

  Future<void> _initBadge() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt('badge_dismissed_${widget.orgId}') ?? 0;
    if (mounted) setState(() => _lastDismissedCount = stored);
    await _fetchApplicationCounts();
  }

  Future<void> _fetchApplicationCounts() async {
    try {
      final response = await Supabase.instance.client
          .from('applications')
          .select('status')
          .eq('org_name', widget.orgName);

      final list = response as List;

      final Map<String, int> counts = {};
      for (final row in list) {
        final status = row['status'] as String? ?? '';
        counts[status] = (counts[status] ?? 0) + 1;
      }

      if (mounted) {
        setState(() {
          _statusCounts = counts;
          _pendingCount = counts['pending'] ?? 0;
          // ← _badgeDismissed = false is REMOVED
        });
      }
    } catch (_) {}
  }

  Future<void> _dismissBadge() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('badge_dismissed_${widget.orgId}', _pendingCount);
    if (mounted) setState(() => _lastDismissedCount = _pendingCount);
  }

  bool get _showBadge =>
      _lastDismissedCount >= 0 && _pendingCount > _lastDismissedCount;

  // ── Logout confirmation dialog ─────────────────────────────────────────────
  Future<void> _showLogoutDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Log out of OrgConnect?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        content: const Text(
          'Are you sure you want to log out of your account? '
          'You will need to enter your credentials to log back in.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          // Cancel
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          // Log Out (destructive)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop(); // close dialog
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const UnifiedLoginPage()),
                  (route) => false,
                );
              }
            },
            child: const Text(
              'Log Out',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ── Toast overlay for "tap again to exit" ─────────────────────────────────
  OverlayEntry? _toastEntry;

  void _showExitToast() {
    _toastEntry?.remove();
    _toastEntry = OverlayEntry(
      builder: (_) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.88),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                'Tap again to exit',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_toastEntry!);
    Future.delayed(const Duration(seconds: 2), () {
      _toastEntry?.remove();
      _toastEntry = null;
    });
  }

  @override
  void dispose() {
    _toastEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // ── Double-tap-to-exit via PopScope ───────────────────────────────────
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final org = AppState.instance.organizations.firstWhere(
          (o) => o.id == widget.orgId,
          orElse: () => Organization(
            id: widget.orgId,
            name: widget.orgName,
            logoAsset: '',
            shortDesc: '',
          ),
        );

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            final now = DateTime.now();
            if (_lastBackPressed == null ||
                now.difference(_lastBackPressed!) >
                    const Duration(seconds: 2)) {
              _lastBackPressed = now;
              _showExitToast();
            } else {
              SystemChannels.platform.invokeMethod('SystemNavigator.pop');
            }
          },
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: _background,

            // ── End Drawer (slides from right) ─────────────────────────────────
            endDrawer: _ProfileEndDrawer(
              onLogoutTap: () {
                Navigator.of(context).pop(); // close drawer first
                _showLogoutDialog();
              },
            ),

            body: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── App Bar ──────────────────────────────────────────────────────
                SliverAppBar(
                  pinned: true,
                  expandedHeight: size.height * 0.22,
                  backgroundColor: _primary,
                  elevation: 0,
                  // Objective 1: No leading back button
                  automaticallyImplyLeading: false,
                  leading: const SizedBox.shrink(),

                  centerTitle: true,
                  // Objective 2: Top-right profile icon
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: IconButton(
                        icon: const Icon(
                          Icons.account_circle,
                          color: Colors.white,
                          size: 28,
                        ),
                        tooltip: 'Profile',
                        onPressed: () =>
                            _scaffoldKey.currentState?.openEndDrawer(),
                      ),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: _OfficerHeroHeader(
                      primary: _primary,
                      secondary: _secondary,
                      org: org,
                    ),
                  ),
                ),

                // ── Body ─────────────────────────────────────────────────────────
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
                              pendingCount: _showBadge ? _pendingCount : 0,
                              onTap: () => _showApplicationFilters(
                                  context, _statusCounts),
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
                                            orgId: widget.orgId,
                                            orgName: widget.orgName,
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
          ),
        );
      },
    );
  }

  void _showApplicationFilters(BuildContext context, Map<String, int> counts) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
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
                context: sheetContext,
                onFilterTapped: () {
                  _dismissBadge();
                  setSheetState(() {});
                },
                filters: [
                  _FilterDef('All', Icons.list_alt_rounded, null,
                      const Color(0xFF4F46E5), 0),
                  _FilterDef(
                      'Pending',
                      Icons.hourglass_top_rounded,
                      'pending',
                      const Color(0xFFF59E0B),
                      _showBadge ? (counts['pending'] ?? 0) : 0),
                  _FilterDef(
                      'For Approval',
                      Icons.approval_rounded,
                      'forApproval',
                      const Color(0xFF06B6D4),
                      _showBadge ? (counts['for_approval'] ?? 0) : 0),
                ],
              ),
              const SizedBox(height: 10),
              _FilterRow(
                context: sheetContext,
                onFilterTapped: () {
                  _dismissBadge();
                  setSheetState(() {});
                },
                filters: [
                  _FilterDef('Interviewees', Icons.people_alt_rounded,
                      'interviewed', const Color(0xFF8B5CF6), 0),
                  _FilterDef('Approved', Icons.check_circle_rounded, 'approved',
                      const Color(0xFF22C55E), 0),
                  _FilterDef('Declined', Icons.cancel_rounded, 'declined',
                      const Color(0xFFEF4444), 0),
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
// _ProfileEndDrawer — slides from the right, profile header + logout tile
// =============================================================================
class _ProfileEndDrawer extends StatelessWidget {
  final VoidCallback onLogoutTap;

  const _ProfileEndDrawer({required this.onLogoutTap});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'Officer';
    final topPadding = MediaQuery.of(context).padding.top;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.50,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
      ),
      child: Column(
        // ← removed SafeArea
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                24, topPadding + 20, 24, 24), // ← manual top inset
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.40),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: () {
                      final orgId = AppState.instance.currentOfficerOrgId;
                      final org = orgId != null
                          ? AppState.instance.organizations.firstWhere(
                              (o) => o.id == orgId,
                              orElse: () => Organization(
                                  id: '',
                                  name: '',
                                  logoAsset: '',
                                  shortDesc: ''),
                            )
                          : null;
                      final logo = org?.logoAsset ?? '';

                      if (logo.startsWith('http')) {
                        return CachedNetworkImage(
                          imageUrl: logo,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Icon(
                            Icons.account_circle,
                            color: Colors.white,
                            size: 36,
                          ),
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.account_circle,
                            color: Colors.white,
                            size: 36,
                          ),
                        );
                      }
                      return const Icon(
                        Icons.account_circle,
                        color: Colors.white,
                        size: 36,
                      );
                    }(),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.30),
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
                ),
                const SizedBox(height: 8),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Text(
              'ACCOUNT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: Colors.grey[400],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: Color(0xFF4F46E5),
                  size: 20,
                ),
              ),
              title: const Text(
                'Edit Org Profile',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              subtitle: const Text(
                'Update logo & info',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                ),
              ),
              onTap: () {
                Navigator.of(context).pop(); // close drawer first
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OfficerOrgProfileScreen(
                      orgId: AppState.instance.currentOfficerOrgId!,
                    ),
                  ),
                );
              },
            ),
          ),

          const Spacer(),
          const Divider(
            height: 1,
            indent: 24,
            endIndent: 24,
            color: Color(0xFFE2E8F0),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFEF4444),
                  size: 20,
                ),
              ),
              title: const Text(
                'Log Out',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFEF4444),
                ),
              ),
              subtitle: const Text(
                'Sign out of your account',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                ),
              ),
              onTap: onLogoutTap,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                24, 0, 24, MediaQuery.of(context).padding.bottom + 16),
            child: Text(
              'OrgConnect • Officer Portal',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[400],
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _OfficerHeroHeader
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 56),
              child: Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _OrgLogoCircle(
                        logoAsset: org.logoAsset,
                        logoSize: logoSize,
                      ),
                      const SizedBox(width: 16),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              org.name,
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
// _OrgLogoCircle
// =============================================================================
class _OrgLogoCircle extends StatelessWidget {
  final String logoAsset;
  final double logoSize;

  const _OrgLogoCircle({
    required this.logoAsset,
    required this.logoSize,
  });

  Widget _buildLogoImage(String logoAsset, double logoSize) {
    if (logoAsset.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: logoAsset,
        width: logoSize,
        height: logoSize,
        fit: BoxFit.cover,
        placeholder: (context, url) => CircleAvatar(
          radius: logoSize / 2,
          backgroundColor: const Color(0xFFE0E7FF),
          child: const Icon(
            Icons.groups_rounded,
            color: Color(0xFF4F46E5),
            size: 28,
          ),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: logoSize / 2,
          backgroundColor: const Color(0xFFE0E7FF),
          child: const Icon(
            Icons.groups_rounded,
            color: Color(0xFF4F46E5),
            size: 28,
          ),
        ),
      );
    }

    if (logoAsset.isNotEmpty) {
      return Image.asset(
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
      );
    }
    return CircleAvatar(
      radius: logoSize / 2,
      backgroundColor: const Color(0xFFE0E7FF),
      child: const Icon(
        Icons.groups_rounded,
        color: Color(0xFF4F46E5),
        size: 28,
      ),
    );
  }

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
              child: _buildLogoImage(logoAsset, logoSize),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _OfficerChip
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
// _ApplicationsCard
// =============================================================================
class _ApplicationsCard extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;
  final int pendingCount;

  const _ApplicationsCard({
    required this.color,
    required this.onTap,
    this.pendingCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final String badgeLabel = pendingCount > 9 ? '9+' : '$pendingCount';
    final bool showBadge = pendingCount > 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
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
        ),

        // ── Badge ──────────────────────────────────────────────────────────
        if (showBadge)
          Positioned(
            top: -10,
            right: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withOpacity(0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                badgeLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// _GridActionCard
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
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const Spacer(),
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
// _FilterRow + _FilterDef
// =============================================================================
// =============================================================================
// _FilterRow + _FilterDef
// =============================================================================
class _FilterDef {
  final String label;
  final IconData icon;
  final String? filter;
  final Color color;
  final int count;
  const _FilterDef(this.label, this.icon, this.filter, this.color, this.count);
}

class _FilterRow extends StatelessWidget {
  final BuildContext context;
  final List<_FilterDef> filters;
  final VoidCallback onFilterTapped;

  const _FilterRow({
    required this.context,
    required this.filters,
    required this.onFilterTapped,
  });

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
                    onTap: () {
                      onFilterTapped();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              OfficerApplicationsScreen(filter: f.filter),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: f.color.withOpacity(0.25),
                          width: 1.2,
                        ),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // ── Main content ──────────────────────────────
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Center(
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: f.color.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Icon(f.icon, color: f.color, size: 18),
                                ),
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),

                          // ── Circle badge (inside, top-right) ──────────
                          if (f.count > 0)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: f.color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: f.color.withOpacity(0.35),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
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
// _SectionLabel
// =============================================================================
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
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
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}
