import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../core/app_state.dart';
import '../../widgets/app_header.dart';

class AdminAccountsScreen extends StatefulWidget {
  const AdminAccountsScreen({super.key});

  @override
  State<AdminAccountsScreen> createState() => _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> {
  List<Map<String, dynamic>> dbUsers = [];
  bool isLoading = true;

  static const Color accent = Color(0xFF22C55E);
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

  // Show org picker when admin sets role to Officer or Adviser.
  Future<void> _showOrgPickerDialog(
    Map<String, dynamic> user, {
    String role = 'officer',
  }) async {
    final orgs = AppState.instance.organizations;

    if (orgs.isEmpty) {
      _showSnack('No organizations found. Please add organizations first.');
      return;
    }

    Organization? selectedOrg;

    // Pre-select if already assigned.
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
                borderRadius: BorderRadius.circular(20),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        color: Color(0xFF22C55E),
                        size: 22,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Assign Organization',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select which org ${user['name'] ?? user['email']} can access as ${role == 'adviser' ? 'Adviser' : 'Officer'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
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
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isChosen
                              ? const Color(0xFF22C55E).withValues(alpha: 0.10)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isChosen
                                ? const Color(0xFF22C55E)
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
                                    ? const Color(0xFF22C55E)
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
                                          ? const Color(0xFF22C55E)
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    'ID: ${org.id}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
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
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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
                              'role': role,
                              'assigned_org_id': orgId,
                            }).eq('id', userId);

                            if (!mounted) return;

                            setState(() {
                              final idx = dbUsers.indexWhere(
                                (u) => u['id'] == userId,
                              );

                              if (idx != -1) {
                                dbUsers[idx]['role'] = role;
                                dbUsers[idx]['assigned_org_id'] = orgId;
                              }
                            });

                            _showSnack(
                              '${user['name'] ?? user['email']} is now ${role == 'adviser' ? 'Adviser' : 'Officer'} of ${selectedOrg!.name}',
                            );
                          } catch (e) {
                            if (!mounted) return;
                            _showSnack('Error: $e');
                          }
                        },
                  child: const Text(
                    'Confirm',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Reusable header for the Accounts screen.
  // AppHeader handles its own status-bar inset.
  Widget _accountsHeader() {
    return AppHeader(
      title: 'Accounts',
      subtitle: 'Manage accounts, roles, and access',
      status: '${dbUsers.length} ACCOUNTS',
      icon: Icons.manage_accounts_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppState.instance.isDark;
    final background =
        isDark ? const Color(0xFF0F1712) : const Color(0xFFF3FAF5);
    final cardColor = isDark ? const Color(0xFF181C27) : Colors.white;
    final textMain = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F2D22);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final dropdownBg =
        isDark ? const Color(0xFF1E2334) : const Color(0xFFF8FAFC);
    final dropdownIcon =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: background,
      body: Builder(
        builder: (context) {
          // Keep the AppHeader as the first item in the scrolling list,
          // including while loading or when there are no accounts.
          // The header stays fixed at the top, even while loading
          // or when there are no accounts.
          if (isLoading) {
            return Column(
              children: [
                _accountsHeader(),
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: accent),
                  ),
                ),
              ],
            );
          }

          if (dbUsers.isEmpty) {
            return Column(
              children: [
                _accountsHeader(),
                Expanded(
                  child: Center(
                    child: Text(
                      'No users found',
                      style: TextStyle(
                        color: textSub,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          final students = dbUsers
              .where(
                (u) => (u['role']?.toString() ?? 'student') == 'student',
              )
              .toList();

          final officers =
              dbUsers.where((u) => u['role']?.toString() == 'officer').toList();

          final admins =
              dbUsers.where((u) => u['role']?.toString() == 'admin').toList();

          final advisers =
              dbUsers.where((u) => u['role']?.toString() == 'adviser').toList();

          final List<dynamic> items = [];

          if (students.isNotEmpty) {
            items.add({'_header': 'Students'});
            items.addAll(students);
          }

          if (officers.isNotEmpty) {
            items.add({'_header': 'Officers'});
            items.addAll(officers);
          }

          if (advisers.isNotEmpty) {
            items.add({'_header': 'Advisers'});
            items.addAll(advisers);
          }

          if (admins.isNotEmpty) {
            items.add({'_header': 'Admins'});
            items.addAll(admins);
          }

          return Column(
            children: [
              _accountsHeader(), // stays fixed at the top
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];

                    if (item is Map && item.containsKey('_header')) {
                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          index == 0 ? 24 : 6,
                          20,
                          10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item['_header'],
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: accent,
                                letterSpacing: .6,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Divider(
                                color: accent.withValues(alpha: .18),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final u = item as Map<String, dynamic>;
                    final role = u['role']?.toString() ?? 'student';
                    final isActive = u['active'] ?? true;
                    final assignedOrgId = u['assigned_org_id']?.toString();

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

                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        index == items.length - 1 ? 30 : 0,
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [cardColor, cardColor]
                                : [
                                    Colors.white,
                                    const Color(0xFFF1FBF5),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : const Color(0xFFD7EFE0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(
                                alpha: isDark ? .08 : .07,
                              ),
                              blurRadius: 18,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 27,
                              backgroundColor: accent.withValues(alpha: .14),
                              child: (u['avatar_url']?.toString().isNotEmpty ??
                                      false)
                                  ? ClipOval(
                                      child: Image.network(
                                        u['avatar_url'].toString(),
                                        width: 54,
                                        height: 54,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Text(
                                          (u['name']?.toString().isNotEmpty ==
                                                  true)
                                              ? u['name']
                                                  .toString()[0]
                                                  .toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: accent,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Text(
                                      (u['name']?.toString().isNotEmpty == true)
                                          ? u['name']
                                              .toString()[0]
                                              .toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: accent,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    u['name']?.toString() ?? 'No Name',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: textMain,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    u['email']?.toString() ?? '',
                                    style: TextStyle(
                                      color: textSub,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  if (assignedOrgName != null &&
                                      role == 'adviser') ...[
                                    const SizedBox(height: 7),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: .09),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: accent.withValues(alpha: .20),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.apartment_rounded,
                                            color: accent,
                                            size: 12,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            assignedOrgName,
                                            style: const TextStyle(
                                              color: accent,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  if (role == 'officer')
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 11,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: .09),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: accent.withValues(alpha: .20),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.lock_person_rounded,
                                            color: accent,
                                            size: 15,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Officer — assigned by Adviser',
                                            style: TextStyle(
                                              color: accent,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: dropdownBg,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white10
                                              : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: DropdownButton<String>(
                                        value: role,
                                        isDense: true,
                                        underline: const SizedBox(),
                                        dropdownColor: dropdownBg,
                                        style: TextStyle(
                                          color: textMain,
                                          fontSize: 12,
                                        ),
                                        icon: Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: dropdownIcon,
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'student',
                                            child: Text('Student'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'admin',
                                            child: Text('Admin'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'adviser',
                                            child: Text('Adviser'),
                                          ),
                                        ],
                                        onChanged: (val) async {
                                          if (val == null) return;

                                          if (val == 'adviser') {
                                            await _showOrgPickerDialog(
                                              u,
                                              role: val,
                                            );
                                          } else {
                                            await supabase
                                                .Supabase.instance.client
                                                .from('profiles')
                                                .update({
                                              'role': val,
                                              'assigned_org_id': null,
                                            }).eq('id', u['id'].toString());

                                            if (!mounted) return;

                                            setState(() {
                                              final realIdx =
                                                  dbUsers.indexWhere(
                                                (d) => d['id'] == u['id'],
                                              );

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
                            const SizedBox(width: 10),
                            Column(
                              children: [
                                Text(
                                  isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    color: isActive ? success : danger,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Switch(
                                  value: isActive,
                                  activeThumbColor: success,
                                  onChanged: (value) async {
                                    await _updateActiveInDatabase(
                                      u['id'].toString(),
                                      value,
                                    );

                                    if (!mounted) return;

                                    setState(() {
                                      final realIdx = dbUsers.indexWhere(
                                        (d) => d['id'] == u['id'],
                                      );

                                      if (realIdx != -1) {
                                        dbUsers[realIdx]['active'] = value;
                                      }
                                    });

                                    _showSnack(
                                      value
                                          ? 'User activated'
                                          : 'User disabled',
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
