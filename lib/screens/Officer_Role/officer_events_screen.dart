import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_state.dart';

// Shared proposal-screen palette. Kept at file scope so all proposal widgets
// can use the same constants, including widgets declared outside the state class.
const green = Color(0xFF128058);
const primary = Color(0xFF16A34A);
const bg = Color(0xFFE6F7EE);
const dark = Color(0xFF073B2A);
const muted = Color(0xFF4D6F62);
const line = Color(0xFFB9E4CF);

class OfficerEventsScreen extends StatefulWidget {
  final String orgId;
  final String orgName;
  final String logoAsset;
  final bool embedded;

  const OfficerEventsScreen({
    super.key,
    required this.orgId,
    required this.orgName,
    this.logoAsset = '',
    this.embedded = false,
  });

  @override
  State<OfficerEventsScreen> createState() => _OfficerEventsScreenState();
}

class _OfficerEventsScreenState extends State<OfficerEventsScreen> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _requests = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _canSubmitProposals = false;
  static const _finalBriefMarker = '[ADVISER_FINAL_LAYOUT_REQUESTED]';

  @override
  void initState() {
    super.initState();
    _load();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    try {
      final userId = _db.auth.currentUser?.id;
      if (userId == null) return;
      final row = await _db
          .from('members')
          .select('position')
          .eq('org_id', widget.orgId)
          .eq('profile_id', userId)
          .maybeSingle();
      final position = row?['position']?.toString().toLowerCase().trim() ?? '';
      if (!mounted) return;
      setState(() {
        _canSubmitProposals = position == 'president' || position == 'vice president';
      });
    } catch (_) {
      if (mounted) setState(() => _canSubmitProposals = false);
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final rows = await _db
          .from('event_requests')
          .select('*')
          .eq('org_id', widget.orgId)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _requests = List<Map<String, dynamic>>.from(rows as List);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Unable to load proposals: $e', true);
    }
  }

  Future<void> _createRequest() async {
    if (!_canSubmitProposals) { _snack('Only the President or Vice President can send proposals to the adviser.', true); return; }
    final title = TextEditingController();
    final desc = TextEditingController();
    DateTime selected = DateTime.now().add(const Duration(days: 1));

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: green),
              SizedBox(width: 10),
              Text('New Activity Proposal', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: InputDecoration(
                    labelText: 'Proposed activity',
                    hintText: 'Intramurals Opening Program',
                    prefixIcon: const Icon(Icons.event_note_rounded),
                    filled: true,
                    fillColor: const Color(0xFFF5FFF9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: desc,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Proposal details',
                    hintText: 'Explain the purpose, participants, venue, and needed resources.',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 62),
                      child: Icon(Icons.description_rounded),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5FFF9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  tileColor: const Color(0xFFF5FFF9),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFDDF4E8),
                    child: Icon(Icons.calendar_today_rounded, color: green, size: 19),
                  ),
                  title: const Text('Target date', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(_date(selected)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selected,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) ss(() => selected = picked);
                  },
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Submit Proposal'),
              style: FilledButton.styleFrom(
                backgroundColor: green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );

    final cleanTitle = title.text.trim();
    final cleanDesc = desc.text.trim();
    title.dispose();
    desc.dispose();

    if (result != true || cleanTitle.isEmpty || cleanDesc.isEmpty) return;

    try {
      final now = DateTime.now();
      final requestId = DateTime.now().microsecondsSinceEpoch.toString();
      await _db.from('event_requests').insert({
        'id': requestId,
        'org_id': widget.orgId,
        'requested_by': _db.auth.currentUser?.id,
        'title': cleanTitle,
        'date': selected.toIso8601String(),
        'description': cleanDesc,
        'purpose': cleanDesc,
        'venue': '',
        'start_time': '',
        'end_time': '',
        'image_urls': <String>[],
        'creative_urls': <String>[],
        'status': 'pending',
        'submitted_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      try {
        await _db.from('notifications').insert({'id': DateTime.now().microsecondsSinceEpoch.toString(), 'title': 'New Activity Proposal', 'message': '$cleanTitle was submitted by the officer for adviser review.', 'date': now.toIso8601String(), 'read': false, 'org_id': widget.orgId, 'student_id': null});
      } catch (_) {}
      _snack('Proposal sent to the adviser.');
      await _load();
    } catch (e) {
      _snack('Could not submit proposal: $e', true);
    }
  }

  String _time24(TimeOfDay value) => '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Future<void> _submitCreative(Map<String, dynamic> request) async {
    if (!_canSubmitProposals) { _snack('Only the President or Vice President can send proposals to the adviser.', true); return; }
    final activityName = TextEditingController(text: request['title']?.toString() ?? '');
    final venue = TextEditingController(text: request['venue']?.toString() ?? '');
    final purpose = TextEditingController(text: request['purpose']?.toString() ?? '');
    var selected = DateTime.tryParse('${request['date'] ?? ''}') ?? DateTime.now().add(const Duration(days: 1));
    final start = TextEditingController(text: request['start_time']?.toString() ?? '');
    final end = TextEditingController(text: request['end_time']?.toString() ?? '');

    final detailsOk = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(children: [Icon(Icons.auto_awesome_rounded, color: green), SizedBox(width: 9), Text('Prepare Final Posting', style: TextStyle(fontWeight: FontWeight.w900))]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: activityName, decoration: const InputDecoration(labelText: 'Activity name', border: OutlineInputBorder())),
              const SizedBox(height: 11),
              TextField(controller: purpose, maxLines: 3, decoration: const InputDecoration(labelText: 'What is the event about?', border: OutlineInputBorder())),
              const SizedBox(height: 11),
              TextField(controller: venue, decoration: const InputDecoration(labelText: 'Venue', border: OutlineInputBorder())),
              const SizedBox(height: 11),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Event date', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${selected.month}/${selected.day}/${selected.year}'),
                trailing: const Icon(Icons.calendar_month_rounded, color: green),
                onTap: () async {
                  final minDate = DateTime.now();
                  final initial = selected.isBefore(minDate) ? minDate : selected;
                  final picked = await showDatePicker(
                    context: dialogContext,
                    initialDate: initial,
                    firstDate: minDate,
                    lastDate: minDate.add(const Duration(days: 365)),
                  );
                  if (picked != null) setDialogState(() => selected = picked);
                },
              ),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: TextField(controller: start, readOnly: true, onTap: () async { final picked = await showTimePicker(context: dialogContext, initialTime: TimeOfDay.now()); if (picked != null) setDialogState(() => start.text = _time24(picked)); }, decoration: const InputDecoration(labelText: 'Start time', suffixIcon: Icon(Icons.schedule_rounded)))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: end, readOnly: true, onTap: () async { final picked = await showTimePicker(context: dialogContext, initialTime: TimeOfDay.now()); if (picked != null) setDialogState(() => end.text = _time24(picked)); }, decoration: const InputDecoration(labelText: 'End time', suffixIcon: Icon(Icons.schedule_rounded)))),
              ]),
              const SizedBox(height: 12),
              const Align(alignment: Alignment.centerLeft, child: Text('Add the event picture(s) next.', style: TextStyle(color: muted, fontSize: 11.5, fontWeight: FontWeight.w600))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton.icon(onPressed: () => Navigator.pop(dialogContext, true), icon: const Icon(Icons.photo_library_rounded, size: 17), label: const Text('Choose Pictures'), style: FilledButton.styleFrom(backgroundColor: green)),
          ],
        ),
      ),
    );
    final activityNameValue = activityName.text.trim();
    final venueValue = venue.text.trim();
    final purposeValue = purpose.text.trim();
    final startValue = start.text.trim();
    final endValue = end.text.trim();
    activityName.dispose();
    venue.dispose();
    purpose.dispose();
    start.dispose();
    end.dispose();
    if (detailsOk != true) return;
    if (activityNameValue.isEmpty || venueValue.isEmpty || purposeValue.isEmpty || startValue.isEmpty) {
      _snack('Please provide the activity name, purpose, venue, and start time.', true);
      return;
    }

    final files = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (files == null || files.files.isEmpty) return;

    final urls = <String>[];
    try {
      for (final file in files.files) {
        if (file.bytes == null) continue;
        final ext = file.extension ?? 'jpg';
        final path = 'event_creatives/${widget.orgId}/${request['id']}_${DateTime.now().microsecondsSinceEpoch}.$ext';
        await _db.storage.from('org-assets').uploadBinary(path, file.bytes!, fileOptions: FileOptions(contentType: 'image/$ext', upsert: true));
        urls.add(_db.storage.from('org-assets').getPublicUrl(path));
      }
      if (urls.isEmpty) return;
      final now = DateTime.now();
      await _db.from('event_requests').update({
        'title': activityNameValue,
        'creative_urls': urls,
        'venue': venueValue,
        'purpose': purposeValue,
        'date': selected.toIso8601String(),
        'start_time': startValue,
        'end_time': endValue,
        'status': 'creative_submitted',
        'submitted_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      }).eq('id', request['id']);
      try {
        await _db.from('notifications').insert({'id': DateTime.now().microsecondsSinceEpoch.toString(), 'title': 'Final Posting Sent to Adviser', 'message': '${request['title'] ?? 'Activity Proposal'} now has the final pictures, venue, purpose, and time details for adviser review.', 'date': now.toIso8601String(), 'read': false, 'org_id': widget.orgId, 'student_id': null});
      } catch (_) {}
      _snack('Final posting sent to the adviser for review.');
      await _load();
    } catch (e) {
      _snack('Could not upload the final posting: $e', true);
    }
  }

  Future<void> _editProposal(Map<String, dynamic> request) async {
    final title = TextEditingController(text: request['title']?.toString() ?? '');
    final desc = TextEditingController(text: request['description']?.toString() ?? '');
    final purpose = TextEditingController(text: request['purpose']?.toString() ?? '');
    final venue = TextEditingController(text: request['venue']?.toString() ?? '');
    var selected = DateTime.tryParse('${request['date'] ?? ''}') ?? DateTime.now().add(const Duration(days: 1));
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Revise Activity Proposal', style: TextStyle(fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Activity title', border: OutlineInputBorder())),
            const SizedBox(height: 11),
            TextField(controller: purpose, maxLines: 3, decoration: const InputDecoration(labelText: 'What is the event about?', border: OutlineInputBorder())),
            const SizedBox(height: 11),
            TextField(controller: desc, maxLines: 5, decoration: const InputDecoration(labelText: 'Proposal details', border: OutlineInputBorder())),
            const SizedBox(height: 11),
            TextField(controller: venue, decoration: const InputDecoration(labelText: 'Venue (optional)', border: OutlineInputBorder())),
            const SizedBox(height: 4),
            ListTile(contentPadding: EdgeInsets.zero, title: const Text('Target date', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${selected.month}/${selected.day}/${selected.year}'), trailing: const Icon(Icons.calendar_month_rounded, color: green), onTap: () async { final minDate = DateTime.now(); final initial = selected.isBefore(minDate) ? minDate : selected; final picked = await showDatePicker(context: dialogContext, initialDate: initial, firstDate: minDate, lastDate: minDate.add(const Duration(days: 365))); if (picked != null) setDialogState(() => selected = picked); }),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Send Revised Proposal'))],
        ),
      ),
    );
    final values = [title.text.trim(), purpose.text.trim(), desc.text.trim(), venue.text.trim()];
    title.dispose(); desc.dispose(); purpose.dispose(); venue.dispose();
    if (ok != true || values[0].isEmpty || values[2].isEmpty || values[1].isEmpty) { _snack('Please complete the revised proposal.', true); return; }
    try {
      final now = DateTime.now();
      await _db.from('event_requests').update({'title': values[0], 'purpose': values[1], 'description': values[2], 'venue': values[3], 'date': selected.toIso8601String(), 'status': 'pending', 'feedback': '', 'submitted_at': now.toIso8601String(), 'updated_at': now.toIso8601String()}).eq('id', request['id']);
      try { await _db.from('notifications').insert({'id': DateTime.now().microsecondsSinceEpoch.toString(), 'title': 'Revised Proposal Submitted', 'message': '${values[0]} was revised by the officer and sent back to the adviser.', 'date': now.toIso8601String(), 'read': false, 'org_id': widget.orgId, 'student_id': null}); } catch (_) {}
      _snack('Revised proposal sent to the adviser.');
      await _load();
    } catch (e) { _snack('Could not update the proposal: $e', true); }
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse('${value ?? ''}');
    if (date == null) return 'No date';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.year}-$month-$day • $hour:$minute $suffix';
  }

  void _snack(String text, [bool error = false]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? Colors.red : green),
    );
  }

  Widget _buildContent() {
    return SafeArea(
      bottom: false,
      child: Column(
          children: [
            _ActivityHeader(
              orgName: widget.orgName,
              orgId: widget.orgId,
              logoAsset: widget.logoAsset,
            ),
            Expanded(
              child: RefreshIndicator(
                color: green,
                onRefresh: _load,
                child: _loading
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 190),
                          Center(child: CircularProgressIndicator(color: green)),
                        ],
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
                        children: [
                          _IntroCard(orgName: widget.orgName),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Your Proposals',
                                style: TextStyle(
                                  color: dark,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -.3,
                                ),
                              ),
                              if (_requests.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDDF4E8),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Text(
                                    '${_requests.length} total',
                                    style: const TextStyle(color: green, fontSize: 11, fontWeight: FontWeight.w800),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_requests.isEmpty)
                            const _EmptyProposals()
                          else
                            ..._requests.map(_card),
                        ],
                      ),
              ),
            ),
          ],
        ),
    );
  }

  Widget? _buildFab() {
    // Only the President and Vice President can create proposals. Other roles
    // can still view existing proposals, but should not see the New Proposal button.
    if (!_canSubmitProposals) return null;
    return FloatingActionButton.extended(
      backgroundColor: green,
      foregroundColor: Colors.white,
      elevation: 8,
      onPressed: _canSubmitProposals ? _createRequest : null,
      icon: const Icon(Icons.add_rounded),
      label: const Text('New Proposal', style: TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Stack(
        children: [
          _buildContent(),
          if (_canSubmitProposals)
            Positioned(
              right: 16,
              bottom: 16,
              child: _buildFab()!,
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: _buildContent(),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _card(Map<String, dynamic> request) {
    final status = request['status']?.toString() ?? 'pending';
    final images = (request['creative_urls'] is List ? request['creative_urls'] : <dynamic>[])
        .whereType<String>()
        .toList();

    final hasCreative = images.isNotEmpty;
    final hasAdviserBrief = (request['feedback']?.toString() ?? '').contains(_finalBriefMarker);
    final isWaitingForAdviser = status == 'admin_approved' && !hasAdviserBrief;
    final isReady = (status == 'admin_approved' && hasAdviserBrief) || (status == 'revision_requested' && hasCreative);
    final needsProposalRevision = status == 'revision_requested' && !hasCreative;
    final isRejected = status == 'rejected' || status == 'admin_rejected';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D128058),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F7EE),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        'ACTIVITY PROPOSAL',
                        style: TextStyle(color: green, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .7),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      request['title']?.toString() ?? 'Untitled proposal',
                      style: const TextStyle(color: dark, fontSize: 18, fontWeight: FontWeight.w900, height: 1.15),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _statusChip(status, hasAdviserBrief: hasAdviserBrief),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded, size: 17, color: green),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _date(request['date']),
                  style: const TextStyle(color: muted, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            request['description']?.toString() ?? '',
            style: const TextStyle(color: muted, fontSize: 13, height: 1.5, fontWeight: FontWeight.w500),
          ),
          if ((request['feedback'] ?? '').toString().replaceAll(_finalBriefMarker, '').trim().isNotEmpty) ...[
            const SizedBox(height: 13),
            _feedbackBox('Adviser feedback / instructions', request['feedback'].toString().replaceAll(_finalBriefMarker, '').trim(), Colors.orange),
          ],
          if ((request['admin_feedback'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 9),
            _feedbackBox('Admin / CSO feedback', request['admin_feedback'].toString(), Colors.red),
          ],
          if (images.isNotEmpty) ...[
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: images.length == 1 ? 190 : 178,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      itemCount: images.length,
                      itemBuilder: (_, index) => Image.network(
                        images[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFE6F7EE),
                          child: const Icon(
                            Icons.image_not_supported_rounded,
                            color: green,
                          ),
                        ),
                      ),
                    ),
                    if (images.length > 1)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xB3128058),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${images.length} pictures',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (needsProposalRevision) ...[
            const SizedBox(height: 14),
            Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: .07), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.orange.withValues(alpha: .15))), child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.edit_note_rounded, color: Colors.orange, size: 17), SizedBox(width: 7), Expanded(child: Text('The adviser requested changes to the proposal. Revise it and send it back to the adviser.', style: TextStyle(color: dark, fontSize: 11.5, height: 1.4, fontWeight: FontWeight.w600)))])),
          ],
          if (isWaitingForAdviser) ...[
            const SizedBox(height: 14),
            const _StatusNote(icon: Icons.schedule_rounded, text: 'Waiting for your adviser to tell the team in Community Chat when to prepare the final event post.'),
          ],
          if (isReady) ...[
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _canSubmitProposals ? () => _submitCreative(request) : null,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  hasCreative ? 'Improve & Resubmit Final Posting' : 'Create & Send Final Posting',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
          ],
          if (needsProposalRevision || isRejected) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _canSubmitProposals ? () => _editProposal(request) : null,
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text('Revise Proposal & Send to Adviser'),
                style: FilledButton.styleFrom(backgroundColor: green, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              ),
            ),
          ],
          if (isRejected) ...[
            const SizedBox(height: 12),
            Row(
              children: const [
                Icon(Icons.info_outline_rounded, size: 17, color: Colors.red),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'This proposal was not approved. Review the feedback above before submitting a new proposal.',
                    style: TextStyle(color: Colors.red, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _feedbackBox(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.feedback_rounded, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(color: dark, fontSize: 12, height: 1.4, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status, {bool hasAdviserBrief = false}) {
    final Color color;
    if (status == 'admin_approved' || status == 'creative_submitted') {
      color = green;
    } else if (status == 'admin_rejected' || status == 'rejected') {
      color = Colors.red;
    } else if (status == 'revision_requested') {
      color = Colors.orange;
    } else {
      color = primary;
    }

    final label = status == 'pending'
        ? 'WAITING FOR ADVISER'
        : status == 'admin_approved'
            ? (hasAdviserBrief ? 'READY FOR FINAL POSTING' : 'WAITING FOR ADVISER')
            : status == 'forwarded_to_admin'
                ? 'WAITING FOR ADMIN / CSO'
                : status == 'creative_submitted'
                    ? 'FINAL POSTING SENT TO ADVISER'
                    : status.replaceAll('_', ' ').toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: .16)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: .3),
      ),
    );
  }
}

class _ActivityHeader extends StatelessWidget {
  final String orgName;
  final String orgId;
  final String logoAsset;

  const _ActivityHeader({
    required this.orgName,
    required this.orgId,
    this.logoAsset = '',
  });

  Widget _orb(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .07),
        ),
      );

  Widget _logo(String path) {
    if (path.isEmpty) {
      return const Icon(Icons.business_rounded, color: green, size: 31);
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: 58,
        height: 58,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.business_rounded, color: green, size: 31),
      );
    }
    return Image.asset(
      path,
      width: 58,
      height: 58,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Icon(Icons.business_rounded, color: green, size: 31),
    );
  }

  @override
  Widget build(BuildContext context) {
    final org = AppState.instance.organizations.cast<Organization?>().firstWhere(
          (item) => item?.id == orgId,
          orElse: () => null,
        );
    final logo = logoAsset.trim().isNotEmpty
        ? logoAsset.trim()
        : (org?.logoAsset.trim() ?? '');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF064E3B), Color(0xFF128058), Color(0xFF22C55E)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Stack(
        children: [
          Positioned(right: -45, top: -70, child: _orb(170)),
          Positioned(right: 45, bottom: -70, child: _orb(125)),
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .20),
                ),
                child: Container(
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  padding: const EdgeInsets.all(3),
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFFE0F5E8),
                    child: ClipOval(child: _logo(logo)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Activity Proposals',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: -.7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      orgName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .86),
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(color: Color(0xFF86EFAC), shape: BoxShape.circle),
                          child: SizedBox(width: 9, height: 9),
                        ),
                        SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            'OFFICER ORGANIZATION HUB',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: .5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusNote extends StatelessWidget {
  final IconData icon;
  final String text;

  const _StatusNote({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 1),
          Icon(icon, color: green, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: dark,
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  final String orgName;
  const _IntroCard({required this.orgName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FFFB), Color(0xFFDDF4E8)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: line),
        boxShadow: const [
          BoxShadow(color: Color(0x0A128058), blurRadius: 18, offset: Offset(0, 7)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .72),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.lightbulb_rounded, color: green, size: 25),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Plan it. Send it. Improve it.', style: TextStyle(color: dark, fontSize: 15.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  'Submit polished activity proposals for $orgName and keep every adviser review in one place.',
                  style: const TextStyle(color: muted, fontSize: 11.5, height: 1.45, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyProposals extends StatelessWidget {
  const _EmptyProposals();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: line),
        boxShadow: const [BoxShadow(color: Color(0x0A128058), blurRadius: 18, offset: Offset(0, 7))],
      ),
      child: Column(
        children: const [
          Icon(Icons.auto_awesome_rounded, color: green, size: 34),
          SizedBox(height: 10),
          Text('No proposals yet', style: TextStyle(color: dark, fontSize: 15, fontWeight: FontWeight.w900)),
          SizedBox(height: 5),
          Text(
            'Your submitted activity proposals will appear here with adviser feedback and creative status.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 11.5, height: 1.45, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
