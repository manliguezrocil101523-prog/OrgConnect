import 'package:flutter/material.dart';
import '../../core/analytics_service.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  AnalyticsSnapshot? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final data = await AnalyticsService.instance.loadSnapshot();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
    await AnalyticsService.instance.logUsage(
      'view_admin_analytics',
      route: 'admin/analytics',
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final data = _data;

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0A140D) : const Color(0xFFF0FDF4),
      appBar: AppBar(
        title: const Text('Organization Analytics'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading || data == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  _intro(),
                  const SizedBox(height: 16),
                  _metrics(data, dark),
                  const SizedBox(height: 20),
                  _section('Organization comparison'),
                  const SizedBox(height: 10),
                  ..._organizationCards(data.organizations, dark),
                  const SizedBox(height: 20),
                  _section('Student-life impact'),
                  const SizedBox(height: 10),
                  _impactCard(dark),
                  const SizedBox(height: 20),
                  _section('Usage & priority'),
                  const SizedBox(height: 10),
                  _usageCard(data, dark),
                ],
              ),
            ),
    );
  }

  Widget _intro() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF166534), Color(0xFF22C55E)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Finals Analytics',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Use participation, event activity and member usage to understand organization activity.',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _metrics(AnalyticsSnapshot data, bool dark) {
    final metrics = <Widget>[
      _metric('Active students', data.activeMembers, Icons.online_prediction_rounded, dark),
      _metric('Members', data.totalMembers, Icons.groups_rounded, dark),
      _metric('Posted events', data.totalEvents, Icons.event_rounded, dark),
      _metric('Event views', data.totalViews, Icons.visibility_rounded, dark),
      _metric('Comments', data.totalComments, Icons.forum_rounded, dark),
      _metric('Organizations', data.organizations.length, Icons.apartment_rounded, dark),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.45,
      children: metrics,
    );
  }

  Widget _metric(String label, int value, IconData icon, bool dark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF102016) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF16A34A)),
          const Spacer(),
          Text('$value', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _section(String text) {
    return Row(
      children: [
        const Icon(Icons.eco_rounded, color: Color(0xFF16A34A), size: 20),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ],
    );
  }

  List<Widget> _organizationCards(List<OrgAnalyticsRow> rows, bool dark) {
    final sorted = List<OrgAnalyticsRow>.from(rows)
      ..sort((a, b) => b.members.compareTo(a.members));

    if (sorted.isEmpty) {
      return <Widget>[const Text('No organization activity data yet.')];
    }

    final maxMembers = sorted.first.members == 0 ? 1 : sorted.first.members;

    return sorted.map((row) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF102016) : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(row.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text(
                  '${row.members} members',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: row.members / maxMembers,
                minHeight: 8,
                backgroundColor: const Color(0xFFDCFCE7),
                color: const Color(0xFF22C55E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${row.events} events  •  ${row.comments} comments',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _impactCard(bool dark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF102016) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Organization impact on student life', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Students can record academic, social, leadership and confidence growth from their dashboard. These records can be reviewed alongside membership and event activity for finals analytics.',
            style: TextStyle(color: Colors.grey, height: 1.45),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Students can record their impact from the student dashboard.')),
              );
            },
            icon: const Icon(Icons.info_outline_rounded),
            label: const Text('How it works'),
          ),
        ],
      ),
    );
  }

  Widget _usageCard(AnalyticsSnapshot data, bool dark) {
    if (data.usageByAction.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF102016) : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text(
          'Usage tracking will appear here as members use the app.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF102016) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: data.usageByAction.entries.map((entry) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bolt_rounded, color: Color(0xFF16A34A)),
            title: Text(entry.key),
            trailing: Text(
              '${entry.value} uses',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          );
        }).toList(),
      ),
    );
  }
}
