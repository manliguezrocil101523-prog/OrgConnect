import 'package:flutter/material.dart';
import '../../core/app_state.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({Key? key}) : super(key: key);

  static const Color mintBg = Color(0xFFEAF6F0);
  static const Color tealHeader = Color(0xFF79CFC4);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mintBg,
      appBar: AppBar(
        backgroundColor: tealHeader,
        elevation: 0,
        title: const Text(
          'Reports',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.0),
        ),
        centerTitle: true,
      ),
      body: AnimatedBuilder(
        animation: AppState.instance,
        builder: (context, _) {
          final users = AppState.instance.users;
          final apps = AppState.instance.applications;
          final members = AppState.instance.members;
          final events = AppState.instance.events;
          final orgs = AppState.instance.organizations;

          int countRole(UserRole r) => users.where((u) => u.role == r).length;
          int pending = apps.where((a) => a.status == ApplicationStatus.pending).length;
          int accepted = apps.where((a) => a.status == ApplicationStatus.accepted).length;
          int declined = apps.where((a) => a.status == ApplicationStatus.declined).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _statCard('Organizations', orgs.length, Icons.apartment_outlined),
              const SizedBox(height: 10),
              _statCard('Users (Students)', countRole(UserRole.student), Icons.school_outlined),
              const SizedBox(height: 10),
              _statCard('Users (Officers)', countRole(UserRole.officer), Icons.badge_outlined),
              const SizedBox(height: 10),
              _statCard('Users (Admins)', countRole(UserRole.admin), Icons.admin_panel_settings_outlined),
              const SizedBox(height: 10),
              _statCard('Applications: ${apps.length}', null, Icons.fact_check_outlined,
                  subtitle: 'Pending: $pending  •  Accepted: $accepted  •  Declined: $declined'),
              const SizedBox(height: 10),
              _statCard('Members', members.length, Icons.groups_outlined),
              const SizedBox(height: 10),
              _statCard('Events', events.length, Icons.event_available_outlined),
            ],
          );
        },
      ),
    );
  }

  Widget _statCard(String title, int? value, IconData icon, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tealHeader,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.black54)),
                ],
              ],
            ),
          ),
          if (value != null)
            Text(
              '$value',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
        ],
      ),
    );
  }
}
