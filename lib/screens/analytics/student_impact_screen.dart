import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_state.dart';
import '../../widgets/app_header.dart';

const _impactGreen = Color(0xFF16A34A);
const _impactTeal = Color(0xFF0F766E);
const _impactBg = Color(0xFFF1F5F9);
const _impactInk = Color(0xFF0F172A);
const _impactMuted = Color(0xFF64748B);

class StudentImpactScreen extends StatefulWidget {
  final String? organizationId;
  final String? organizationName;

  const StudentImpactScreen(
      {super.key, this.organizationId, this.organizationName});

  @override
  State<StudentImpactScreen> createState() => _StudentImpactScreenState();
}

class _StudentImpactScreenState extends State<StudentImpactScreen> {
  bool _saving = false;
  final Map<String, int> _scores = <String, int>{
    'Academic': 3,
    'Social': 3,
    'Leadership': 3,
    'Confidence': 3,
  };
  final Map<String, IconData> _icons = const <String, IconData>{
    'Academic': Icons.school_rounded,
    'Social': Icons.groups_rounded,
    'Leadership': Icons.workspace_premium_rounded,
    'Confidence': Icons.auto_awesome_rounded,
  };
  String? _orgId;
  final Map<String, String> _questions = const {
    'Academic':
        'How helpful has this organization been to you in your studies, learning, or academic skills?',
    'Social':
        'How helpful has this organization been to you in building friendships, communication, and a sense of belonging?',
    'Leadership':
        'How helpful has this organization been in developing your leadership, responsibility, and decision-making skills?',
    'Confidence':
        'How helpful has this organization been in building your confidence and personal growth?',
  };

  @override
  void initState() {
    super.initState();
    _orgId = widget.organizationId ??
        (AppState.instance.organizations.isNotEmpty
            ? AppState.instance.organizations.first.id
            : null);
    if (_orgId != null) _loadImpact();
  }

  Future<void> _loadImpact() async {
    final user = Supabase.instance.client.auth.currentUser;
    final orgId = _orgId;
    if (user == null || orgId == null) return;
    try {
      final row = await Supabase.instance.client
          .from('student_impact')
          .select(
              'academic_growth,social_growth,leadership_growth,confidence_growth')
          .eq('student_id', user.id)
          .eq('org_id', orgId)
          .maybeSingle();
      if (!mounted || row == null) return;
      setState(() {
        _scores['Academic'] = _normalizeScore(row['academic_growth']);
        _scores['Social'] = _normalizeScore(row['social_growth']);
        _scores['Leadership'] = _normalizeScore(row['leadership_growth']);
        _scores['Confidence'] = _normalizeScore(row['confidence_growth']);
      });
    } catch (_) {}
  }

  int _normalizeScore(dynamic value) {
    final n = value is num
        ? value.round()
        : int.tryParse(value?.toString() ?? '') ?? 3;
    if (n >= 1 && n <= 5) return n;
    if (n <= 0) return 1;
    final scaled = (n / 20).round();
    if (scaled < 1) return 1;
    if (scaled > 5) return 5;
    return scaled;
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
          const SnackBar(
            content: Text(
                'Impact tracking is not enabled yet. Run the included Supabase migration.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final organizations = AppState.instance.organizations;

    return Scaffold(
      backgroundColor: _impactBg,
      body: Column(
        children: [
          AppHeader(
            title: 'My Impact',
            subtitle: 'How is your organization helping you?',
            status: 'RATE FROM 1 TO 5',
            icon: Icons.insights_rounded,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
              children: [
                _OrganizationPicker(
                  organizations: organizations,
                  selectedId: _orgId,
                  onChanged: (value) {
                    setState(() => _orgId = value);
                    _loadImpact();
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'How helpful has this organization been to you?',
                  style: TextStyle(
                    color: _impactInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Rate each area from 1 to 5. 1 means the organization has not been helpful in this area; 5 means it has been extremely helpful.',
                  style: TextStyle(
                      color: _impactMuted, fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 13),
                // Keep every impact area in its own full-width card so the
                // Academic, Social, Leadership, and Confidence ratings are
                // clearly separated and easy to complete one at a time.
                ..._scores.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ImpactCard(
                      label: entry.key,
                      value: entry.value,
                      icon: _icons[entry.key] ?? Icons.insights_rounded,
                      question: _questions[entry.key] ??
                          'How is this organization helping you?',
                      onChanged: (value) => setState(
                        () => _scores[entry.key] = value,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: _impactGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.check_circle_rounded),
                    label: const Text(
                      'Save my impact',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _ImpactHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    const headerHeight = 138.0;
    return SizedBox(
      height: headerHeight,
      width: double.infinity,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_impactGreen, _impactTeal],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -45,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .07),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: -35,
              bottom: -55,
              child: Container(
                width: 115,
                height: 115,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Back',
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 21),
                    ),
                  ),
                  const SizedBox(
                    height: headerHeight,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(64, 12, 28, 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'How is your organization helping you?',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800),
                            ),
                            SizedBox(height: 6),
                            Text(
                              '1 = Not helpful  •  5 = Extremely helpful',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.5,
                                  height: 1.3,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrganizationPicker extends StatelessWidget {
  final List<Organization> organizations;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  const _OrganizationPicker({
    required this.organizations,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 7, 15, 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE7E1)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A0F172A), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: DropdownButtonFormField<String>(
        initialValue: selectedId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Organization',
          prefixIcon: Icon(Icons.groups_rounded, color: _impactGreen),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
        items: organizations
            .map(
              (organization) => DropdownMenuItem<String>(
                value: organization.id,
                child: Text(
                  organization.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _impactInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: organizations.isEmpty ? null : onChanged,
      ),
    );
  }
}

class _ImpactCard extends StatelessWidget {
  final String label;
  final String question;
  final int value;
  final IconData icon;
  final ValueChanged<int> onChanged;
  const _ImpactCard({
    required this.label,
    required this.question,
    required this.value,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE5F8F0), Color(0xFFD2F0E4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFBFE5D2)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A0F8A61), blurRadius: 18, offset: Offset(0, 7))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: const Color(0xFFE8F7EE),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: _impactGreen, size: 22)),
          const SizedBox(width: 11),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: _impactInk,
                      fontSize: 16,
                      fontWeight: FontWeight.w900))),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: _impactGreen,
                  borderRadius: BorderRadius.circular(999)),
              child: Text('$value / 5',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 13),
        Text(question,
            style: const TextStyle(
                color: _impactInk,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
          Text('1 = Not helpful',
              style: TextStyle(
                  color: _impactMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700)),
          Text('5 = Extremely helpful',
              style: TextStyle(
                  color: _impactMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 9),
        Row(
          children: List.generate(5, (i) {
            final number = i + 1;
            final selected = number == value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == 4 ? 0 : 7),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onChanged(number),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color:
                            selected ? _impactGreen : const Color(0xFFF8FCF9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              selected ? _impactGreen : const Color(0xFFD8E6DC),
                          width: selected ? 1.5 : 1,
                        ),
                        boxShadow: selected
                            ? const [
                                BoxShadow(
                                    color: Color(0x1A16A34A),
                                    blurRadius: 8,
                                    offset: Offset(0, 3))
                              ]
                            : null,
                      ),
                      child: Text(
                        '$number',
                        style: TextStyle(
                          color: selected ? Colors.white : _impactInk,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ]),
    );
  }
}
