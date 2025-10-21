import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import 'org_form_screen.dart';

class OrgDetailScreen extends StatefulWidget {
  final String orgId;

  const OrgDetailScreen({super.key, required this.orgId});

  @override
  State<OrgDetailScreen> createState() => _OrgDetailScreenState();
}

class _OrgDetailScreenState extends State<OrgDetailScreen> {
  String _selectedTab = 'profile'; // 'profile' or 'apply'

  @override
  Widget build(BuildContext context) {
    final org =
        AppState.instance.organizations.firstWhere((o) => o.id == widget.orgId);
    final darkGreen = const Color(0xFF79CFC4);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE8F5E9),
              Color(0xFFB2DFDB),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Fixed Header Section
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    // Centered Back button
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Logo Container
                    Container(
                      height: 120,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(60),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          org.logoAsset,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Organization Name
                    Text(
                      org.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    // Tab Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                setState(() => _selectedTab = 'profile'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedTab == 'profile'
                                  ? darkGreen
                                  : Colors.white,
                              foregroundColor: _selectedTab == 'profile'
                                  ? Colors.white
                                  : darkGreen,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: _selectedTab == 'profile' ? 2 : 0,
                              side: _selectedTab == 'profile'
                                  ? null
                                  : BorderSide(
                                      color: darkGreen.withOpacity(0.4)),
                            ),
                            child: const Text(
                              'Profile',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                setState(() => _selectedTab = 'apply'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedTab == 'apply'
                                  ? darkGreen
                                  : Colors.white,
                              foregroundColor: _selectedTab == 'apply'
                                  ? Colors.white
                                  : darkGreen,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: _selectedTab == 'apply' ? 2 : 0,
                              side: _selectedTab == 'apply'
                                  ? null
                                  : BorderSide(
                                      color: darkGreen.withOpacity(0.4)),
                            ),
                            child: const Text(
                              'Apply',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Content Area
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: IndexedStack(
                      index: _selectedTab == 'profile' ? 0 : 1,
                      children: [
                        _buildProfileContent(org),
                        _buildApplyContent(org),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent(Organization org) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Organization Details
          if (org.acronym.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF79CFC4).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                org.acronym,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF79CFC4),
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Category/Type
          if (org.category.isNotEmpty)
            _buildInfoRow(
              icon: Icons.category,
              label: 'Category',
              value: org.category,
            ),

          // Description
          if (org.about.isNotEmpty)
            _buildInfoRow(
              icon: Icons.description,
              label: 'About',
              value: org.about,
              isMultiLine: true,
            ),

          // Mission & Vision
          if (org.missionVision.isNotEmpty)
            _buildInfoRow(
              icon: Icons.flag,
              label: 'Mission & Vision',
              value: org.missionVision,
              isMultiLine: true,
            ),

          // Adviser/Head
          if (org.adviser.isNotEmpty)
            _buildInfoRow(
              icon: Icons.person,
              label: 'Adviser',
              value: org.adviser,
            ),

          // Contact Information
          if (org.contactEmail.isNotEmpty || org.contactPhone.isNotEmpty)
            _buildContactInfo(org),

          // Officers
          if (org.officers.isNotEmpty) _buildOfficersList(org.officers),

          // Activities/Events
          if (org.activitiesHighlights.isNotEmpty)
            _buildActivitiesList(org.activitiesHighlights),
        ],
      ),
    );
  }

  Widget _buildApplyContent(Organization org) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Apply to ${org.name}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Fill out the application form below to join ${org.name}.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          // Application Form Widget
          _getApplyScreen(widget.orgId),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isMultiLine = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment:
            isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF79CFC4).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF79CFC4),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    height: isMultiLine ? 1.4 : 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo(Organization org) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF79CFC4).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.contact_mail,
              color: const Color(0xFF79CFC4),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contact Information',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                if (org.contactEmail.isNotEmpty)
                  Text(
                    'Email: ${org.contactEmail}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                if (org.contactPhone.isNotEmpty)
                  Text(
                    'Phone: ${org.contactPhone}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                if (org.socialLink.isNotEmpty)
                  Text(
                    'Social: ${org.socialLink}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficersList(List<String> officers) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF79CFC4).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.people,
              color: const Color(0xFF79CFC4),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Officers',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                ...officers.map(
                  (officer) => Text(
                    '• $officer',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesList(List<String> activities) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF79CFC4).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.event_note,
              color: const Color(0xFF79CFC4),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activities & Events',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                ...activities.map(
                  (activity) => Text(
                    '• $activity',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _getApplyScreen(String orgId) {
    final org =
        AppState.instance.organizations.firstWhere((o) => o.id == orgId);
    return OrgFormContent(
      title: org.name,
      logoAsset: org.logoAsset,
    );
  }
}
