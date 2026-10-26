import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_state.dart';

const Color _impactGreen = Color(0xFF059669);
const Color _impactGreenDark = Color(0xFF047857);
const Color _impactGreenLight = Color(0xFFECFDF5);
const Color _impactBg = Color(0xFFF8FAFC);
const Color _impactInk = Color(0xFF0F172A);
const Color _impactMuted = Color(0xFF64748B);
const Color _cardBorder = Color(0xFFE2E8F0);

class StudentImpactScreen extends StatefulWidget {
  final String? organizationId;
  final String? organizationName;

  const StudentImpactScreen({
    super.key,
    this.organizationId,
    this.organizationName,
  });

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

  final Map<String, String> _questions = const <String, String>{
    'Academic':
        'How helpful has this organization been to you in your studies, learning, or academic skills?',
    'Social':
        'How helpful has this organization been to you in building friendships, communication, and a sense of belonging?',
    'Leadership':
        'How helpful has this organization been in developing your leadership, responsibility, and decision-making skills?',
    'Confidence':
        'How helpful has this organization been in building your confidence and personal growth?',
  };

  String? _orgId;

  bool _loadingOrgs = true;
  String? _orgsError;
  List<dynamic> _joinedOrgs = <dynamic>[];

  @override
  void initState() {
    super.initState();
    _loadJoinedOrgs();
  }

  Future<void> _loadJoinedOrgs() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _loadingOrgs = false;
        _orgsError = 'Please sign in again to send feedback.';
      });
      return;
    }

    setState(() {
      _loadingOrgs = true;
      _orgsError = null;
    });

    try {
      final rows = await Supabase.instance.client
          .from('members')
          .select('org_id')
          .eq('profile_id', user.id);

      final joinedIds = rows
          .map((r) => r['org_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      final joined = AppState.instance.organizations
          .where((o) => joinedIds.contains(o.id))
          .toList();

      String? selected;
      if (widget.organizationId != null &&
          joined.any((o) => o.id == widget.organizationId)) {
        selected = widget.organizationId;
      } else if (joined.isNotEmpty) {
        selected = joined.first.id;
      }

      if (!mounted) return;
      setState(() {
        _joinedOrgs = joined;
        _orgId = selected;
        _loadingOrgs = false;
      });
      if (selected != null) _loadImpact();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingOrgs = false;
        _orgsError = 'Could not load your organizations. Please try again.';
      });
    }
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

      if (!mounted) return;
      setState(() {
        if (row == null) {
          // No saved feedback for this org yet: reset to defaults
          for (final key in _scores.keys) {
            _scores[key] = 3;
          }
        } else {
          _scores['Academic'] = _normalizeScore(row['academic_growth']);
          _scores['Social'] = _normalizeScore(row['social_growth']);
          _scores['Leadership'] = _normalizeScore(row['leadership_growth']);
          _scores['Confidence'] = _normalizeScore(row['confidence_growth']);
        }
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
    return scaled.clamp(1, 5);
  }

  Future<void> _save() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _orgId == null) return;
    if (!_joinedOrgs.any((o) => o.id == _orgId)) return; // not a joined org

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
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                      'Your feedback was successfully sent to your adviser.'),
                ),
              ],
            ),
            backgroundColor: _impactGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Feedback could not be sent. Please check your connection.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final organizations = _joinedOrgs;
    final ratedCount = _scores.values.where((v) => v > 0).length;

    return Scaffold(
      backgroundColor: _impactBg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _PlainTitleHeader(
              title: 'Organization Feedback',
              onBack: () => Navigator.of(context).maybePop(),
            ),

            // Main Content Body
            Expanded(
              child: _loadingOrgs
                  ? const Center(
                      child: CircularProgressIndicator(color: _impactGreen),
                    )
                  : (_orgsError != null || organizations.isEmpty)
                      ? _EmptyOrgsState(
                          message: _orgsError ??
                              'You haven\'t joined any organization yet. Join an organization to share your feedback.',
                          showRetry: _orgsError != null,
                          onRetry: _loadJoinedOrgs,
                        )
                      : Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 680),
                            child: ListView(
                              physics: const BouncingScrollPhysics(),
                              padding:
                                  const EdgeInsets.fromLTRB(16, 16, 16, 32),
                              children: [
                                // Sub-header details moved directly below the header
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: _cardBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Share how your organization supports your growth.',
                                          style: TextStyle(
                                            color: _impactMuted,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: _impactGreenLight,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: const BoxDecoration(
                                                color: _impactGreen,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'EVALUATION',
                                              style: TextStyle(
                                                color: _impactGreen,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Target Organization Dropdown Picker
                                _OrganizationPicker(
                                  organizations: organizations,
                                  selectedId: _orgId,
                                  onChanged: (value) {
                                    setState(() => _orgId = value);
                                    _loadImpact();
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Assessment Summary Card
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: _cardBorder),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x0A0F172A),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: _impactGreenLight,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                            Icons.rate_review_rounded,
                                            color: _impactGreen,
                                            size: 22),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Impact Assessment',
                                              style: TextStyle(
                                                color: _impactInk,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$ratedCount of ${_scores.length} categories evaluated',
                                              style: const TextStyle(
                                                color: _impactMuted,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: _impactGreenLight,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${(ratedCount / _scores.length * 100).toInt()}%',
                                          style: const TextStyle(
                                            color: _impactGreen,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Impact Cards List
                                ..._scores.entries.map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _ImpactCard(
                                      label: entry.key,
                                      value: entry.value,
                                      icon: _icons[entry.key] ??
                                          Icons.insights_rounded,
                                      question: _questions[entry.key] ??
                                          'How is this organization helping you?',
                                      onChanged: (value) => setState(
                                        () => _scores[entry.key] = value,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Submit Button
                                SizedBox(
                                  height: 52,
                                  child: FilledButton.icon(
                                    onPressed: _saving ? null : _save,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _impactGreen,
                                      foregroundColor: Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    icon: _saving
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : const Icon(Icons.send_rounded,
                                            size: 20),
                                    label: Text(
                                      _saving
                                          ? 'Submitting feedback...'
                                          : 'Submit feedback',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// Clean, flat white header matching the requested style with black back chevron
class _PlainTitleHeader extends StatelessWidget {
  const _PlainTitleHeader({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(bottom: BorderSide(color: _cardBorder)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.only(
            top: pad.top + 4,
            left: pad.left + 4,
            right: pad.right + 16,
            bottom: 8,
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: onBack,
                icon: const Icon(Icons.chevron_left_rounded,
                    color: Colors.black, size: 32),
              ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _impactInk,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrganizationPicker extends StatelessWidget {
  final List<dynamic> organizations;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _OrganizationPicker({
    required this.organizations,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final validSelectedId =
        organizations.any((org) => org.id == selectedId) ? selectedId : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        initialValue: validSelectedId,
        isExpanded: true,
        dropdownColor: Colors.white,
        decoration: const InputDecoration(
          labelText: 'Target Organization',
          labelStyle: TextStyle(
            color: _impactMuted,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          prefixIcon: Icon(Icons.business_rounded, color: _impactGreen),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
        items: organizations
            .map(
              (organization) => DropdownMenuItem<String>(
                value: organization.id as String,
                child: Text(
                  organization.name as String,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _impactInk,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _impactGreenLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _impactGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: _impactInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _impactGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$value / 5',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            question,
            style: const TextStyle(
              color: _impactInk,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                '1 = Not helpful',
                style: TextStyle(
                  color: _impactMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '5 = Extremely helpful',
                style: TextStyle(
                  color: _impactMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              final number = i + 1;
              final selected = number == value;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 4 ? 0 : 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onChanged(number),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? _impactGreen : _impactBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? _impactGreen : _cardBorder,
                            width: selected ? 1.5 : 1,
                          ),
                          boxShadow: selected
                              ? const [
                                  BoxShadow(
                                    color: Color(0x1A059669),
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          '$number',
                          style: TextStyle(
                            color: selected ? Colors.white : _impactInk,
                            fontSize: 15,
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
        ],
      ),
    );
  }
}

class _EmptyOrgsState extends StatelessWidget {
  const _EmptyOrgsState({
    required this.message,
    required this.showRetry,
    required this.onRetry,
  });

  final String message;
  final bool showRetry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _impactGreenLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.groups_rounded,
                  color: _impactGreen, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _impactMuted,
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (showRetry) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
