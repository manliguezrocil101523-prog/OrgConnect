import 'package:flutter/material.dart';
import '../../core/app_state.dart';
class AdminAccountsScreen extends StatelessWidget {
  const AdminAccountsScreen({Key? key}) : super(key: key);

  static const Color mintBg = Color(0xFFEAF6F0);
  static const Color tealHeader = Color(0xFF79CFC4);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mintBg,
      appBar: AppBar(
        backgroundColor: tealHeader,
        elevation: 0,
        title: const Text(
          'Accounts',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.0),
        ),
        centerTitle: true,
      ),
      body: AnimatedBuilder(
        animation: AppState.instance,
        builder: (context, _) {
          final users = AppState.instance.users;
          if (users.isEmpty) {
            return const Center(child: Text('No users.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final u = users[index];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: tealHeader,
                    child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text('${u.name} • ${u.email}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Row(
                    children: [
                      const Text('Role: '),
                      DropdownButton<UserRole>(
                        value: u.role,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: UserRole.student, child: Text('Student')),
                          DropdownMenuItem(value: UserRole.officer, child: Text('Officer')),
                          DropdownMenuItem(value: UserRole.admin, child: Text('Admin')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            AppState.instance.setUserRole(u.id, val);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('User role updated.')),
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
                        activeThumbColor: tealHeader,
                        onChanged: (value) {
                          AppState.instance.setUserActive(u.id, value);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${u.name} ${value ? 'activated' : 'deactivated'}')),
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
