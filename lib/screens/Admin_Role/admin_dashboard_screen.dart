import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_manage_accounts.dart';
import 'admin_organization_detail_screen.dart';
import 'admin_profile_screen.dart';

import 'admin_create_organization_screen.dart';

/// Layout breakpoints: mobile < 600, tablet 600-1024, desktop > 1024.
///
/// Navigation follows the same classes:
///   mobile  -> bottom navigation bar
///   tablet  -> compact navigation rail (icons + labels)
///   desktop -> full sidebar with brand and profile card
enum _Screen { mobile, tablet, desktop }

/// Date filter for the Home "Upcoming Events" list.
enum _EventRange { all, today, week, month }

class _NavItem {
  const _NavItem(this.icon, this.selectedIcon, this.label);
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // ---------------------------------------------------------------------------
  // Design tokens
  // ---------------------------------------------------------------------------
  static const green = Color(0xFF059669); // primary emerald
  static const accent = Color(0xFF10B981); // lighter emerald
  static const dark = Color(0xFF111827); // headings
  static const muted = Color(0xFF6B7280); // subtext / metadata
  static const bg = Color(0xFFF9FAFB); // page background
  static const line = Color(0xFFE5E7EB); // borders
  static const emeraldSoft = Color(0xFFECFDF5); // tinted backgrounds
  static const emeraldBorder = Color(0xFFA7F3D0);
  static const emeraldDeep = Color(0xFF047857); // text on tinted emerald
  static const danger = Color(0xFFDC2626);
  static const amber = Color(0xFFD97706);

  // Spacing scale (4-pt based) and shared sizes.
  static const double _xs = 4;
  static const double _sm = 8;
  static const double _md = 12;
  static const double _lg = 16;
  static const double _xl = 24;
  static const double _section = 28; // gap between page sections
  static const double _maxContentWidth = 1200;

  /// Inner content width at which two columns sit side by side
  /// (Home: events | proposals).
  static const double _sideBySideMin = 860;

  /// Index of the profile page inside the IndexedStack. It is no longer in the
  /// navigation; it opens from the avatar (top right / sidebar card).
  static const int _profileTab = 4;

  static const List<_NavItem> _items = [
    _NavItem(Icons.dashboard_outlined, Icons.dashboard_rounded, 'Home'),
    _NavItem(Icons.insights_outlined, Icons.insights_rounded, 'Analytics'),
    _NavItem(
        Icons.apartment_outlined, Icons.apartment_rounded, 'Organizations'),
    _NavItem(Icons.manage_accounts_outlined, Icons.manage_accounts_rounded,
        'Accounts'),
  ];

  static const List<String> _months = [
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
    'Dec',
  ];

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------
  final db = Supabase.instance.client;
  int tab = 0;
  bool loading = true;
  List<Map<String, dynamic>> orgs = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> proposals = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> homeEvents = <Map<String, dynamic>>[];
  int members = 0;
  int events = 0;
  int users = 0;
  Map<String, double> scores = <String, double>{};
  Map<String, int> orgMembers = <String, int>{};
  Map<String, int> orgEvents = <String, int>{};
  Map<String, int> orgProposals = <String, int>{};
  Map<String, int> orgComments = <String, int>{};
  Map<String, String> proposalSubmitters = <String, String>{};
  String _avatarUrl = '';
  String _userName = '';
  RealtimeChannel? _realtimeChannel;

  Timer? _reloadTimer;
  bool _isLoadingNow = false;
  bool _reloadQueued = false;

  // Upcoming-events filter state (UI only, no data logic).
  final TextEditingController _eventSearchCtrl = TextEditingController();
  String _eventQuery = '';
  String _eventOrg = ''; // '' = all organizations
  _EventRange _eventRange = _EventRange.all;

  // One scroll controller per scrolling page (each feeds its own
  // "back to top" button).
  final ScrollController _homeScroll = ScrollController();
  final ScrollController _analyticsScroll = ScrollController();
  final ScrollController _orgsScroll = ScrollController();

  void _scheduleReload() {
    if (!mounted) return;
    _reloadTimer?.cancel();
    _reloadTimer =
        Timer(const Duration(milliseconds: 600), () => _load(silent: true));
  }

  @override
  void initState() {
    super.initState();
    _load();
    _realtimeChannel = db
        .channel('admin-dashboard-realtime')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'organizations',
            callback: (_) => _scheduleReload())
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'members',
            callback: (_) => _scheduleReload())
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'events',
            callback: (_) => _scheduleReload())
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'profiles',
            callback: (_) => _scheduleReload())
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'event_requests',
            callback: (_) => _scheduleReload())
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'event_comments',
            callback: (_) => _scheduleReload())
        .subscribe();
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    _eventSearchCtrl.dispose();
    _homeScroll.dispose();
    _analyticsScroll.dispose();
    _orgsScroll.dispose();
    final channel = _realtimeChannel;
    if (channel != null) db.removeChannel(channel);
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_isLoadingNow) {
      _reloadQueued = true;
      return;
    }
    _isLoadingNow = true;
    if (!silent && mounted) setState(() => loading = true);
    try {
      final results = await Future.wait<dynamic>([
        db.from('organizations').select('*').order('name'),
        db.from('members').select('id,org_id,org_name'),
        db.from('events').select('*').order('date', ascending: true),
        db.from('profiles').select('id,role'),
        db
            .from('profiles')
            .select('name,avatar_url')
            .eq('id', db.auth.currentUser?.id ?? '')
            .maybeSingle(),
        db
            .from('event_requests')
            .select('*')
            .order('created_at', ascending: false),
      ]);

      final organizationRows =
          List<Map<String, dynamic>>.from(results[0] as List);
      final memberRows = List<Map<String, dynamic>>.from(results[1] as List);
      final eventRows = List<Map<String, dynamic>>.from(results[2] as List);
      final profileRows = List<Map<String, dynamic>>.from(results[3] as List);
      final proposalRows = List<Map<String, dynamic>>.from(results[5] as List);

      final requesterIds = proposalRows
          .map((x) => x['requested_by']?.toString() ?? '')
          .where((x) => x.isNotEmpty)
          .toSet()
          .toList();
      Map<String, String> submitterNames = <String, String>{};
      if (requesterIds.isNotEmpty) {
        try {
          final requesters = await db
              .from('profiles')
              .select('id,name,email')
              .inFilter('id', requesterIds);
          for (final row in requesters as List) {
            final id = row['id']?.toString() ?? '';
            final name = row['name']?.toString().trim();
            final email = row['email']?.toString().trim();
            if (id.isNotEmpty) {
              submitterNames[id] = (name?.isNotEmpty ?? false)
                  ? name!
                  : (email?.isNotEmpty ?? false)
                      ? email!
                      : 'Unknown user';
            }
          }
        } catch (_) {
          // Some deployments may restrict profile lookup for requester names.
        }
      }

      List<dynamic> comments = <dynamic>[];
      try {
        comments = await db.from('event_comments').select('event_id');
      } catch (_) {
        // Comments are optional analytics data.
      }

      final nextOrgMembers = <String, int>{};
      final nextOrgEvents = <String, int>{};
      final nextOrgProposals = <String, int>{};
      final nextOrgComments = <String, int>{};

      for (final row in memberRows) {
        final id = row['org_id']?.toString() ?? '';
        if (id.isNotEmpty) nextOrgMembers[id] = (nextOrgMembers[id] ?? 0) + 1;
      }
      for (final row in eventRows) {
        final id = row['org_id']?.toString() ?? '';
        if (id.isNotEmpty) nextOrgEvents[id] = (nextOrgEvents[id] ?? 0) + 1;
      }
      for (final row in proposalRows) {
        final id = row['org_id']?.toString() ?? '';
        if (id.isNotEmpty) {
          nextOrgProposals[id] = (nextOrgProposals[id] ?? 0) + 1;
        }
      }
      for (final row in comments) {
        final eventId = row['event_id']?.toString();
        final matches =
            eventRows.where((event) => event['id']?.toString() == eventId);
        if (matches.isNotEmpty) {
          final id = matches.first['org_id']?.toString() ?? '';
          if (id.isNotEmpty) {
            nextOrgComments[id] = (nextOrgComments[id] ?? 0) + 1;
          }
        }
      }

      final nextScores = <String, double>{};
      for (final row in organizationRows) {
        final id = row['id']?.toString() ?? '';
        nextScores[id] = ((nextOrgMembers[id] ?? 0) +
                (nextOrgEvents[id] ?? 0) * 3 +
                (nextOrgProposals[id] ?? 0) * 2 +
                (nextOrgComments[id] ?? 0))
            .toDouble();
      }

      final filteredProposals = proposalRows
          .where((x) => x['status']?.toString() == 'forwarded_to_admin')
          .toList();
      final profile = results[4] as Map<String, dynamic>?;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      // All upcoming events (no cap). Events without a parseable date are
      // kept, exactly like before.
      final futureEvents = eventRows.where((x) {
        final date = DateTime.tryParse(x['date']?.toString() ?? '');
        return date == null ||
            !DateTime(date.year, date.month, date.day).isBefore(today);
      }).toList();

      if (!mounted) return;
      setState(() {
        orgs = organizationRows;
        members = memberRows.length;
        events = eventRows.length;
        users = profileRows.length;
        orgMembers = nextOrgMembers;
        orgEvents = nextOrgEvents;
        orgProposals = nextOrgProposals;
        orgComments = nextOrgComments;
        scores = nextScores;
        proposals = filteredProposals;
        proposalSubmitters = submitterNames;
        _avatarUrl = profile?['avatar_url']?.toString() ?? '';
        _userName = profile?['name']?.toString().trim() ?? '';
        homeEvents = futureEvents;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load admin data: $error')),
      );
    } finally {
      _isLoadingNow = false;
      if (_reloadQueued) {
        _reloadQueued = false;
        _scheduleReload();
      }
    }
  }

  /// Pull-to-refresh uses a silent reload (same queries, same error handling)
  /// so the RefreshIndicator stays alive until the data arrives instead of
  /// being replaced by the full-screen spinner mid-gesture.
  Future<void> _pullRefresh() => _load(silent: true);

  // ---------------------------------------------------------------------------
  // Responsive helpers
  // ---------------------------------------------------------------------------
  _Screen _screenOf(double width) {
    if (width < 600) return _Screen.mobile;
    if (width <= 1024) return _Screen.tablet;
    return _Screen.desktop;
  }

  double _hPad(_Screen s) {
    switch (s) {
      case _Screen.mobile:
        return 16;
      case _Screen.tablet:
        return 24;
      case _Screen.desktop:
        return 32;
    }
  }

  /// Lays [items] out in [cols] equal-width columns. Uses Wrap so tiles size
  /// to their own content height (no fixed aspect ratios, nothing overflows).
  Widget _wrapGrid(
    List<Widget> items, {
    required int cols,
    required double gap,
    required double maxWidth,
  }) {
    final tileWidth = (maxWidth - gap * (cols - 1)) / cols;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final item in items) SizedBox(width: tileWidth, child: item),
      ],
    );
  }

  /// Picks as many columns as fit given [minTileWidth].
  Widget _grid(
    List<Widget> items, {
    double minTileWidth = 300,
    double gap = 16,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, box) {
      final cols = ((box.maxWidth + gap) / (minTileWidth + gap))
          .floor()
          .clamp(1, items.length)
          .toInt();
      return _wrapGrid(items, cols: cols, gap: gap, maxWidth: box.maxWidth);
    });
  }

  String _formatCount(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return value < 0 ? '-$buffer' : buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Shell: scaffold + navigation
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final s = _screenOf(constraints.maxWidth);
      final body = loading
          ? const Center(child: CircularProgressIndicator(color: green))
          : IndexedStack(
              index: tab,
              children: [
                _home(s),
                _analytics(s),
                _organizations(s),
                const AdminAccountsScreen(),
                const AdminProfileScreen(), // index 4 = _profileTab
              ],
            );

      // mobile: bottom bar (below) | tablet: rail | desktop: full sidebar
      final Widget content = s == _Screen.mobile
          ? body
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                s == _Screen.desktop ? _sidebar() : _rail(),
                Expanded(child: body),
              ],
            );

      return Scaffold(
        backgroundColor: bg,
        body: SafeArea(top: false, child: content),
        floatingActionButton: _fab(s),
        bottomNavigationBar: s == _Screen.mobile ? _bottomNav() : null,
      );
    });
  }

  /// Create-organization button; only shown while the Organizations tab is
  /// active. Extended (with a label) on larger screens.
  Widget? _fab(_Screen s) {
    if (tab != 2) return null;
    if (s == _Screen.mobile) {
      return FloatingActionButton(
        onPressed: _openCreateOrg,
        tooltip: 'Create organization',
        backgroundColor: green,
        foregroundColor: Colors.white,
        elevation: 2,
        child: const Icon(Icons.add_rounded),
      );
    }
    return FloatingActionButton.extended(
      onPressed: _openCreateOrg,
      backgroundColor: green,
      foregroundColor: Colors.white,
      elevation: 2,
      icon: const Icon(Icons.add_rounded),
      label: const Text('New organization',
          style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _logoMark(double size) => ClipRRect(
        borderRadius: BorderRadius.circular(size * .26),
        child: Image.asset(
          'assets/icon/app_logo2.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: size,
            height: size,
            color: green,
            child:
                Icon(Icons.hub_rounded, color: Colors.white, size: size * .58),
          ),
        ),
      );

  /// One navigation destination (icon + label). Used by the bottom bar and
  /// the tablet rail. Selection is shown only by color (icon + label), with
  /// no background pill. The label scales down instead of clipping.
  Widget _navButton(int i) {
    final item = _items[i];
    final selected = tab == i;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: () => setState(() => tab = i),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _xs, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 56,
                height: 30,
                child: Center(
                  child: Icon(selected ? item.selectedIcon : item.icon,
                      size: 22, color: selected ? green : muted),
                ),
              ),
              const SizedBox(height: _xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? emeraldDeep : muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom navigation (mobile). Respects the bottom safe area.
  Widget _bottomNav() => Material(
        color: Colors.white,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: line)),
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Row(children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(child: _navButton(i)),
              ]),
            ),
          ),
        ),
      );

  /// Compact navigation rail (tablet). Scrolls on very short windows.
  Widget _rail() => Container(
        width: 96,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: line)),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: _lg),
              Center(child: _logoMark(40)),
              const SizedBox(height: _md),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: _sm, vertical: _xs),
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: _xs),
                        child: _navButton(i),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  /// Permanent sidebar (desktop).
  Widget _sidebar() => Container(
        width: 264,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: line)),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Row(children: [
                  _logoMark(38),
                  const SizedBox(width: _md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('OrgConnect',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: dark,
                                letterSpacing: -.2)),
                        SizedBox(height: 1),
                        Text('CSO Admin Workspace',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: muted)),
                      ],
                    ),
                  ),
                ]),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 4, 24, 6),
                child: Text('MENU',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9CA3AF),
                        letterSpacing: 1)),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  children: [
                    for (var i = 0; i < _items.length; i++) _sidebarItem(i),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Material(
                  color: bg,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: line),
                  ),
                  child: InkWell(
                    onTap: () => setState(() => tab = _profileTab),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(children: [
                        _avatar(36),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_userName.isEmpty ? 'Admin' : _userName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: dark)),
                              const Text('Administrator',
                                  style:
                                      TextStyle(fontSize: 11.5, color: muted)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: Color(0xFF9CA3AF), size: 20),
                      ]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  /// Sidebar destination. Selection is color only (icon + label), no
  /// background or border.
  Widget _sidebarItem(int i) {
    final item = _items[i];
    final selected = tab == i;
    return Padding(
      padding: const EdgeInsets.only(bottom: _xs),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: InkWell(
            onTap: () => setState(() => tab = i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(children: [
                Icon(selected ? item.selectedIcon : item.icon,
                    size: 20, color: selected ? green : muted),
                const SizedBox(width: _md),
                Expanded(
                  child: Text(item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? emeraldDeep : const Color(0xFF374151),
                      )),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------
  String _headerName(String fullName, String fallback) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.isEmpty ? fallback : parts.take(2).join(' ');
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildHeader({
    required _Screen s,
    required String title,
    required String subtitle,
    required String badge,
    IconData? icon,
  }) {
    final isMobile = s == _Screen.mobile;
    final hPad = _hPad(s);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: line)),
      ),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 14),
            child: Row(children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: emeraldSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: green, size: 22),
                ),
                const SizedBox(width: _md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _roleChip(badge),
                    const SizedBox(height: 6),
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.w800,
                            color: dark,
                            letterSpacing: -.3)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: isMobile ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: isMobile ? 12.5 : 13.5,
                            color: muted,
                            height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: _md),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => _load(),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                color: muted,
                style: IconButton.styleFrom(
                  minimumSize: const Size(40, 40),
                  side: const BorderSide(color: line),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: _sm),
              Tooltip(
                message: 'Open profile',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() => tab = _profileTab),
                  child: _avatar(40),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _roleChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: emeraldSoft,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: emeraldBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                const BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: emeraldDeep,
                    letterSpacing: .6)),
          ),
        ]),
      );

  Widget _avatar(double size) {
    final initial =
        _userName.trim().isNotEmpty ? _userName.trim()[0].toUpperCase() : 'A';
    final fallback = Container(
      alignment: Alignment.center,
      decoration:
          const BoxDecoration(color: emeraldSoft, shape: BoxShape.circle),
      child: Text(initial,
          style: TextStyle(
              color: emeraldDeep,
              fontWeight: FontWeight.w800,
              fontSize: size * .4)),
    );
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: emeraldBorder, width: 1.5),
      ),
      child: ClipOval(
        child: _avatarUrl.isEmpty
            ? fallback
            : Image.network(_avatarUrl,
                fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Page scaffolding
  // ---------------------------------------------------------------------------
  /// [scrollController] drives the page's ListView and the floating
  /// "back to top" button. [topButtonBottomOffset] lifts that button when
  /// another floating element (the create-organization FAB) shares the corner.
  Widget _pageBackground({
    required _Screen s,
    required Future<void> Function() onRefresh,
    required Widget header,
    required List<Widget> children,
    required ScrollController scrollController,
    double bottomPadding = 32,
    double topButtonBottomOffset = 0,
  }) {
    final hPad = _hPad(s);
    return Container(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header, // stays fixed at the top
          Expanded(
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: onRefresh,
                  color: green,
                  backgroundColor: Colors.white,
                  child: ListView(
                    controller: scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    padding: EdgeInsets.zero,
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: _maxContentWidth),
                          child: SizedBox(
                            width: double.infinity,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                  hPad, _xl, hPad, bottomPadding),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: children,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: _lg,
                  bottom: _lg + topButtonBottomOffset,
                  child: _ScrollToTopButton(controller: scrollController),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Base white card with border, restrained shadow and optional ink ripple.
  Widget _card({
    required Widget child,
    VoidCallback? onTap,
    EdgeInsets padding = const EdgeInsets.all(16),
    double radius = 16,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }

  /// Section title with an optional tinted icon and trailing widget.
  /// [warm] switches the icon tint from emerald to amber.
  Widget _sectionHeader(
    String title,
    String subtitle, {
    IconData? icon,
    bool warm = false,
    Widget? trailing,
  }) =>
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: warm ? amber.withValues(alpha: .10) : emeraldSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: warm ? amber : green, size: 18),
          ),
          const SizedBox(width: _md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: dark,
                      letterSpacing: -.2)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style:
                      const TextStyle(fontSize: 13, color: muted, height: 1.4)),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: _md), trailing],
      ]);

  // ---------------------------------------------------------------------------
  // HOME
  // ---------------------------------------------------------------------------
  Widget _home(_Screen s) => _pageBackground(
        s: s,
        onRefresh: _pullRefresh,
        scrollController: _homeScroll,
        header: _buildHeader(
          s: s,
          title: '${_greeting()}, ${_headerName(_userName, 'Admin')}',
          subtitle: 'Your organization network at a glance',
          badge: 'ADMIN / CSO WORKSPACE',
        ),
        children: [
          _homeStatsGrid(),
          const SizedBox(height: _section),
          // Side by side only when the content area is wide enough for both
          // panels to stay comfortable; otherwise stack them.
          LayoutBuilder(builder: (context, box) {
            if (box.maxWidth >= _sideBySideMin) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _eventsSection()),
                  const SizedBox(width: _xl),
                  Expanded(flex: 2, child: _proposalsSection()),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _eventsSection(),
                const SizedBox(height: _section),
                _proposalsSection(),
              ],
            );
          }),
        ],
      );

  // ---- Upcoming events: filtering -------------------------------------------

  /// Distinct, sorted organization names found in the upcoming events.
  List<String> _eventOrgNames() {
    final names = <String>{};
    for (final e in homeEvents) {
      final name = (e['org_name'] ?? '').toString().trim();
      if (name.isNotEmpty) names.add(name);
    }
    final list = names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  /// The selected organization, or '' if it no longer exists after a reload.
  String _effectiveEventOrg() {
    if (_eventOrg.isEmpty) return '';
    return _eventOrgNames().contains(_eventOrg) ? _eventOrg : '';
  }

  bool get _hasEventFilters =>
      _eventQuery.isNotEmpty ||
      _effectiveEventOrg().isNotEmpty ||
      _eventRange != _EventRange.all;

  void _clearEventFilters() {
    _eventSearchCtrl.clear();
    setState(() {
      _eventQuery = '';
      _eventOrg = '';
      _eventRange = _EventRange.all;
    });
  }

  List<Map<String, dynamic>> _filteredEvents() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Week runs through the coming Sunday.
    final weekEnd = today.add(Duration(days: 7 - today.weekday));
    final org = _effectiveEventOrg();

    return homeEvents.where((e) {
      if (org.isNotEmpty &&
          (e['org_name'] ?? '').toString().trim() != org) {
        return false;
      }
      if (_eventQuery.isNotEmpty) {
        final haystack = [
          e['title'],
          e['venue'],
          e['location'],
          e['org_name'],
          e['description'],
        ].map((v) => (v ?? '').toString()).join(' ').toLowerCase();
        if (!haystack.contains(_eventQuery)) return false;
      }
      if (_eventRange != _EventRange.all) {
        final date = DateTime.tryParse(e['date']?.toString() ?? '');
        if (date == null) return false;
        final day = DateTime(date.year, date.month, date.day);
        switch (_eventRange) {
          case _EventRange.today:
            if (day != today) return false;
            break;
          case _EventRange.week:
            if (day.isAfter(weekEnd)) return false;
            break;
          case _EventRange.month:
            if (day.year != today.year || day.month != today.month) {
              return false;
            }
            break;
          case _EventRange.all:
            break;
        }
      }
      return true;
    }).toList();
  }

  String _rangeLabel(_EventRange r) {
    switch (r) {
      case _EventRange.all:
        return 'All';
      case _EventRange.today:
        return 'Today';
      case _EventRange.week:
        return 'This week';
      case _EventRange.month:
        return 'This month';
    }
  }

  Widget _eventSearchField() => TextField(
        controller: _eventSearchCtrl,
        onChanged: (v) => setState(() => _eventQuery = v.trim().toLowerCase()),
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14, color: dark),
        decoration: InputDecoration(
          hintText: 'Search title, venue or organization',
          hintStyle: const TextStyle(fontSize: 13.5, color: muted),
          prefixIcon:
              const Icon(Icons.search_rounded, size: 20, color: muted),
          suffixIcon: _eventQuery.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: muted,
                  onPressed: () {
                    _eventSearchCtrl.clear();
                    setState(() => _eventQuery = '');
                  },
                ),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: green, width: 1.5),
          ),
        ),
      );

  Widget _eventOrgDropdown() {
    final names = _eventOrgNames();
    final value = _effectiveEventOrg();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: value.isEmpty ? line : green),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          menuMaxHeight: 320,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: muted),
          style: const TextStyle(fontSize: 14, color: dark),
          items: [
            const DropdownMenuItem<String>(
              value: '',
              child: Row(children: [
                Icon(Icons.apartment_rounded, size: 18, color: muted),
                SizedBox(width: 8),
                Text('All organizations'),
              ]),
            ),
            for (final name in names)
              DropdownMenuItem<String>(
                value: name,
                child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() => _eventOrg = v ?? ''),
        ),
      ),
    );
  }

  Widget _eventRangeChips() => SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final r in _EventRange.values)
              Padding(
                padding: const EdgeInsets.only(right: _sm),
                child: ChoiceChip(
                  label: Text(_rangeLabel(r)),
                  selected: _eventRange == r,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _eventRange = r),
                  backgroundColor: Colors.white,
                  selectedColor: emeraldSoft,
                  side: BorderSide(
                      color: _eventRange == r ? emeraldBorder : line),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                        _eventRange == r ? FontWeight.w700 : FontWeight.w500,
                    color: _eventRange == r ? emeraldDeep : muted,
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _eventFilters() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, box) {
            if (box.maxWidth >= 520) {
              return Row(children: [
                Expanded(flex: 3, child: _eventSearchField()),
                const SizedBox(width: _md),
                Expanded(flex: 2, child: _eventOrgDropdown()),
              ]);
            }
            return Column(children: [
              _eventSearchField(),
              const SizedBox(height: 10),
              _eventOrgDropdown(),
            ]);
          }),
          const SizedBox(height: 10),
          _eventRangeChips(),
        ],
      );

  Widget _eventsSection() {
    final filtered = _filteredEvents();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Upcoming Events',
          'Events already posted across organizations',
          icon: Icons.event_rounded,
          trailing: homeEvents.isEmpty ? null : _badge('${filtered.length}'),
        ),
        const SizedBox(height: 14),
        if (homeEvents.isEmpty)
          _emptyCard('No upcoming events posted yet.', Icons.event_busy_rounded)
        else ...[
          _eventFilters(),
          const SizedBox(height: _md),
          if (filtered.isEmpty) ...[
            _emptyCard('No events match your filters.', Icons.search_off_rounded),
            if (_hasEventFilters)
              Padding(
                padding: const EdgeInsets.only(top: _sm),
                child: Center(
                  child: TextButton.icon(
                    onPressed: _clearEventFilters,
                    style: TextButton.styleFrom(foregroundColor: green),
                    icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                    label: const Text('Clear filters',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
          ] else ...[
            if (_hasEventFilters)
              Padding(
                padding: const EdgeInsets.only(bottom: _sm),
                child: Row(children: [
                  Expanded(
                    child: Text(
                        'Showing ${filtered.length} of ${homeEvents.length} events',
                        style: const TextStyle(fontSize: 12, color: muted)),
                  ),
                  TextButton(
                    onPressed: _clearEventFilters,
                    style: TextButton.styleFrom(
                      foregroundColor: green,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Clear filters',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            _grid(filtered.map(_eventCard).toList(),
                minTileWidth: 420, gap: _md),
          ],
        ],
      ],
    );
  }

  Widget _proposalsSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Pending Adviser Proposals',
            'See who submitted each proposal and review it directly from Home',
            icon: Icons.assignment_turned_in_rounded,
            trailing: proposals.isEmpty ? null : _badge('${proposals.length}'),
          ),
          const SizedBox(height: 14),
          _pendingPreview(),
        ],
      );

  /// Two columns on narrow widths, four when each tile can stay >= 160 wide.
  Widget _homeStatsGrid() => LayoutBuilder(builder: (context, box) {
        const gap = _md;
        final cols = box.maxWidth >= 4 * 160 + 3 * gap ? 4 : 2;
        return _wrapGrid(
          [
            _stat(Icons.apartment_rounded, 'Organizations', orgs.length),
            _stat(Icons.manage_accounts_rounded, 'User Accounts', users),
            _stat(Icons.groups_rounded, 'Members', members),
            _stat(Icons.event_available_rounded, 'Events', events),
          ],
          cols: cols,
          gap: gap,
          maxWidth: box.maxWidth,
        );
      });

  Widget _stat(IconData icon, String label, int value) => _card(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(builder: (context, box) {
          // Wide tiles: icon beside the numbers. Narrow tiles: stacked.
          final horizontal = box.maxWidth >= 180;
          final iconBox = Container(
            padding: EdgeInsets.all(horizontal ? 11 : 9),
            decoration: BoxDecoration(
              color: emeraldSoft,
              borderRadius: BorderRadius.circular(horizontal ? 12 : 10),
            ),
            child: Icon(icon, color: green, size: horizontal ? 22 : 20),
          );
          final numbers = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(_formatCount(value),
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: dark,
                        height: 1.1)),
              ),
              const SizedBox(height: 2),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: muted,
                      fontWeight: FontWeight.w500)),
            ],
          );
          if (horizontal) {
            return Row(children: [
              iconBox,
              const SizedBox(width: 14),
              Expanded(child: numbers),
            ]);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [iconBox, const SizedBox(height: _md), numbers],
          );
        }),
      );

  String _formatDate(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year}';

  String? _eventTime(Map<String, dynamic> e, DateTime? date) {
    final raw = (e['time'] ?? e['start_time'] ?? '').toString().trim();
    if (raw.isNotEmpty) return raw;
    if (date != null && (date.hour != 0 || date.minute != 0)) {
      final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final m = date.minute.toString().padLeft(2, '0');
      return '$h:$m ${date.hour >= 12 ? 'PM' : 'AM'}';
    }
    return null;
  }

  bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }

  /// Compact horizontal event row: small thumbnail on the left, details on
  /// the right. Every optional field is skipped gracefully when missing.
  Widget _eventCard(Map<String, dynamic> e) {
    final imgs =
        (e['image_urls'] is List ? e['image_urls'] as List : const <dynamic>[])
            .whereType<String>()
            .toList();
    final single = e['image_url']?.toString();
    if (single != null && single.isNotEmpty && !imgs.contains(single)) {
      imgs.insert(0, single);
    }
    // First usable http(s) URL; anything else falls back to the placeholder.
    final imageUrl = imgs.firstWhere(_isHttpUrl, orElse: () => '');
    final date = DateTime.tryParse(e['date']?.toString() ?? '');
    final dateText = date == null ? 'Date to be announced' : _formatDate(date);
    final timeText = _eventTime(e, date);
    final place = (e['location'] ?? e['venue'] ?? '').toString().trim();
    final description = (e['description'] ?? '').toString().trim();
    final rawOrg = (e['org_name'] ?? '').toString().trim();
    final orgName = rawOrg.isEmpty ? 'Organization' : rawOrg;
    final rawTitle = (e['title'] ?? '').toString().trim();
    final title = rawTitle.isEmpty ? 'Untitled event' : rawTitle;

    return LayoutBuilder(builder: (context, box) {
      // Slightly larger thumbnail only when the tile is genuinely wide.
      final wide = box.maxWidth >= 440;
      final thumbW = wide ? 104.0 : 88.0;
      final thumbH = wide ? 112.0 : 96.0;
      return _card(
        padding: const EdgeInsets.all(_md),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: thumbH),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _eventThumb(imageUrl, thumbW, thumbH),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _orgBadge(orgName),
                    const SizedBox(height: 6),
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: dark,
                            height: 1.25)),
                    const SizedBox(height: 6),
                    Wrap(spacing: _md, runSpacing: _xs, children: [
                      _meta(Icons.calendar_month_rounded, dateText),
                      if (timeText != null)
                        _meta(Icons.schedule_rounded, timeText),
                    ]),
                    if (place.isNotEmpty) ...[
                      const SizedBox(height: _xs),
                      _meta(Icons.location_on_outlined, place),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: muted, height: 1.4, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _eventThumb(String url, double width, double height) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: width,
          height: height,
          child: url.isEmpty
              ? _eventPlaceholder()
              : Image.network(
                  url.trim(),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _eventPlaceholder(),
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : _eventPlaceholder(),
                ),
        ),
      );

  Widget _eventPlaceholder() => Container(
        color: emeraldSoft,
        alignment: Alignment.center,
        child: const Icon(Icons.event_rounded, color: green, size: 28),
      );

  /// Small icon + single-line text, sized to its content.
  Widget _meta(IconData icon, String text) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: green),
        const SizedBox(width: 5),
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: muted, fontSize: 12.5, fontWeight: FontWeight.w500)),
        ),
      ]);

  Widget _orgBadge(String text) => Row(children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: emeraldSoft,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: emeraldBorder),
            ),
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: emeraldDeep,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ]);

  Widget _pendingPreview() {
    if (proposals.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: _card(
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: emeraldSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_circle_outline_rounded,
                  color: green, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('All caught up',
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: dark)),
                  SizedBox(height: 2),
                  Text('No proposals are waiting for CSO review.',
                      style:
                          TextStyle(color: muted, fontSize: 12.5, height: 1.4)),
                ],
              ),
            ),
          ]),
        ),
      );
    }

    final shown = proposals.take(4).toList();
    return SizedBox(
      width: double.infinity,
      child: _card(
        padding: EdgeInsets.zero,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: line),
            _pendingRow(shown[i]),
          ],
          Container(
            decoration: const BoxDecoration(
              color: bg,
              border: Border(top: BorderSide(color: line)),
            ),
            padding: const EdgeInsets.fromLTRB(_lg, 4, _sm, 4),
            child: Row(children: [
              Expanded(
                child: proposals.length > shown.length
                    ? Text('Showing ${shown.length} of ${proposals.length}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: muted))
                    : const SizedBox.shrink(),
              ),
              TextButton.icon(
                onPressed: () => _openProposalOrganization(proposals.first),
                style: TextButton.styleFrom(foregroundColor: green),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Open proposals',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _pendingRow(Map<String, dynamic> p) {
    final orgName = _orgNameFor(p['org_id']?.toString());
    final knownSubmitter = proposalSubmitters[p['requested_by']?.toString()];
    final submitter = knownSubmitter ?? 'Submitter not available';
    final initial = (knownSubmitter != null && knownSubmitter.trim().isNotEmpty)
        ? knownSubmitter.trim()[0].toUpperCase()
        : '?';
    return InkWell(
      onTap: () => _openProposalOrganization(p),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration:
                const BoxDecoration(color: emeraldSoft, shape: BoxShape.circle),
            child: Text(initial,
                style: const TextStyle(
                    color: emeraldDeep,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
          ),
          const SizedBox(width: _md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['title']?.toString() ?? 'Proposal',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: dark)),
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: amber.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text('Pending',
                        style: TextStyle(
                            fontSize: 10,
                            color: amber,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(orgName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11.5,
                            color: muted,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 3),
                Text('Submitted by $submitter',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: muted)),
              ],
            ),
          ),
          const SizedBox(width: _sm),
          FilledButton(
            onPressed: () => _openProposalOrganization(p),
            style: FilledButton.styleFrom(
              backgroundColor: emeraldSoft,
              foregroundColor: emeraldDeep,
              elevation: 0,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: emeraldBorder),
              ),
            ),
            child: const Text('Review'),
          ),
        ]),
      ),
    );
  }

  void _openProposalOrganization(Map<String, dynamic> proposal) {
    final org = orgs
        .where((row) => row['id']?.toString() == proposal['org_id']?.toString())
        .toList();
    if (org.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('The organization for this proposal could not be found.')),
      );
      return;
    }
    _openOrg(
      org.first,
      initialTab: 2,
      focusProposalId: proposal['id']?.toString(),
    );
  }

  // ---------------------------------------------------------------------------
  // ANALYTICS
  // ---------------------------------------------------------------------------
  Widget _analytics(_Screen s) {
    final ranked = _ranked();
    final mostActive = ranked.take(5).toList();
    final needAttention = ranked.reversed.take(5).toList();
    final comparison = _memberComparison();
    final maxCount =
        comparison.isEmpty ? 1 : comparison.first['members'] as int;

    final activeSection = _rankedSection(
      title: 'Most Active Organizations',
      subtitle: 'Activity is based on members, events, proposals, and comments',
      rows: mostActive,
      active: true,
    );
    final attentionSection = _rankedSection(
      title: 'Organizations Needing Attention',
      subtitle: 'Lower activity surfaces areas worth checking',
      rows: needAttention,
      active: false,
    );

    return _pageBackground(
      s: s,
      onRefresh: _pullRefresh,
      scrollController: _analyticsScroll,
      header: _buildHeader(
        s: s,
        title: 'Analytics',
        subtitle: 'Organization activity, participation, and momentum',
        badge: 'ADMIN ANALYTICS',
        icon: Icons.insights_rounded,
      ),
      children: [
        LayoutBuilder(builder: (context, box) {
          if (box.maxWidth >= 820) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: activeSection),
                const SizedBox(width: _xl),
                Expanded(child: attentionSection),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              activeSection,
              const SizedBox(height: 22),
              attentionSection,
            ],
          );
        }),
        const SizedBox(height: _section),
        _sectionHeader(
          'Member Count Comparison',
          'Compare the current number of members across all organizations',
          icon: Icons.groups_rounded,
        ),
        const SizedBox(height: 14),
        if (comparison.isEmpty)
          _emptyCard('No organizations found.', Icons.groups_outlined)
        else
          _grid(
            comparison
                .map((row) => _memberComparisonCard(row, maxCount))
                .toList(),
            minTileWidth: 260,
            gap: _md,
          ),
      ],
    );
  }

  Widget _rankedSection({
    required String title,
    required String subtitle,
    required List<Map<String, dynamic>> rows,
    required bool active,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            title,
            subtitle,
            icon:
                active ? Icons.trending_up_rounded : Icons.visibility_outlined,
            warm: !active,
          ),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            _emptyCard('No organizations to rank yet.', Icons.insights_outlined)
          else
            ...rows.map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _analyticsOrgCard(row, active: active),
                )),
        ],
      );

  List<Map<String, dynamic>> _ranked() {
    final list = orgs.map((row) {
      final id = row['id']?.toString() ?? '';
      return <String, dynamic>{
        'org': row,
        'score': scores[id] ?? 0,
        'members': orgMembers[id] ?? 0,
        'events': orgEvents[id] ?? 0,
        'proposals': orgProposals[id] ?? 0,
      };
    }).toList();
    list.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    return list;
  }

  List<Map<String, dynamic>> _memberComparison() {
    final rows = orgs.map((org) {
      final id = org['id']?.toString() ?? '';
      return <String, dynamic>{
        'org': org,
        'members': orgMembers[id] ?? 0,
      };
    }).toList();
    rows.sort((a, b) => (b['members'] as int).compareTo(a['members'] as int));
    return rows;
  }

  /// Logo + name on top, progress bar + member count underneath, so long
  /// names get the full card width.
  Widget _memberComparisonCard(Map<String, dynamic> row, int maxCount) {
    final org = row['org'] as Map<String, dynamic>;
    final count = row['members'] as int;
    final progress = maxCount <= 0 ? 0.0 : count / maxCount;
    return _card(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _orgLogo(org['logo_asset']?.toString() ?? '', size: 40),
          const SizedBox(width: _md),
          Expanded(
              child: Text(org['name']?.toString() ?? 'Organization',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: dark,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      height: 1.25))),
        ]),
        const SizedBox(height: _md),
        Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: const Color(0xFFF3F4F6),
                valueColor: const AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('$count member${count == 1 ? '' : 's'}',
              style: const TextStyle(
                  color: emeraldDeep,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5)),
        ]),
      ]),
    );
  }

  /// Emerald points badge for active organizations, amber for the
  /// "worth checking" list. Low activity is a prompt to look, not a verdict.
  Widget _analyticsOrgCard(Map<String, dynamic> row, {required bool active}) {
    final org = row['org'] as Map<String, dynamic>;
    final score = (row['score'] as double).round();
    final tone = active ? green : amber;
    return _card(
      onTap: () => _openOrg(org),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        _orgLogo(org['logo_asset']?.toString() ?? '', size: 46),
        const SizedBox(width: _md),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(org['name']?.toString() ?? 'Organization',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: dark,
                  height: 1.25)),
          const SizedBox(height: _xs),
          Text(
              '${row['members']} members • ${row['events']} events • ${row['proposals']} proposals',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, fontSize: 12, height: 1.35)),
        ])),
        const SizedBox(width: _sm),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: tone.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: tone.withValues(alpha: .25))),
            child: Text('$score pts',
                style: TextStyle(
                    color: tone, fontWeight: FontWeight.w700, fontSize: 11.5))),
      ]),
    );
  }

  // ---------------------------------------------------------------------------
  // ORGANIZATIONS
  // ---------------------------------------------------------------------------
  Widget _organizations(_Screen s) => _pageBackground(
        s: s,
        onRefresh: _pullRefresh,
        scrollController: _orgsScroll,
        bottomPadding: 96, // room for the floating action button
        topButtonBottomOffset: 64, // sit above the create-organization FAB
        header: _buildHeader(
          s: s,
          title: 'Organizations',
          subtitle: 'Browse every organization and its activity report',
          badge: '${orgs.length} ORGANIZATIONS',
          icon: Icons.apartment_rounded,
        ),
        children: [
          _sectionHeader(
            'Organization Network',
            'Select an organization to explore its people, events, proposals, and finances',
            icon: Icons.hub_rounded,
          ),
          const SizedBox(height: 14),
          if (orgs.isEmpty)
            _emptyCard('No organizations found.', Icons.apartment_outlined)
          else
            _grid(orgs.map(_orgCard).toList(), minTileWidth: 320),
        ],
      );

  /// Header row (logo, name, category, delete) above a three-number stats bar.
  Widget _orgCard(Map<String, dynamic> org) {
    final id = org['id']?.toString() ?? '';
    final category = (org['category']?.toString() ?? '').trim();
    return _card(
      onTap: () => _openOrg(org),
      padding: const EdgeInsets.all(_lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _orgLogo(org['logo_asset']?.toString() ?? '', size: 56),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(org['name']?.toString() ?? 'Organization',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: dark,
                        height: 1.25)),
              ),
              if (category.isNotEmpty) ...[
                const SizedBox(height: _xs),
                Text(category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: green,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ]),
          ),
          const SizedBox(width: _sm),
          IconButton(
            tooltip: 'Delete organization',
            onPressed: () => _confirmDeleteOrg(org),
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: danger,
            style: IconButton.styleFrom(
              backgroundColor: danger.withValues(alpha: .06),
              minimumSize: const Size(44, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: danger.withValues(alpha: .18)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: line),
          ),
          child: Row(children: [
            Expanded(child: _orgStat(orgMembers[id] ?? 0, 'Members')),
            _statDivider(),
            Expanded(child: _orgStat(orgEvents[id] ?? 0, 'Events')),
            _statDivider(),
            Expanded(child: _orgStat(orgProposals[id] ?? 0, 'Proposals')),
          ]),
        ),
      ]),
    );
  }

  Widget _orgStat(int value, String label) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_formatCount(value),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: dark)),
          ),
          const SizedBox(height: 1),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11, color: muted, fontWeight: FontWeight.w500)),
        ],
      );

  Widget _statDivider() => Container(width: 1, height: 28, color: line);

  Widget _orgLogo(String asset, {double size = 64}) {
    final value = asset.trim();
    Widget image;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      image = Image.network(value,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _logoFallback(size));
    } else if (value.isNotEmpty) {
      image = Image.asset(value.startsWith('assets/') ? value : 'assets/$value',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _logoFallback(size));
    } else {
      image = _logoFallback(size);
    }
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .28),
        color: Colors.white,
        border: Border.all(color: line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .24),
        child: image,
      ),
    );
  }

  Widget _logoFallback(double size) => Container(
      color: emeraldSoft,
      child: Icon(Icons.groups_rounded, color: green, size: size * .48));

  // ---------------------------------------------------------------------------
  // Shared small widgets
  // ---------------------------------------------------------------------------
  Widget _emptyCard(String text, IconData icon) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                  color: emeraldSoft, shape: BoxShape.circle),
              child: Icon(icon, color: green, size: 26)),
          const SizedBox(height: _md),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, height: 1.4, fontSize: 13.5))
        ]),
      );

  Widget _badge(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: emeraldSoft,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: emeraldBorder)),
      child: Text(text,
          style: const TextStyle(
              color: emeraldDeep,
              fontSize: 11.5,
              fontWeight: FontWeight.w700)));

  String _orgNameFor(String? id) {
    if (id == null || id.isEmpty) return 'Organization';
    for (final org in orgs) {
      if (org['id']?.toString() == id) {
        return org['name']?.toString() ?? 'Organization';
      }
    }
    return 'Organization';
  }

  // ---------------------------------------------------------------------------
  // Actions (unchanged logic)
  // ---------------------------------------------------------------------------
  Future<void> _openCreateOrg() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminCreateOrganizationScreen(),
      ),
    );
    if (created == true) await _load(silent: true);
  }

  Future<void> _confirmDeleteOrg(Map<String, dynamic> org) async {
    final id = org['id']?.toString() ?? '';
    final name = org['name']?.toString() ?? 'Organization';
    if (id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteOrgDialog(
        orgName: name,
        members: orgMembers[id] ?? 0,
        events: orgEvents[id] ?? 0,
        proposals: orgProposals[id] ?? 0,
      ),
    );
    if (confirmed != true || !mounted) return;

    final logo = org['logo_asset']?.toString() ?? '';
    setState(() => loading = true);
    try {
      await db.rpc('admin_delete_organization', params: {'p_org_id': id});
    } catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete organization: $error')),
      );
      return;
    }

    await _removeOrgLogo(logo);
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"$name" was deleted.')),
    );
  }

  // Best effort: only removes logos stored in org-assets/org_logos/.
  Future<void> _removeOrgLogo(String logo) async {
    const marker = '/object/public/org-assets/org_logos/';
    final index = logo.indexOf(marker);
    if (index < 0) return;
    final file = logo.substring(index + marker.length).split('?').first;
    try {
      await db.storage.from('org-assets').remove(['org_logos/$file']);
    } catch (_) {
      // The org is already deleted; a leftover logo file is harmless.
    }
  }

  void _openOrg(
    Map<String, dynamic> org, {
    int initialTab = 0,
    String? focusProposalId,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminOrganizationDetailScreen(
          orgId: org['id'].toString(),
          orgName: org['name']?.toString() ?? 'Organization',
          initialTab: initialTab,
          focusProposalId: focusProposalId,
        ),
      ),
    );
  }
}

/// Green circular "back to top" button. Fades/scales in once the attached
/// scrollable has moved past [_showAfter] pixels and animates smoothly back
/// to the top when tapped.
class _ScrollToTopButton extends StatefulWidget {
  const _ScrollToTopButton({required this.controller});

  final ScrollController controller;

  @override
  State<_ScrollToTopButton> createState() => _ScrollToTopButtonState();
}

class _ScrollToTopButtonState extends State<_ScrollToTopButton> {
  static const double _showAfter = 320;
  static const Color _green = Color(0xFF059669);

  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _ScrollToTopButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.controller.hasClients) return;
    final show = widget.controller.offset > _showAfter;
    if (show != _visible && mounted) setState(() => _visible = show);
  }

  void _toTop() {
    if (!widget.controller.hasClients) return;
    widget.controller.animateTo(
      0,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !_visible,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedScale(
          scale: _visible ? 1 : .6,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: Tooltip(
            message: 'Back to top',
            child: Material(
              color: _green,
              elevation: 4,
              shadowColor: Colors.black38,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _toTop,
                child: const SizedBox(
                  width: 46,
                  height: 46,
                  child: Icon(Icons.keyboard_arrow_up_rounded,
                      color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteOrgDialog extends StatefulWidget {
  const _DeleteOrgDialog({
    required this.orgName,
    required this.members,
    required this.events,
    required this.proposals,
  });

  final String orgName;
  final int members;
  final int events;
  final int proposals;

  @override
  State<_DeleteOrgDialog> createState() => _DeleteOrgDialogState();
}

class _DeleteOrgDialogState extends State<_DeleteOrgDialog> {
  final _controller = TextEditingController();

  bool get _matches =>
      _controller.text.trim().toLowerCase() ==
      widget.orgName.trim().toLowerCase();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF111827);
    const muted = Color(0xFF6B7280);
    const danger = Color(0xFFDC2626);
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Delete organization?',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: dark)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'This permanently deletes "${widget.orgName}" and cannot be undone.',
                style: const TextStyle(color: dark, height: 1.4)),
            const SizedBox(height: 12),
            Text(
                'It will also remove ${widget.members} members, ${widget.events} events, '
                '${widget.proposals} proposals, and all applications, chat messages, '
                'attendance, meeting minutes, finance records and impact ratings of this '
                'organization. Its officers and adviser become regular students.',
                style:
                    const TextStyle(fontSize: 12.5, height: 1.4, color: muted)),
            const SizedBox(height: 14),
            const Text('Type the organization name to confirm:',
                style: TextStyle(fontWeight: FontWeight.w600, color: dark)),
            const SizedBox(height: 6),
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: widget.orgName,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: danger, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(foregroundColor: muted),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _matches ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(backgroundColor: danger),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}