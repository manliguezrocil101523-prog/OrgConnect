import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../core/app_state.dart';

class AdminAccountsScreen extends StatefulWidget {
  const AdminAccountsScreen({super.key});

  @override
  State<AdminAccountsScreen> createState() => _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> {
  List<Map<String, dynamic>> dbUsers = [];
  bool isLoading = true;

  static const Color accent = Color(0xFF6366F1);
  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _fetchUsersFromDatabase();
  }

  Future<void> _fetchUsersFromDatabase() async {
    try {
      final response =
          await supabase.Supabase.instance.client.from('profiles').select('*');
      setState(() {
        dbUsers = List<Map<String, dynamic>>.from(response as List);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        dbUsers = [];
        isLoading = false;
      });
    }
  }

  Future<void> _updateActiveInDatabase(String userId, bool active) async {
    try {
      await supabase.Supabase.instance.client
          .from('profiles')
          .update({'active': active}).eq('id', userId);
    } catch (e) {
      _showSnack('Failed to update status: $e');
    }
  }

  // ─── Show org picker when admin sets role to Officer ──────────────────────
  Future<void> _showOrgPickerDialog(Map<String, dynamic> user) async {
    final orgs = AppState.instance.organizations;

    if (orgs.isEmpty) {
      _showSnack('No organizations found. Please add organizations first.');
      return;
    }

    Organization? selectedOrg;

    // Pre-select if already assigned
    final currentOrgId = user['assigned_org_id']?.toString();
    if (currentOrgId != null) {
      try {
        selectedOrg = orgs.firstWhere((o) => o.id == currentOrgId);
      } catch (_) {}
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_rounded,
                          color: Color(0xFF6366F1), size: 22),
                      SizedBox(width: 8),
                      Text('Assign Organization',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select which org ${user['name'] ?? user['email']} can access as Officer',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: orgs.length,
                  itemBuilder: (_, index) {
                    final org = orgs[index];
                    final isChosen = selectedOrg?.id == org.id;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedOrg = org),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isChosen
                              ? const Color(0xFF6366F1).withOpacity(0.10)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isChosen
                                ? const Color(0xFF6366F1)
                                : Colors.grey.shade200,
                            width: isChosen ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isChosen
                                    ? const Color(0xFF6366F1)
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Icon(
                                isChosen
                                    ? Icons.check_rounded
                                    : Icons.business_rounded,
                                color: isChosen
                                    ? Colors.white
                                    : Colors.grey.shade500,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    org.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5,
                                      color: isChosen
                                          ? const Color(0xFF6366F1)
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    'ID: ${org.id}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: selectedOrg == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          final userId = user['id'].toString();
                          final orgId = selectedOrg!.id;
                          try {
                            await supabase.Supabase.instance.client
                                .from('profiles')
                                .update({
                              'role': 'officer',
                              'assigned_org_id': orgId,
                            }).eq('id', userId);

                            setState(() {
                              final idx =
                                  dbUsers.indexWhere((u) => u['id'] == userId);
                              if (idx != -1) {
                                dbUsers[idx]['role'] = 'officer';
                                dbUsers[idx]['assigned_org_id'] = orgId;
                              }
                            });

                            _showSnack(
                              '✅ ${user['name'] ?? user['email']} is now Officer of ${selectedOrg!.name}',
                            );
                          } catch (e) {
                            _showSnack('Error: $e');
                          }
                        },
                  child: const Text('Confirm',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppState.instance.isDark;
    final background =
        isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F7FA);
    final cardColor = isDark ? const Color(0xFF181C27) : Colors.white;
    final primary = isDark ? const Color(0xFF181C27) : const Color(0xFF1E293B);
    final textMain = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
    final textSub = isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600;
    final textSub2 = isDark ? const Color(0xFF64748B) : Colors.grey.shade500;
    final dropdownBg = isDark ? const Color(0xFF1E2334) : Colors.grey.shade100;
    final dropdownIcon = isDark ? const Color(0xFF94A3B8) : Colors.black54;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primary,
        title: const Text(
          'User Management',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() => isLoading = true);
              _fetchUsersFromDatabase();
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : dbUsers.isEmpty
              ? const Center(child: Text('No users found'))
              : Builder(
                  builder: (context) {
                    // ── Group users by role ──────────────────────────────
                    final students = dbUsers
                        .where((u) =>
                            (u['role']?.toString() ?? 'student') == 'student')
                        .toList();
                    final officers = dbUsers
                        .where((u) => u['role']?.toString() == 'officer')
                        .toList();
                    final admins = dbUsers
                        .where((u) => u['role']?.toString() == 'admin')
                        .toList();

                    // ── Build flat list: [header, user, user, header, ...] ──
                    final List<dynamic> items = [];

                    if (students.isNotEmpty) {
                      items.add({'_header': 'Students'});
                      items.addAll(students);
                    }
                    if (officers.isNotEmpty) {
                      items.add({'_header': 'Officers'});
                      items.addAll(officers);
                    }
                    if (admins.isNotEmpty) {
                      items.add({'_header': 'Admins'});
                      items.addAll(admins);
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];

                        // ── Render section header ──
                        if (item is Map && item.containsKey('_header')) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 10),
                            child: Row(
                              children: [
                                Text(
                                  item['_header'],
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Divider(
                                    color: accent.withOpacity(0.25),
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // ── Render user card ──
                        final u = item as Map<String, dynamic>;
                        final role = u['role']?.toString() ?? 'student';
                        final isActive = u['active'] ?? true;
                        final assignedOrgId = u['assigned_org_id']?.toString();

                        // Find org name to display on the card
                        String? assignedOrgName;
                        if (assignedOrgId != null) {
                          try {
                            assignedOrgName = AppState.instance.organizations
                                .firstWhere((o) => o.id == assignedOrgId)
                                .name;
                          } catch (_) {
                            assignedOrgName = assignedOrgId;
                          }
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(isDark ? 0.3 : 0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: accent,
                                child: Text(
                                  (u['name']?.toString().isNotEmpty == true)
                                      ? u['name'].toString()[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      u['name']?.toString() ?? 'No Name',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: textMain),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      u['email']?.toString() ?? '',
                                      style: TextStyle(
                                          color: textSub, fontSize: 13),
                                    ),
                                    if (u['student_id'] != null)
                                      Text(
                                        'ID: ${u['student_id']}',
                                        style: TextStyle(
                                            color: textSub2, fontSize: 12),
                                      ),

                                    // ── Assigned org badge ──
                                    if (role == 'officer' &&
                                        assignedOrgName != null) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6366F1)
                                              .withOpacity(0.10),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: const Color(0xFF6366F1)
                                                .withOpacity(0.30),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.shield_rounded,
                                                color: Color(0xFF6366F1),
                                                size: 12),
                                            const SizedBox(width: 4),
                                            Text(
                                              assignedOrgName,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF6366F1),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 10),

                                    // Role Dropdown
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: dropdownBg,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: DropdownButton<String>(
                                        value: role,
                                        underline: const SizedBox(),
                                        dropdownColor: dropdownBg,
                                        style: TextStyle(color: textMain),
                                        icon: Icon(Icons.keyboard_arrow_down,
                                            color: dropdownIcon),
                                        items: const [
                                          DropdownMenuItem(
                                              value: 'student',
                                              child: Text('Student')),
                                          DropdownMenuItem(
                                              value: 'officer',
                                              child: Text('Officer')),
                                          DropdownMenuItem(
                                              value: 'admin',
                                              child: Text('Admin')),
                                        ],
                                        onChanged: (val) async {
                                          if (val == null) return;

                                          if (val == 'officer') {
                                            // Show org picker
                                            await _showOrgPickerDialog(u);
                                          } else {
                                            // Remove officer privileges
                                            await supabase
                                                .Supabase.instance.client
                                                .from('profiles')
                                                .update({
                                              'role': val,
                                              'assigned_org_id': null,
                                            }).eq('id', u['id'].toString());

                                            setState(() {
                                              final realIdx =
                                                  dbUsers.indexWhere((d) =>
                                                      d['id'] == u['id']);
                                              if (realIdx != -1) {
                                                dbUsers[realIdx]['role'] = val;
                                                dbUsers[realIdx]
                                                    ['assigned_org_id'] = null;
                                              }
                                            });
                                            _showSnack('Role updated to $val');
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Active Switch
                              Column(
                                children: [
                                  Text(
                                    isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      color: isActive ? success : danger,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Switch(
                                    value: isActive,
                                    activeThumbColor: success,
                                    onChanged: (value) async {
                                      await _updateActiveInDatabase(
                                          u['id'].toString(), value);
                                      setState(() {
                                        final realIdx = dbUsers.indexWhere(
                                            (d) => d['id'] == u['id']);
                                        if (realIdx != -1) {
                                          dbUsers[realIdx]['active'] = value;
                                        }
                                      });
                                      _showSnack(value
                                          ? 'User activated'
                                          : 'User disabled');
                                    },
                                  ),
                                ],
                              ), // Column (active switch)
                            ],
                          ), // Row
                        ); // Container (card)
                      }, // itemBuilder
                    ); // ListView.builder
                  }, // Builder callback
                ), // Builder
    ); // Scaffold
  } // build()

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
