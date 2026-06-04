import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_state.dart';
import 'admin_manage_accounts.dart';
import 'admin_manage_organization.dart';
import '../auth/unified_login_page.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM — centralised tokens so every widget stays consistent
// ─────────────────────────────────────────────────────────────────────────────
abstract class _DS {
  static const Color bg = Color(0xFF0F1117);
  static const Color surface = Color(0xFF181C27);
  static const Color surface2 = Color(0xFF1E2334);
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryDk = Color(0xFF4F46E5);
  static const Color chromeHeader = Color(0xFF181C27);
  static const Color onPrimary = Colors.white;
  static const Color textHd = Color(0xFFE2E8F0);
  static const Color textSub = Color(0xFF94A3B8);
  static const Color divider = Color(0xFF2A2F45);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color accent = Color(0xFF8B5CF6);
  static const Color teal = Color(0xFF06B6D4);
  static const double radiusCard = 20;
  static const double radiusChip = 40;
  // Light mode tokens
  static const Color lightBg = Color(0xFFF1F5F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFF8FAFC);
  static const Color lightDivider = Color(0xFFE2E8F0);
  static const Color lightTextHd = Color(0xFF1E293B);
  static const Color lightTextSub = Color(0xFF64748B);

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.25),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT — AdminDashboard (now StatefulWidget to support data fetching)
// ─────────────────────────────────────────────────────────────────────────────
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // ── Analytics state (lifted from admin_reports.dart) ──────────────────────
  bool _loading = true;

  int _totalUsers = 0;
  int _totalOrgs = 0;
  int _totalMembers = 0;
  int _totalEvents = 0;
  int _totalApps = 0;
  int _pending = 0;
  int _forApproval = 0;
  int _accepted = 0;
  int _declined = 0;
  int _interviewees = 0;
  int _students = 0;
  int _officers = 0;
  int _admins = 0;
  // Theme is now managed globally by AppState — no local state needed

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  // ── Data fetching — identical logic from admin_reports.dart ───────────────
  Future<void> _loadReports() async {
    setState(() => _loading = true);

    try {
      // Fetch everything directly from Supabase — no AppState dependency
      final results = await Future.wait([
        Supabase.instance.client.from('profiles').select('role'),
        Supabase.instance.client.from('members').select('id'),
        Supabase.instance.client.from('events').select('id, title'),
        Supabase.instance.client.from('applications').select('id, status'),
      ]);

      final profilesResponse = results[0] as List;
      final membersResponse = results[1] as List;
      final eventsResponse = results[2] as List;
      final appsResponse = results[3] as List;

      int students = 0, officers = 0, admins = 0;
      for (var p in profilesResponse) {
        final role = p['role'] ?? '';
        if (role == 'student') {
          students++;
        } else if (role == 'officer')
          officers++;
        else if (role == 'admin') admins++;
      }

      final filteredEvents = eventsResponse
          .where((e) =>
              !(e['title'] as String).toLowerCase().contains('interview'))
          .toList();

      int pending = 0,
          forApproval = 0,
          accepted = 0,
          declined = 0,
          interviewees = 0;
      for (var a in appsResponse) {
        final status = a['status'] ?? '';
        if (status == 'pending') {
          pending++;
        } else if (status == 'for_approval')
          forApproval++;
        else if (status == 'accepted')
          accepted++;
        else if (status == 'declined')
          declined++;
        else if (status == 'interview_scheduled') interviewees++;
      }

      setState(() {
        _totalUsers = profilesResponse.length;
        _totalOrgs = AppState.instance.organizations.length; // stays hardcoded
        _totalMembers = membersResponse.length;
        _totalEvents = filteredEvents.length;
        _totalApps = appsResponse.length;
        _pending = pending;
        _forApproval = forApproval;
        _accepted = accepted;
        _declined = declined;
        _interviewees = interviewees;
        _students = students;
        _officers = officers;
        _admins = admins;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading reports: $e');
      setState(() => _loading = false);
    }
  }

  // ── Logout confirmation dialog ─────────────────────────────────────────────
  Future<void> _showLogoutDialog(BuildContext context) async {
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
            color: _DS.lightTextHd,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out of your account? '
          'You will need to enter your credentials to log back in.',
          style: TextStyle(
            fontSize: 14,
            color: _DS.lightTextSub,
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: _DS.textSub,
              side: const BorderSide(color: _DS.divider),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
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
              Navigator.of(ctx).pop();
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UnifiedLoginPage(),
                  ),
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

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppState.instance.isDark ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        backgroundColor: AppState.instance.isDark ? _DS.bg : _DS.lightBg,

        // ── Left Sidebar Drawer (unchanged) ──────────────────────────────────
        drawer: _AdminSidebarDrawer(
          onLogoutTap: () {
            Navigator.of(context).pop();
            _showLogoutDialog(context);
          },
        ),

        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: _DashboardAppBar(
            onRefresh: _loadReports,
            isDark: AppState.instance.isDark,
            onToggleTheme: () {
              AppState.instance.toggleTheme();
              setState(() {}); // rebuild this screen
            },
          ),
        ),

        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadReports,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isWide = constraints.maxWidth >= 640;
                      return ListView(
                        padding: EdgeInsets.symmetric(
                          horizontal: isWide ? 40 : 20,
                          vertical: 28,
                        ),
                        children: [
                          // ── Welcome Banner (unchanged) ────────────────────
                          _WelcomeBanner(isDark: AppState.instance.isDark),
                          const SizedBox(height: 28),

                          // ── Summary Grid (real data) ──────────────────────
                          _SectionLabel(
                              label: 'System Overview',
                              isDark: AppState.instance.isDark),
                          const SizedBox(height: 14),
                          _SummaryGrid(
                            totalOrgs: _totalOrgs,
                            totalEvents: _totalEvents,
                            totalMembers: _totalMembers,
                            totalUsers: _totalUsers,
                            isDark: AppState.instance.isDark,
                          ),
                          const SizedBox(height: 28),

                          // ── Applications Overview ─────────────────────────
                          // ── Applications Overview + Roles (responsive) ───
                          _SectionLabel(
                              label: 'User Roles',
                              isDark: AppState.instance.isDark),
                          const SizedBox(height: 14),

                          _RolesCard(
                            students: _students,
                            officers: _officers,
                            admins: _admins,
                            isDark: AppState.instance.isDark,
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION LABEL
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: isDark ? _DS.textSub : _DS.lightTextSub,
      ),
    );
  }
}

class _SummaryItem {
  final IconData icon;
  final String label;
  final int value;
  final Color accent;
  const _SummaryItem(this.icon, this.label, this.value, this.accent);
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY GRID — 4 cards with real data
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryGrid extends StatelessWidget {
  final int totalOrgs, totalEvents, totalMembers, totalUsers;
  final bool isDark;

  const _SummaryGrid({
    required this.totalOrgs,
    required this.totalEvents,
    required this.totalMembers,
    required this.totalUsers,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _SummaryItem(Icons.apartment_outlined, 'Organizations', totalOrgs,
          const Color(0xFF8B5CF6)),
      _SummaryItem(Icons.event_available_outlined, 'Events', totalEvents,
          const Color(0xFF3B82F6)),
      _SummaryItem(Icons.group_outlined, 'Members', totalMembers, _DS.success),
      _SummaryItem(Icons.person_outline, 'Users', totalUsers, _DS.primary),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final int cols = constraints.maxWidth >= 600 ? 4 : 2;
        final double ratio = constraints.maxWidth >= 600 ? 1.6 : 1.4;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: ratio,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => _SummaryCard(item: items[i], isDark: isDark),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final _SummaryItem item;
  final bool isDark;
  const _SummaryCard({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _DS.surface : _DS.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? _DS.divider : _DS.lightDivider),
        boxShadow: _DS.cardShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: item.accent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.accent, size: 18),
              ),
              const Spacer(),
              Text(
                '${item.value}',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? _DS.textHd : _DS.lightTextHd,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? _DS.textSub : _DS.lightTextSub),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APPLICATIONS STATUS CARD
// ─────────────────────────────────────────────────────────────────────────────
class _AppStatusCard extends StatelessWidget {
  final int total, pending, forApproval, accepted, declined, interviewees;
  final bool isDark;

  const _AppStatusCard({
    required this.total,
    required this.pending,
    required this.forApproval,
    required this.accepted,
    required this.declined,
    required this.interviewees,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final statuses = [
      ('Pending', pending, _DS.warning),
      ('For Approval', forApproval, _DS.primary),
      ('Accepted', accepted, _DS.success),
      ('Declined', declined, _DS.danger),
      ('Interview', interviewees, _DS.teal),
    ];
    final safeTotal = total == 0 ? 1 : total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? _DS.surface : _DS.lightSurface,
        borderRadius: BorderRadius.circular(_DS.radiusCard),
        border: Border.all(color: isDark ? _DS.divider : _DS.lightDivider),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Application Status',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? _DS.textHd : _DS.lightTextHd)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? _DS.surface2 : _DS.lightSurface2,
                  border: Border.all(
                      color: isDark ? _DS.divider : _DS.lightDivider),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('$total Total',
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? _DS.textSub : _DS.lightTextSub)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(80, 80),
                      painter: _DonutPainter(
                        statuses: statuses.map((s) => (s.$2, s.$3)).toList(),
                        total: safeTotal,
                        trackColor: isDark ? _DS.surface2 : _DS.lightSurface2,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$total',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isDark ? _DS.textHd : _DS.lightTextHd)),
                        Text('apps',
                            style: TextStyle(
                                fontSize: 9,
                                color:
                                    isDark ? _DS.textSub : _DS.lightTextSub)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: statuses.map((s) {
                    final pct = s.$2 / safeTotal;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(s.$1,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? _DS.textSub
                                          : _DS.lightTextSub)),
                              Text('${s.$2}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: s.$3)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 5,
                              backgroundColor:
                                  isDark ? _DS.surface2 : _DS.lightSurface2,
                              valueColor: AlwaysStoppedAnimation(s.$3),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<(int, Color)> statuses;
  final int total;
  final Color trackColor;

  const _DonutPainter({
    required this.statuses,
    required this.total,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const strokeW = 11.0;
    final radius = (size.width - strokeW) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), radius, trackPaint);

    // Segments
    double startAngle = -math.pi / 2;
    for (final (count, color) in statuses) {
      if (count == 0) continue;
      final sweep = (count / total) * 2 * math.pi;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        startAngle,
        sweep - 0.08,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $count',
        style:
            TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USER ROLES CARD
// ─────────────────────────────────────────────────────────────────────────────
class _RolesCard extends StatelessWidget {
  final int students, officers, admins;
  final bool isDark;

  const _RolesCard({
    required this.students,
    required this.officers,
    required this.admins,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final total = students + officers + admins;
    final safe = total == 0 ? 1 : total;
    final roles = [
      ('Students', students, _DS.primary),
      ('Officers', officers, _DS.accent),
      ('Admins', admins, _DS.teal),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? _DS.surface : _DS.lightSurface,
        borderRadius: BorderRadius.circular(_DS.radiusCard),
        border: Border.all(color: isDark ? _DS.divider : _DS.lightDivider),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Role Distribution',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? _DS.textHd : _DS.lightTextHd)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? _DS.surface2 : _DS.lightSurface2,
                  border: Border.all(
                      color: isDark ? _DS.divider : _DS.lightDivider),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('$total Users',
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? _DS.textSub : _DS.lightTextSub)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 36,
              child: Row(
                children: roles.map((r) {
                  final flex = r.$2 == 0 ? 0 : ((r.$2 / safe) * 100).round();
                  if (flex == 0) return const SizedBox.shrink();
                  return Expanded(
                    flex: flex,
                    child: Container(
                      color: r.$3,
                      alignment: Alignment.center,
                      child: Text(
                        '${((r.$2 / safe) * 100).round()}%',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...roles.map((r) {
            final pct = ((r.$2 / safe) * 100).round();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: r.$3,
                              borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 10),
                      Text(r.$1,
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark ? _DS.textSub : _DS.lightTextSub)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: r.$3.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('$pct%',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: r.$3.withOpacity(0.9))),
                      ),
                    ],
                  ),
                  Text('${r.$2}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? _DS.textHd : _DS.lightTextHd)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RoleRow extends StatelessWidget {
  final String label;
  final int value;

  const _RoleRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: _DS.textSub)),
          Text(
            '$value',
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15, color: _DS.textHd),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN SIDEBAR DRAWER — unchanged from original
// ─────────────────────────────────────────────────────────────────────────────
class _AdminSidebarDrawer extends StatelessWidget {
  final VoidCallback onLogoutTap;

  const _AdminSidebarDrawer({required this.onLogoutTap});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'Administrator';

    return Drawer(
      backgroundColor: _DS.chromeHeader,
      width: 270,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _DS.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.dashboard_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'OrgConnect',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.10),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _DS.primary.withOpacity(0.30),
                      child: const Icon(Icons.person_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Administrator',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'NAVIGATION',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  color: Colors.white.withOpacity(0.35),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _SidebarTile(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              onTap: () => Navigator.of(context).pop(),
            ),
            _SidebarTile(
              icon: Icons.manage_accounts_outlined,
              label: 'Manage Accounts',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminAccountsScreen()),
                );
              },
            ),
            _SidebarTile(
              icon: Icons.apartment_outlined,
              label: 'Organizations',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminOrganizationsScreen()),
                );
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(
                color: Colors.white.withOpacity(0.10),
                thickness: 1,
                height: 1,
              ),
            ),
            const SizedBox(height: 8),
            _SidebarTile(
              icon: Icons.logout_rounded,
              label: 'Log Out',
              accentRed: true,
              onTap: onLogoutTap,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SidebarTile — unchanged
// ─────────────────────────────────────────────────────────────────────────────
class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accentRed;

  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accentRed = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color tileColor = accentRed ? const Color(0xFFEF4444) : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          splashColor: tileColor.withOpacity(0.08),
          highlightColor: tileColor.withOpacity(0.05),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: tileColor.withOpacity(accentRed ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: tileColor, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tileColor,
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

// ─────────────────────────────────────────────────────────────────────────────
// APP BAR — now accepts onRefresh callback
// ─────────────────────────────────────────────────────────────────────────────
class _DashboardAppBar extends StatelessWidget {
  final VoidCallback onRefresh;
  final bool isDark;
  final VoidCallback onToggleTheme;
  const _DashboardAppBar({
    required this.onRefresh,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isDark ? Colors.white : _DS.lightTextHd;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? _DS.surface : _DS.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? _DS.divider : _DS.lightDivider,
            width: 1,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: MediaQuery.of(context).padding.top,
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.menu_rounded, color: iconColor, size: 22),
            tooltip: 'Open menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          if (MediaQuery.of(context).size.width >= 640) ...[
            const SizedBox(width: 12),
            Text(
              'Admin Dashboard',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: iconColor,
                letterSpacing: 0.2,
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: iconColor, size: 20),
            tooltip: 'Refresh',
            onPressed: onRefresh,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: iconColor,
              size: 20,
            ),
            tooltip: isDark ? 'Light mode' : 'Dark mode',
            onPressed: onToggleTheme,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 4),
          _AdminChip(isDark: isDark),
        ],
      ),
    );
  }
}

class _AdminChip extends StatelessWidget {
  final bool isDark;
  const _AdminChip({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _DS.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(_DS.radiusChip),
        border: Border.all(color: _DS.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: _DS.primary.withOpacity(0.25),
            child:
                const Icon(Icons.person_rounded, size: 14, color: _DS.primary),
          ),
          const SizedBox(width: 7),
          const Text(
            'Admin',
            style: TextStyle(
              color: _DS.primary,
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
// WELCOME BANNER — unchanged
// ─────────────────────────────────────────────────────────────────────────────
class _WelcomeBanner extends StatelessWidget {
  final bool isDark;
  const _WelcomeBanner({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A1D2E), const Color(0xFF232742)]
              : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
        ),
        borderRadius: BorderRadius.circular(_DS.radiusCard),
        border: Border.all(
          color: isDark ? _DS.divider : const Color(0xFFC7D2FE),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back 👋',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF6366F1),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'System Overview',
                  style: TextStyle(
                    color: isDark ? Colors.white : _DS.lightTextHd,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage your platform from one place.',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : _DS.lightTextSub,
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
              color: _DS.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.admin_panel_settings_rounded,
              color: isDark ? Colors.white : _DS.primary,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}
