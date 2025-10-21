import 'package:flutter/material.dart'; // Import Flutter's material design library for building UI components in the role router
import '../core/app_state.dart'; // Import the app state manager for accessing selected role and organization data
import 'Officer_Role/officer_rule_screen.dart'; // Import the officer rule screen (though not used in this file, perhaps for future use)
import 'Admin_Role/admin_dashboard_screen.dart'; // Import the admin dashboard screen for admin role routing
import 'Officer_Role/officer_dashboard_screen.dart'; // Import the officer dashboard screen for officer role routing

class RoleRouter extends StatelessWidget { // Define the RoleRouter class extending StatelessWidget to route users based on their selected role in the organization management system
  const RoleRouter({super.key}); // Constructor for RoleRouter using super.key for widget key

  @override // Override the build method to define the routing logic
  Widget build(BuildContext context) { // Build method that returns the appropriate dashboard based on the selected role
    final state = AppState.instance; // Get the singleton instance of AppState
    // If no role selected → go back to home // Comment indicating check for no role
    if (state.selectedRole == null) { // Check if no role is selected
      return const Center(child: Text("No role selected")); // Return a centered text widget indicating no role selected
    }
    switch (state.selectedRole!) { // Switch statement on the selected role (non-null asserted)
      case UserRole.student: // Case for student role
        return const StudentDashboard(); // Return the student dashboard widget
      case UserRole.admin: // Case for admin role
        return const AdminDashboard(); // Return the admin dashboard widget
      case UserRole.officer: // Case for officer role
        final orgId = state.currentOfficerOrgId; // Get the current officer's organization ID
        if (orgId == null) { // Check if no organization is selected for the officer
          return const Center(child: Text("No organization selected")); // Return centered text for no organization
        }
        final org = state.organizations.firstWhere((o) => o.id == orgId); // Find the organization by ID
        // 🚀 Route officer into the correct dashboard // Comment indicating routing to specific dashboard
        return BaseOfficerDashboard( // Return the base officer dashboard
          orgId: org.id, // Pass the organization ID
          orgName: org.name, // Pass the organization name
        );
    }
  }
}
