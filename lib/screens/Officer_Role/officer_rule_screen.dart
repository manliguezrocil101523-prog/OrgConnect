import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import 'officer_applications_screen.dart';
import 'officer_members_screen.dart';
import 'officer_events_screen.dart';
import 'officer_authorization_screen.dart';

class BaseOfficerDashboard extends StatelessWidget {
  final String orgId; // 👈 change from int → String
  final String orgName;

  const BaseOfficerDashboard({
    super.key,
    required this.orgId,
    required this.orgName,
  });

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const OfficerAuthorizationScreen(),
            ),
          ),
        ),
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
                  Icons.list_alt_outlined,
                  () => _showApplicationFilters(context),
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

  void _showApplicationFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: mintBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Application Filters',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: tealHeader,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _filterButton(context, 'All', Icons.list_alt, null),
                  _filterButton(context, 'Pending', Icons.pending, 'pending'),
                  _filterButton(context, 'For Approval', Icons.approval, 'forApproval'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _filterButton(
                      context, 'Interviewees', Icons.people, 'interviewed'),
                  _filterButton(
                      context, 'Approved', Icons.check_circle, 'approved'),
                  _filterButton(context, 'Declined', Icons.cancel, 'declined'),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _filterButton(
      BuildContext context, String label, IconData icon, String? filter) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OfficerApplicationsScreen(filter: filter),
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: tealHeader,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: tealHeader, width: 1),
            ),
          ),
          icon: Icon(icon, size: 16),
          label: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
