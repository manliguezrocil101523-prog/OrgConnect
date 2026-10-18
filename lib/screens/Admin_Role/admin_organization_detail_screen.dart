import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../analytics/event_comments_sheet.dart';

class AdminOrganizationDetailScreen extends StatefulWidget {
  final String orgId;
  final String orgName;
  final int initialTab;
  final String? focusProposalId;

  const AdminOrganizationDetailScreen({
    super.key,
    required this.orgId,
    required this.orgName,
    this.initialTab = 0,
    this.focusProposalId,
  });

  @override
  State<AdminOrganizationDetailScreen> createState() =>
      _AdminOrganizationDetailScreenState();
}

class _AdminOrganizationDetailScreenState
    extends State<AdminOrganizationDetailScreen>
    with SingleTickerProviderStateMixin {
  static const green = Color(0xFF128058);
  static const dark = Color(0xFF073B2A);
  static const muted = Color(0xFF4D6F62);
  static const bg = Color(0xFFE6F7EE);
  static const mint = Color(0xFFDDF4E8);
  static const line = Color(0xFFB9E4CF);

  final db = Supabase.instance.client;
  late final TabController tabs;
  bool loading = true;
  Map<String, dynamic>? org;
  List<Map<String, dynamic>> members = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> officers = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> advisers = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> events = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> proposals = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> finance = <Map<String, dynamic>>[];
  Map<String, String> proposalSubmitters = <String, String>{};
  double allocated = 0;
  DateTime _calendarFocusedDay = DateTime.now();
  DateTime? _calendarSelectedDay;
  bool _showAllProposalHistory = false;

  @override
  void initState() {
    super.initState();
    tabs = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    _load();
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    try {
      final results = await Future.wait<dynamic>([
        db.from('organizations').select().eq('id', widget.orgId).maybeSingle(),
        db
            .from('members')
            .select('id,name,position,profile_id')
            .eq('org_id', widget.orgId),
        db
            .from('profiles')
            .select('id,name,email,role,avatar_url')
            .or('assigned_org_id.eq.${widget.orgId},org_id.eq.${widget.orgId}')
            .order('name'),
        db
            .from('events')
            .select('*')
            .eq('org_id', widget.orgId)
            .order('date', ascending: false),
        db
            .from('event_requests')
            .select('*')
            .eq('org_id', widget.orgId)
            .order('created_at', ascending: false),
        db
            .from('org_financial_transactions')
            .select('*')
            .eq('org_id', widget.orgId)
            .order('transaction_date', ascending: false),
      ]);

      final organization = results[0] as Map<String, dynamic>?;
      final memberRows = List<Map<String, dynamic>>.from(results[1] as List);
      final profileRows = List<Map<String, dynamic>>.from(results[2] as List);
      final eventRows = List<Map<String, dynamic>>.from(results[3] as List);
      final proposalRows = List<Map<String, dynamic>>.from(results[4] as List);
      final financeRows = List<Map<String, dynamic>>.from(results[5] as List);

      final positionByProfileId = <String, String>{};
      for (final member in memberRows) {
        final profileId = member['profile_id']?.toString() ?? '';
        final position = member['position']?.toString().trim() ?? '';
        if (profileId.isNotEmpty && position.isNotEmpty) {
          positionByProfileId[profileId] = position;
        }
      }
      for (final person in profileRows) {
        final profileId = person['id']?.toString() ?? '';
        final position = positionByProfileId[profileId];
        if (position != null && position.isNotEmpty) {
          person['position'] = position;
        }
      }

      final submitterNames = <String, String>{};
      for (final person in profileRows) {
        final id = person['id']?.toString() ?? '';
        final name = person['name']?.toString().trim() ?? '';
        final email = person['email']?.toString().trim() ?? '';
        if (id.isNotEmpty) {
          submitterNames[id] = name.isNotEmpty
              ? name
              : (email.isNotEmpty ? email : 'Organization user');
        }
      }

      if (widget.focusProposalId != null) {
        proposalRows.sort((a, b) {
          final aMatch = a['id']?.toString() == widget.focusProposalId ? 0 : 1;
          final bMatch = b['id']?.toString() == widget.focusProposalId ? 0 : 1;
          return aMatch.compareTo(bMatch);
        });
      }

      if (!mounted) return;
      setState(() {
        org = organization;
        members = memberRows;
        officers = profileRows.where((x) {
          final role = (x['role']?.toString() ?? '').toLowerCase().replaceAll(' ', '_');
          return const {
            'officer', 'president', 'vice_president', 'secretary',
            'assistant_secretary', 'treasurer'
          }.contains(role);
        }).toList();
        advisers = profileRows
            .where((x) => x['role']?.toString() == 'adviser')
            .toList();
        events = eventRows;
        proposals = proposalRows;
        proposalSubmitters = submitterNames;
        finance = financeRows;
        allocated =
            (organization?['allocated_budget'] as num?)?.toDouble() ?? 0;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load organization: $error')));
    }
  }

  double get income => finance
      .where((x) => x['type'] == 'income')
      .fold(0.0, (sum, x) => sum + ((x['amount'] as num?)?.toDouble() ?? 0));
  double get expenses => finance
      .where((x) => x['type'] == 'expense')
      .fold(0.0, (sum, x) => sum + ((x['amount'] as num?)?.toDouble() ?? 0));
  // CSO allocation is tracked separately; only posted available-fund transactions affect spendable balance.
  double get balance => income - expenses;

  @override
  Widget build(BuildContext context) {
    final currentOrg = org;
    final logo = currentOrg?['logo_asset']?.toString() ?? '';
    final category = currentOrg?['category']?.toString() ?? 'Organization';

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        top: false,
        child: loading
            ? const Center(child: CircularProgressIndicator(color: green))
            : Column(
                children: [
                  _hero(currentOrg, logo, category),
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      controller: tabs,
                      labelColor: green,
                      unselectedLabelColor: muted,
                      indicatorColor: green,
                      indicatorWeight: 3,
                      dividerColor: Colors.transparent,
                      isScrollable: true,
                      tabs: const [
                        Tab(
                            icon: Icon(Icons.dashboard_rounded, size: 18),
                            text: 'Overview'),
                        Tab(
                            icon: Icon(Icons.groups_rounded, size: 18),
                            text: 'People'),
                        Tab(
                            icon: Icon(Icons.event_rounded, size: 18),
                            text: 'Events & Proposals'),
                        Tab(
                            icon: Icon(Icons.account_balance_wallet_rounded,
                                size: 18),
                            text: 'Liquidation'),
                      ],
                    ),
                  ),
                  Expanded(
                      child: TabBarView(controller: tabs, children: [
                    _overview(),
                    _people(),
                    _events(),
                    _liquidation()
                  ])),
                ],
              ),
      ),
    );
  }

  Widget _hero(
      Map<String, dynamic>? organization, String logo, String category) {
    return SizedBox(
      width: double.infinity,
      height: 162,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF064E3B), Color(0xFF128058), Color(0xFF22C55E)],
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        child: Stack(
          children: [
            Positioned(right: -50, top: -72, child: _orb(160)),
            Positioned(left: -45, bottom: -80, child: _orb(145)),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _circleIcon(Icons.arrow_back_rounded,
                            () => Navigator.of(context).maybePop()),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        _logo(logo, 64),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                organization?['name']?.toString() ??
                                    widget.orgName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .14),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: .22)),
                                ),
                                child: Text(
                                  category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleIcon(IconData icon, VoidCallback onTap) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .14),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: .20)),
        ),
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: Colors.white, size: 18),
          padding: EdgeInsets.zero,
        ),
      );

  Widget _orb(double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          shape: BoxShape.circle, color: Colors.white.withValues(alpha: .07)));

  Widget _logo(String asset, double size) {
    Widget image;
    if (asset.startsWith('http')) {
      image = Image.network(asset,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => _logoFallback());
    } else if (asset.isNotEmpty) {
      image = Image.asset(asset.startsWith('assets/') ? asset : 'assets/$asset',
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => _logoFallback());
    } else {
      image = _logoFallback();
    }
    return Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(3),
        decoration:
            const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: ClipOval(child: image));
  }

  Widget _logoFallback() => Container(
      color: mint,
      child: const Center(
          child: Icon(Icons.groups_rounded, color: green, size: 34)));

  Widget _overview() => _scrollBody([
        _sectionTitle('Organization Snapshot',
            'The same clean card treatment used across the Admin Home'),
        const SizedBox(height: 10),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            (org?['about']?.toString().trim().isNotEmpty ?? false)
                ? org!['about'].toString()
                : ((org?['short_desc']?.toString().trim().isNotEmpty ?? false)
                    ? org!['short_desc'].toString()
                    : 'No organization description yet.'),
            style: const TextStyle(color: muted, height: 1.45),
          ),
          const SizedBox(height: 16),
          GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.9,
              children: [
                _metricCard(
                    Icons.groups_rounded, 'Members', '${members.length}'),
                _metricCard(
                    Icons.badge_rounded, 'Officers', '${officers.length}'),
                _metricCard(Icons.event_rounded, 'Events', '${events.length}'),
                _metricCard(Icons.assignment_rounded, 'Proposals',
                    '${proposals.length}'),
              ]),
        ])),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Financial Snapshot',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: dark)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _moneyCard(
                    'Allocated', allocated, Icons.account_balance_outlined)),
            const SizedBox(width: 10),
            Expanded(
                child: _moneyCard('Available', balance, Icons.wallet_rounded))
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _moneyCard('Income', income, Icons.trending_up_rounded)),
            const SizedBox(width: 10),
            Expanded(
                child: _moneyCard(
                    'Expenses', expenses, Icons.trending_down_rounded))
          ]),
        ])),
      ]);

  Widget _people() {
    final organization = org ?? <String, dynamic>{};
    final organizationAdviser = organization['adviser']?.toString().trim() ?? '';
    final rawOfficers = organization['officers'];
    final organizationOfficers = rawOfficers is List
        ? rawOfficers.map((value) => value.toString()).toList()
        : <String>[];
    final rawSavedProfiles = organization['officer_profiles'];
    final savedProfiles = rawSavedProfiles is List
        ? rawSavedProfiles.whereType<Map>().map((value) => Map<String, dynamic>.from(value)).toList()
        : <Map<String, dynamic>>[];

    Map<String, dynamic>? findLivePerson(String name) {
      for (final person in [...advisers, ...officers]) {
        if ((person['name']?.toString().trim() ?? '').toLowerCase() == name.trim().toLowerCase()) {
          return person;
        }
      }
      return null;
    }

    Map<String, dynamic>? findSavedPerson(String name) {
      for (final person in savedProfiles) {
        if ((person['name']?.toString().trim() ?? '').toLowerCase() == name.trim().toLowerCase()) {
          return person;
        }
      }
      return null;
    }

    final adviser = advisers.isNotEmpty
        ? Map<String, dynamic>.from(advisers.first)
        : <String, dynamic>{'name': organizationAdviser, 'role': 'Adviser', 'avatar_url': ''};
    if ((adviser['name']?.toString().trim() ?? '').isEmpty) {
      adviser['name'] = organizationAdviser.isNotEmpty ? organizationAdviser : 'Adviser';
    }
    adviser['role'] = 'Adviser';

    final officerPeople = <Map<String, dynamic>>[];
    for (final raw in organizationOfficers) {
      final colon = raw.indexOf(':');
      final role = colon < 0 ? 'Officer' : raw.substring(0, colon).trim();
      final name = (colon < 0 ? raw : raw.substring(colon + 1)).trim();
      if (name.isEmpty) continue;
      final live = findLivePerson(name);
      final saved = findSavedPerson(name);
      final liveAvatar = live?['avatar_url']?.toString().trim() ?? '';
      final savedAvatar = saved?['avatar_url']?.toString().trim() ?? '';
      officerPeople.add({
        'name': name,
        'role': (saved?['role']?.toString().trim().isNotEmpty ?? false)
            ? saved!['role'].toString().trim()
            : role,
        // Match the Student Joined Orgs source priority: current profile image first,
        // saved organization officer profile only as a fallback.
        'avatar_url': liveAvatar.isNotEmpty ? liveAvatar : savedAvatar,
      });
    }
    if (organizationOfficers.isEmpty) {
      officerPeople.addAll(officers.map((person) => Map<String, dynamic>.from(person)));
    }

    return _scrollBody([
      _sectionTitle('People',
          'See the adviser, officers, and total members of this organization'),
      const SizedBox(height: 10),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.school_rounded, color: green, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Adviser', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: dark))),
          _status(adviser['name']?.toString().trim().isNotEmpty == true ? '1' : '0'),
        ]),
        const SizedBox(height: 10),
        if ((adviser['name']?.toString().trim() ?? '').isEmpty)
          const Text('No adviser assigned yet.', style: TextStyle(color: muted))
        else
          _studentStylePersonTile(adviser, Icons.school_rounded, wide: true),
      ])),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.badge_rounded, color: green, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Officers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: dark))),
          _status('${officerPeople.length}'),
        ]),
        const SizedBox(height: 10),
        if (officerPeople.isEmpty)
          const Text('No officer profiles have been posted for this organization yet.', style: TextStyle(color: muted))
        else
          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: officerPeople.map((person) => _studentStylePersonTile(person, Icons.badge_rounded)).toList(),
          ),
      ])),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.groups_rounded, color: green, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: dark))),
          _status('${members.length}'),
        ]),
        const SizedBox(height: 10),
        Text('${members.length} member${members.length == 1 ? '' : 's'} in this organization', style: const TextStyle(color: muted)),
      ])),
    ]);
  }

  Widget _events() {
    Map<String, dynamic>? focused;
    if (widget.focusProposalId != null) {
      for (final proposal in proposals) {
        if (proposal['id']?.toString() == widget.focusProposalId &&
            proposal['status']?.toString() == 'forwarded_to_admin') {
          focused = proposal;
          break;
        }
      }
    }

    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final datedEvents = events.map((event) {
      final raw = event['date']?.toString();
      return MapEntry(event, raw == null ? null : DateTime.tryParse(raw)?.toLocal());
    }).where((entry) => entry.value != null).toList();
    final upcoming = datedEvents
        .where((entry) => !entry.value!.isBefore(startOfToday))
        .toList()
      ..sort((a, b) => a.value!.compareTo(b.value!));
    final past = datedEvents
        .where((entry) => entry.value!.isBefore(startOfToday))
        .toList()
      ..sort((a, b) => b.value!.compareTo(a.value!));

    return _scrollBody([
      _sectionTitle('Events & Proposals',
          'Upcoming events, past event history, and all saved proposals for this organization'),
      const SizedBox(height: 10),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Upcoming Events',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: dark)),
        const SizedBox(height: 8),
        if (upcoming.isEmpty)
          const Text('No upcoming events scheduled.', style: TextStyle(color: muted))
        else
          ...upcoming.map((entry) => _eventRow(entry.key, showImage: true)),
      ])),
      if (focused != null)
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Proposal opened from Home',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: dark)),
          const SizedBox(height: 4),
          const Text('Review this proposal below before checking the rest of the organization activity.',
              style: TextStyle(color: muted, fontSize: 11.5, height: 1.35)),
          const SizedBox(height: 10),
          _proposalRow(focused),
        ])),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Past Events Calendar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: dark)),
        const SizedBox(height: 8),
        TableCalendar<MapEntry<Map<String, dynamic>, DateTime?>>(
          firstDay: DateTime(2018),
          lastDay: DateTime(2100),
          focusedDay: _calendarFocusedDay,
          selectedDayPredicate: (day) => _calendarSelectedDay != null && isSameDay(_calendarSelectedDay, day),
          eventLoader: (day) => past.where((entry) => isSameDay(entry.value, day)).toList(),
          calendarFormat: CalendarFormat.month,
          headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
          calendarStyle: const CalendarStyle(markerDecoration: BoxDecoration(color: green, shape: BoxShape.circle), selectedDecoration: BoxDecoration(color: green, shape: BoxShape.circle), todayDecoration: BoxDecoration(color: mint, shape: BoxShape.circle)),
          onDaySelected: (selectedDay, focusedDay) => setState(() { _calendarSelectedDay = selectedDay; _calendarFocusedDay = focusedDay; }),
          onPageChanged: (focusedDay) => _calendarFocusedDay = focusedDay,
        ),
        const SizedBox(height: 8),
        Text(_calendarSelectedDay == null ? 'Select a date to view past events' : DateFormat.yMMMMd().format(_calendarSelectedDay!), style: const TextStyle(fontWeight: FontWeight.w800, color: dark)),
        const SizedBox(height: 6),
        ...((past.where((entry) => _calendarSelectedDay != null && isSameDay(entry.value, _calendarSelectedDay)).toList())
          .map((entry) => _eventRow(entry.key, showImage: true))),
        if (past.isEmpty) const Text('No past events recorded yet.', style: TextStyle(color: muted)),
        if (_calendarSelectedDay != null && past.where((entry) => isSameDay(entry.value, _calendarSelectedDay)).isEmpty)
          const Text('No past events on this date.', style: TextStyle(color: muted)),
      ])),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Proposal History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: dark)),
        const SizedBox(height: 8),
        if (proposals.isEmpty)
          const Text('No proposals recorded yet.', style: TextStyle(color: muted))
        else ...[
          ...proposals.take(_showAllProposalHistory ? proposals.length : 5).map(_proposalRow),
          if (proposals.length > 5)
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () => setState(() => _showAllProposalHistory = !_showAllProposalHistory),
                icon: Icon(_showAllProposalHistory ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                label: Text(_showAllProposalHistory ? 'Show Less' : 'View All (${proposals.length})'),
              ),
            ),
        ],
      ])),
    ]);
  }


  Future<void> _setBudget() async {
    final controller = TextEditingController(text: allocated.toStringAsFixed(2));
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set organization budget'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Allocated budget (₱)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim().replaceAll(',', ''));
              if (parsed == null || parsed < 0) return;
              Navigator.pop(dialogContext, parsed);
            },
            child: const Text('Save budget'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    try {
      await db.from('organizations').update({'allocated_budget': value}).eq('id', widget.orgId);
      if (!mounted) return;
      setState(() => allocated = value);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Organization budget updated.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update budget: $error')));
    }
  }

  Future<void> _addBalance() async {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final eventController = TextEditingController(text: 'Additional organization balance');
    DateTime date = DateTime.now();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add organization balance'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (₱)')),
              TextField(controller: eventController, decoration: const InputDecoration(labelText: 'Event / purpose')),
              TextField(controller: descriptionController, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (optional)')),
              ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.calendar_month_rounded), title: const Text('Transaction date'), subtitle: Text(DateFormat.yMMMd().format(date)), onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (picked != null) setDialogState(() => date = picked);
              }),
            ])),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Add balance')),
          ],
        ),
      ),
    );
    if (saved != true) { amountController.dispose(); descriptionController.dispose(); eventController.dispose(); return; }
    final amount = double.tryParse(amountController.text.trim().replaceAll(',', ''));
    if (amount == null || amount <= 0 || eventController.text.trim().isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount and purpose.')));
      amountController.dispose(); descriptionController.dispose(); eventController.dispose();
      return;
    }
    try {
      await db.from('org_financial_transactions').insert({
        'org_id': widget.orgId,
        'type': 'income',
        'amount': amount,
        'category': 'Additional balance',
        'description': descriptionController.text.trim(),
        'event_name': eventController.text.trim(),
        'transaction_date': DateFormat('yyyy-MM-dd').format(date),
        'created_by': db.auth.currentUser?.id,
      });
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Organization balance added.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add balance: $error')));
    } finally { amountController.dispose(); descriptionController.dispose(); eventController.dispose(); }
  }

  Future<void> _addReimbursement() async {
    final amountController = TextEditingController();
    final eventController = TextEditingController();
    final categoryController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime date = DateTime.now();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Record reimbursement'),
          content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount to reimburse (₱)')),
            TextField(controller: eventController, decoration: const InputDecoration(labelText: 'Event / purpose')),
            TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Expense category')),
            TextField(controller: descriptionController, maxLines: 2, decoration: const InputDecoration(labelText: 'Details / receipt notes')),
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.calendar_month_rounded), title: const Text('Expense date'), subtitle: Text(DateFormat.yMMMd().format(date)), onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (picked != null) setDialogState(() => date = picked);
            }),
          ]))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save reimbursement')),
          ],
        ),
      ),
    );
    if (saved != true) { amountController.dispose(); eventController.dispose(); categoryController.dispose(); descriptionController.dispose(); return; }
    final amount = double.tryParse(amountController.text.trim().replaceAll(',', ''));
    if (amount == null || amount <= 0 || eventController.text.trim().isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount and event / purpose.')));
      amountController.dispose(); eventController.dispose(); categoryController.dispose(); descriptionController.dispose();
      return;
    }
    try {
      await db.from('org_financial_transactions').insert({
        'org_id': widget.orgId,
        'type': 'expense',
        'amount': amount,
        'category': 'Reimbursement${categoryController.text.trim().isEmpty ? '' : ': ${categoryController.text.trim()}'}',
        'description': 'Reimbursement: ${descriptionController.text.trim()}'.trim(),
        'event_name': eventController.text.trim(),
        'transaction_date': DateFormat('yyyy-MM-dd').format(date),
        'created_by': db.auth.currentUser?.id,
      });
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reimbursement recorded.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not record reimbursement: $error')));
    } finally { amountController.dispose(); eventController.dispose(); categoryController.dispose(); descriptionController.dispose(); }
  }

  Widget _liquidation() => _scrollBody([
        _sectionTitle('Liquidation',
            'CSO budget, organization income, and reimbursable expenses'),
        const SizedBox(height: 10),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
                child: Text('CSO Budget',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: dark))),
            TextButton.icon(
              onPressed: _setBudget,
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('Set budget'),
              style: TextButton.styleFrom(foregroundColor: green),
            ),
            FilledButton.icon(
              onPressed: _addBalance,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Add Balance'),
              style: FilledButton.styleFrom(backgroundColor: green, foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE8FFF0), Color(0xFFD0F6DD)]),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: line),
            ),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: green.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      color: green)),
              const SizedBox(width: 12),
              const Expanded(
                  child: Text(
                      'Amount the CSO has allocated or would give this organization.',
                      style: TextStyle(
                          color: muted, fontSize: 11.5, height: 1.35))),
              Text(_money(allocated),
                  style: const TextStyle(
                      color: dark, fontSize: 18, fontWeight: FontWeight.w900)),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _moneyCard('Income', income, Icons.trending_up_rounded)),
            const SizedBox(width: 10),
            Expanded(
                child: _moneyCard(
                    'Expenses', expenses, Icons.trending_down_rounded)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _moneyCard('Available', balance, Icons.wallet_rounded)),
            const SizedBox(width: 10),
            Expanded(
                child: _moneyCard(
                    'Reimbursements',
                    finance
                        .where((x) =>
                            x['type'] == 'expense' &&
                            (x['category']?.toString().toLowerCase() ==
                                    'reimbursement' ||
                                x['description']
                                        ?.toString()
                                        .toLowerCase()
                                        .startsWith('reimbursement') ==
                                    true))
                        .fold(
                            0.0,
                            (sum, x) =>
                                sum + ((x['amount'] as num?)?.toDouble() ?? 0)),
                    Icons.receipt_long_rounded)),
          ]),
        ])),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
                child: Text('Reimburse an Organization Expense',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: dark))),
            FilledButton.icon(
              onPressed: _addReimbursement,
              style: FilledButton.styleFrom(backgroundColor: green),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Add'),
            ),
          ]),
          const SizedBox(height: 6),
          const Text(
            'When an organization pays with its own money because the CSO budget is not enough, record the reimbursement here. It will be included in expenses.',
            style: TextStyle(color: muted, fontSize: 11.5, height: 1.4),
          ),
        ])),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F8058), Color(0xFF07553A)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.description_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Financial Report', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white)),
                SizedBox(height: 4),
                Text('Review the organization finances before printing', style: TextStyle(fontSize: 11.5, color: Colors.white, height: 1.3)),
              ])),
              IconButton.filledTonal(
                tooltip: 'Preview and print financial report',
                onPressed: _printFinancialReport,
                style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: green),
                icon: const Icon(Icons.print_rounded),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          if (finance.isNotEmpty) ...[
            Row(children: [
              const Icon(Icons.calendar_month_rounded, color: green, size: 22),
              const SizedBox(width: 8),
              const Expanded(child: Text('Semester Summary', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: dark))),
              Text('${_semesterFinanceSummary().length} period(s)', style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            ..._semesterFinanceSummary().entries.map((entry) {
              final totalIncome = entry.value['income']!;
              final totalExpense = entry.value['expense']!;
              final net = totalIncome - totalExpense;
              final events = _eventFinanceSummaryForSemester(entry.key).entries.toList();
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: line), boxShadow: [BoxShadow(color: dark.withValues(alpha: .04), blurRadius: 8, offset: const Offset(0, 3))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [const Icon(Icons.school_rounded, color: green, size: 18), const SizedBox(width: 7), Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: dark))) ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _semesterMetric('Income', totalIncome, const Color(0xFF15803D), Icons.south_west_rounded)),
                    const SizedBox(width: 8),
                    Expanded(child: _semesterMetric('Expenses', totalExpense, const Color(0xFFB91C1C), Icons.north_east_rounded)),
                    const SizedBox(width: 8),
                    Expanded(child: _semesterMetric('Net Balance', net, net >= 0 ? green : const Color(0xFFB91C1C), Icons.account_balance_wallet_rounded)),
                  ]),
                  if (events.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 9),
                    const Text('Breakdown by event', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: dark)),
                    const SizedBox(height: 5),
                    ...events.map((event) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.event_note_rounded, size: 15, color: muted), const SizedBox(width: 7),
                      Expanded(child: Text(event.key, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: dark))),
                      const SizedBox(width: 8),
                      Text(_money(event.value['income']! - event.value['expense']!), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: event.value['income']! - event.value['expense']! >= 0 ? green : const Color(0xFFB91C1C))),
                    ]))),
                  ],
                ]),
              );
            }),
          ],
          if (finance.isEmpty)
            const Text('No financial transactions recorded yet.',
                style: TextStyle(color: muted))
          else
            ...finance.take(100).map((row) {
              final isIncome = row['type'] == 'income';
              final isReimbursement =
                  row['category']?.toString().toLowerCase() ==
                          'reimbursement' ||
                      row['description']
                              ?.toString()
                              .toLowerCase()
                              .startsWith('reimbursement') ==
                          true;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: (isIncome ? Colors.green : Colors.red)
                      .withValues(alpha: .10),
                  child: Icon(
                      isReimbursement
                          ? Icons.replay_rounded
                          : (isIncome ? Icons.add : Icons.remove),
                      color: isIncome ? Colors.green : Colors.red),
                ),
                title: Text(
                    row['description']?.toString() ??
                        row['category']?.toString() ??
                        'Transaction',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: dark)),
                subtitle: Text(
                    '${row['transaction_date'] ?? ''} • ${row['event_name'] ?? ''}',
                    style: const TextStyle(color: muted, fontSize: 11)),
                trailing: Text(
                    '${isIncome ? '+' : '-'} ${_money((row['amount'] as num? ?? 0).toDouble())}',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: isIncome ? Colors.green : Colors.red)),
              );
            }),
        ])),
      ]);

  Widget _semesterMetric(String label, double amount, Color color, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
    decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(fontSize: 10, color: muted, fontWeight: FontWeight.w700)),
      const SizedBox(height: 3),
      Text(_money(amount), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w900)),
    ]),
  );

  Map<String, Map<String, double>> _semesterFinanceSummary() {
    final result = <String, Map<String, double>>{};
    for (final row in finance) {
      final date = DateTime.tryParse(row['transaction_date']?.toString() ?? '');
      if (date == null) continue;
      final label = date.month >= 8 || date.month <= 1
          ? 'Semester 1 • ${date.month >= 8 ? date.year : date.year - 1}-${date.month >= 8 ? date.year + 1 : date.year}'
          : 'Semester 2 • ${date.year}';
      final bucket = result.putIfAbsent(label, () => {'income': 0.0, 'expense': 0.0});
      final type = row['type']?.toString().toLowerCase() == 'income' ? 'income' : 'expense';
      bucket[type] = bucket[type]! + ((row['amount'] as num?)?.toDouble() ?? 0);
    }
    return result;
  }

  Map<String, Map<String, double>> _eventFinanceSummaryForSemester(String semester) {
    final result = <String, Map<String, double>>{};
    for (final row in finance) {
      final date = DateTime.tryParse(row['transaction_date']?.toString() ?? '');
      if (date == null) continue;
      final label = date.month >= 8 || date.month <= 1
          ? 'Semester 1 • ${date.month >= 8 ? date.year : date.year - 1}-${date.month >= 8 ? date.year + 1 : date.year}'
          : 'Semester 2 • ${date.year}';
      if (label != semester) continue;
      final event = row['event_name']?.toString().trim().isNotEmpty == true ? row['event_name'].toString().trim() : 'General organization funds';
      final bucket = result.putIfAbsent(event, () => {'income': 0.0, 'expense': 0.0});
      final type = row['type']?.toString().toLowerCase() == 'income' ? 'income' : 'expense';
      bucket[type] = bucket[type]! + ((row['amount'] as num?)?.toDouble() ?? 0);
    }
    return result;
  }

  Future<void> _printFinancialReport() async {
    final document = pw.Document();
    final reportDate = DateFormat('MMMM d, yyyy').format(DateTime.now());
    final incomeTotal = income;
    final expenseTotal = expenses;
    final semesterRows = _semesterFinanceSummary().entries.toList();
    final transactionRows = finance;

    document.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => [
        pw.Center(
          child: pw.Column(children: [
            pw.Text('Financial Report', style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Text(widget.orgName, style: pw.TextStyle(fontSize: 21, fontWeight: pw.FontWeight.bold)),
            pw.Text('Generated on $reportDate', style: const pw.TextStyle(fontSize: 9)),
          ]),
        ),
        pw.SizedBox(height: 22),
        pw.Text('Summary', style: pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
          columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(1)},
          children: [
            _pdfSummaryRow('Allocated budget', _money(allocated)),
            _pdfSummaryRow('Total income', _money(incomeTotal)),
            _pdfSummaryRow('Total expenses', _money(expenseTotal)),
            _pdfSummaryRow('Available balance', _money(balance)),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Text('Semester Summary', style: pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        if (semesterRows.isEmpty)
          pw.Text('No semester transactions recorded.', style: const pw.TextStyle(fontSize: 10))
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
            children: [
              _pdfTableHeader(['Semester', 'Income', 'Expenses', 'Net']),
              ...semesterRows.map((entry) => pw.TableRow(children: [
                _pdfCell(entry.key),
                _pdfCell(_money(entry.value['income']!)),
                _pdfCell(_money(entry.value['expense']!)),
                _pdfCell(_money(entry.value['income']! - entry.value['expense']!)),
              ])),
            ],
          ),
        pw.SizedBox(height: 18),
        pw.Text('Transaction Details', style: pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        if (transactionRows.isEmpty)
          pw.Text('No financial transactions recorded.', style: const pw.TextStyle(fontSize: 10))
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.2),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(.9),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FlexColumnWidth(1),
            },
            children: [
              _pdfTableHeader(['Date', 'Event', 'Type', 'Description', 'Amount']),
              ...transactionRows.map((row) => pw.TableRow(children: [
                _pdfCell(row['transaction_date']?.toString() ?? ''),
                _pdfCell(row['event_name']?.toString() ?? ''),
                _pdfCell((row['type']?.toString() ?? '').toUpperCase()),
                _pdfCell((row['description'] ?? row['category'] ?? '').toString()),
                _pdfCell(_money((row['amount'] as num?)?.toDouble() ?? 0)),
              ])),
            ],
          ),
      ],
    ));

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: MediaQuery.of(dialogContext).size.width * .82,
          height: MediaQuery.of(dialogContext).size.height * .84,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              color: green,
              child: Row(children: [
                const Icon(Icons.description_rounded, color: Colors.white),
                const SizedBox(width: 10),
                const Expanded(child: Text('Financial Report Preview', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))),
                IconButton(onPressed: () => Navigator.of(dialogContext).pop(), tooltip: 'Close preview', icon: const Icon(Icons.close_rounded, color: Colors.white)),
              ]),
            ),
            Expanded(child: PdfPreview(
              build: (_) async => document.save(),
              canChangePageFormat: true,
              canChangeOrientation: true,
              allowPrinting: true,
              allowSharing: true,
              pdfFileName: 'Financial_Report_${widget.orgName.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')}.pdf',
              useActions: true,
            )),
          ]),
        ),
      ),
    );
  }

  pw.TableRow _pdfSummaryRow(String label, String value) => pw.TableRow(children: [
    _pdfCell(label, bold: true),
    _pdfCell(value),
  ]);

  pw.TableRow _pdfTableHeader(List<String> labels) => pw.TableRow(
    decoration: const pw.BoxDecoration(color: PdfColors.green100),
    children: labels.map((label) => _pdfCell(label, bold: true)).toList(),
  );

  pw.Widget _pdfCell(String value, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 8),
    child: pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
  );


  Widget _scrollBody(List<Widget> children) => Scrollbar(
      thumbVisibility: true,
      child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
          children: children));

  Widget _sectionTitle(String title, String subtitle) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900, color: dark)),
        const SizedBox(height: 3),
        Text(subtitle,
            style: const TextStyle(fontSize: 11.5, color: muted, height: 1.35))
      ]);

  Widget _card(Widget child) => Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF5FFF9)]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: line),
          boxShadow: [
            BoxShadow(
                color: green.withValues(alpha: .05),
                blurRadius: 14,
                offset: const Offset(0, 6))
          ]),
      child: child);

  Widget _metricCard(IconData icon, String label, String value) => Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F8F62), Color(0xFF20B77D)]),
          borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: Colors.white, size: 17)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: .82),
                fontSize: 9,
                fontWeight: FontWeight.w800))
      ]));

  Widget _moneyCard(String label, double value, IconData icon) => Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
          color: mint,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: line.withValues(alpha: .8))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: green, size: 19),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(
                color: muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(_money(value),
            style: const TextStyle(
                color: dark, fontSize: 17, fontWeight: FontWeight.w900))
      ]));


  // Visual counterpart of the Adviser and Officers cards in Student > Joined Orgs.
  Widget _studentStylePersonTile(Map<String, dynamic> person, IconData fallback, {bool wide = false}) {
    final name = (person['name']?.toString().trim().isNotEmpty ?? false)
        ? person['name'].toString().trim()
        : 'Organization member';
    final role = person['position']?.toString().trim().isNotEmpty == true
        ? person['position'].toString().trim()
        : (person['role']?.toString().trim() ?? '');
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
          ? Image.network(avatarUrl, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(fallback, color: green, size: 30))
          : Icon(fallback, color: green, size: 30),
    );
    if (wide) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFF8FFFB), Color(0xFFE7F8F0)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFCBE8DC)),
        ),
        child: Row(children: [
          image,
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF24463C), fontSize: 14, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(role.isEmpty ? 'Adviser' : role,
              style: const TextStyle(color: Color(0xFF0F8A61), fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            const Text('Organization adviser', style: TextStyle(color: Color(0xFF6B8178), fontSize: 11)),
          ])),
        ]),
      );
    }
    return Container(
      width: 132,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8EEE4)),
        boxShadow: const [BoxShadow(color: Color(0x070F8A61), blurRadius: 12, offset: Offset(0, 5))],
      ),
      child: Column(children: [
        image,
        const SizedBox(height: 8),
        Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF24463C), fontSize: 11.5, fontWeight: FontWeight.w900, height: 1.2)),
        if (role.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(role, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B8178), fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ]),
    );
  }

  List<String> _eventImageUrls(Map<String, dynamic> event) {
    final result = <String>[];
    final raw = event['image_urls'];
    if (raw is List) {
      result.addAll(raw.map((value) => value.toString()).where((value) => value.trim().isNotEmpty));
    }
    final single = event['image_url']?.toString() ?? '';
    if (result.isEmpty && single.trim().isNotEmpty) result.add(single);
    return result;
  }

  Widget _eventRow(Map<String, dynamic> event, {bool showImage = false}) {
    final images = _eventImageUrls(event);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (showImage && images.isNotEmpty)
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 130, maxHeight: 320),
            color: const Color(0xFFF2F8F4),
            child: Image.network(
              images.first,
              width: double.infinity,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox(
                height: 130,
                child: Center(child: Icon(Icons.broken_image_outlined, color: muted)),
              ),
            ),
          ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.event_note_rounded, color: green),
          ),
          title: Text(event['title']?.toString() ?? 'Event',
              style: const TextStyle(fontWeight: FontWeight.w800, color: dark)),
          subtitle: Text(_date(event['date']), style: const TextStyle(color: muted, fontSize: 11)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: event['id'] == null ? null : () => showEventComments(
                context,
                eventId: event['id'].toString(),
                eventTitle: event['title']?.toString() ?? 'Event',
              ),
              icon: const Icon(Icons.forum_outlined, size: 17),
              label: const Text('Comment & React'),
              style: FilledButton.styleFrom(
                backgroundColor: mint,
                foregroundColor: green,
                elevation: 0,
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _proposalRow(Map<String, dynamic> proposal) {
    final status = proposal['status']?.toString() ?? 'pending';
    final canReview = status == 'forwarded_to_admin';
    final isFocused = widget.focusProposalId != null &&
        proposal['id']?.toString() == widget.focusProposalId;
    final submitter =
        proposalSubmitters[proposal['requested_by']?.toString()] ??
            proposal['requested_by']?.toString() ??
            'Unknown submitter';
    final date = proposal['date']?.toString() ?? '';
    final venue = proposal['venue']?.toString().trim() ?? '';
    final purpose = proposal['purpose']?.toString().trim() ?? '';
    final start = proposal['start_time']?.toString().trim() ?? '';
    final end = proposal['end_time']?.toString().trim() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: isFocused
            ? const LinearGradient(
                colors: [Color(0xFFE5FFF0), Color(0xFFD1F7DE)])
            : const LinearGradient(colors: [Colors.white, Color(0xFFF8FFFB)]),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
            color: isFocused ? green : line, width: isFocused ? 2 : 1),
        boxShadow: [
          BoxShadow(
              color: green.withValues(alpha: isFocused ? .12 : .04),
              blurRadius: isFocused ? 18 : 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: mint, borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.assignment_rounded, color: green)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(proposal['title']?.toString() ?? 'Proposal',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: dark)),
                  const SizedBox(height: 3),
                  Text('Submitted by $submitter',
                      style: const TextStyle(
                          color: muted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600)),
                ])),
            _status(status),
          ]),
          if (isFocused) ...[
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                  color: green.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12)),
              child: const Row(children: [
                Icon(Icons.push_pin_rounded, size: 15, color: green),
                SizedBox(width: 6),
                Text('Opened from Pending Adviser Proposals',
                    style: TextStyle(
                        color: green,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800))
              ]),
            ),
          ],
          if (purpose.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('About: $purpose',
                style: const TextStyle(
                    color: dark,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600)),
          ],
          if (venue.isNotEmpty ||
              start.isNotEmpty ||
              end.isNotEmpty ||
              date.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 7, runSpacing: 7, children: [
              if (date.isNotEmpty)
                _detailPill(Icons.calendar_month_rounded, _date(date)),
              if (venue.isNotEmpty) _detailPill(Icons.place_rounded, venue),
              if (start.isNotEmpty)
                _detailPill(Icons.schedule_rounded,
                    end.isNotEmpty ? '$start – $end' : start),
            ]),
          ],
          if ((proposal['description'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(proposal['description'].toString(),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(color: muted, fontSize: 12, height: 1.4)),
          ],
          if ((proposal['feedback'] ?? '').toString().isNotEmpty) ...[
            _feedbackPill('Adviser feedback', proposal['feedback'].toString(),
                Colors.orange),
          ],
          if ((proposal['admin_feedback'] ?? '').toString().isNotEmpty) ...[
            _feedbackPill('Admin / CSO feedback',
                proposal['admin_feedback'].toString(), Colors.red),
          ],
          if (canReview) ...[
            const SizedBox(height: 9),
            Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: () => _reviewProposal(proposal, false),
                      icon: const Icon(Icons.undo_rounded, size: 16),
                      label: const Text('Return'))),
              const SizedBox(width: 8),
              Expanded(
                  child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: green),
                      onPressed: () => _reviewProposal(proposal, true),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Approve'))),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _detailPill(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
            color: mint,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: line.withValues(alpha: .75))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: green),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(
                  color: dark, fontSize: 10.5, fontWeight: FontWeight.w800))
        ]),
      );

  Widget _feedbackPill(String title, String text, Color color) => Container(
        margin: const EdgeInsets.only(top: 9),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: color.withValues(alpha: .14))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 15, color: color),
          const SizedBox(width: 7),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(text,
                    style: const TextStyle(
                        color: dark, fontSize: 11.5, height: 1.35))
              ]))
        ]),
      );

  Future<void> _reviewProposal(
      Map<String, dynamic> proposal, bool approve) async {
    final feedback = TextEditingController();
    try {
      if (!approve) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Return to Adviser'),
            content: TextField(
                controller: feedback,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Feedback', border: OutlineInputBorder())),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Return')),
            ],
          ),
        );
        if (confirmed != true) return;
      }
      final now = DateTime.now();
      final message = approve
          ? 'The proposal “${proposal['title'] ?? 'Activity Proposal'}” was approved by the Admin / CSO. The adviser can now ask the officer to prepare the final posting.'
          : 'The proposal “${proposal['title'] ?? 'Activity Proposal'}” was returned by the Admin / CSO. Feedback: ${feedback.text.trim()}';
      await db.from('event_requests').update({
        'status': approve ? 'admin_approved' : 'admin_rejected',
        'admin_feedback': feedback.text.trim(),
        'admin_reviewed_at': now.toIso8601String(),
        'reviewed_by': db.auth.currentUser?.id,
        'updated_at': now.toIso8601String(),
      }).eq('id', proposal['id']);
      try {
        await db.from('notifications').insert({
          'id': DateTime.now().microsecondsSinceEpoch.toString(),
          'title': approve
              ? 'Proposal Approved by Admin / CSO'
              : 'Proposal Returned by Admin / CSO',
          'message': message,
          'date': now.toIso8601String(),
          'read': false,
          'org_id': widget.orgId,
          'student_id': null,
        });
      } catch (_) {}
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(approve
                ? 'Proposal approved.'
                : 'Proposal returned to adviser.'),
            backgroundColor: green));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update proposal: $error')));
      }
    } finally {
      feedback.dispose();
    }
  }

  Widget _status(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
          color: green.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(30)),
      child: Text(text.replaceAll('_', ' '),
          style: const TextStyle(
              color: dark, fontSize: 9.5, fontWeight: FontWeight.w900)));
  String _date(dynamic value) {
    final date = DateTime.tryParse('${value ?? ''}');
    return date == null ? 'No date' : '${date.month}/${date.day}/${date.year}';
  }

  String _money(double value) => '₱${NumberFormat('#,##0.00').format(value)}';
}
