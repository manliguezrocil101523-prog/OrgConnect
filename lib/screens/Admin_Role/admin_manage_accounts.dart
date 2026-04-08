import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../core/app_state.dart';

class AdminAccountsScreen extends StatefulWidget {
  const AdminAccountsScreen({super.key});

  @override
  State<AdminAccountsScreen> createState() => _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> {
  List<User> dbUsers = [];
  bool isLoading = true;

  // 🎨 Modern Color Palette (Professional Dark + Soft Accent)
  static const Color background = Color(0xFFF5F7FA);
  static const Color primary = Color(0xFF1E293B); // Dark blue-gray
  static const Color accent = Color(0xFF6366F1); // Indigo modern
  static const Color cardColor = Colors.white;
  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _fetchUsersFromDatabase();
  }

  Future<void> _fetchUsersFromDatabase() async {
    try {
      final response = await supabase.Supabase.instance.client
          .from('profiles')
          .select('*');

      final fetchedUsers = (response as List<dynamic>).map((userData) {
        return User(
          id: userData['id']?.toString() ?? '',
          name: userData['name']?.toString() ?? '',
          email: userData['email']?.toString() ?? '',
          role: _parseUserRole(userData['role']?.toString() ?? 'student'),
          active: userData['active'] ?? true,
          studentId: userData['student_id']?.toString(),
        );
      }).toList();

      setState(() {
        dbUsers = fetchedUsers;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        dbUsers = [];
        isLoading = false;
      });
    }
  }

  UserRole _parseUserRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'officer':
        return UserRole.officer;
      default:
        return UserRole.student;
    }
  }

  @override
  Widget build(BuildContext context) {
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
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedBuilder(
              animation: AppState.instance,
              builder: (context, _) {
                final currentStudent = AppState.instance.currentStudent;

                final displayUsers = <User>[];
                if (currentStudent != null) {
                  displayUsers.add(User(
                    id: currentStudent.id,
                    name: currentStudent.name,
                    email: currentStudent.email,
                    role: UserRole.student,
                    active: true,
                    studentId: currentStudent.studentId,
                  ));
                }
                displayUsers.addAll(dbUsers);

                if (displayUsers.isEmpty) {
                  return const Center(child: Text('No users found'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: displayUsers.length,
                  itemBuilder: (context, index) {
                    final u = displayUsers[index];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
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
                              u.name.isNotEmpty
                                  ? u.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Info Section
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  u.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  u.email,
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13),
                                ),
                                if (u.studentId != null)
                                  Text(
                                    'ID: ${u.studentId}',
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12),
                                  ),
                                const SizedBox(height: 10),

                                // Role Dropdown (Styled)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: DropdownButton<UserRole>(
                                    value: u.role,
                                    underline: const SizedBox(),
                                    icon: const Icon(Icons.keyboard_arrow_down),
                                    items: const [
                                      DropdownMenuItem(
                                          value: UserRole.student,
                                          child: Text('Student')),
                                      DropdownMenuItem(
                                          value: UserRole.officer,
                                          child: Text('Officer')),
                                      DropdownMenuItem(
                                          value: UserRole.admin,
                                          child: Text('Admin')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        AppState.instance
                                            .setUserRole(u.id, val);
                                        _showSnack('Role updated');
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Status Switch
                          Column(
                            children: [
                              Text(
                                u.active ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  color: u.active ? success : danger,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Switch(
                                value: u.active,
                                activeColor: success,
                                onChanged: (value) {
                                  AppState.instance
                                      .setUserActive(u.id, value);
                                  _showSnack(
                                      value ? 'User activated' : 'User disabled');
                                },
                              ),
                            ],
                          )
                        ],
                      ),
                    );
                  },
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
