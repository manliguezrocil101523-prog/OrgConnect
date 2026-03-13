import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../core/app_state.dart';

class AdminAccountsScreen extends StatefulWidget {
  const AdminAccountsScreen({super.key});

  static const Color mintBg = Color(0xFFEAF6F0);
  static const Color tealHeader = Color(0xFF79CFC4);

  @override
  State<AdminAccountsScreen> createState() => _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> {
  List<User> dbUsers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsersFromDatabase();
  }

  Future<void> _fetchUsersFromDatabase() async {
    try {
      final response = await supabase.Supabase.instance.client
          .from('profile  s')
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
      // If database fetch fails, set to empty list
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
      case 'student':
      default:
        return UserRole.student;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminAccountsScreen.mintBg,
      appBar: AppBar(
        backgroundColor: AdminAccountsScreen.tealHeader,
        elevation: 0,
        title: const Text(
          'Accounts',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.0),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedBuilder(
              animation: AppState.instance,
              builder: (context, _) {
                final currentStudent = AppState.instance.currentStudent;

                // Create a list starting with the signed-in student if exists, then add database users
                final displayUsers = <User>[];
                if (currentStudent != null) {
                  displayUsers.add(User(
                    id: currentStudent.id,
                    name: currentStudent.name,
                    email: currentStudent.email,
                    role: UserRole.student,
                    active: true, // Assume signed-in students are active
                    studentId: currentStudent.studentId,
                  ));
                }
                displayUsers.addAll(dbUsers);

                if (displayUsers.isEmpty) {
                  return const Center(child: Text('No users.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: displayUsers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final u = displayUsers[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: AdminAccountsScreen.tealHeader,
                          child: Text(
                              u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(
                            u.role == UserRole.student && u.studentId != null
                                ? '${u.name} • ${u.email} • ID: ${u.studentId}'
                                : '${u.name} • ${u.email}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Row(
                          children: [
                            const Text('Role: '),
                            DropdownButton<UserRole>(
                              value: u.role,
                              underline: const SizedBox.shrink(),
                              items: const [
                                DropdownMenuItem(
                                    value: UserRole.student, child: Text('Student')),
                                DropdownMenuItem(
                                    value: UserRole.officer, child: Text('Officer')),
                                DropdownMenuItem(
                                    value: UserRole.admin, child: Text('Admin')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  AppState.instance.setUserRole(u.id, val);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('User role updated.')),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Active'),
                            const SizedBox(width: 6),
                            Switch(
                              value: u.active,
                              activeThumbColor: AdminAccountsScreen.tealHeader,
                              onChanged: (value) {
                                AppState.instance.setUserActive(u.id, value);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          '${u.name} ${value ? 'activated' : 'deactivated'}')),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
