import 'package:flutter/material.dart';
import '../../core/app_state.dart';

class OfficerMembersScreen extends StatelessWidget {
  const OfficerMembersScreen({Key? key}) : super(key: key);

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
          'Members',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.0),
        ),
        centerTitle: true,
      ),
      body: AnimatedBuilder(
        animation: AppState.instance,
        builder: (context, _) {
          final members = AppState.instance.members;
          if (members.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('No members yet. Tap + to add.', style: TextStyle(fontSize: 14)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: members.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final m = members[index];
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  leading: CircleAvatar(
                    backgroundColor: tealHeader,
                    child: Text(
                      m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${m.position} • ${m.orgName}'),
                  onTap: () => _showMemberDialog(context, existing: m),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit_outlined, color: Colors.black87),
                        onPressed: () => _showMemberDialog(context, existing: m),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () {
                          AppState.instance.removeMember(m.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Removed ${m.name}')),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: tealHeader,
        foregroundColor: Colors.white,
        onPressed: () => _showMemberDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showMemberDialog(BuildContext context, {Member? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final orgCtrl = TextEditingController(text: existing?.orgName ?? '');
    String position = existing?.position.isNotEmpty == true ? existing!.position : 'Member';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? 'Add Member' : 'Edit Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: position,
                items: const [
                  DropdownMenuItem(value: 'Member', child: Text('Member')),
                  DropdownMenuItem(value: 'Officer', child: Text('Officer')),
                  DropdownMenuItem(value: 'President', child: Text('President')),
                  DropdownMenuItem(value: 'Vice President', child: Text('Vice President')),
                  DropdownMenuItem(value: 'Secretary', child: Text('Secretary')),
                ],
                onChanged: (v) => setState(() => position = v ?? 'Member'),
                decoration: const InputDecoration(labelText: 'Position'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: orgCtrl,
                decoration: const InputDecoration(labelText: 'Organization'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: tealHeader, foregroundColor: Colors.white),
              onPressed: () {
                final name = nameCtrl.text.trim();
                final org = orgCtrl.text.trim();
                if (name.isEmpty || org.isEmpty) return;
                if (existing == null) {
                  AppState.instance.addMember(name: name, position: position, orgName: org);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added $name')),
                  );
                } else {
                  AppState.instance.updateMember(
                    existing.copyWith(name: name, position: position, orgName: org),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Updated $name')),
                  );
                }
                Navigator.pop(ctx);
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }
}
