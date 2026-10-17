import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

      final submitterNames = <String, String>{};
      for (final person in profileRows) {
        final id = person['id']?.toString() ?? '';
        final name = person['name']?.toString().trim() ?? '';
        final email = person['email']?.toString().trim() ?? '';
        if (id.isNotEmpty)
          submitterNames[id] = name.isNotEmpty
              ? name
              : (email.isNotEmpty ? email : 'Organization user');
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
        officers = profileRows
            .where((x) => x['role']?.toString() == 'officer')
            .toList();
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
  double get balance => allocated + income - expenses;

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

  Widget _people() => _scrollBody([
        _sectionTitle('People',
            'See the adviser, officers, and total members of this organization'),
        const SizedBox(height: 10),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: mint, borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.school_rounded, color: green, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('Adviser',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: dark))),
            _status('${advisers.length}'),
          ]),
          const SizedBox(height: 10),
          if (advisers.isEmpty)
            const Text('No adviser assigned yet.',
                style: TextStyle(color: muted))
          else
            ...advisers
                .map((person) => _personRow(person, Icons.school_rounded)),
        ])),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: mint, borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.badge_rounded, color: green, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('Officers',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: dark))),
            _status('${officers.length}'),
          ]),
          const SizedBox(height: 10),
          if (officers.isEmpty)
            const Text('No officers recorded yet.',
                style: TextStyle(color: muted))
          else
            ...officers
                .map((person) => _personRow(person, Icons.badge_rounded)),
        ])),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: mint, borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.groups_rounded, color: green, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('Members',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: dark))),
            _status('${members.length}'),
          ]),
          const SizedBox(height: 10),
          Text(
            '${members.length} member${members.length == 1 ? '' : 's'} in this organization',
            style: const TextStyle(
                color: muted, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ])),
      ]);

  Widget _events() {
    Map<String, dynamic>? focused;
    if (widget.focusProposalId != null) {
      for (final proposal in proposals) {
        final status = proposal['status']?.toString() ?? '';
        if (proposal['id']?.toString() == widget.focusProposalId &&
            status == 'forwarded_to_admin') {
          focused = proposal;
          break;
        }
      }
    }
    final history = List<Map<String, dynamic>>.from(proposals);

    return _scrollBody([
      _sectionTitle('Events & Proposals',
          'Upcoming events and saved proposal history for this organization'),
      const SizedBox(height: 10),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Upcoming Event',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900, color: dark)),
        const SizedBox(height: 8),
        ...(() {
          final now = DateTime.now();
          final upcoming = events.where((e) {
            final raw = e['date']?.toString();
            final date = raw == null ? null : DateTime.tryParse(raw);
            return date != null &&
                !date.isBefore(DateTime(now.year, now.month, now.day));
          }).toList()
            ..sort((a, b) => (DateTime.tryParse(a['date']?.toString() ?? '') ??
                    DateTime(9999))
                .compareTo(DateTime.tryParse(b['date']?.toString() ?? '') ??
                    DateTime(9999)));
          return upcoming.isEmpty
              ? <Widget>[
                  const Text('No upcoming event scheduled.',
                      style: TextStyle(color: muted))
                ]
              : <Widget>[_eventRow(upcoming.first)];
        })(),
      ])),
      if (focused != null)
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Proposal opened from Home',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: dark)),
          const SizedBox(height: 4),
          const Text(
              'Review this proposal below before checking the rest of the organization activity.',
              style: TextStyle(color: muted, fontSize: 11.5, height: 1.35)),
          const SizedBox(height: 10),
          _proposalRow(focused),
        ])),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Events',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900, color: dark)),
        const SizedBox(height: 8),
        if (events.isEmpty)
          const Text('No events recorded yet.', style: TextStyle(color: muted))
        else
          ...events.take(30).map(_eventRow),
      ])),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Proposal History',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900, color: dark)),
        const SizedBox(height: 8),
        if (history.isEmpty)
          const Text('No approved or returned proposals yet.',
              style: TextStyle(color: muted))
        else
          ...history.take(40).map(_proposalRow),
      ])),
    ]);
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
          const Row(children: [
            Expanded(
                child: Text('Financial Report',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: dark))),
            Icon(Icons.receipt_long_rounded, color: green)
          ]),
          const SizedBox(height: 10),
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

  Future<void> _setBudget() async {
    final controller =
        TextEditingController(text: allocated.toStringAsFixed(2));
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Set CSO Budget'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
              labelText: 'Budget amount',
              prefixText: '₱ ',
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext,
                  double.tryParse(controller.text.replaceAll(',', '').trim())),
              child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    try {
      await db
          .from('organizations')
          .update({'allocated_budget': value}).eq('id', widget.orgId);
      await _load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('CSO budget updated.'), backgroundColor: green));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update budget: $error')));
    }
  }

  Future<void> _addReimbursement() async {
    final amount = TextEditingController();
    final description = TextEditingController();
    final eventName = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Add reimbursement'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₱ ',
                    border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
                controller: description,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Expense description',
                    border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
                controller: eventName,
                decoration: const InputDecoration(
                    labelText: 'Event / activity (optional)',
                    border: OutlineInputBorder())),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: green),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Record expense')),
        ],
      ),
    );
    final amountValue = double.tryParse(amount.text.replaceAll(',', '').trim());
    final descriptionValue = description.text.trim();
    final eventValue = eventName.text.trim();
    amount.dispose();
    description.dispose();
    eventName.dispose();
    if (ok != true ||
        amountValue == null ||
        amountValue <= 0 ||
        descriptionValue.isEmpty) return;
    try {
      await db.from('org_financial_transactions').insert({
        'org_id': widget.orgId,
        'type': 'expense',
        'amount': amountValue,
        'description': 'Reimbursement: $descriptionValue',
        'transaction_date': DateTime.now().toIso8601String(),
        'event_name': eventValue,
        'category': 'reimbursement',
      });
      await _load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Reimbursement added to expenses.'),
            backgroundColor: green));
    } catch (error) {
      try {
        await db.from('org_financial_transactions').insert({
          'org_id': widget.orgId,
          'type': 'expense',
          'amount': amountValue,
          'description': 'Reimbursement: $descriptionValue',
          'transaction_date': DateTime.now().toIso8601String(),
        });
        await _load();
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Reimbursement added to expenses.'),
              backgroundColor: green));
      } catch (retryError) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Could not record reimbursement: $retryError')));
      }
    }
  }

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

  Widget _personRow(Map<String, dynamic> person, IconData fallback) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
          backgroundColor: mint,
          backgroundImage:
              (person['avatar_url']?.toString().isNotEmpty ?? false)
                  ? NetworkImage(person['avatar_url'])
                  : null,
          child: person['avatar_url']?.toString().isNotEmpty ?? false
              ? null
              : Icon(fallback, color: green)),
      title: Text(person['name']?.toString() ?? 'Person',
          style: const TextStyle(fontWeight: FontWeight.w800, color: dark)),
      subtitle: Text(
          person['position']?.toString() ??
              person['role']?.toString() ??
              'Member',
          style: const TextStyle(color: muted, fontSize: 11)));

  Widget _eventRow(Map<String, dynamic> event) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
              color: mint, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.event_note_rounded, color: green)),
      title: Text(event['title']?.toString() ?? 'Event',
          style: const TextStyle(fontWeight: FontWeight.w800, color: dark)),
      subtitle: Text(_date(event['date']),
          style: const TextStyle(color: muted, fontSize: 11)));

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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(approve
                ? 'Proposal approved.'
                : 'Proposal returned to adviser.'),
            backgroundColor: green));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update proposal: $error')));
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
