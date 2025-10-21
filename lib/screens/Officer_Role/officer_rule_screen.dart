import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import 'officer_applications_screen.dart';
import 'officer_members_screen.dart';
import 'officer_events_screen.dart';

class BaseOfficerDashboard extends StatelessWidget {
  final String orgId; // 👈 change from int → String
  final String orgName;

  const BaseOfficerDashboard({
    Key? key,
    required this.orgId,
    required this.orgName,
  }) : super(key: key);

  static const Color mintBg = Color(0xFFEAF6F0);
  static const Color tealHeader = Color(0xFF79CFC4);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mintBg,
      appBar: AppBar(
        backgroundColor: tealHeader,
        elevation: 0,
        title: Text(
          '$orgName Officer Dashboard',
          style:
              const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.0),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 32, top: 20),
                  child: Center(
                    child: ClipOval(
                      child: Image.asset(
                        AppState.instance.organizations
                            .firstWhere((o) => o.id == orgId)
                            .logoAsset,
                        width: 140,
                        height: 140,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                _tile(
                  context,
                  'Manage Applications',
                  Icons.fact_check_outlined,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OfficerApplicationsScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _tile(
                  context,
                  'Manage Members',
                  Icons.groups_outlined,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OfficerMembersScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _tile(
                  context,
                  'Manage Events',
                  Icons.event_available_outlined,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          OfficerEventsScreen(orgId: orgId, orgName: orgName),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(
      BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: tealHeader,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}
