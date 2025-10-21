import 'package:flutter/material.dart';
import '../../core/app_state.dart';

class OfficerEventsScreen extends StatelessWidget {
  final String orgId;
  final String orgName;

  const OfficerEventsScreen({
    Key? key,
    required this.orgId,
    required this.orgName,
  }) : super(key: key);

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
          'Events',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.0),
        ),
        centerTitle: true,
      ),
      body: AnimatedBuilder(
        animation: AppState.instance,
        builder: (context, _) {
          final events = AppState.instance.events.where((e) => e.orgId == orgId || e.orgName == orgName).toList();
          if (events.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('No events yet. Tap + to add.', style: TextStyle(fontSize: 14)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final e = events[index];
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
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: tealHeader, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.event_available_outlined, color: Colors.white),
                  ),
                  title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${e.orgName} • ${_dateLabel(e.date)}\n${e.description}'),
                  isThreeLine: true,
                  onTap: () => _showEventDialog(context, existing: e),
                  trailing: IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () {
                      AppState.instance.removeEvent(e.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Removed ${e.title}')),
                      );
                    },
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
        onPressed: () => _showEventDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _dateLabel(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void _showEventDialog(BuildContext context, {Event? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final dateCtrl = TextEditingController(text: existing != null ? _dateLabel(existing.date) : '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');

    DateTime? selected = existing?.date;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? 'Add Event' : 'Edit Event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: dateCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selected ?? now,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 3),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(primary: tealHeader),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setState(() {
                        selected = picked;
                        dateCtrl.text = _dateLabel(picked);
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: tealHeader, foregroundColor: Colors.white),
              onPressed: () {
                final title = titleCtrl.text.trim();
                final desc = descCtrl.text.trim();
                final date = selected ?? DateTime.now();
                if (title.isEmpty) return;
                if (existing == null) {
                  AppState.instance.addEvent(title: title, date: date, description: desc, orgName: orgName, orgId: orgId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added $title')),
                  );
                } else {
                  AppState.instance.updateEvent(
                    existing.copyWith(title: title, date: date, description: desc, orgName: orgName, orgId: orgId),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Updated $title')),
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
