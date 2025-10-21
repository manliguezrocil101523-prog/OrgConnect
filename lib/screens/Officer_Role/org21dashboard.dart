import 'package:flutter/material.dart';
import 'officer_rule_screen.dart';

class OfficerDashboardOrg1 extends StatelessWidget {
  const OfficerDashboardOrg1({super.key});

  @override
  Widget build(BuildContext context) {
    return const BaseOfficerDashboard(
      orgId: "21",
      orgName: "BCC DANCE COMPANY", // 👈 must provide orgName
    );
  }
}
