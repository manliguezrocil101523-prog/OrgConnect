import 'package:flutter/material.dart';
import '../../core/app_state.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  // 🎨 Shared Design System
  static const Color background = Color(0xFFF5F7FA);
  static const Color primary = Color(0xFF1E293B);
  static const Color accent = Color(0xFF6366F1);
  static const Color cardColor = Colors.white;
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

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
      ),
      body: AnimatedBuilder(
        animation: AppState.instance,
        builder: (context, _) {
          final users = AppState.instance.users;
          final apps = AppState.instance.applications;
          final members = AppState.instance.members;
          final events = AppState.instance.events
              .where((e) => !e.title.toLowerCase().contains('interview'))
              .toList();
          final orgs = AppState.instance.organizations;

          int countRole(UserRole r) =>
              users.where((u) => u.role == r).length;

          int pending = apps
              .where((a) => a.status == ApplicationStatus.pending)
              .length;
          int forApproval = apps
              .where((a) => a.status == ApplicationStatus.for_approval)
              .length;
          int accepted = apps
              .where((a) => a.status == ApplicationStatus.accepted)
              .length;
          int declined = apps
              .where((a) => a.status == ApplicationStatus.declined)
              .length;
          int interviewees = apps
              .where((a) =>
                  a.status == ApplicationStatus.interview_scheduled)
              .length;

          return ListView(
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
                  _summaryCard('Organizations', orgs.length,
                      Icons.apartment_outlined),
                  _summaryCard(
                      'Events', events.length, Icons.event_available_outlined),
                  _summaryCard('Members', members.length,
                      Icons.group_outlined),
                  _summaryCard('Users', users.length,
                      Icons.person_outline),
                ],
              ),

              const SizedBox(height: 16),

              // Applications Breakdown
              _sectionTitle('Applications Overview'),
              const SizedBox(height: 10),
              _appStatusCard(
                total: apps.length,
                pending: pending,
                forApproval: forApproval,
                accepted: accepted,
                declined: declined,
                interviewees: interviewees,
              ),

              const SizedBox(height: 16),

              // User Roles Breakdown
              _sectionTitle('User Roles'),
              const SizedBox(height: 10),
              _rolesCard(
                students: countRole(UserRole.student),
                officers: countRole(UserRole.officer),
                admins: countRole(UserRole.admin),
              ),
            ],
          );
        },
      ),
    );
  }

  // 🔹 Section Title
  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // 🔹 Summary Cards (Grid)
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
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // 🔹 Applications Status Card
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
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

  // 🔹 Roles Breakdown
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
        Text(
          '$value',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
