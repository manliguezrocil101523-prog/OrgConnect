import 'package:flutter/material.dart'; 
import '../core/app_state.dart'; 
import 'Officer_Role/officer_rule_screen.dart'; 
import 'Admin_Role/admin_dashboard_screen.dart'; 
import 'Officer_Role/officer_dashboard_screen.dart'; 

class RoleRouter extends StatelessWidget { 
  const RoleRouter({super.key}); 

  @override 
  Widget build(BuildContext context) { 
    final state = AppState.instance; 
    
    if (state.selectedRole == null) { 
      return const Center(child: Text("No role selected")); 
    }
    switch (state.selectedRole!) { 
      case UserRole.student: 
        return const StudentDashboard(); 
      case UserRole.admin: 
        return const AdminDashboard(); 
      case UserRole.officer: 
        final orgId = state.currentOfficerOrgId; 
        if (orgId == null) { 
          return const Center(child: Text("No organization selected")); 
        }
        final org = state.organizations.firstWhere((o) => o.id == orgId); 
        
        return BaseOfficerDashboard( 
          orgId: org.id, 
          orgName: org.name, 
        );
    }
  }
}
