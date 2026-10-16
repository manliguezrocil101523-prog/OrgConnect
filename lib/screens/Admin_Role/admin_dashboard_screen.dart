import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_manage_accounts.dart';
import 'admin_organization_detail_screen.dart';
import 'admin_profile_screen.dart';

import '../../widgets/app_header.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  static const green = Color(0xFF128058);
  static const dark = Color(0xFF073B2A);
  static const muted = Color(0xFF4D6F62);
  static const bg = Color(0xFFE6F7EE);
  static const line = Color(0xFFB9E4CF);

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
      final futureEvents = eventRows
          .where((x) {
            final date = DateTime.tryParse(x['date']?.toString() ?? '');
            return date == null ||
                !DateTime(date.year, date.month, date.day).isBefore(today);
          })
          .take(6)
          .toList();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        top: false,
        child: loading
            ? const Center(child: CircularProgressIndicator(color: green))
            : IndexedStack(
                index: tab,
                children: [
                  _home(),
                  _analytics(),
                  _organizations(),
                  const AdminAccountsScreen(),
                  const AdminProfileScreen(),
                ],
              ),
      ),
      bottomNavigationBar: _nav(),
    );
  }

  Widget _nav() => NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) => setState(() => tab = index),
        backgroundColor: Colors.white,
        indicatorColor: green.withValues(alpha: .13),
        elevation: 10,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: green),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded, color: green),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.apartment_outlined),
            selectedIcon: Icon(Icons.apartment_rounded, color: green),
            label: 'Organizations',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_accounts_outlined),
            selectedIcon: Icon(Icons.manage_accounts_rounded, color: green),
            label: 'Accounts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded, color: green),
            label: 'Profile',
          ),
        ],
      );

  String _headerName(String fullName, String fallback) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.isEmpty ? fallback : parts.take(2).join(' ');
  }

  Widget _home() => _pageBackground(
        onRefresh: _load,
        header: AppHeader(
          title: 'Good day, ${_headerName(_userName, 'Admin')} 👋',
          subtitle: 'Your organization network at a glance',
          status: 'ADMIN / CSO WORKSPACE',
          avatarUrl: _avatarUrl,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _homeStatsGrid(),
                const SizedBox(height: 24),
                _sectionHeader('Upcoming Events',
                    'Events already posted across organizations'),
                const SizedBox(height: 10),
                if (homeEvents.isEmpty)
                  _emptyCard('No upcoming events posted yet.',
                      Icons.event_busy_rounded)
                else
                  ...homeEvents.take(4).map(_eventCard),
                const SizedBox(height: 24),
                _sectionHeader(
                  'Pending Adviser Proposals',
                  'See who submitted each proposal and review it directly from Home',
                ),
                const SizedBox(height: 10),
                _pendingPreview(),
              ],
            ),
          ),
        ],
      );
  Widget _analytics() => _pageBackground(
        onRefresh: _load,
        header: const AppHeader(
          title: 'Analytics',
          subtitle: 'Organization activity, participation, and momentum',
          status: 'ADMIN ANALYTICS',
          icon: Icons.insights_rounded,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('Most Active Organizations',
                    'Activity is based on members, events, proposals, and comments'),
                const SizedBox(height: 10),
                ..._ranked()
                    .take(5)
                    .map((row) => _analyticsOrgCard(row, active: true)),
                if (_ranked().isNotEmpty) const SizedBox(height: 18),
                _sectionHeader('Organizations Needing Attention',
                    'Lower activity surfaces areas worth checking'),
                const SizedBox(height: 10),
                ..._ranked()
                    .reversed
                    .take(5)
                    .map((row) => _analyticsOrgCard(row, active: false)),
                const SizedBox(height: 24),
                _sectionHeader('Member Count Comparison',
                    'Compare the current number of members across all organizations'),
                const SizedBox(height: 10),
                ..._memberComparison().map(_memberComparisonCard),
              ],
            ),
          ),
        ],
      );
  Widget _organizations() => _pageBackground(
        onRefresh: _load,
        header: AppHeader(
          title: 'Organizations',
          subtitle: 'Browse every organization and its activity report',
          status: '${orgs.length} ORGANIZATIONS',
          icon: Icons.apartment_rounded,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('Organization Network',
                    'Select an organization to explore its people, events, proposals, and finances'),
                const SizedBox(height: 10),
                if (orgs.isEmpty)
                  _emptyCard(
                      'No organizations found.', Icons.apartment_outlined)
                else
                  ...orgs.map(_orgCard),
              ],
            ),
          ),
        ],
      );
  Widget _pageBackground({
    required Future<void> Function() onRefresh,
    required Widget header,
    required List<Widget> children,
  }) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE6F7EE), Color(0xFFDDF4E8), Color(0xFFF5FFF9)],
        ),
      ),
      child: Column(
        children: [
          header, // stays fixed at the top
          Expanded(
            child: RefreshIndicator(
              onRefresh: onRefresh,
              color: green,
              backgroundColor: const Color(0xFFF5FFF9),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: EdgeInsets.zero,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _homeStatsGrid() => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.15,
        children: [
          _stat(Icons.apartment_rounded, 'Organizations', orgs.length),
          _stat(Icons.manage_accounts_rounded, 'User Accounts', users),
        ],
      );

  Widget _stat(IconData icon, String label, int value) => Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F8F62), Color(0xFF20B77D)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .18)),
          boxShadow: [
            BoxShadow(
                color: green.withValues(alpha: .14),
                blurRadius: 18,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: Colors.white, size: 16)),
          const Spacer(),
          Text('$value',
              style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.white.withValues(alpha: .82),
                  fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _sectionHeader(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w900, color: dark)),
          const SizedBox(height: 3),
          Text(subtitle,
              style:
                  const TextStyle(fontSize: 11.5, color: muted, height: 1.35)),
        ],
      );

  Widget _eventCard(Map<String, dynamic> e) {
    final imgs =
        (e['image_urls'] is List ? e['image_urls'] as List : const <dynamic>[])
            .whereType<String>()
            .toList();
    final single = e['image_url']?.toString();
    if (single != null && single.isNotEmpty && !imgs.contains(single)) {
      imgs.insert(0, single);
    }
    final date = DateTime.tryParse(e['date']?.toString() ?? '');
    final dateText = date == null
        ? 'Date to be announced'
        : '${date.month}/${date.day}/${date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE9FFF2), Color(0xFFBDF3D0)]),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: line),
        boxShadow: [
          BoxShadow(
              color: green.withValues(alpha: .08),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (imgs.isNotEmpty)
          SizedBox(
              height: 220,
              width: double.infinity,
              child: Image.network(imgs.first,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _eventPlaceholder()))
        else
          _eventPlaceholder(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e['title']?.toString() ?? 'Untitled event',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w900, color: dark)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.calendar_month_rounded, size: 15, color: green),
              const SizedBox(width: 6),
              Text(dateText,
                  style: const TextStyle(
                      color: muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700))
            ]),
            const SizedBox(height: 5),
            Text(e['org_name']?.toString() ?? 'Organization',
                style: const TextStyle(
                    color: muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
            if ((e['description'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(e['description'].toString(),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: muted, height: 1.35, fontSize: 12)),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _eventPlaceholder() => Container(
      height: 220,
      width: double.infinity,
      color: green.withValues(alpha: .08),
      child: const Center(
          child: Icon(Icons.image_outlined, color: green, size: 40)));

  Widget _pendingPreview() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF8FFFB), Color(0xFFDDF4E8)]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: line),
          boxShadow: [
            BoxShadow(
                color: green.withValues(alpha: .06),
                blurRadius: 15,
                offset: const Offset(0, 6))
          ],
        ),
        child: proposals.isEmpty
            ? const Row(children: [
                Icon(Icons.check_circle_outline_rounded, color: green),
                SizedBox(width: 10),
                Expanded(
                    child: Text('No proposals are waiting for CSO review.',
                        style: TextStyle(
                            color: muted, fontWeight: FontWeight.w700)))
              ])
            : Column(children: [
                Row(children: [
                  Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                          color: green.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.assignment_turned_in_rounded,
                          color: green, size: 19)),
                  const SizedBox(width: 10),
                  const Expanded(
                      child: Text('Waiting for CSO review',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: dark))),
                  _badge('${proposals.length}'),
                ]),
                const SizedBox(height: 10),
                ...proposals.take(4).map(_pendingRow),
                const SizedBox(height: 8),
                Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                        onPressed: proposals.isEmpty
                            ? null
                            : () => _openProposalOrganization(proposals.first),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Open proposals'))),
              ]),
      );

  Widget _pendingRow(Map<String, dynamic> p) {
    final orgName = _orgNameFor(p['org_id']?.toString());
    final submitter = proposalSubmitters[p['requested_by']?.toString()] ??
        'Submitter not available';
    return InkWell(
      onTap: () => _openProposalOrganization(p),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .78),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: line.withValues(alpha: .8))),
        child: Row(children: [
          const Icon(Icons.description_outlined, color: green, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(p['title']?.toString() ?? 'Proposal',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, color: dark)),
                const SizedBox(height: 3),
                Text(orgName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10.5,
                        color: muted,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Submitted by $submitter',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: muted)),
              ])),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
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

  Widget _memberComparisonCard(Map<String, dynamic> row) {
    final org = row['org'] as Map<String, dynamic>;
    final count = row['members'] as int;
    final rows = _memberComparison();
    final maxCount = rows.isEmpty ? 1 : rows.first['members'] as int;
    final progress = maxCount <= 0 ? 0.0 : count / maxCount;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
        boxShadow: [
          BoxShadow(
              color: green.withValues(alpha: .045),
              blurRadius: 12,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _orgLogo(org['logo_asset']?.toString() ?? '', size: 42),
          const SizedBox(width: 10),
          Expanded(
              child: Text(org['name']?.toString() ?? 'Organization',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: dark,
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5))),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                  color: green.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(30)),
              child: Text('$count member${count == 1 ? '' : 's'}',
                  style: const TextStyle(
                      color: green,
                      fontWeight: FontWeight.w900,
                      fontSize: 10.5))),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: const Color(0xFFE5F5EC),
            valueColor: const AlwaysStoppedAnimation<Color>(green),
          ),
        ),
      ]),
    );
  }

  Widget _analyticsOrgCard(Map<String, dynamic> row, {required bool active}) {
    final org = row['org'] as Map<String, dynamic>;
    final score = (row['score'] as double).round();
    final labelColor = active ? green : const Color(0xFFD97706);
    return InkWell(
      onTap: () => _openOrg(org),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: line),
          boxShadow: [
            BoxShadow(
                color: green.withValues(alpha: .05),
                blurRadius: 14,
                offset: const Offset(0, 6))
          ],
        ),
        child: Row(children: [
          _orgLogo(org['logo_asset']?.toString() ?? '', size: 50),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(org['name']?.toString() ?? 'Organization',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: dark)),
                const SizedBox(height: 4),
                Text(
                    '${row['members']} members • ${row['events']} events • ${row['proposals']} proposals',
                    style: const TextStyle(color: muted, fontSize: 11.5)),
              ])),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                  color: labelColor.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(30)),
              child: Text('$score pts',
                  style: TextStyle(
                      color: labelColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 10.5))),
        ]),
      ),
    );
  }

  Widget _orgCard(Map<String, dynamic> org) {
    final id = org['id']?.toString() ?? '';
    return InkWell(
      onTap: () => _openOrg(org),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF8FFFB), Color(0xFFDDF4E8)]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: line),
          boxShadow: [
            BoxShadow(
                color: green.withValues(alpha: .07),
                blurRadius: 15,
                offset: const Offset(0, 6))
          ],
        ),
        child: Row(children: [
          _orgLogo(org['logo_asset']?.toString() ?? '', size: 64),
          const SizedBox(width: 13),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(org['name']?.toString() ?? 'Organization',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: dark)),
                if ((org['category']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(org['category'].toString(),
                      style: const TextStyle(
                          color: green,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800)),
                ],
                const SizedBox(height: 7),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _miniChip(
                      Icons.groups_rounded, '${orgMembers[id] ?? 0} members'),
                  _miniChip(
                      Icons.event_rounded, '${orgEvents[id] ?? 0} events'),
                  _miniChip(Icons.assignment_rounded,
                      '${orgProposals[id] ?? 0} proposals'),
                ]),
              ])),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        ]),
      ),
    );
  }

  Widget _miniChip(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .80),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: line.withValues(alpha: .7))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: green),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  fontSize: 9.5, color: muted, fontWeight: FontWeight.w800))
        ]),
      );

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
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.white.withValues(alpha: .9)),
          boxShadow: [
            BoxShadow(color: green.withValues(alpha: .08), blurRadius: 12)
          ]),
      child: ClipOval(child: image),
    );
  }

  Widget _logoFallback(double size) => Container(
      color: const Color(0xFFE8F7ED),
      child: Icon(Icons.groups_rounded, color: green, size: size * .48));

  Widget _emptyCard(String text, IconData icon) => Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 220),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFF8FFFB), Color(0xFFDDF4E8)]),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: line)),
        child: Column(children: [
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: green.withValues(alpha: .09), shape: BoxShape.circle),
              child: Icon(icon, color: green, size: 26)),
          const SizedBox(height: 10),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, height: 1.4))
        ]),
      );

  Widget _badge(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: green.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(30)),
      child: Text(text,
          style: const TextStyle(
              color: dark, fontSize: 10.5, fontWeight: FontWeight.w900)));

  String _orgNameFor(String? id) {
    if (id == null || id.isEmpty) return 'Organization';
    for (final org in orgs) {
      if (org['id']?.toString() == id) {
        return org['name']?.toString() ?? 'Organization';
      }
    }
    return 'Organization';
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
