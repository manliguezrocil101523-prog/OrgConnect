import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_state.dart';
import 'admin_manage_accounts.dart';
import 'admin_manage_organization.dart';
import '../auth/unified_login_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM — centralised tokens so every widget stays consistent
// ─────────────────────────────────────────────────────────────────────────────
abstract class _DS {
  static const Color bg = Color(0xFFF5F7FA);
  static const Color surface = Colors.white;
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryDk = Color(0xFF4338CA);
  static const Color chromeHeader = Color(0xFF1E293B);
  static const Color onPrimary = Colors.white;
  static const Color textHd = Color(0xFF1E293B);
  static const Color textSub = Color(0xFF64748B);
  static const Color divider = Color(0xFFE2E8F0);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color accent = Color(0xFF6366F1);
  static const double radiusCard = 20;
  static const double radiusChip = 40;

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF4F46E5).withOpacity(0.08),
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

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  // ── Data fetching — identical logic from admin_reports.dart ───────────────
  Future<void> _loadReports() async {
    setState(() => _loading = true);
    try {
      await Future.wait([
        AppState.instance.fetchEvents(),
        AppState.instance.fetchMembers(),
        AppState.instance.fetchApplications(),
      ]);

      final profilesResponse =
          await Supabase.instance.client.from('profiles').select('role');

      int students = 0, officers = 0, admins = 0;
      for (var p in profilesResponse) {
        final role = p['role'] ?? '';
        if (role == 'student')
          students++;
        else if (role == 'officer')
          officers++;
        else if (role == 'admin') admins++;
      }

      final apps = AppState.instance.applications;
      final events = AppState.instance.events
          .where((e) => !e.title.toLowerCase().contains('interview'))
          .toList();

      setState(() {
        _totalUsers = profilesResponse.length;
        _totalOrgs = AppState.instance.organizations.length;
        _totalMembers = AppState.instance.members.length;
        _totalEvents = events.length;
        _totalApps = apps.length;
        _pending =
            apps.where((a) => a.status == ApplicationStatus.pending).length;
        _forApproval = apps
            .where((a) => a.status == ApplicationStatus.for_approval)
            .length;
        _accepted =
            apps.where((a) => a.status == ApplicationStatus.accepted).length;
        _declined =
            apps.where((a) => a.status == ApplicationStatus.declined).length;
        _interviewees = apps
            .where((a) => a.status == ApplicationStatus.interview_scheduled)
            .length;
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
            color: _DS.textHd,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out of your account? '
          'You will need to enter your credentials to log back in.',
          style: TextStyle(
            fontSize: 14,
            color: _DS.textSub,
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
    return Scaffold(
      backgroundColor: _DS.bg,

      // ── Left Sidebar Drawer (unchanged) ──────────────────────────────────
      drawer: _AdminSidebarDrawer(
        onLogoutTap: () {
          Navigator.of(context).pop();
          _showLogoutDialog(context);
        },
      ),

      appBar: PreferredSize(
        preferredSize: Size.fromHeight(64 + MediaQuery.of(context).padding.top),
        child: _DashboardAppBar(onRefresh: _loadReports),
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
                        const _WelcomeBanner(),
                        const SizedBox(height: 28),

                        // ── Summary Grid (real data) ──────────────────────
                        _SectionLabel(label: 'System Overview'),
                        const SizedBox(height: 14),
                        _SummaryGrid(
                          totalOrgs: _totalOrgs,
                          totalEvents: _totalEvents,
                          totalMembers: _totalMembers,
                          totalUsers: _totalUsers,
                        ),
                        const SizedBox(height: 28),

                        // ── Applications Overview ─────────────────────────
                        _SectionLabel(label: 'Applications Overview'),
                        const SizedBox(height: 14),
                        _AppStatusCard(
                          total: _totalApps,
                          pending: _pending,
                          forApproval: _forApproval,
                          accepted: _accepted,
                          declined: _declined,
                          interviewees: _interviewees,
                        ),
                        const SizedBox(height: 28),

                        // ── User Roles Breakdown ──────────────────────────
                        _SectionLabel(label: 'User Roles'),
                        const SizedBox(height: 14),
                        _RolesCard(
                          students: _students,
                          officers: _officers,
                          admins: _admins,
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
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
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: _DS.textSub,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY GRID — 4 cards with real data
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryGrid extends StatelessWidget {
  final int totalOrgs;
  final int totalEvents;
  final int totalMembers;
  final int totalUsers;

  const _SummaryGrid({
    required this.totalOrgs,
    required this.totalEvents,
    required this.totalMembers,
    required this.totalUsers,
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

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _SummaryCard(item: items[i]),
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

class _SummaryCard extends StatelessWidget {
  final _SummaryItem item;
  const _SummaryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _DS.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _DS.cardShadow,
        border: Border.all(color: _DS.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: item.accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.accent, size: 18),
          ),
          const Spacer(),
          Text(
            '${item.value}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _DS.textHd,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: const TextStyle(fontSize: 11, color: _DS.textSub),
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
  final int total;
  final int pending;
  final int forApproval;
  final int accepted;
  final int declined;
  final int interviewees;

  const _AppStatusCard({
    required this.total,
    required this.pending,
    required this.forApproval,
    required this.accepted,
    required this.declined,
    required this.interviewees,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _DS.surface,
        borderRadius: BorderRadius.circular(_DS.radiusCard),
        boxShadow: _DS.cardShadow,
        border: Border.all(color: _DS.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Applications: $total',
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15, color: _DS.textHd),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatusChip('Pending', pending, _DS.warning),
              _StatusChip('For Approval', forApproval, _DS.accent),
              _StatusChip('Accepted', accepted, _DS.success),
              _StatusChip('Declined', declined, _DS.danger),
              _StatusChip('Interview', interviewees, _DS.chromeHeader),
            ],
          ),
        ],
      ),
    );
  }
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
  final int students;
  final int officers;
  final int admins;

  const _RolesCard({
    required this.students,
    required this.officers,
    required this.admins,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _DS.surface,
        borderRadius: BorderRadius.circular(_DS.radiusCard),
        boxShadow: _DS.cardShadow,
        border: Border.all(color: _DS.divider),
      ),
      child: Column(
        children: [
          _RoleRow(label: 'Students', value: students),
          const Divider(color: _DS.divider),
          _RoleRow(label: 'Officers', value: officers),
          const Divider(color: _DS.divider),
          _RoleRow(label: 'Admins', value: admins),
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

  const _DashboardAppBar({required this.onRefresh});

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
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
            tooltip: 'Open menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 8),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
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
          // ── Refresh button ─────────────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: Colors.white, size: 20),
            tooltip: 'Refresh',
            onPressed: onRefresh,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 4),
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
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(_DS.radiusChip),
        border: Border.all(color: Colors.white.withOpacity(0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.white.withOpacity(0.35),
            child:
                const Icon(Icons.person_rounded, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 7),
          const Text(
            'Admin',
            style: TextStyle(
              color: Colors.white,
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
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'System Overview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Manage your platform from one place.',
                  style: TextStyle(
                    color: Colors.white70,
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
              color: Colors.white.withOpacity(0.15),
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
