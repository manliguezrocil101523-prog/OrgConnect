import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../core/app_state.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  // 🎨 Shared Design System
  static const Color background = Color(0xFFF5F7FA);
  static const Color primary = Color(0xFF1E293B);
  static const Color accent = Color(0xFF6366F1);
  static const Color cardColor = Colors.white;
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  bool _loading = true;

  // These will be populated from Supabase
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

  Future<void> _loadReports() async {
    setState(() => _loading = true);
    try {
      // Re-fetch everything fresh from Supabase
      await Future.wait([
        AppState.instance.fetchEvents(),
        AppState.instance.fetchMembers(),
        AppState.instance.fetchApplications(),
      ]);

      // Fetch users from Supabase profiles table (not in-memory hardcoded list)
      final profilesResponse = await supabase.Supabase.instance.client
          .from('profiles')
          .select('role');

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
      print('Error loading reports: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Reports & Analytics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReports,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Top Summary Grid
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _summaryCard('Organizations', _totalOrgs,
                          Icons.apartment_outlined),
                      _summaryCard('Events', _totalEvents,
                          Icons.event_available_outlined),
                      _summaryCard(
                          'Members', _totalMembers, Icons.group_outlined),
                      _summaryCard('Users', _totalUsers, Icons.person_outline),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Applications Breakdown
                  _sectionTitle('Applications Overview'),
                  const SizedBox(height: 10),
                  _appStatusCard(
                    total: _totalApps,
                    pending: _pending,
                    forApproval: _forApproval,
                    accepted: _accepted,
                    declined: _declined,
                    interviewees: _interviewees,
                  ),

                  const SizedBox(height: 16),

                  // User Roles Breakdown
                  _sectionTitle('User Roles'),
                  const SizedBox(height: 10),
                  _rolesCard(
                    students: _students,
                    officers: _officers,
                    admins: _admins,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _summaryCard(String title, int value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent),
          ),
          const Spacer(),
          Text(
            '$value',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(title, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _appStatusCard({
    required int total,
    required int pending,
    required int forApproval,
    required int accepted,
    required int declined,
    required int interviewees,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Applications: $total',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _statusChip('Pending', pending, warning),
              _statusChip('For Approval', forApproval, accent),
              _statusChip('Accepted', accepted, success),
              _statusChip('Declined', declined, danger),
              _statusChip('Interview', interviewees, primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _rolesCard({
    required int students,
    required int officers,
    required int admins,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _roleRow('Students', students),
          const Divider(),
          _roleRow('Officers', officers),
          const Divider(),
          _roleRow('Admins', admins),
        ],
      ),
    );
  }

  Widget _roleRow(String label, int value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
