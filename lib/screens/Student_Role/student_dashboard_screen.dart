import 'dart:convert';
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter/services.dart';
import '../../core/app_state.dart';
import '../../core/analytics_service.dart';
import '../analytics/event_comments_sheet.dart';
import '/screens/notifications/notification_screen.dart';
import '/screens/Student_Role/student_dashboard_events.dart';
import '/screens/profile/profile_screen.dart';
import '../community/org_community_chat_screen.dart';
import '/screens/organizations/org_list_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  // ─── Color tokens — MUST match ProfileScreen exactly ─────────────────────
  static const Color _primary = Color(0xFF16A34A);
  static const Color _secondary = Color(0xFF0F766E);
  static const Color _background = Color(0xFFF0FDF4);

  // Per-action accent colors — all within the permitted palette
  static const Color _profileAccent = Color(0xFF16A34A);
  static const Color _orgAccent = Color(0xFF0F766E);
  static const Color _notifAccent = Color(0xFF22C55E);
  static const Color _eventsAccent = Color(0xFF15803D);

  // ─── Double-tap-to-exit state tracker ────────────────────────────────────
  DateTime? _lastBackPressed;
  int _selectedIndex = 0;

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

  void _onAppStateChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

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
        body: IndexedStack(
          index: _selectedIndex,
          children: const [
            _HomeTab(),
            OrgListScreen(),
            StudentDashboard(),
            ProfileScreen(),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(unreadCount),
      ),
    );
  }

  Widget _buildBottomNav(int unreadCount) {
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = (screenWidth * 0.065).clamp(22.0, 30.0);
    final fontSize = (screenWidth * 0.028).clamp(10.0, 13.0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: (screenWidth * 0.18).clamp(56.0, 72.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                index: 0,
                selectedIndex: _selectedIndex,
                iconSize: iconSize,
                fontSize: fontSize,
                primaryColor: _primary,
                onTap: () => setState(() => _selectedIndex = 0),
              ),
              _NavItem(
                icon: Icons.groups_rounded,
                label: 'Orgs',
                index: 1,
                selectedIndex: _selectedIndex,
                iconSize: iconSize,
                fontSize: fontSize,
                primaryColor: _orgAccent,
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              _NavItem(
                icon: Icons.calendar_month_rounded,
                label: 'Events',
                index: 2,
                selectedIndex: _selectedIndex,
                iconSize: iconSize,
                fontSize: fontSize,
                primaryColor: _eventsAccent,
                onTap: () => setState(() => _selectedIndex = 2),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                index: 3,
                selectedIndex: _selectedIndex,
                iconSize: iconSize,
                fontSize: fontSize,
                primaryColor: _profileAccent,
                onTap: () => setState(() => _selectedIndex = 3),
              ),
            ],
          ),
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
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
                        ListenableBuilder(
                          listenable: AppState.instance,
                          builder: (context, _) {
                            final fullName =
                                AppState.instance.currentStudent?.name ?? '';
                            final firstName = fullName.trim().split(' ').first;
                            final greeting = firstName.isNotEmpty
                                ? 'Welcome Back, $firstName 👋'
                                : 'Welcome Back 👋';
                            return Text(
                              greeting,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.1,
                                height: 1.15,
                              ),
                            );
                          },
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
        ],
      ),
    );
  }

  // paste here ↓
  Widget _buildAvatar(double avatarSize) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
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
                color: const Color(0xFF16A34A),
              )
            : null;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: CircleAvatar(
            key: ValueKey(avatarUrl),
            radius: avatarSize / 2,
            backgroundColor: const Color(0xFFE0E7FF),
            backgroundImage: bgImage,
            child: fallbackChild,
          ),
        );
      },
    );
  }
} // ← this is the original closing brace of _HeroHeader

// =============================================================================
// _HeroBottomStrip — scrolls away with the page (NOT inside SliverAppBar)
// =============================================================================
class _HeroBottomStrip extends StatelessWidget {
  final Color primary;
  final Color secondary;

  const _HeroBottomStrip({
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final student = AppState.instance.currentStudent;
    final joinedCount = student?.joinedOrgIds.length ?? 0;
    final applicationCount = AppState.instance.applications
        .where((a) => a.userId == student?.id || a.studentId == student?.studentId)
        .length;
    final updateCount = AppState.instance.notifications
        .where((n) => (n.studentId == student?.id || n.studentId == student?.studentId) && !n.read)
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _HeroStatChip(
            label: 'Applications',
            value: applicationCount.toString(),
            icon: Icons.assignment_rounded,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _MyApplicationsScreen())),
          )),
          _VerticalDividerChip(),
          Expanded(child: _HeroStatChip(
            label: 'Joined Orgs',
            value: joinedCount.toString(),
            icon: Icons.groups_rounded,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _JoinedOrganizationsScreen())),
          )),
          _VerticalDividerChip(),
          Expanded(child: _HeroStatChip(
            label: 'Notifications',
            value: updateCount.toString(),
            icon: Icons.notifications_active_rounded,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
          )),
        ],
      ),
    );
  }
}

// =============================================================================
// _HeroStatChip  (UNCHANGED)
// =============================================================================
class _HeroStatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _HeroStatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.16)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 17),
                    if (value != '0') Positioned(
                      right: -1, top: -3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: Text(value, style: const TextStyle(color: Color(0xFF0F766E), fontSize: 8, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              const Text('Tap to open', style: TextStyle(color: Colors.white70, fontSize: 8.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
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
// Student quick-access screens
// =============================================================================
class _MyApplicationsScreen extends StatelessWidget {
  const _MyApplicationsScreen();

  @override
  Widget build(BuildContext context) {
    final student = AppState.instance.currentStudent;
    final apps = AppState.instance.applications
        .where((a) => a.userId == student?.id || a.studentId == student?.studentId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: const Color(0xFFF1FAF6),
      appBar: AppBar(title: const Text('My Applications')),
      body: apps.isEmpty
          ? const _QuickEmpty(
              icon: Icons.assignment_outlined,
              title: 'No applications yet',
              subtitle: 'Organizations you apply to will appear here with their current status.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
              itemCount: apps.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _ApplicationCard(application: apps[i]),
            ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final Application application;
  const _ApplicationCard({required this.application});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(application.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBE8DC)),
        boxShadow: const [BoxShadow(color: Color(0x090F8A61), blurRadius: 15, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: const Color(0xFFE4F7EF), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.groups_rounded, color: Color(0xFF0F8A61)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(application.orgName, style: const TextStyle(color: Color(0xFF173B30), fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  'Applied ${application.createdAt.month}/${application.createdAt.day}/${application.createdAt.year}',
                  style: const TextStyle(color: Color(0xFF6B8178), fontSize: 11.5),
                ),
                if (application.status == ApplicationStatus.declined && application.declineReason.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Reason: ${application.declineReason}', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 11.5, height: 1.35)),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(12)),
            child: Text(_statusLabel(application.status), style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  static Color _statusColor(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.accepted:
        return const Color(0xFF0F8A61);
      case ApplicationStatus.declined:
        return const Color(0xFFDC2626);
      case ApplicationStatus.interviewed:
      case ApplicationStatus.interview_scheduled:
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF2563EB);
    }
  }

  static String _statusLabel(ApplicationStatus status) {
    return status.name
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}

class _JoinedOrganizationsScreen extends StatefulWidget {
  const _JoinedOrganizationsScreen();

  @override
  State<_JoinedOrganizationsScreen> createState() => _JoinedOrganizationsScreenState();
}

class _JoinedOrganizationsScreenState extends State<_JoinedOrganizationsScreen> {
  final Set<String> _joinedOrgIds = <String>{};
  final Set<String> _joinedOrgNames = <String>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadJoinedOrganizations());
  }

  Future<void> _loadJoinedOrganizations() async {
    if (mounted) setState(() => _loading = true);
    try {
      await AppState.instance.loadStudentProfile();
      await AppState.instance.fetchOrganizations();
      await AppState.instance.fetchApplications();
      await AppState.instance.fetchMembers();
      await AppState.instance.syncCurrentStudentMemberships();

      final student = AppState.instance.currentStudent;
      final ids = <String>{...?student?.joinedOrgIds};
      final names = <String>{};

      // Existing member rows.
      for (final member in AppState.instance.members) {
        final profileMatch = member.profileId == student?.id;
        final legacyNameMatch = student != null &&
            student.name.trim().isNotEmpty &&
            member.name.trim().toLowerCase() == student.name.trim().toLowerCase();
        if (!profileMatch && !legacyNameMatch) continue;
        final memberId = member.orgId?.trim();
        if (memberId != null && memberId.isNotEmpty) ids.add(memberId);
        final memberName = member.orgName.trim().toLowerCase();
        if (memberName.isNotEmpty) names.add(memberName);
      }

      // Use the applications already fetched for the signed-in student.
      // Supabase RLS permits students to read their own applications, so this
      // stays within AppState and avoids a second client-specific query here.
      for (final application in AppState.instance.applications) {
        final status = application.status.name.toLowerCase();
        if (status != 'approved' && status != 'accepted') continue;

        final matchesUser = student != null &&
            application.userId != null && application.userId == student.id;
        final matchesStudentId = student != null &&
            student.studentId.trim().isNotEmpty &&
            application.studentId.trim() == student.studentId.trim();
        if (!matchesUser && !matchesStudentId) continue;

        final orgId = application.orgId?.trim();
        final orgName = application.orgName.trim();
        if (orgId != null && orgId.isNotEmpty) ids.add(orgId);
        if (orgName.isNotEmpty) names.add(orgName.toLowerCase());
      }

      // Name matching is a fallback for old records whose org_id is missing or
      // no longer matches the current organizations row.
      for (final org in AppState.instance.organizations) {
        if (names.contains(org.name.trim().toLowerCase())) ids.add(org.id);
      }

      if (mounted) {
        setState(() {
          _joinedOrgIds
            ..clear()
            ..addAll(ids);
          _joinedOrgNames
            ..clear()
            ..addAll(names);
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading Joined Orgs: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final joined = AppState.instance.organizations
            .where((org) =>
                _joinedOrgIds.contains(org.id) ||
                _joinedOrgNames.contains(org.name.trim().toLowerCase()))
            .toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF1FAF6),
          appBar: AppBar(title: const Text('Organizations I Joined')),
          body: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0F8A61)),
                )
              : joined.isEmpty
                  ? const _QuickEmpty(
                      icon: Icons.groups_outlined,
                      title: 'No organizations joined yet',
                      subtitle: 'When an application is accepted, your organization will appear here.',
                    )
                  : RefreshIndicator(
                      onRefresh: _loadJoinedOrganizations,
                      color: const Color(0xFF0F8A61),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                        itemCount: joined.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _JoinedOrgCard(org: joined[i]),
                      ),
                    ),
        );
      },
    );
  }
}

class _JoinedOrgCard extends StatelessWidget {
  final Organization org;
  const _JoinedOrgCard({required this.org});

  @override
  Widget build(BuildContext context) {
    final updates = AppState.instance.notifications.where((n) => n.orgId == org.id).length;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _MemberOrganizationSpace(org: org))),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFCBE8DC)),
            boxShadow: const [BoxShadow(color: Color(0x090F8A61), blurRadius: 15, offset: Offset(0, 6))],
          ),
          child: Row(
            children: [
              _OrgLogo(asset: org.logoAsset, size: 62),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(org.name, style: const TextStyle(color: Color(0xFF173B30), fontSize: 15, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      org.shortDesc.isEmpty ? 'Your member community' : org.shortDesc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF6B8178), fontSize: 11.5, height: 1.35),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(Icons.campaign_rounded, size: 14, color: Color(0xFF0F8A61)),
                        const SizedBox(width: 4),
                        Text('$updates updates', style: const TextStyle(color: Color(0xFF0F8A61), fontSize: 10.5, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B8178)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberOrganizationSpace extends StatefulWidget {
  final Organization org;
  const _MemberOrganizationSpace({required this.org});

  @override
  State<_MemberOrganizationSpace> createState() => _MemberOrganizationSpaceState();
}

class _MemberOrganizationSpaceState extends State<_MemberOrganizationSpace> {
  final _messageController = TextEditingController();
  final List<String> _myMessages = [];
  List<Notification> _orgAnnouncements = <Notification>[];
  bool _loadingCommunity = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCommunityData());
  }

  Future<void> _loadCommunityData() async {
    if (mounted) setState(() => _loadingCommunity = true);
    try {
      await Future.wait([
        AppState.instance.fetchOrganizations(),
        AppState.instance.fetchEvents(),
        AppState.instance.fetchMembers(),
        AppState.instance.fetchNotifications(),
      ]);

      // Only load organization-wide announcements here. Personal notifications
      // such as interview schedules and membership congratulations belong in
      // the student's Notifications screen, not in the organization's feed.
      final announcements = AppState.instance.notifications
          .where((n) => n.orgId == widget.org.id &&
              (n.studentId == null || n.studentId!.trim().isEmpty))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _orgAnnouncements = announcements;
          _loadingCommunity = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading member organization community: $e');
      if (mounted) {
        setState(() {
          _orgAnnouncements = <Notification>[];
          _loadingCommunity = false;
        });
      }
    }
  }

  bool _isFeeAnnouncement(Notification n) {
    final text = '${n.title} ${n.message}'.toLowerCase();
    return RegExp(r'\bfee\b|fees|registration|membership dues|dues|payment|payable|₱|php').hasMatch(text);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final org = widget.org;
    final events = AppState.instance.events
        .where((e) => e.orgId == org.id || e.orgName == org.name)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final members = AppState.instance.members
        .where((m) => m.orgId == org.id || m.orgName == org.name)
        .toList();

    final feeAnnouncements = _orgAnnouncements.where(_isFeeAnnouncement).toList();
    final regularAnnouncements = _orgAnnouncements.where((n) => !_isFeeAnnouncement(n)).toList();
    final officers = org.officers.where((o) => o.trim().isNotEmpty).toList();
    final plans = org.activitiesHighlights
        .map((item) => item.caption.trim().isNotEmpty ? item.caption.trim() : item.content.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1FAF6),
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(org.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: RefreshIndicator(
        onRefresh: _loadCommunityData,
        color: const Color(0xFF0F8A61),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF075A42), Color(0xFF20B77D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  _OrgLogo(asset: org.logoAsset, size: 58),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Member space',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Stay connected with ${org.name}',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Organization announcements only: meetings, reminders, deadlines,
            // rehearsals, orientations, and other messages sent to all members.
            _CommunitySection(
              title: 'Organization announcements',
              icon: Icons.campaign_rounded,
              child: _loadingCommunity
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : regularAnnouncements.isEmpty
                      ? const Text(
                          'No organization announcements have been posted yet. Meeting notices, reminders, deadlines, and other member updates will appear here.',
                          style: TextStyle(color: Color(0xFF6B8178), height: 1.45),
                        )
                      : Column(
                          children: regularAnnouncements.take(10).map((n) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7FCF9),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFDCEFE6)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE4F7EF),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: const Icon(Icons.campaign_rounded, color: Color(0xFF0F8A61)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(n.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 4),
                                        Text(n.message, style: const TextStyle(color: Color(0xFF4E665E), height: 1.35)),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${n.date.month}/${n.date.day}/${n.date.year}',
                                          style: const TextStyle(color: Color(0xFF0F8A61), fontSize: 10.5, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
            ),
            const SizedBox(height: 14),

            // Officers and the organization's current activity/planning list.
            _CommunitySection(
              title: 'Officers & current plans',
              icon: Icons.groups_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (officers.isEmpty)
                    const Text('No officer information has been posted yet.', style: TextStyle(color: Color(0xFF6B8178)))
                  else ...[
                    const Text('Organization officers', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF24463C))),
                    const SizedBox(height: 8),
                    ...officers.map(
                      (officer) => Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.badge_rounded, size: 18, color: Color(0xFF0F8A61)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(officer, style: const TextStyle(color: Color(0xFF526B63), height: 1.3))),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (plans.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    const Divider(height: 22),
                    const Text('Current activities / plans', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF24463C))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: plans.map((plan) => Chip(
                        avatar: const Icon(Icons.lightbulb_outline_rounded, size: 15, color: Color(0xFF0F8A61)),
                        label: Text(plan),
                        backgroundColor: const Color(0xFFE8F7F0),
                        side: BorderSide.none,
                      )).toList(),
                    ),
                  ],
                  if (org.adviser.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Adviser: ${org.adviser}', style: const TextStyle(color: Color(0xFF6B8178), fontSize: 11.5)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Fee/payment notices are pulled from the organization's own
            // organization-wide announcements. Nothing is invented here.
            _CommunitySection(
              title: 'Membership fees & registration',
              icon: Icons.payments_rounded,
              child: feeAnnouncements.isEmpty
                  ? const Text(
                      'No registration fee or payment information has been posted by the organization yet. Check organization announcements for official fee notices.',
                      style: TextStyle(color: Color(0xFF6B8178), height: 1.45),
                    )
                  : Column(
                      children: feeAnnouncements.take(6).map((n) => Container(
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: const Color(0xFFF3E6B3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.receipt_long_rounded, color: Color(0xFFB7791F)),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(n.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 3),
                                  Text(n.message, style: const TextStyle(color: Color(0xFF695B36), height: 1.35)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
            ),
            const SizedBox(height: 14),

            _CommunitySection(
              title: 'Upcoming events',
              icon: Icons.event_rounded,
              child: events.isEmpty
                  ? const Text('No upcoming events posted yet.', style: TextStyle(color: Color(0xFF6B8178)))
                  : Column(
                      children: events.take(8).map((e) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FCF9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFDCEFE6)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE4F7EF),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(Icons.event_rounded, color: Color(0xFF0F8A61)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${e.date.month}/${e.date.day}/${e.date.year}',
                                    style: const TextStyle(color: Color(0xFF0F8A61), fontSize: 11.5, fontWeight: FontWeight.w700),
                                  ),
                                  if (e.description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(e.description, style: const TextStyle(color: Color(0xFF6B8178), fontSize: 12, height: 1.35)),
                                  ],
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => showEventComments(context, eventId: e.id, eventTitle: e.title),
                                    icon: const Icon(Icons.forum_outlined, size: 16),
                                    label: const Text('Comment on event'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF0F8A61),
                                      side: const BorderSide(color: Color(0xFFCBE8DC)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
            ),
            const SizedBox(height: 14),

            _CommunitySection(
              title: 'Members',
              icon: Icons.groups_rounded,
              child: members.isEmpty
                  ? const Text('Member list will appear when membership records are available.', style: TextStyle(color: Color(0xFF6B8178)))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: members.map((m) => Chip(
                        avatar: const CircleAvatar(backgroundColor: Color(0xFFE4F7EF), child: Icon(Icons.person_rounded, size: 15, color: Color(0xFF0F8A61))),
                        label: Text(m.name),
                      )).toList(),
                    ),
            ),
            const SizedBox(height: 14),

            _CommunitySection(
              title: 'Suggestions & community chat',
              icon: Icons.forum_rounded,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Open your organization community. Messages are shared with members, officers, and the adviser in the same organization.', style: TextStyle(color: Color(0xFF496A5D), fontSize: 12, height: 1.4)),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrgCommunityChatScreen(orgId: org.id, orgName: org.name))),
                  icon: const Icon(Icons.forum_rounded),
                  label: const Text('Open Community Chat'),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F8A61), foregroundColor: Colors.white),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrgLogo extends StatelessWidget {
  final String asset;
  final double size;

  const _OrgLogo({required this.asset, required this.size});

  @override
  Widget build(BuildContext context) {
    const fallbackColor = Color(0xFFE4F7EF);
    const iconColor = Color(0xFF0F8A61);

    Widget fallback() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: fallbackColor,
            borderRadius: BorderRadius.circular(17),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.groups_rounded,
            color: iconColor,
            size: 28,
          ),
        );

    final value = asset.trim();
    if (value.isEmpty) return fallback();

    if (value.startsWith('data:')) {
      try {
        final comma = value.indexOf(',');
        if (comma >= 0) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Image.memory(
              base64Decode(value.substring(comma + 1)),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback(),
            ),
          );
        }
      } catch (_) {
        return fallback();
      }
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Image.network(
          value,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback(),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(17),
      child: Image.asset(
        value,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      ),
    );
  }
}

class _CommunitySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _CommunitySection({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBE8DC)),
        boxShadow: const [BoxShadow(color: Color(0x080F8A61), blurRadius: 12, offset: Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color(0xFFE4F7EF), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: const Color(0xFF0F8A61), size: 18)),
            const SizedBox(width: 9),
            Text(title, style: const TextStyle(color: Color(0xFF173B30), fontSize: 15, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 11),
          child,
        ],
      ),
    );
  }
}

class _QuickEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _QuickEmpty({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 72, height: 72, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F8A61), Color(0xFF20B77D)]), borderRadius: BorderRadius.circular(22)), child: Icon(icon, color: Colors.white, size: 32)),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF173B30), fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B8178), fontSize: 12.5, height: 1.45)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _HomeTab — shown when index == 0 (the hero header + welcome content)
// =============================================================================
class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  static const Color _primary = Color(0xFF16A34A);
  static const Color _secondary = Color(0xFF0F766E);

  @override
  void initState() {
    super.initState();
    AppState.instance.fetchEvents();
    AnalyticsService.instance.logUsage('open_student_dashboard', route: 'student/home');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final now = DateTime.now();
        final events = AppState.instance.eventsForCurrentStudent()
            .where((event) => event.date.isAfter(now))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

        return Column(
          children: [
            // The profile symbol in the hero is always synced with the
            // student's saved profile through AppState.
            SizedBox(
              height: (size.height * 0.26).clamp(210.0, 270.0),
              child: _HeroHeader(
                primary: _primary,
                secondary: _secondary,
              ),
            ),
            _HeroBottomStrip(
              primary: _primary,
              secondary: _secondary,
            ),
            // Scrolling intentionally starts at Upcoming Events.
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                interactive: true,
                thickness: 7,
                radius: const Radius.circular(10),
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 4,
                            height: 22,
                            decoration: BoxDecoration(
                              color: _secondary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Upcoming Events', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F0D2E), letterSpacing: -0.4)),
                                Text('Plan ahead for what is coming next.', style: TextStyle(fontSize: 11.5, color: Color(0xFF6B6B8E), fontWeight: FontWeight.w400)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (events.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [_primary, _secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(Icons.event_note_rounded, color: Colors.white, size: 32),
                              ),
                              const SizedBox(height: 16),
                              const Text('No events yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F0D2E))),
                              const SizedBox(height: 6),
                              const Text('Events from your organizations\nwill appear here.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: Color(0xFF6B6B8E), height: 1.55)),
                            ],
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        child: Column(
                          children: events.map((event) => _EventFeedCard(event: event)).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// _NavItem — a single bottom nav tab button
// =============================================================================
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int selectedIndex;
  final double iconSize;
  final double fontSize;
  final Color primaryColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.iconSize,
    required this.fontSize,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == selectedIndex;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              isSelected ? primaryColor.withOpacity(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: isSelected ? primaryColor : const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? primaryColor : const Color(0xFFCBD5E1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _NavBadgeItem — nav tab with unread count badge (for Notifications)
// =============================================================================
class _NavBadgeItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int selectedIndex;
  final double iconSize;
  final double fontSize;
  final Color primaryColor;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavBadgeItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.iconSize,
    required this.fontSize,
    required this.primaryColor,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == selectedIndex;
    final showBadge = badgeCount > 0;
    final badgeLabel = badgeCount > 9 ? '9+' : '$badgeCount';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              isSelected ? primaryColor.withOpacity(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: iconSize,
                  color: isSelected ? primaryColor : const Color(0xFFCBD5E1),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? primaryColor : const Color(0xFFCBD5E1),
                  ),
                ),
              ],
            ),
            if (showBadge)
              Positioned(
                top: -6,
                right: -10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF16A34A), Color(0xFF0F766E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    badgeLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
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
// _EventFeedCard — rich card shown in the student home feed
// =============================================================================
// =============================================================================
// _EventFeedCard — rich card with multi-image carousel
// =============================================================================
class _EventFeedCard extends StatefulWidget {
  final Event event;
  const _EventFeedCard({required this.event});

  @override
  State<_EventFeedCard> createState() => _EventFeedCardState();
}

class _EventFeedCardState extends State<_EventFeedCard> {
  int _currentImageIndex = 0;

  // Build the final list of image URLs to show
  List<String> get _imageUrls {
    if (widget.event.imageUrls.isNotEmpty) return widget.event.imageUrls;
    if (widget.event.imageUrl != null && widget.event.imageUrl!.isNotEmpty) {
      return [widget.event.imageUrl!];
    }
    return [];
  }

  ImageProvider _eventImageProvider(String url) {
    if (url.startsWith('data:')) {
      try {
        final comma = url.indexOf(',');
        if (comma >= 0) {
          return MemoryImage(base64Decode(url.substring(comma + 1)));
        }
      } catch (_) {}
    }
    return NetworkImage(url);
  }

  Widget _buildImage(String url, double height) {
    if (url.startsWith('data:')) {
      try {
        final comma = url.indexOf(',');
        if (comma >= 0) {
          return Image.memory(
            base64Decode(url.substring(comma + 1)),
            width: double.infinity,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _imageFallback(height),
          );
        }
      } catch (_) {}
      return _imageFallback(height);
    }

    return Image.network(
      url,
      width: double.infinity,
      height: height,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          height: height,
          color: const Color(0xFFDCFCE7),
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF16A34A),
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _imageFallback(height),
    );
  }

  Widget _imageFallback(double height) => Container(
        width: double.infinity,
        height: height,
        color: const Color(0xFFDCFCE7),
        alignment: Alignment.center,
        child: const Icon(
          Icons.broken_image_rounded,
          color: Color(0xFF16A34A),
          size: 36,
        ),
      );

  void _openZoom(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Image(image: _eventImageProvider(url), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUpcoming = widget.event.date.isAfter(DateTime.now());
    final urls = _imageUrls;
    final hasImages = urls.isNotEmpty;
    final hasMultiple = urls.length > 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUpcoming
              ? const Color(0xFF16A34A).withOpacity(0.18)
              : const Color(0xFFE8E9F3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image / Carousel ─────────────────────────────────────
          if (hasImages)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  // ── Carousel or single image ──────────────────────
                  if (hasMultiple)
                    SizedBox(
                      height: 200,
                      child: PageView.builder(
                        itemCount: urls.length,
                        onPageChanged: (index) =>
                            setState(() => _currentImageIndex = index),
                        itemBuilder: (_, index) => GestureDetector(
                          onTap: () => _openZoom(context, urls[index]),
                          child: _buildImage(urls[index], 200),
                        ),
                      ),
                    )
                  else
                    // Single image — no carousel needed
                    GestureDetector(
                      onTap: () => _openZoom(context, urls.first),
                      child: Image.network(
                        urls.first,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 200,
                            color: const Color(0xFFDCFCE7),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF16A34A),
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          height: 200,
                          color: const Color(0xFFDCFCE7),
                          child: const Icon(Icons.broken_image_rounded,
                              color: Color(0xFF16A34A), size: 36),
                        ),
                      ),
                    ),

                  // ── Dot indicators (only for multiple images) ─────
                  if (hasMultiple)
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: urls.asMap().entries.map((entry) {
                          final isActive = entry.key == _currentImageIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: isActive ? 18 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  // ── Image counter badge (top-right) ───────────────
                  if (hasMultiple)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentImageIndex + 1} / ${urls.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // ── Content ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Org name + status pill
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.event.orgName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F766E),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isUpcoming
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isUpcoming ? 'Upcoming' : 'Past',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: isUpcoming
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Title
                Text(
                  widget.event.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F0D2E),
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),

                // Description
                if (widget.event.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.event.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B6B8E),
                      height: 1.55,
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Date row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isUpcoming
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 11,
                            color: isUpcoming
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _formatDate(widget.event.date),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isUpcoming
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => showEventComments(context, eventId: widget.event.id, eventTitle: widget.event.title),
                    icon: const Icon(Icons.forum_outlined, size: 17),
                    label: const Text('Comments'),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF15803D)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
