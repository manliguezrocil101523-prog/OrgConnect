import 'dart:convert';
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../core/app_state.dart';
import '../../core/analytics_service.dart';
import '../analytics/event_comments_sheet.dart';
import '/screens/notifications/notification_screen.dart';
import '/screens/Student_Role/student_dashboard_events.dart';
import '/screens/profile/profile_screen.dart';
import '../community/org_community_chat_screen.dart';
import '/screens/organizations/org_list_screen.dart';
import '../../widgets/app_header.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  // ─── Color tokens — MUST match ProfileScreen exactly ─────────────────────
  static const Color _primary = Color(0xFF16A34A);
  static const Color _background = Color(0xFFF0FDF4);

  // Per-action accent colors — all within the permitted palette
  static const Color _profileAccent = Color(0xFF16A34A);
  static const Color _orgAccent = Color(0xFF0F766E);
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

  Future<void> _refreshNotifications() async {
    try {
      await AppState.instance.fetchNotifications();
    } catch (e) {
      debugPrint('Could not refresh notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = AppState.instance.currentStudent;
    final unreadCount = student == null
        ? 0
        : AppState.instance.notifications.where((n) {
            final title = n.title.toLowerCase();
            final message = n.message.toLowerCase();
            final isInterview = title.contains('interview') ||
                message.contains('scheduled interview');
            final isMember = title.contains('congratulations') ||
                message.contains('officially a member');
            return (n.studentId == student.id ||
                    n.studentId == student.studentId) &&
                (isInterview || isMember) &&
                !n.read;
          }).length;

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
            NotificationScreen(showBackButton: false),
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
            color: Colors.black.withValues(alpha: 0.08),
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
                icon: Icons.notifications_rounded,
                label: 'Notifs',
                index: 3,
                selectedIndex: _selectedIndex,
                iconSize: iconSize,
                fontSize: fontSize,
                primaryColor: _eventsAccent,
                badgeCount: unreadCount,
                onTap: () {
                  setState(() => _selectedIndex = 3);
                  _refreshNotifications();
                },
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                index: 4,
                selectedIndex: _selectedIndex,
                iconSize: iconSize,
                fontSize: fontSize,
                primaryColor: _profileAccent,
                onTap: () => setState(() => _selectedIndex = 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _QuickActionsRow — Applications / Joined Orgs / Notifications
// Sits BELOW the green header, on the light background.
// =============================================================================
class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    final student = AppState.instance.currentStudent;

    final unreadOrgUpdates = AppState.instance.notifications
        .where((n) =>
            n.orgId != null &&
            n.orgId!.isNotEmpty &&
            !n.read &&
            !_isWorkflowOrganizationNotification(n) &&
            !_isStudentPersonalNotification(n))
        .length;

    final unreadNotifications = AppState.instance.notifications
        .where((n) =>
            (n.studentId == student?.id || n.studentId == student?.studentId) &&
            !n.read)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionCard(
              label: 'Applications',
              icon: Icons.assignment_rounded,
              accent: const Color(0xFF16A34A),
              badgeCount: 0,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const _MyApplicationsScreen()),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickActionCard(
              label: 'Joined Orgs',
              icon: Icons.groups_rounded,
              accent: const Color(0xFF0F766E),
              badgeCount: unreadOrgUpdates,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const _JoinedOrganizationsScreen()),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickActionCard(
              label: 'Notifications',
              icon: Icons.notifications_active_rounded,
              accent: const Color(0xFF15803D),
              badgeCount: unreadNotifications,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _QuickActionCard — one white rounded card with icon + label + red badge
// =============================================================================
class _QuickActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final int badgeCount;

  const _QuickActionCard({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCBE8DC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F8A61),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: accent, size: 23),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -5,
                        top: -4,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 18),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            badgeCount > 99 ? '99+' : '$badgeCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF173B30),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Student quick-access screens
// =============================================================================
class _MyApplicationsScreen extends StatefulWidget {
  const _MyApplicationsScreen();

  @override
  State<_MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<_MyApplicationsScreen> {
  bool _refreshing = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _refreshApplications();
  }

  Future<void> _refreshApplications() async {
    if (mounted)
      setState(() {
        _refreshing = true;
        _failed = false;
      });
    try {
      final app = AppState.instance;
      if (app.currentStudent == null) await app.loadStudentProfile();

      // Only what this screen needs, and in parallel.
      await Future.wait<void>([
        app.fetchApplications(),
        if (app.organizations.isEmpty) app.fetchOrganizations(),
      ]);
    } catch (e) {
      debugPrint('Could not refresh My Applications: $e');
      if (mounted) _failed = true;
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds automatically when AppState changes (fetch finishes).
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final authUserId =
            supabase.Supabase.instance.client.auth.currentUser?.id;

        // SECURITY: match ONLY on the authenticated user id (see section 3).
        final apps = AppState.instance.applications
            .where((a) => authUserId != null && a.userId == authUserId)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        Widget body;
        if (apps.isEmpty && _refreshing) {
          body = const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F8A61)));
        } else if (apps.isEmpty && _failed) {
          body = _QuickEmpty(
            icon: Icons.wifi_off_rounded,
            title: 'Could not load applications',
            subtitle: 'Check your connection and pull down to try again.',
          );
        } else if (apps.isEmpty) {
          body = const _QuickEmpty(
            icon: Icons.assignment_outlined,
            title: 'No applications yet',
            subtitle:
                'Organizations you apply to will appear here with their current status.',
          );
        } else {
          body = ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
            itemCount: apps.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _ApplicationCard(application: apps[i]),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF1FAF6),
          body: Column(children: [
            AppHeader(
              title: 'My Applications',
              subtitle: 'Track your organization applications',
              status: apps.isEmpty
                  ? 'NO APPLICATIONS YET'
                  : '${apps.length} APPLICATION${apps.length == 1 ? '' : 'S'}',
              icon: Icons.assignment_rounded,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            // Thin bar: old data stays visible while fresh data loads.
            if (_refreshing && apps.isNotEmpty)
              const LinearProgressIndicator(
                  minHeight: 2, color: Color(0xFF0F8A61)),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF0F8A61),
                onRefresh: _refreshApplications,
                child: apps.isEmpty
                    ? ListView(children: [
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.5,
                            child: body)
                      ])
                    : body,
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final Application application;
  const _ApplicationCard({required this.application});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(application.status);
    final rawApplicationOrgName = application.orgName.trim();
    final normalizedApplicationOrgName = rawApplicationOrgName.toLowerCase();
    final org =
        AppState.instance.organizations.cast<Organization?>().firstWhere(
              (candidate) =>
                  candidate != null &&
                  ((application.orgId != null &&
                          candidate.id == application.orgId) ||
                      candidate.name.trim().toLowerCase() ==
                          normalizedApplicationOrgName ||
                      candidate.acronym.trim().toLowerCase() ==
                          normalizedApplicationOrgName ||
                      (normalizedApplicationOrgName == 'scap' &&
                          candidate.acronym.trim().toLowerCase() == 'scap') ||
                      (normalizedApplicationOrgName.contains('el teatro') &&
                          candidate.name
                              .trim()
                              .toLowerCase()
                              .contains('el teatro'))),
              orElse: () => null,
            );

    // The organization was renamed from SCAP to Student Catholic Action.
    // Prefer the current organization record everywhere on the card so an
    // older application row cannot make the UI revert to the old name.
    final displayName = org?.name.trim().isNotEmpty == true
        ? org!.name
        : (normalizedApplicationOrgName == 'scap'
            ? 'Student Catholic Action'
            : rawApplicationOrgName);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBE8DC)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x090F8A61), blurRadius: 15, offset: Offset(0, 6))
        ],
      ),
      child: Row(
        children: [
          if (org != null)
            _OrgLogo(asset: org.logoAsset, size: 46)
          else
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: const Color(0xFFE4F7EF),
                  borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.groups_rounded, color: Color(0xFF0F8A61)),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName,
                    style: const TextStyle(
                        color: Color(0xFF173B30),
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  'Applied ${application.createdAt.month}/${application.createdAt.day}/${application.createdAt.year}',
                  style:
                      const TextStyle(color: Color(0xFF6B8178), fontSize: 11.5),
                ),
                if (application.status == ApplicationStatus.declined &&
                    application.declineReason.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Reason: ${application.declineReason}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontSize: 11.5,
                          height: 1.35)),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12)),
            child: Text(_statusLabel(application.status),
                style: TextStyle(
                    color: color, fontSize: 10.5, fontWeight: FontWeight.w900)),
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
      case ApplicationStatus.interviewScheduled:
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF2563EB);
    }
  }

  static String _statusLabel(ApplicationStatus status) {
    if (status == ApplicationStatus.approved ||
        status == ApplicationStatus.accepted) {
      return 'Approved';
    }
    return status.name
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}

class _JoinedOrganizationsScreen extends StatefulWidget {
  const _JoinedOrganizationsScreen();

  @override
  State<_JoinedOrganizationsScreen> createState() =>
      _JoinedOrganizationsScreenState();
}

class _JoinedOrganizationsScreenState
    extends State<_JoinedOrganizationsScreen> {
  final Set<String> _joinedOrgIds = <String>{};
  final Set<String> _joinedOrgNames = <String>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _loadJoinedOrganizations());
  }

  Future<void> _loadJoinedOrganizations() async {
    if (mounted) setState(() => _loading = true);
    try {
      if (AppState.instance.currentStudent == null) {
        await AppState.instance.loadStudentProfile();
      }
      // These three reads are independent; load them concurrently so Joined
      // Organizations does not wait for each Supabase request one after another.
      await Future.wait<void>([
        AppState.instance.fetchOrganizations(),
        AppState.instance.fetchMembers(),
      ]);
      // Joined Organizations is derived directly from the fresh membership,
      // application, and profile data below; no extra membership-sync round trip
      // is needed just to render this screen.

      final student = AppState.instance.currentStudent;
      final ids = <String>{...?student?.joinedOrgIds};
      final names = <String>{};

      // Existing member rows.
      for (final member in AppState.instance.members) {
        final profileMatch = member.profileId == student?.id;
        final legacyNameMatch = student != null &&
            student.name.trim().isNotEmpty &&
            member.name.trim().toLowerCase() ==
                student.name.trim().toLowerCase();
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
            application.userId != null &&
            application.userId == student.id;
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
      debugPrint('Error loading Joined Orgs: $e');
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
          body: Column(
            children: [
              AppHeader(
                title: 'Joined Organizations',
                subtitle: 'Your organization communities',
                status: joined.isEmpty
                    ? 'NO ORGANIZATIONS YET'
                    : '${joined.length} JOINED',
                icon: Icons.groups_rounded,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFF0F8A61)),
                      )
                    : joined.isEmpty
                        ? const _QuickEmpty(
                            icon: Icons.groups_outlined,
                            title: 'No organizations joined yet',
                            subtitle:
                                'When an application is accepted, your organization will appear here.',
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                            itemCount: joined.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) =>
                                _JoinedOrgCard(org: joined[i]),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

bool _isStudentPersonalNotification(Notification n) {
  final title = n.title.trim().toLowerCase();
  final message = n.message.trim().toLowerCase();
  return title.contains('interview scheduled') ||
      title == 'application update' ||
      title.contains('congratulations') ||
      message.contains('your interview') ||
      message.contains('your application') ||
      message.contains('officially a member');
}

bool _isWorkflowOrganizationNotification(Notification n) {
  final title = n.title.trim().toLowerCase();
  final message = n.message.trim().toLowerCase();
  const workflowWords = [
    'proposal approved',
    'proposal forwarded',
    'proposal revision',
    'proposal sent back',
    'admin / cso',
    'final posting',
    'creative submitted',
    'revision requested',
    'forwarded to admin',
    'approved and published',
    'has been approved and published',
    'final pictures',
  ];
  return workflowWords
          .any((word) => title.contains(word) || message.contains(word)) ||
      title == 'new event';
}

class _JoinedOrgCard extends StatelessWidget {
  final Organization org;
  const _JoinedOrgCard({required this.org});

  @override
  Widget build(BuildContext context) {
    final updates = AppState.instance.notifications
        .where((n) =>
            n.orgId == org.id &&
            !n.read &&
            !_isWorkflowOrganizationNotification(n) &&
            !_isStudentPersonalNotification(n))
        .length;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => _MemberOrganizationSpace(org: org))),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFCBE8DC)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x090F8A61),
                  blurRadius: 15,
                  offset: Offset(0, 6))
            ],
          ),
          child: Row(
            children: [
              _OrgLogo(asset: org.logoAsset, size: 62),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(org.name,
                        style: const TextStyle(
                            color: Color(0xFF173B30),
                            fontSize: 15,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      org.shortDesc.isEmpty
                          ? 'Your member community'
                          : org.shortDesc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF6B8178),
                          fontSize: 11.5,
                          height: 1.35),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(Icons.campaign_rounded,
                            size: 14, color: Color(0xFF0F8A61)),
                        const SizedBox(width: 4),
                        Text(
                          updates == 0
                              ? 'No new updates'
                              : '$updates new update${updates == 1 ? '' : 's'}',
                          style: const TextStyle(
                              color: Color(0xFF0F8A61),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800),
                        ),
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
  State<_MemberOrganizationSpace> createState() =>
      _MemberOrganizationSpaceState();
}

class _MemberOrganizationSpaceState extends State<_MemberOrganizationSpace> {
  final _messageController = TextEditingController();
  List<Notification> _orgAnnouncements = <Notification>[];
  List<Map<String, dynamic>> _orgPeople = <Map<String, dynamic>>[];
  bool _loadingCommunity = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCommunityData());
  }

  Future<void> _loadCommunityData() async {
    if (mounted) setState(() => _loadingCommunity = true);
    try {
      final client = supabase.Supabase.instance.client;
      final results = await Future.wait<dynamic>([
        AppState.instance.fetchOrganizations(),
        AppState.instance.fetchEvents(),
        AppState.instance.fetchMembers(),
        AppState.instance.fetchNotifications(),
        client
            .from('notifications')
            .select('id,title,message,date,read,org_id,student_id,created_at')
            .eq('org_id', widget.org.id)
            .order('created_at', ascending: false),
        client
            .from('profiles')
            .select('id,name,role,avatar_url,assigned_org_id,org_id')
            .or('assigned_org_id.eq.${widget.org.id},org_id.eq.${widget.org.id}')
            .order('name'),
      ]);

      // Read organization notifications directly so adviser announcements are
      // shown even when an older notification row was mistakenly addressed to
      // a student's ID. Personal notification types stay in Notifications.
      final notificationRows =
          List<Map<String, dynamic>>.from(results[4] as List);
      final announcements = notificationRows
          .map((row) => Notification(
                id: row['id']?.toString() ?? '',
                title: row['title']?.toString() ?? '',
                message: row['message']?.toString() ?? '',
                date: DateTime.tryParse(
                        (row['date'] ?? row['created_at'])?.toString() ?? '') ??
                    DateTime.now(),
                read: row['read'] == true,
                orgId: row['org_id']?.toString(),
                studentId: row['student_id']?.toString(),
              ))
          .where((n) =>
              !_isPersonalStudentNotification(n) &&
              !_isWorkflowOrganizationNotification(n))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      final people = (results[5] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

      if (mounted) {
        setState(() {
          _orgAnnouncements = announcements;
          _orgPeople = people;
          _loadingCommunity = false;
        });
      }

      // Opening the organization space counts as seeing the adviser updates.
      final unreadAnnouncements = announcements
          .where((n) => !n.read && !_isWorkflowOrganizationNotification(n))
          .toList();
      for (final announcement in unreadAnnouncements) {
        await AppState.instance.markNotificationRead(announcement.id);
      }
      if (mounted && unreadAnnouncements.isNotEmpty) {
        setState(() {
          _orgAnnouncements = announcements
              .map((n) => unreadAnnouncements.any((u) => u.id == n.id)
                  ? n.copyWith(read: true)
                  : n)
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading member organization community: $e');
      if (mounted) {
        setState(() {
          _orgAnnouncements = <Notification>[];
          _orgPeople = <Map<String, dynamic>>[];
          _loadingCommunity = false;
        });
      }
    }
  }

  bool _isPersonalStudentNotification(Notification n) {
    final title = n.title.trim().toLowerCase();
    final message = n.message.trim().toLowerCase();
    return title.contains('interview scheduled') ||
        title == 'application update' ||
        title.contains('congratulations') ||
        message.contains('your interview') ||
        message.contains('your application');
  }

  bool _isFeeAnnouncement(Notification n) {
    final text = '${n.title} ${n.message}'.toLowerCase();
    return RegExp(
            r'\bfee\b|fees|registration|membership dues|dues|payment|payable|₱|php')
        .hasMatch(text);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final org = widget.org;
    final now = DateTime.now();
    final events = AppState.instance.events
        .where((e) =>
            (e.orgId == org.id || e.orgName == org.name) &&
            !DateTime(e.date.year, e.date.month, e.date.day)
                .isBefore(DateTime(now.year, now.month, now.day)))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final members = AppState.instance.members
        .where((m) => m.orgId == org.id || m.orgName == org.name)
        .toList();

    final regularAnnouncements =
        _orgAnnouncements.where((n) => !_isFeeAnnouncement(n)).toList();
    final officers = _orgPeople
        .where((p) => p['role']?.toString().toLowerCase() == 'officer')
        .toList();
    final advisers = _orgPeople
        .where((p) => p['role']?.toString().toLowerCase() == 'adviser')
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1FAF6),
      body: Column(children: [
        _StudentOrgHeader(org: org),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadCommunityData,
            color: const Color(0xFF0F8A61),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                // Organization announcements only: meetings, reminders, deadlines,
                // rehearsals, orientations, and other messages sent to all members.
                _CommunitySection(
                  title: 'Organization announcements',
                  icon: Icons.campaign_rounded,
                  child: _loadingCommunity
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : regularAnnouncements.isEmpty
                          ? const Text(
                              'No organization announcements have been posted yet. Meeting notices, reminders, deadlines, and other member updates will appear here.',
                              style: TextStyle(
                                  color: Color(0xFF6B8178), height: 1.45),
                            )
                          : Column(
                              children: regularAnnouncements.take(10).map((n) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(13),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7FCF9),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: const Color(0xFFDCEFE6)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE4F7EF),
                                          borderRadius:
                                              BorderRadius.circular(13),
                                        ),
                                        child: const Icon(
                                            Icons.campaign_rounded,
                                            color: Color(0xFF0F8A61)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(n.title,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w800)),
                                            const SizedBox(height: 4),
                                            Text(n.message,
                                                style: const TextStyle(
                                                    color: Color(0xFF4E665E),
                                                    height: 1.35)),
                                            const SizedBox(height: 6),
                                            Text(
                                              '${n.date.month}/${n.date.day}/${n.date.year}',
                                              style: const TextStyle(
                                                  color: Color(0xFF0F8A61),
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700),
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

                // Adviser first, then officers. Their saved profile photos are shown
                // as clean square organization cards rather than circular login avatars.
                _CommunitySection(
                  title: 'Adviser & officers',
                  icon: Icons.badge_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (advisers.isNotEmpty) ...[
                        const Text('Adviser',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF24463C))),
                        const SizedBox(height: 10),
                        _OrganizationPersonTile(
                          person: advisers.first,
                          fallbackIcon: Icons.school_rounded,
                          wide: true,
                        ),
                      ] else if (org.adviser.trim().isNotEmpty) ...[
                        const Text('Adviser',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF24463C))),
                        const SizedBox(height: 10),
                        _OrganizationFallbackPersonTile(
                          name: org.adviser.trim(),
                          label: 'Adviser',
                          icon: Icons.school_rounded,
                        ),
                      ],
                      const SizedBox(height: 18),
                      const Text('Officers',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF24463C))),
                      const SizedBox(height: 10),
                      if (officers.isEmpty)
                        const Text(
                          'No officer profiles have been posted for this organization yet.',
                          style: TextStyle(color: Color(0xFF6B8178)),
                        )
                      else
                        Wrap(
                          spacing: 10,
                          runSpacing: 12,
                          children: officers
                              .map((person) => _OrganizationPersonTile(
                                    person: person,
                                    fallbackIcon: Icons.badge_rounded,
                                  ))
                              .toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                const SizedBox(height: 14),

                // Fee/payment notices are pulled from the organization's own
                // organization-wide announcements. Nothing is invented here.

                _CommunitySection(
                  title: 'Upcoming events',
                  icon: Icons.event_rounded,
                  child: events.isEmpty
                      ? const Text('No upcoming events posted yet.',
                          style: TextStyle(color: Color(0xFF6B8178)))
                      : Column(
                          children: events.take(8).map((e) {
                            final image = e.imageUrl ??
                                (e.imageUrls.isNotEmpty
                                    ? e.imageUrls.first
                                    : '');
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: const Color(0xFFCBE8DC)),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Color(0x090F8A61),
                                      blurRadius: 16,
                                      offset: Offset(0, 6)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (image.isNotEmpty)
                                    SizedBox(
                                      height: 175,
                                      width: double.infinity,
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: Image.network(
                                              image,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                color: const Color(0xFFDDF4E8),
                                                child: const Icon(
                                                    Icons.event_rounded,
                                                    color: Color(0xFF0F8A61),
                                                    size: 40),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            left: 12,
                                            top: 12,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 9,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withValues(alpha: .92),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                      Icons
                                                          .event_available_rounded,
                                                      size: 14,
                                                      color: Color(0xFF0F8A61)),
                                                  SizedBox(width: 5),
                                                  Text('Upcoming',
                                                      style: TextStyle(
                                                          color:
                                                              Color(0xFF0F8A61),
                                                          fontSize: 10.5,
                                                          fontWeight:
                                                              FontWeight.w900)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        14, 13, 14, 14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(e.title,
                                            style: const TextStyle(
                                                color: Color(0xFF173B30),
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900)),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE4F7EF),
                                            borderRadius:
                                                BorderRadius.circular(11),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                  Icons.calendar_month_rounded,
                                                  size: 14,
                                                  color: Color(0xFF0F8A61)),
                                              const SizedBox(width: 6),
                                              Text(
                                                  '${e.date.month}/${e.date.day}/${e.date.year}',
                                                  style: const TextStyle(
                                                      color: Color(0xFF0F8A61),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w800)),
                                            ],
                                          ),
                                        ),
                                        if (e.description.isNotEmpty) ...[
                                          const SizedBox(height: 9),
                                          Text(e.description,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  color: Color(0xFF6B8178),
                                                  fontSize: 12,
                                                  height: 1.4)),
                                        ],
                                        const SizedBox(height: 10),
                                        EventReactionBar(eventId: e.id),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: FilledButton.icon(
                                            onPressed: () => showEventComments(
                                                context,
                                                eventId: e.id,
                                                eventTitle: e.title),
                                            icon: const Icon(
                                                Icons.forum_outlined,
                                                size: 15),
                                            label: const Text('Comments'),
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFFE4F7EF),
                                              foregroundColor:
                                                  const Color(0xFF0F8A61),
                                              elevation: 0,
                                              minimumSize: Size.zero,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                            ),
                                          ),
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

                _CommunitySection(
                  title: 'Members',
                  icon: Icons.groups_rounded,
                  child: members.isEmpty
                      ? const Text(
                          'Member list will appear when membership records are available.',
                          style: TextStyle(color: Color(0xFF6B8178)),
                        )
                      : Column(
                          children: members.map((m) {
                            final profile = _orgPeople
                                .cast<Map<String, dynamic>?>()
                                .firstWhere(
                                  (p) => p?['id']?.toString() == m.profileId,
                                  orElse: () => null,
                                );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _OrganizationMemberCard(
                                name: m.name,
                                role: m.position,
                                avatarUrl:
                                    profile?['avatar_url']?.toString() ?? '',
                              ),
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 14),

                _CommunitySection(
                  title: 'Community Chat',
                  icon: Icons.forum_rounded,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                            'Open your organization community. Messages are shared with members, officers, and the adviser in the same organization.',
                            style: TextStyle(
                                color: Color(0xFF496A5D),
                                fontSize: 12,
                                height: 1.4)),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => OrgCommunityChatScreen(
                                      orgId: org.id, orgName: org.name))),
                          icon: const Icon(Icons.forum_rounded),
                          label: const Text('Open Community Chat'),
                          style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0F8A61),
                              foregroundColor: Colors.white),
                        ),
                      ]),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _StudentOrgHeader extends StatelessWidget {
  final Organization org;
  const _StudentOrgHeader({required this.org});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 150,
        width: double.infinity,
        child: Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF16A34A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)),
          child: Stack(children: [
            SafeArea(
                bottom: false,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(76, 12, 20, 0),
                    child: Row(children: [
                      _OrgLogo(asset: org.logoAsset, size: 60),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('Member Space',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1)),
                            const SizedBox(height: 4),
                            const Text('Stay connected with el teatro',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600)),
                          ]))
                    ]))),
            Positioned(
              left: 8,
              top: MediaQuery.of(context).padding.top + 4,
              child: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white),
              ),
            ),
          ]),
        ),
      );
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

class _OrganizationPersonTile extends StatelessWidget {
  final Map<String, dynamic> person;
  final IconData fallbackIcon;
  final bool wide;

  const _OrganizationPersonTile({
    required this.person,
    required this.fallbackIcon,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = (person['name']?.toString().trim().isNotEmpty ?? false)
        ? person['name'].toString().trim()
        : 'Organization member';
    final role = person['role']?.toString().trim() ?? '';
    final avatarUrl = person['avatar_url']?.toString().trim() ?? '';

    final image = Container(
      width: wide ? 82 : 86,
      height: wide ? 82 : 86,
      decoration: BoxDecoration(
        color: const Color(0xFFE4F7EF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCBE8DC), width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl.isNotEmpty
          ? Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                fallbackIcon,
                color: const Color(0xFF0F8A61),
                size: 30,
              ),
            )
          : Icon(fallbackIcon, color: const Color(0xFF0F8A61), size: 30),
    );

    if (wide) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FFFB), Color(0xFFE7F8F0)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFCBE8DC)),
        ),
        child: Row(
          children: [
            image,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF24463C),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role.isEmpty ? 'Adviser' : _roleLabel(role),
                    style: const TextStyle(
                      color: Color(0xFF0F8A61),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Organization adviser',
                    style: TextStyle(
                      color: Color(0xFF6B8178),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 132,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8EEE4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F8A61),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          image,
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF24463C),
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          if (role.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              _roleLabel(role),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B8178),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _roleLabel(String role) {
    if (role.isEmpty) return role;
    return role[0].toUpperCase() + role.substring(1);
  }
}

class _OrganizationFallbackPersonTile extends StatelessWidget {
  final String name;
  final String label;
  final IconData icon;

  const _OrganizationFallbackPersonTile({
    required this.name,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FFFB), Color(0xFFE7F8F0)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCBE8DC)),
      ),
      child: Row(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: const Color(0xFFE4F7EF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFCBE8DC), width: 1.4),
            ),
            child: Icon(icon, color: const Color(0xFF0F8A61), size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF24463C),
                        fontSize: 14,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF0F8A61),
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 7),
                const Text('Organization adviser',
                    style: TextStyle(color: Color(0xFF6B8178), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganizationMemberCard extends StatelessWidget {
  final String name;
  final String role;
  final String avatarUrl;

  const _OrganizationMemberCard({
    required this.name,
    required this.role,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final cleanName = name.trim().isEmpty ? 'Member' : name.trim();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFFB),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFD8EEE4)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFE4F7EF),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFCBE8DC)),
            ),
            clipBehavior: Clip.antiAlias,
            child: avatarUrl.isEmpty
                ? const Icon(Icons.person_rounded,
                    color: Color(0xFF0F8A61), size: 25)
                : Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.person_rounded,
                        color: Color(0xFF0F8A61),
                        size: 25),
                  ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cleanName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF24463C),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(role.trim().isEmpty ? 'Member' : role.trim(),
                    style: const TextStyle(
                        color: Color(0xFF6B8178),
                        fontSize: 10.8,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Icon(Icons.verified_rounded,
              color: Color(0xFF16A34A), size: 18),
        ],
      ),
    );
  }
}

class _CommunitySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _CommunitySection(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBE8DC)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x080F8A61), blurRadius: 12, offset: Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: const Color(0xFFE4F7EF),
                    borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: const Color(0xFF0F8A61), size: 18)),
            const SizedBox(width: 9),
            Text(title,
                style: const TextStyle(
                    color: Color(0xFF173B30),
                    fontSize: 15,
                    fontWeight: FontWeight.w900)),
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
  const _QuickEmpty(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF0F8A61), Color(0xFF20B77D)]),
                    borderRadius: BorderRadius.circular(22)),
                child: Icon(icon, color: Colors.white, size: 32)),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF173B30),
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF6B8178), fontSize: 12.5, height: 1.45)),
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
  static const Duration _postLifetime = Duration(days: 30);
  bool _showAllEvents = false;

  @override
  void initState() {
    super.initState();
    AppState.instance.fetchEvents();
    AnalyticsService.instance
        .logUsage('open_student_dashboard', route: 'student/home');
  }

  ImageProvider? _headerAvatar() {
    final url = AppState.instance.currentStudent?.avatarUrl ?? '';
    if (url.startsWith('data:')) {
      try {
        return MemoryImage(base64Decode(url.substring(url.indexOf(',') + 1)));
      } catch (_) {
        return null;
      }
    }
    return url.isNotEmpty ? NetworkImage(url) : null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final cutoff = now.subtract(_postLifetime);
        final allActiveEvents = AppState.instance.events.where((event) {
          final eventDay =
              DateTime(event.date.year, event.date.month, event.date.day);
          return !eventDay.isBefore(today) && !event.createdAt.isBefore(cutoff);
        }).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final events =
            _showAllEvents ? allActiveEvents : allActiveEvents.take(3).toList();

        return Column(
          children: [
            // The profile symbol in the hero is always synced with the
            // student's saved profile through AppState.
            AppHeader(
              title: () {
                final name = (AppState.instance.currentStudent?.name ?? '')
                    .trim()
                    .split(RegExp(r'\s+'))
                    .where((p) => p.isNotEmpty)
                    .take(2)
                    .join(' ');
                return name.isNotEmpty
                    ? 'Welcome Back, $name 👋'
                    : 'Welcome Back 👋';
              }(),
              subtitle: 'Manage your organizations and campus life',
              status: 'STUDENT DASHBOARD',
              avatarImage: _headerAvatar(),
            ),
            const _QuickActionsRow(),
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
                                Text('Upcoming Events',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F0D2E),
                                        letterSpacing: -0.4)),
                                Text(
                                    'Latest posts from all campus organizations.',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF6B6B8E),
                                        fontWeight: FontWeight.w400)),
                              ],
                            ),
                          ),
                          if (allActiveEvents.length > 3)
                            TextButton(
                              onPressed: () => setState(
                                  () => _showAllEvents = !_showAllEvents),
                              child: Text(
                                  _showAllEvents ? 'Latest 3' : 'View all'),
                            ),
                        ],
                      ),
                    ),
                    if (events.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 40),
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                      colors: [_primary, _secondary],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(Icons.event_note_rounded,
                                    color: Colors.white, size: 32),
                              ),
                              const SizedBox(height: 16),
                              const Text('No events yet',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F0D2E))),
                              const SizedBox(height: 6),
                              const Text(
                                  'Events from your organizations\nwill appear here.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13.5,
                                      color: Color(0xFF6B6B8E),
                                      height: 1.55)),
                            ],
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        child: Column(
                          children: events
                              .map((event) => _EventFeedCard(event: event))
                              .toList(),
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
  final int badgeCount;
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
    this.badgeCount = 0,
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
          color: isSelected
              ? primaryColor.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: iconSize,
                  color: isSelected ? primaryColor : const Color(0xFFCBD5E1),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -8,
                    top: -5,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
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
              child:
                  Image(image: _eventImageProvider(url), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isUpcoming = !DateTime(widget.event.date.year,
            widget.event.date.month, widget.event.date.day)
        .isBefore(today);
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
              ? const Color(0xFF16A34A).withValues(alpha: 0.18)
              : const Color(0xFFE8E9F3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                                  : Colors.white.withValues(alpha: 0.45),
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
                          color: Colors.black.withValues(alpha: 0.45),
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
                EventReactionBar(eventId: widget.event.id),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => showEventComments(context,
                        eventId: widget.event.id,
                        eventTitle: widget.event.title),
                    icon: const Icon(Icons.forum_outlined, size: 17),
                    label: const Text('Comments'),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF15803D)),
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
