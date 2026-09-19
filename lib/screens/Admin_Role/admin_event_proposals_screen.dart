import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin / CSO review screen for activity proposals forwarded by advisers.
///
/// Workflow:
/// Officer -> Adviser -> Admin/CSO -> Officer creates final creative -> Adviser.
class AdminEventProposalsScreen extends StatefulWidget {
  const AdminEventProposalsScreen({super.key});

  @override
  State<AdminEventProposalsScreen> createState() =>
      _AdminEventProposalsScreenState();
}

class _AdminEventProposalsScreenState extends State<AdminEventProposalsScreen> {
  static const Color green = Color(0xFF16A34A);
  static const Color background = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);

  final SupabaseClient _db = Supabase.instance.client;
  final List<Map<String, dynamic>> _requests = <Map<String, dynamic>>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final response = await _db
          .from('event_requests')
          .select('*')
          .eq('status', 'forwarded_to_admin')
          .order('created_at', ascending: false);

      final rows = List<Map<String, dynamic>>.from(response as List);

      if (!mounted) return;
      setState(() {
        _requests
          ..clear()
          ..addAll(rows);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Unable to load proposals: $error', error: true);
    }
  }

  Future<void> _reviewProposal(
    Map<String, dynamic> proposal, {
    required bool approve,
  }) async {
    final feedbackController = TextEditingController();

    if (!approve) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Return Proposal'),
          content: TextField(
            controller: feedbackController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Reason / requested changes',
              hintText: 'Explain what needs to be changed before approval.',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Return'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        feedbackController.dispose();
        return;
      }
    }

    try {
      final userId = _db.auth.currentUser?.id;
      final status = approve ? 'admin_approved' : 'admin_rejected';
      final feedback = feedbackController.text.trim();

      await _db.from('event_requests').update({
        'status': status,
        'admin_feedback': feedback,
        'admin_reviewed_at': DateTime.now().toIso8601String(),
        'reviewed_by': userId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', proposal['id']);

      await _sendNotification(
        orgId: proposal['org_id']?.toString(),
        title: approve
            ? 'Proposal Approved by Admin / CSO'
            : 'Proposal Returned by Admin / CSO',
        message: approve
            ? 'The proposal "${proposal['title'] ?? 'Activity'}" was approved. Officers may now prepare the final creative.'
            : 'The proposal "${proposal['title'] ?? 'Activity'}" was returned for changes.',
      );

      if (!mounted) return;
      _showMessage(
        approve ? 'Proposal approved.' : 'Proposal returned to the adviser.',
      );
      await _loadRequests();
    } catch (error) {
      if (mounted) {
        _showMessage('Could not review proposal: $error', error: true);
      }
    } finally {
      feedbackController.dispose();
    }
  }

  Future<void> _sendNotification({
    required String? orgId,
    required String title,
    required String message,
  }) async {
    if (orgId == null || orgId.isEmpty) return;

    try {
      await _db.from('notifications').insert({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'title': title,
        'message': message,
        'date': DateTime.now().toIso8601String(),
        'read': false,
        'org_id': orgId,
        'student_id': null,
      });
    } catch (_) {
      // The proposal decision has already been saved. A notification failure
      // should not make the approval itself appear unsuccessful.
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : green,
      ),
    );
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'No target date';
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: green,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Activity Proposals'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadRequests,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRequests,
              child: _requests.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: const [
                        SizedBox(height: 120),
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: textMuted,
                        ),
                        SizedBox(height: 16),
                        Center(
                          child: Text(
                            'No proposals are waiting for Admin / CSO review.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(18),
                      itemCount: _requests.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        return _ProposalCard(
                          proposal: _requests[index],
                          onReturn: () => _reviewProposal(
                            _requests[index],
                            approve: false,
                          ),
                          onApprove: () => _reviewProposal(
                            _requests[index],
                            approve: true,
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.onReturn,
    required this.onApprove,
  });

  static const Color green = Color(0xFF16A34A);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);

  final Map<String, dynamic> proposal;
  final VoidCallback onReturn;
  final VoidCallback onApprove;

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'No target date';
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final title = proposal['title']?.toString().trim();
    final description = proposal['description']?.toString().trim();

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: green.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.assignment_outlined,
                    color: green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title == null || title.isEmpty ? 'Untitled proposal' : title,
                    style: const TextStyle(
                      color: textDark,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              description == null || description.isEmpty
                  ? 'No proposal details were provided.'
                  : description,
              style: const TextStyle(
                color: textMuted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: textMuted),
                const SizedBox(width: 6),
                Text(
                  _date(proposal['date']),
                  style: const TextStyle(
                    color: textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReturn,
                    icon: const Icon(Icons.undo_rounded),
                    label: const Text('Return'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade200),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
