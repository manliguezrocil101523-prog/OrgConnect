import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_state.dart';

class StudentImpactScreen extends StatefulWidget {
  const StudentImpactScreen({super.key});

  @override
  State<StudentImpactScreen> createState() => _StudentImpactScreenState();
}

class _StudentImpactScreenState extends State<StudentImpactScreen> {
  bool _saving = false;
  final Map<String, int> _scores = <String, int>{
    'Academic': 50,
    'Social': 50,
    'Leadership': 50,
    'Confidence': 50,
  };
  String? _orgId;

  @override
  void initState() {
    super.initState();
    if (AppState.instance.organizations.isNotEmpty) {
      _orgId = AppState.instance.organizations.first.id;
    }
  }

  Future<void> _save() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _orgId == null) return;

    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from('student_impact').upsert(
        {
          'student_id': user.id,
          'org_id': _orgId,
          'academic_growth': _scores['Academic'],
          'social_growth': _scores['Social'],
          'leadership_growth': _scores['Leadership'],
          'confidence_growth': _scores['Confidence'],
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'student_id,org_id',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your organization impact was saved.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impact tracking is not enabled yet. Run the included Supabase migration.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final organizations = AppState.instance.organizations;

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0A140D) : const Color(0xFFF0FDF4),
      appBar: AppBar(title: const Text('My Organization Impact')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF166534), Color(0xFF22C55E)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How is your organization helping you?',
                  style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 6),
                Text(
                  'Rate your current growth. This becomes part of the finals analytics.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            value: _orgId,
            decoration: const InputDecoration(
              labelText: 'Organization',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
            ),
            items: organizations
                .map(
                  (organization) => DropdownMenuItem<String>(
                    value: organization.id,
                    child: Text(organization.name),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _orgId = value),
          ),
          const SizedBox(height: 14),
          ..._scores.entries.map((entry) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${entry.key}: ${entry.value}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Slider(
                      value: entry.value.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 10,
                      activeColor: const Color(0xFF16A34A),
                      onChanged: (value) => setState(() => _scores[entry.key] = value.round()),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Save impact'),
            ),
          ),
        ],
      ),
    );
  }
}
