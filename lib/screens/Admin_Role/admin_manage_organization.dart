import 'package:flutter/material.dart';
import '../../core/app_state.dart';
class AdminOrganizationsScreen extends StatelessWidget {
  const AdminOrganizationsScreen({Key? key}) : super(key: key);

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
          'Organizations',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.0),
        ),
        centerTitle: true,
      ),
      body: AnimatedBuilder(
        animation: AppState.instance,
        builder: (context, _) {
          final orgs = AppState.instance.organizations;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            itemCount: orgs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final o = orgs[index];
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
                    child: Text(o.name.isNotEmpty ? o.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(o.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(o.shortDesc),
                  onTap: () => _showOrgDialog(context, o),
                  trailing: IconButton(
                    tooltip: 'Remove',
                    onPressed: () {
                      AppState.instance.removeOrganization(o.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Removed ${o.name}')),
                      );
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
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
        onPressed: () => _showOrgDialog(context, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showOrgDialog(BuildContext context, Organization? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final logoCtrl = TextEditingController(text: existing?.logoAsset ?? '');
    final descCtrl = TextEditingController(text: existing?.shortDesc ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Add Organization' : 'Edit Organization'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: logoCtrl,
              decoration: const InputDecoration(labelText: 'Logo Asset (path)'),
            ),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Short Description'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: tealHeader, foregroundColor: Colors.white),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final logo = logoCtrl.text.trim();
              final desc = descCtrl.text.trim();
              if (name.isEmpty) return;
              if (existing == null) {
                AppState.instance.addOrganization(name: name, logoAsset: logo, shortDesc: desc);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added $name')),
                );
              } else {
                AppState.instance.updateOrganization(
                  existing.copyWith(name: name, logoAsset: logo, shortDesc: desc),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Updated $name')),
                );
              }
              Navigator.pop(context);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }
}

