import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
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

// Private tokens for the redesigned layout.
const _ink = Color(0xFF173B30);
const _sub = Color(0xFF55695F); // muted text, 5.9:1 on white
const _border = Color(0xFFE3ECE7);
const _mint = Color(0xFFE4F7EF);
const _skeleton = Color(0xFFEDF2F0);
const _cardDeco = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(16)),
  border: Border.fromBorderSide(BorderSide(color: _border)),
  boxShadow: [
    BoxShadow(color: Color(0x0D173B30), blurRadius: 8, offset: Offset(0, 2)),
  ],
);

enum _Filter { all, action, review, published }

typedef _Flags = ({
  String status,
  List<String> images,
  bool hasCreative,
  bool hasAdviserBrief,
  bool isWaitingForAdviser,
  bool isReady,
  bool needsProposalRevision,
  bool isRejected,
});

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
  bool _refreshing = false;
  bool _failed = false;
  bool _canSubmitProposals = false;
  bool _busy = false;
  _Filter _filter = _Filter.all;
  final Set<String> _expanded = <String>{};
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
        _canSubmitProposals =
            position == 'president' || position == 'vice president';
      });
    } catch (_) {
      if (mounted) setState(() => _canSubmitProposals = false);
    }
  }

  Future<void> _load() async {
    if (mounted && !_loading) setState(() => _refreshing = true);
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
        _refreshing = false;
        _failed = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _failed = true;
      });
      _snack('Unable to load proposals: $e', true);
    }
  }

  Future<void> _createRequest() async {
    if (!_canSubmitProposals) {
      _snack(
          'Only the President or Vice President can send proposals to the adviser.',
          true);
      return;
    }
    final title = TextEditingController();
    final desc = TextEditingController();
    DateTime selected = DateTime.now().add(const Duration(days: 1));

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: green),
              SizedBox(width: 10),
              Text('New Activity Proposal',
                  style: TextStyle(fontWeight: FontWeight.w900)),
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
                    hintText:
                        'Explain the purpose, participants, venue, and needed resources.',
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  tileColor: const Color(0xFFF5FFF9),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFDDF4E8),
                    child: Icon(Icons.calendar_today_rounded,
                        color: green, size: 19),
                  ),
                  title: const Text('Target date',
                      style: TextStyle(fontWeight: FontWeight.w800)),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
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
        await _db.from('notifications').insert({
          'id': DateTime.now().microsecondsSinceEpoch.toString(),
          'title': 'New Activity Proposal',
          'message':
              '$cleanTitle was submitted by the officer for adviser review.',
          'date': now.toIso8601String(),
          'read': false,
          'org_id': widget.orgId,
          'student_id': null
        });
      } catch (_) {}
      _snack('Proposal sent to the adviser.');
      await _load();
    } catch (e) {
      _snack('Could not submit proposal: $e', true);
    }
  }

  String _time24(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Future<void> _submitCreative(Map<String, dynamic> request) async {
    if (!_canSubmitProposals) {
      _snack(
          'Only the President or Vice President can send proposals to the adviser.',
          true);
      return;
    }
    final activityName =
        TextEditingController(text: request['title']?.toString() ?? '');
    final venue =
        TextEditingController(text: request['venue']?.toString() ?? '');
    final purpose =
        TextEditingController(text: request['purpose']?.toString() ?? '');
    var selected = DateTime.tryParse('${request['date'] ?? ''}') ??
        DateTime.now().add(const Duration(days: 1));
    final start =
        TextEditingController(text: request['start_time']?.toString() ?? '');
    final end =
        TextEditingController(text: request['end_time']?.toString() ?? '');

    final detailsOk = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(children: [
            Icon(Icons.auto_awesome_rounded, color: green),
            SizedBox(width: 9),
            Text('Prepare Final Posting',
                style: TextStyle(fontWeight: FontWeight.w900))
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: activityName,
                  decoration: const InputDecoration(
                      labelText: 'Activity name',
                      border: OutlineInputBorder())),
              const SizedBox(height: 11),
              TextField(
                  controller: purpose,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'What is the event about?',
                      border: OutlineInputBorder())),
              const SizedBox(height: 11),
              TextField(
                  controller: venue,
                  decoration: const InputDecoration(
                      labelText: 'Venue', border: OutlineInputBorder())),
              const SizedBox(height: 11),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Event date',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle:
                    Text('${selected.month}/${selected.day}/${selected.year}'),
                trailing:
                    const Icon(Icons.calendar_month_rounded, color: green),
                onTap: () async {
                  final minDate = DateTime.now();
                  final initial =
                      selected.isBefore(minDate) ? minDate : selected;
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
                Expanded(
                    child: TextField(
                        controller: start,
                        readOnly: true,
                        onTap: () async {
                          final picked = await showTimePicker(
                              context: dialogContext,
                              initialTime: TimeOfDay.now());
                          if (picked != null) {
                            setDialogState(() => start.text = _time24(picked));
                          }
                        },
                        decoration: const InputDecoration(
                            labelText: 'Start time',
                            suffixIcon: Icon(Icons.schedule_rounded)))),
                const SizedBox(width: 10),
                Expanded(
                    child: TextField(
                        controller: end,
                        readOnly: true,
                        onTap: () async {
                          final picked = await showTimePicker(
                              context: dialogContext,
                              initialTime: TimeOfDay.now());
                          if (picked != null) {
                            setDialogState(() => end.text = _time24(picked));
                          }
                        },
                        decoration: const InputDecoration(
                            labelText: 'End time',
                            suffixIcon: Icon(Icons.schedule_rounded)))),
              ]),
              const SizedBox(height: 12),
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Add the event picture(s) next.',
                      style: TextStyle(
                          color: muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600))),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.photo_library_rounded, size: 17),
                label: const Text('Choose Pictures'),
                style: FilledButton.styleFrom(backgroundColor: green)),
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
    if (activityNameValue.isEmpty ||
        venueValue.isEmpty ||
        purposeValue.isEmpty ||
        startValue.isEmpty) {
      _snack(
          'Please provide the activity name, purpose, venue, and start time.',
          true);
      return;
    }

    final files = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (files == null || files.files.isEmpty) return;

    if (_busy) return;
    _busy = true;
    final urls = <String>[];
    try {
      for (final file in files.files) {
        if (file.bytes == null) continue;
        final ext = (file.extension ?? 'jpg').toLowerCase();
        final contentType = ext == 'png'
            ? 'image/png'
            : ext == 'webp'
                ? 'image/webp'
                : ext == 'gif'
                    ? 'image/gif'
                    : 'image/jpeg';
        final path =
            'event_creatives/${widget.orgId}/${request['id']}_${DateTime.now().microsecondsSinceEpoch}.$ext';
        await _db.storage.from('org-assets').uploadBinary(path, file.bytes!,
            fileOptions: FileOptions(contentType: contentType, upsert: true));
        urls.add(_db.storage.from('org-assets').getPublicUrl(path));
      }
      if (urls.isEmpty) return;
      final now = DateTime.now();
      final saved = await _db
          .from('event_requests')
          .update({
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
          })
          .eq('id', request['id'])
          .select();
      if ((saved as List).isEmpty) {
        _snack(
            'Could not update this proposal. Only the officer who created it, or an admin, may change it.',
            true);
        return;
      }
      try {
        await _db.from('notifications').insert({
          'id': DateTime.now().microsecondsSinceEpoch.toString(),
          'title': 'Final Posting Sent to Adviser',
          'message':
              '${request['title'] ?? 'Activity Proposal'} now has the final pictures, venue, purpose, and time details for adviser review.',
          'date': now.toIso8601String(),
          'read': false,
          'org_id': widget.orgId,
          'student_id': null
        });
      } catch (_) {}
      _snack('Final posting sent to the adviser for review.');
      await _load();
    } catch (e) {
      _snack('Could not upload the final posting: $e', true);
    } finally {
      _busy = false;
    }
  }

  Future<void> _editProposal(Map<String, dynamic> request) async {
    final title =
        TextEditingController(text: request['title']?.toString() ?? '');
    final desc =
        TextEditingController(text: request['description']?.toString() ?? '');
    final purpose =
        TextEditingController(text: request['purpose']?.toString() ?? '');
    final venue =
        TextEditingController(text: request['venue']?.toString() ?? '');
    var selected = DateTime.tryParse('${request['date'] ?? ''}') ??
        DateTime.now().add(const Duration(days: 1));
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Revise Activity Proposal',
              style: TextStyle(fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: title,
                decoration: const InputDecoration(
                    labelText: 'Activity title', border: OutlineInputBorder())),
            const SizedBox(height: 11),
            TextField(
                controller: purpose,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'What is the event about?',
                    border: OutlineInputBorder())),
            const SizedBox(height: 11),
            TextField(
                controller: desc,
                maxLines: 5,
                decoration: const InputDecoration(
                    labelText: 'Proposal details',
                    border: OutlineInputBorder())),
            const SizedBox(height: 11),
            TextField(
                controller: venue,
                decoration: const InputDecoration(
                    labelText: 'Venue (optional)',
                    border: OutlineInputBorder())),
            const SizedBox(height: 4),
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Target date',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle:
                    Text('${selected.month}/${selected.day}/${selected.year}'),
                trailing:
                    const Icon(Icons.calendar_month_rounded, color: green),
                onTap: () async {
                  final minDate = DateTime.now();
                  final initial =
                      selected.isBefore(minDate) ? minDate : selected;
                  final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: initial,
                      firstDate: minDate,
                      lastDate: minDate.add(const Duration(days: 365)));
                  if (picked != null) setDialogState(() => selected = picked);
                }),
          ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Send Revised Proposal'))
          ],
        ),
      ),
    );
    final values = [
      title.text.trim(),
      purpose.text.trim(),
      desc.text.trim(),
      venue.text.trim()
    ];
    title.dispose();
    desc.dispose();
    purpose.dispose();
    venue.dispose();
    if (ok != true ||
        values[0].isEmpty ||
        values[2].isEmpty ||
        values[1].isEmpty) {
      _snack('Please complete the revised proposal.', true);
      return;
    }
    try {
      final now = DateTime.now();
      final saved = await _db
          .from('event_requests')
          .update({
            'title': values[0],
            'purpose': values[1],
            'description': values[2],
            'venue': values[3],
            'date': selected.toIso8601String(),
            'status': 'pending',
            'feedback': '',
            'submitted_at': now.toIso8601String(),
            'updated_at': now.toIso8601String()
          })
          .eq('id', request['id'])
          .select();
      if ((saved as List).isEmpty) {
        _snack(
            'Could not update this proposal. Only the officer who created it, or an admin, may change it.',
            true);
        return;
      }
      try {
        await _db.from('notifications').insert({
          'id': DateTime.now().microsecondsSinceEpoch.toString(),
          'title': 'Revised Proposal Submitted',
          'message':
              '${values[0]} was revised by the officer and sent back to the adviser.',
          'date': now.toIso8601String(),
          'read': false,
          'org_id': widget.orgId,
          'student_id': null
        });
      } catch (_) {}
      _snack('Revised proposal sent to the adviser.');
      await _load();
    } catch (e) {
      _snack('Could not update the proposal: $e', true);
    }
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse('${value ?? ''}');
    if (date == null) return 'No date';
    return DateFormat('MMM d, y').format(date);
  }

  String _clock(dynamic value) {
    final raw = '${value ?? ''}'.trim();
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw);
    final h = int.tryParse(m?.group(1) ?? '');
    final min = int.tryParse(m?.group(2) ?? '');
    if (h == null || min == null || h > 23 || min > 59) return raw;
    return DateFormat('h:mm a').format(DateTime(2000, 1, 1, h, min));
  }

  String _when(Map<String, dynamic> r) {
    final start = _clock(r['start_time']);
    final end = _clock(r['end_time']);
    final date = _date(r['date']);
    if (start.isEmpty) return date;
    return '$date - $start${end.isEmpty ? '' : ' to $end'}';
  }

  void _snack(String text, [bool error = false]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(text), backgroundColor: error ? Colors.red : green),
    );
  }

  // The derived flags, copied from the old _card, shared by the filter and the card.
  _Flags _flags(Map<String, dynamic> request) {
    final status = request['status']?.toString() ?? 'pending';
    final images = (request['creative_urls'] is List
            ? request['creative_urls']
            : <dynamic>[])
        .whereType<String>()
        .toList();

    final hasCreative = images.isNotEmpty;
    final hasAdviserBrief =
        (request['feedback']?.toString() ?? '').contains(_finalBriefMarker);
    final isWaitingForAdviser = status == 'admin_approved' && !hasAdviserBrief;
    final isReady = (status == 'admin_approved' && hasAdviserBrief) ||
        (status == 'revision_requested' && hasCreative);
    final needsProposalRevision =
        status == 'revision_requested' && !hasCreative;
    final isRejected = status == 'rejected' || status == 'admin_rejected';
    return (
      status: status,
      images: images,
      hasCreative: hasCreative,
      hasAdviserBrief: hasAdviserBrief,
      isWaitingForAdviser: isWaitingForAdviser,
      isReady: isReady,
      needsProposalRevision: needsProposalRevision,
      isRejected: isRejected,
    );
  }

  _Filter _bucket(Map<String, dynamic> request) {
    final f = _flags(request);
    if (f.isReady || f.needsProposalRevision || f.isRejected) {
      return _Filter.action;
    }
    return f.status == 'published' ? _Filter.published : _Filter.review;
  }

  Widget _grid(List<Widget> items, int cols) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i += cols)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = i; j < i + cols; j++) ...[
                    if (j > i) const SizedBox(width: 12),
                    Expanded(
                        child: j < items.length ? items[j] : const SizedBox()),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContent(double w) {
    final pad = w < 600 ? 16.0 : 24.0;
    final cols = w >= 700 ? 2 : 1;
    final buckets = _requests.map(_bucket).toList();
    int count(_Filter f) => f == _Filter.all
        ? _requests.length
        : buckets.where((b) => b == f).length;
    final shown = [
      for (var i = 0; i < _requests.length; i++)
        if (_filter == _Filter.all || buckets[i] == _filter) _requests[i],
    ];
    const labels = {
      _Filter.all: 'All',
      _Filter.action: 'Needs action',
      _Filter.review: 'In review',
      _Filter.published: 'Published',
    };
    final needs = count(_Filter.action);
    final total = _requests.length;

    final Widget body;
    if (_loading) {
      body =
          _grid([for (var i = 0; i < cols * 2; i++) const _Skeleton()], cols);
    } else if (_failed && _requests.isEmpty) {
      body = _Notice(
        icon: Icons.cloud_off_rounded,
        text: 'Could not load proposals. Check your connection and try again.',
        button: 'Retry',
        onTap: _load,
      );
    } else if (_requests.isEmpty) {
      body = _Notice(
        icon: Icons.auto_awesome_rounded,
        text:
            'No proposals yet. Submitted proposals appear here with adviser feedback.',
        button: _canSubmitProposals ? 'New Proposal' : null,
        onTap: _createRequest,
      );
    } else if (shown.isEmpty) {
      body = const _Notice(
          icon: Icons.inbox_rounded, text: 'No proposals in this filter.');
    } else {
      body = _grid([for (final r in shown) _card(r, w >= 600)], cols);
    }

    return Column(
      children: [
        _ActivityHeader(
          orgName: widget.orgName,
          orgId: widget.orgId,
          logoAsset: widget.logoAsset,
          pad: pad,
        ),
        if (_refreshing)
          const LinearProgressIndicator(
              minHeight: 2, color: green, backgroundColor: _mint),
        Expanded(
          child: SafeArea(
            top: false,
            bottom: false,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: RefreshIndicator(
                color: green,
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                      pad, 16, pad, _canSubmitProposals && w < 600 ? 96 : 28),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Your Proposals',
                                    style: TextStyle(
                                        color: _ink,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Refresh',
                                  onPressed:
                                      (_loading || _refreshing) ? null : _load,
                                  icon: const Icon(Icons.refresh_rounded),
                                ),
                                if (_canSubmitProposals && w >= 600)
                                  FilledButton.icon(
                                    onPressed: _createRequest,
                                    icon:
                                        const Icon(Icons.add_rounded, size: 18),
                                    label: const Text('New Proposal'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: green,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(0, 44),
                                    ),
                                  ),
                              ],
                            ),
                            if (total > 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                '$total proposal${total == 1 ? '' : 's'} • $needs ${needs == 1 ? 'needs' : 'need'} action',
                                style: const TextStyle(
                                    color: _sub,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final f in labels.keys)
                                    ChoiceChip(
                                      label: Text('${labels[f]} ${count(f)}'),
                                      selected: _filter == f,
                                      onSelected: (_) =>
                                          setState(() => _filter = f),
                                      showCheckmark: false,
                                      selectedColor: _mint,
                                      backgroundColor: Colors.white,
                                      side: BorderSide(
                                          color:
                                              _filter == f ? green : _border),
                                      labelStyle: TextStyle(
                                        color: _filter == f
                                            ? const Color(0xFF0B6B4D)
                                            : _ink,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.padded,
                                    ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 14),
                            body,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildFab() {
    // Only the President and Vice President can create proposals. Other roles
    // can still view existing proposals, but should not see the New Proposal button.
    if (!_canSubmitProposals) return null;
    return FloatingActionButton.extended(
      backgroundColor: green,
      foregroundColor: Colors.white,
      elevation: 2,
      onPressed: _canSubmitProposals ? _createRequest : null,
      icon: const Icon(Icons.add_rounded),
      label: const Text('New Proposal',
          style: TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Measure the real width of this tab, not the window (a rail may sit beside it).
    return LayoutBuilder(
      builder: (context, c) {
        final fab = c.maxWidth < 600 ? _buildFab() : null;
        final content = _buildContent(c.maxWidth);
        if (widget.embedded) {
          return Stack(
            children: [
              content,
              if (fab != null) Positioned(right: 16, bottom: 16, child: fab),
            ],
          );
        }
        return Scaffold(
          backgroundColor: Colors.white,
          body: content,
          floatingActionButton: fab,
        );
      },
    );
  }

  Widget _thumb(List<String> images) {
    if (images.isEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
            color: _mint, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.event_note_rounded, color: green),
      );
    }
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: images.first,
                fit: BoxFit.cover,
                memCacheWidth: 200,
                placeholder: (_, __) => const ColoredBox(color: _skeleton),
                errorWidget: (_, __, ___) => const ColoredBox(
                  color: _skeleton,
                  child: Center(
                      child: Icon(Icons.broken_image_outlined, color: _sub)),
                ),
              ),
            ),
          ),
          if (images.length > 1)
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: const Color(0xCC173B30),
                    borderRadius: BorderRadius.circular(10)),
                child: Text('+${images.length - 1}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> request, bool wide) {
    final f = _flags(request);
    final id = '${request['id']}';
    final open = _expanded.contains(id);
    final title = request['title']?.toString() ?? 'Untitled proposal';
    final description = request['description']?.toString() ?? '';
    final feedback = (request['feedback'] ?? '')
        .toString()
        .replaceAll(_finalBriefMarker, '')
        .trim();
    final adminFeedback = (request['admin_feedback'] ?? '').toString();

    final (IconData, String, VoidCallback)? act = f.isReady
        ? (
            Icons.auto_awesome_rounded,
            f.hasCreative
                ? 'Improve & Resubmit Final Posting'
                : 'Create & Send Final Posting',
            () => _submitCreative(request),
          )
        : (f.needsProposalRevision || f.isRejected)
            ? (
                Icons.edit_note_rounded,
                'Revise Proposal & Send to Adviser',
                () => _editProposal(request),
              )
            : null;

    final extra = <Widget>[
      if (feedback.isNotEmpty)
        _feedbackBox(
            'Adviser feedback / instructions', feedback, Colors.orange),
      if (adminFeedback.isNotEmpty)
        _feedbackBox('Admin / CSO feedback', adminFeedback, Colors.red),
      if (f.needsProposalRevision)
        const _StatusNote(
            icon: Icons.edit_note_rounded,
            text:
                'The adviser requested changes to the proposal. Revise it and send it back to the adviser.'),
      if (f.isWaitingForAdviser)
        const _StatusNote(
            icon: Icons.schedule_rounded,
            text:
                'Waiting for your adviser to tell the team in Community Chat when to prepare the final event post.'),
      if (f.isRejected)
        const _StatusNote(
            icon: Icons.info_outline_rounded,
            text:
                'This proposal was not approved. Review the feedback above before submitting a new proposal.'),
      if (f.images.isNotEmpty) _Gallery(f.images, key: ValueKey(id)),
    ];

    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(
              color: Color(0x0D173B30), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: '$title. Tap to ${open ? 'collapse' : 'expand'} details.',
              child: InkWell(
                hoverColor: const Color(0x0F128058),
                focusColor: const Color(0x1F128058),
                onTap: () => setState(() {
                  if (open) {
                    _expanded.remove(id);
                  } else {
                    _expanded.add(id);
                  }
                }),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _thumb(f.images),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: _ink,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        height: 1.25),
                                  ),
                                ),
                                Icon(
                                    open
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                    color: _sub),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _statusChip(f.status,
                                hasAdviserBrief: f.hasAdviserBrief),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(Icons.calendar_month_rounded,
                                      size: 15, color: _sub),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _when(request),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: _sub,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                description,
                                maxLines: open ? null : 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: _sub, fontSize: 13, height: 1.4),
                              ),
                            ],
                            if (!open &&
                                (feedback.isNotEmpty ||
                                    adminFeedback.isNotEmpty))
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  children: [
                                    const Icon(Icons.feedback_outlined,
                                        size: 14, color: Color(0xFFB45309)),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        feedback.isNotEmpty
                                            ? 'Adviser feedback • tap to read'
                                            : 'Admin / CSO feedback • tap to read',
                                        style: const TextStyle(
                                            color: Color(0xFFB45309),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: double.infinity,
                child: open && extra.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final item in extra)
                              Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: item),
                          ],
                        ),
                      )
                    : null,
              ),
            ),
            if (act != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: wide ? null : double.infinity,
                    child: FilledButton.icon(
                      onPressed: _canSubmitProposals ? act.$3 : null,
                      icon: Icon(act.$1, size: 18),
                      label: Text(act.$2),
                      style: FilledButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _feedbackBox(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.feedback_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: _ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(value,
                    style: const TextStyle(
                        color: _ink,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status, {bool hasAdviserBrief = false}) {
    // In review = amber, ready/published = green, revision = orange, rejected = red.
    // Text uses the darker shade of each color so it keeps >= 4.5:1 contrast.
    final (Color bg, Color fg) = switch (status) {
      'admin_approved' when hasAdviserBrief => (
          const Color(0xFFE4F7EF),
          const Color(0xFF0B6B4D)
        ),
      'published' => (const Color(0xFFE4F7EF), const Color(0xFF0B6B4D)),
      'revision_requested' => (
          const Color(0xFFFFEDD5),
          const Color(0xFFC2410C)
        ),
      'admin_rejected' || 'rejected' => (
          const Color(0xFFFEE2E2),
          const Color(0xFFB91C1C)
        ),
      _ => (const Color(0xFFFEF3C7), const Color(0xFFB45309)),
    };

    final label = status == 'pending'
        ? 'WAITING FOR ADVISER'
        : status == 'admin_approved'
            ? (hasAdviserBrief
                ? 'READY FOR FINAL POSTING'
                : 'WAITING FOR ADVISER')
            : status == 'forwarded_to_admin'
                ? 'WAITING FOR ADMIN / CSO'
                : status == 'creative_submitted'
                    ? 'FINAL POSTING SENT TO ADVISER'
                    : status.replaceAll('_', ' ').toUpperCase();

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)),
        child: Text(
          label,
          style: TextStyle(
              color: fg,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .2),
        ),
      ),
    );
  }
}

class _ActivityHeader extends StatelessWidget {
  final String orgName;
  final String orgId;
  final String logoAsset;
  final double pad;

  const _ActivityHeader({
    required this.orgName,
    required this.orgId,
    required this.pad,
    this.logoAsset = '',
  });

  Widget _logo(String path) {
    const fallback = Icon(Icons.business_rounded, color: green, size: 28);
    if (path.isEmpty) return fallback;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(path,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback);
    }
    return Image.asset(path,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback);
  }

  @override
  Widget build(BuildContext context) {
    final org =
        AppState.instance.organizations.cast<Organization?>().firstWhere(
              (item) => item?.id == orgId,
              orElse: () => null,
            );
    final logo = logoAsset.trim().isNotEmpty
        ? logoAsset.trim()
        : (org?.logoAsset.trim() ?? '');

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF064E3B), Color(0xFF0B6B4D), Color(0xFF1A9E6B)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -40,
            top: -60,
            child: SizedBox(
              width: 160,
              height: 160,
              child: DecoratedBox(
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: Color(0x12FFFFFF)),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                pad, MediaQuery.paddingOf(context).top + 16, pad, 18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: Colors.white),
                      child: ClipOval(child: _logo(logo)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Activity Proposals',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.15),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            orgName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xE6FFFFFF),
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                    color: Color(0xFF86EFAC),
                                    shape: BoxShape.circle),
                                child: SizedBox(width: 8, height: 8),
                              ),
                              SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  'OFFICER ORGANIZATION HUB',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: .4),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: _mint, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: green, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  color: _ink,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Gallery extends StatefulWidget {
  final List<String> images;
  const _Gallery(this.images, {super.key});

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _page = PageController();
  int _i = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _go(int d) => _page.animateToPage(_i + d,
      duration: const Duration(milliseconds: 250), curve: Curves.easeOut);

  Widget _arrow(IconData icon, String tip, VoidCallback? onTap) => IconButton(
        tooltip: tip,
        onPressed: onTap,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0x99173B30),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0x33173B30),
          disabledForegroundColor: Colors.white54,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final n = widget.images.length;
    return SizedBox(
      height: 220,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _page,
              itemCount: n,
              onPageChanged: (v) => setState(() => _i = v),
              itemBuilder: (_, k) => CachedNetworkImage(
                imageUrl: widget.images[k],
                fit: BoxFit.cover,
                memCacheWidth: 900,
                placeholder: (_, __) => const ColoredBox(color: _skeleton),
                errorWidget: (_, __, ___) => const ColoredBox(
                  color: _skeleton,
                  child: Center(
                      child: Icon(Icons.broken_image_outlined, color: _sub)),
                ),
              ),
            ),
            if (n > 1) ...[
              Positioned(
                left: 4,
                top: 0,
                bottom: 0,
                child: Center(
                    child: _arrow(Icons.chevron_left_rounded,
                        'Previous picture', _i > 0 ? () => _go(-1) : null)),
              ),
              Positioned(
                right: 4,
                top: 0,
                bottom: 0,
                child: Center(
                    child: _arrow(Icons.chevron_right_rounded, 'Next picture',
                        _i < n - 1 ? () => _go(1) : null)),
              ),
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var k = 0; k < n; k++)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: k == _i ? Colors.white : Colors.white54,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatefulWidget {
  const _Skeleton();

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading proposal',
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final color =
              Color.lerp(_skeleton, const Color(0xFFDDE7E3), _c.value)!;
          Widget box(double w, double h, [double r = 8]) => Container(
                width: w,
                height: h,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(r)),
              );
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: _cardDeco,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                box(72, 72, 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      box(double.infinity, 16),
                      const SizedBox(height: 8),
                      box(120, 12),
                      const SizedBox(height: 8),
                      box(double.infinity, 12),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? button;
  final VoidCallback? onTap;

  const _Notice({
    required this.icon,
    required this.text,
    this.button,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = button;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: _cardDeco,
      child: Column(
        children: [
          Icon(icon, color: green, size: 32),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _sub,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500),
          ),
          if (label != null) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: green,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
              ),
              child: Text(label),
            ),
          ],
        ],
      ),
    );
  }
}
