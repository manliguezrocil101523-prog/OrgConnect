import 'dart:math' show max;
import 'dart:ui' show PointerDeviceKind;

import 'adviser_accounts_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../core/app_state.dart';
import '../Officer_Role/officer_members_screen.dart';
import '../Officer_Role/officer_org_profile_screen.dart';
import 'adviser_profile_screen.dart';
import 'adviser_liquidation_screen.dart';
import 'adviser_meeting_minutes_screen.dart';
import '../community/org_community_chat_screen.dart';
import '../analytics/event_comments_sheet.dart';
import '../../widgets/app_header.dart';

class AdviserDashboard extends StatefulWidget {
  final String orgId, orgName;
  const AdviserDashboard(
      {super.key, required this.orgId, required this.orgName});
  @override
  State<AdviserDashboard> createState() => _AdviserDashboardState();
}

class _AdviserDashboardState extends State<AdviserDashboard> {
  static const green = Color(0xFF0D6343);
  static const dark = Color(0xFF163B2E);
  static const muted = Color(0xFF60776D);
  static const bg = Colors.white;
  static const card = Color(0xFFFFFFFF);
  static const mint = Color(0xFFEAF4EE);
  static const line = Color(0xFFD8E7DD);
  static const _tabs = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.assignment_outlined, Icons.assignment_rounded, 'Proposals'),
    (Icons.apartment_outlined, Icons.apartment_rounded, 'Organization'),
    (Icons.person_outline, Icons.person_rounded, 'Profile'),
  ];
  final _db = Supabase.instance.client;
  final _bodyKey = GlobalKey(); // keeps tab state when the layout switches
  int _tab = 0;
  bool _loading = true;
  bool _loadedOnce = false;
  bool _loadInProgress = false;
  bool _reloadPending = false;
  bool _showAllPublishedEvents = false;
  bool _showAllProposals = false;
  List<Map<String, dynamic>> _requests = [], _events = [], _posts = [];
  String _avatarUrl = '';
  String _userName = '';
  DateTime? _proposalSeenAt;
  RealtimeChannel? _proposalChannel;
  static const _finalBriefMarker = '[ADVISER_FINAL_LAYOUT_REQUESTED]';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppState.instance.setRole(UserRole.adviser);
      AppState.instance.setCurrentOfficerOrgId(widget.orgId);
    });
    _loadProposalSeenAt();
    _load();
    _proposalChannel = _db.channel(
        'adviser-proposals-${widget.orgId}-${_db.auth.currentUser?.id ?? 'local'}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'event_requests',
        filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'org_id',
            value: widget.orgId),
        callback: (_) => _load(),
      )
      ..subscribe();
  }

  @override
  void dispose() {
    final channel = _proposalChannel;
    if (channel != null) {
      _db.removeChannel(channel);
    }
    super.dispose();
  }

  Future<void> _load() async {
    // Realtime events can arrive in quick succession. Serialize requests and
    // run one follow-up refresh rather than allowing stale requests to race.
    if (_loadInProgress) {
      _reloadPending = true;
      return;
    }
    _loadInProgress = true;
    if (mounted && !_loadedOnce) {
      setState(() => _loading = true);
    }

    try {
      final userId = _db.auth.currentUser?.id;
      final profileRequest = userId == null
          ? Future<Map<String, dynamic>?>.value(null)
          : _db
              .from('profiles')
              .select('name,avatar_url')
              .eq('id', userId)
              .maybeSingle();

      final results = await Future.wait<dynamic>([
        _db
            .from('event_requests')
            .select('*')
            .eq('org_id', widget.orgId)
            .order('created_at', ascending: false),
        _db
            .from('events')
            .select('*')
            .eq('org_id', widget.orgId)
            .order('date', ascending: false),
        _db
            .from('notifications')
            .select('id,title,message,date,created_at')
            .eq('org_id', widget.orgId)
            .isFilter('student_id', null)
            .order('created_at', ascending: false),
        profileRequest,
      ]);

      if (!mounted) return;
      setState(() {
        _requests = List<Map<String, dynamic>>.from(results[0] as List);
        _events = List<Map<String, dynamic>>.from(results[1] as List)
          ..sort((a, b) => ('${b['date'] ?? b['created_at'] ?? ''}')
              .compareTo('${a['date'] ?? a['created_at'] ?? ''}'));
        _posts =
            List<Map<String, dynamic>>.from(results[2] as List).where((post) {
          final title = post['title']?.toString().toLowerCase() ?? '';
          final message = post['message']?.toString().toLowerCase() ?? '';
          final combined = '$title $message';
          final isProposalNotice = combined.contains('proposal') ||
              combined.contains('final pictures') ||
              combined.contains('creative submitted') ||
              combined.contains('approved and published') ||
              combined.contains('final posting sent to adviser') ||
              combined.contains('final layout') ||
              combined.contains('adviser review') ||
              combined.contains('forwarded to admin / cso') ||
              combined.contains('revision requested') ||
              combined.contains('sent back to officers');
          return !isProposalNotice;
        }).toList();

        final profile = results[3] as Map<String, dynamic>?;
        _avatarUrl = profile?['avatar_url']?.toString().trim() ?? '';
        _userName = profile?['name']?.toString().trim() ?? '';
        _loading = false;
        _loadedOnce = true;
      });

      if (_proposalSeenAt == null && _requests.isNotEmpty) {
        final stamps = _requests
            .map(_proposalTimestamp)
            .whereType<DateTime>()
            .where((date) => !date.isAfter(DateTime.now()))
            .toList();
        if (stamps.isNotEmpty) {
          stamps.sort();
          final latest = stamps.last;
          if (mounted) {
            setState(() => _proposalSeenAt = latest);
          } else {
            _proposalSeenAt = latest;
          }
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              'adviser_proposal_seen_at_${widget.orgId}',
              latest.toIso8601String(),
            );
          } catch (_) {
            // The dashboard still works if local seen-state persistence fails.
          }
        }
      }

      await AppState.instance.fetchMembers();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Unable to load adviser dashboard: $e', true);
      }
    } finally {
      _loadInProgress = false;
      if (mounted && _reloadPending) {
        _reloadPending = false;
        await _load();
      }
    }
  }

  Future<void> _loadProposalSeenAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('adviser_proposal_seen_at_${widget.orgId}');
      if (!mounted) return;
      final stored = raw == null ? null : DateTime.tryParse(raw);
      setState(() {
        if (stored != null || _proposalSeenAt == null) {
          _proposalSeenAt = stored;
        }
      });
    } catch (_) {
      // A missing local preference should not block the dashboard.
    }
  }

  DateTime? _proposalTimestamp(Map<String, dynamic> r) {
    return DateTime.tryParse(r['created_at']?.toString() ?? '') ??
        DateTime.tryParse(r['updated_at']?.toString() ?? '');
  }

  int get _unreadProposalCount {
    final seen = _proposalSeenAt;
    if (seen == null) return 0;
    final now = DateTime.now();
    return _requests.where((r) {
      final status = r['status']?.toString();
      if (status != 'pending' &&
          status != 'admin_approved' &&
          status != 'creative_submitted') {
        return false;
      }
      final stamp = _proposalTimestamp(r);
      if (stamp == null || stamp.isAfter(now)) return false;
      return stamp.isAfter(seen);
    }).length;
  }

  bool get _hasUnreadProposalNotice => _unreadProposalCount > 0;

  void _markProposalNotificationsSeen() {
    final mark = DateTime.now();
    if (mounted) setState(() => _proposalSeenAt = mark);
    SharedPreferences.getInstance().then((prefs) {
      return prefs.setString(
        'adviser_proposal_seen_at_${widget.orgId}',
        mark.toIso8601String(),
      );
    }).catchError((_) => false);
  }

  String _visibleFeedback(dynamic value) {
    return (value?.toString() ?? '').replaceAll(_finalBriefMarker, '').trim();
  }

  bool _finalBriefSent(Map<String, dynamic> r) {
    return (r['feedback']?.toString() ?? '').contains(_finalBriefMarker);
  }

  Future<void> _tellOfficerToPrepareFinalLayout(Map<String, dynamic> r) async {
    final proposalTitle = r['title']?.toString() ?? 'Activity Proposal';
    final message =
        'Admin / CSO has approved "$proposalTitle". Please prepare the final event post with the activity picture, activity details, venue, date, start time, and end time, then send the final layout to me here for review. Organization members can also share design suggestions in this community chat.';
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrgCommunityChatScreen(
            orgId: widget.orgId,
            orgName: widget.orgName,
            initialMessage: message,
            onMessageSent: () async {
              if (_finalBriefSent(r)) return;
              final now = DateTime.now();
              final existing = _visibleFeedback(r['feedback']);
              final feedback = existing.isEmpty
                  ? _finalBriefMarker
                  : '$existing\n$_finalBriefMarker';
              try {
                await _db.from('event_requests').update({
                  'feedback': feedback,
                  'updated_at': now.toIso8601String(),
                }).eq('id', r['id']);
              } catch (_) {}
            },
          ),
        ),
      );
      await _load();
    } catch (e) {
      _snack('Could not open community chat: $e', true);
    }
  }

  void _snack(String s, [bool err = false]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(s),
        backgroundColor: err ? Colors.red : green,
        behavior: SnackBarBehavior.floating,
        width: MediaQuery.sizeOf(context).width >= 600 ? 440 : null));
  }

  DateTime? _parseFlexibleDate(dynamic value) {
    final raw = '${value ?? ''}'.trim();
    if (raw.isEmpty) return null;
    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;
    final mdy =
        RegExp(r'^(\d{1,2})[\-/](\d{1,2})[\-/](\d{4})$').firstMatch(raw);
    if (mdy != null) {
      final month = int.tryParse(mdy.group(1)!) ?? 0;
      final day = int.tryParse(mdy.group(2)!) ?? 0;
      final year = int.tryParse(mdy.group(3)!) ?? 0;
      if (year > 0 && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  String _date(dynamic v) {
    final d = _parseFlexibleDate(v);
    if (d == null) return 'No date';
    return DateFormat('MMMM d, yyyy', 'en_US').format(d);
  }

  String _time(dynamic v) {
    final raw = '${v ?? ''}'.trim();
    if (raw.isEmpty) return '';
    final match = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*([AaPp][Mm])?$')
        .firstMatch(raw);
    if (match == null) return raw;
    var hour = int.tryParse(match.group(1)!) ?? 0;
    final minute = int.tryParse(match.group(2)!) ?? 0;
    final suffix = match.group(3)?.toUpperCase();
    if (suffix == null) {
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return raw;
      final isPm = hour >= 12;
      hour %= 12;
      if (hour == 0) hour = 12;
      return '${hour.toString()}:${minute.toString().padLeft(2, '0')} ${isPm ? 'PM' : 'AM'}';
    }
    if (hour < 1 || hour > 12 || minute < 0 || minute > 59) return raw;
    return '${hour.toString()}:${minute.toString().padLeft(2, '0')} $suffix';
  }

  String _eventDateTime(Map<String, dynamic> e) {
    final date = _date(e['date']);
    final start = _time(e['start_time']);
    final end = _time(e['end_time']);
    if (start.isEmpty) return date;
    return '$date • $start${end.isNotEmpty ? ' – $end' : ''}';
  }

  List<String> _images(Map<String, dynamic> r) {
    final primary = r['image_urls'];
    final creative = r['creative_urls'];
    return [
      ...(primary is List ? primary.whereType<String>() : <String>[]),
      ...(creative is List ? creative.whereType<String>() : <String>[]),
    ].map((url) => url.trim()).where((url) => url.isNotEmpty).toList();
  }

  String _publicDescription(Map<String, dynamic> r) {
    final parts = <String>[];
    final purpose = r['purpose']?.toString().trim() ?? '';
    final description = r['description']?.toString().trim() ?? '';
    final venue = r['venue']?.toString().trim() ?? '';
    final start = r['start_time']?.toString().trim() ?? '';
    final end = r['end_time']?.toString().trim() ?? '';
    if (purpose.isNotEmpty) parts.add('About: $purpose');
    if (description.isNotEmpty && description != purpose) {
      parts.add(description);
    }
    if (venue.isNotEmpty) parts.add('Venue: $venue');
    if (start.isNotEmpty) {
      parts.add('Time: ${end.isNotEmpty ? '$start – $end' : start}');
    }
    return parts.join('\n');
  }

  String _publicDate(Map<String, dynamic> r) {
    final raw = DateTime.tryParse('${r['date'] ?? ''}');
    if (raw == null) return '${r['date'] ?? ''}';
    final start = r['start_time']?.toString().trim() ?? '';
    final m24 = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(start);
    final m12 = RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$').firstMatch(start);
    if (m24 == null && m12 == null) return raw.toIso8601String();
    var hour = int.tryParse((m24 ?? m12)!.group(1)!) ?? raw.hour;
    final minute = int.tryParse((m24 ?? m12)!.group(2)!) ?? raw.minute;
    if (m12 != null) {
      final suffix = m12.group(3)!.toUpperCase();
      if (suffix == 'PM' && hour < 12) hour += 12;
      if (suffix == 'AM' && hour == 12) hour = 0;
    }
    return DateTime(raw.year, raw.month, raw.day, hour, minute)
        .toIso8601String();
  }

  Future<void> _sendAdminReturnToOfficers(Map<String, dynamic> r) async {
    final feedback = r['admin_feedback']?.toString().trim() ?? '';
    try {
      final now = DateTime.now();
      await _db.from('event_requests').update({
        'status': 'pending',
        'feedback': feedback.isEmpty
            ? 'Please improve the proposal based on the Admin / CSO review.'
            : feedback,
        'adviser_reviewed_at': now.toIso8601String(),
        'reviewed_by': _db.auth.currentUser?.id,
        'updated_at': now.toIso8601String(),
      }).eq('id', r['id']);
      try {
        await _db.from('notifications').insert({
          'id': DateTime.now().microsecondsSinceEpoch.toString(),
          'title': 'Proposal Sent Back to Officers',
          'message':
              '${r['title'] ?? 'Activity Proposal'} needs improvement before it can be forwarded to Admin / CSO. ${feedback.isEmpty ? '' : feedback}',
          'date': now.toIso8601String(),
          'read': false,
          'org_id': widget.orgId,
          'student_id': null,
        });
      } catch (_) {}
      _snack(
          'The proposal was sent back to the officers with the Admin / CSO feedback.');
      await _load();
    } catch (e) {
      _snack('Could not send the proposal back to officers: $e', true);
    }
  }

  Future<void> _forward(Map<String, dynamic> r) async {
    try {
      final now = DateTime.now();
      await _db.from('event_requests').update({
        'status': 'forwarded_to_admin',
        'adviser_reviewed_at': now.toIso8601String(),
        'reviewed_by': _db.auth.currentUser?.id,
        'updated_at': now.toIso8601String()
      }).eq('id', r['id']);
      try {
        await _db.from('notifications').insert({
          'id': DateTime.now().microsecondsSinceEpoch.toString(),
          'title': 'Proposal Forwarded to Admin / CSO',
          'message':
              '${r['title'] ?? 'Activity Proposal'} from ${widget.orgName} is ready for Admin / CSO review.',
          'date': now.toIso8601String(),
          'read': false,
          'org_id': widget.orgId,
          'student_id': null
        });
      } catch (_) {}
      _snack('Proposal forwarded to Admin / CSO.');
      await _load();
    } catch (e) {
      _snack('Could not forward proposal: $e', true);
    }
  }

  Future<void> _requestRevision(Map<String, dynamic> r) async {
    final f = await _feedback(
        'Request Revision', 'Tell the officers what needs improvement.');
    if (!mounted || f == null) return;
    try {
      final now = DateTime.now();
      await _db.from('event_requests').update({
        'status': 'revision_requested',
        'feedback': f,
        'adviser_reviewed_at': now.toIso8601String(),
        'reviewed_by': _db.auth.currentUser?.id,
        'updated_at': now.toIso8601String()
      }).eq('id', r['id']);
      try {
        await _db.from('notifications').insert({
          'id': DateTime.now().microsecondsSinceEpoch.toString(),
          'title': 'Proposal Revision Requested',
          'message':
              '${r['title'] ?? 'Activity Proposal'} needs improvement. Feedback: $f',
          'date': now.toIso8601String(),
          'read': false,
          'org_id': widget.orgId,
          'student_id': null
        });
      } catch (_) {}
      _snack('Revision sent back to officers.');
      await _load();
    } catch (e) {
      _snack('Could not request revision: $e', true);
    }
  }

  bool _publishing = false;

  Future<void> _publish(Map<String, dynamic> r) async {
    if (_publishing || !mounted) return;
    setState(() => _publishing = true);
    var claimed = false;
    var eventSaved = false;
    final now = DateTime.now();
    try {
      final imgs = _images(r);
      final claim = await _db
          .from('event_requests')
          .update({
            'status': 'published',
            'published_at': now.toIso8601String(),
            'adviser_reviewed_at': now.toIso8601String(),
            'reviewed_by': _db.auth.currentUser?.id,
            'updated_at': now.toIso8601String()
          })
          .eq('id', r['id'])
          .eq('status', 'creative_submitted')
          .select();
      if ((claim as List).isEmpty) {
        _snack('This proposal was already published or changed. Refreshing.',
            true);
        await _load();
        return;
      }
      claimed = true;
      await _db.from('events').insert({
        'title': r['title'],
        'date': _publicDate(r),
        'description': _publicDescription(r),
        'org_name': widget.orgName,
        'org_id': widget.orgId,
        'image_url': imgs.isEmpty ? null : imgs.first,
        'image_urls': imgs,
        'venue': (r['venue'] ?? '').toString().trim(),
        'start_time': (r['start_time'] ?? '').toString().trim().isEmpty
            ? null
            : r['start_time'].toString().trim(),
        'end_time': (r['end_time'] ?? '').toString().trim().isEmpty
            ? null
            : r['end_time'].toString().trim(),
      });
      eventSaved = true;
      try {
        await _db.from('notifications').insert({
          'id': DateTime.now().microsecondsSinceEpoch.toString(),
          'title': 'New Event',
          'message':
              '${r['title']} has been approved and published by ${widget.orgName}. It is now visible to guests, students, officers, advisers, and admins.',
          'date': now.toIso8601String(),
          'read': false,
          'org_id': widget.orgId,
          'student_id': null
        });
      } catch (_) {}
      _snack('Event published successfully.');
      await _load();
    } catch (e) {
      if (claimed && !eventSaved) {
        try {
          await _db.from('event_requests').update({
            'status': 'creative_submitted',
            'published_at': null,
            'updated_at': DateTime.now().toIso8601String()
          }).eq('id', r['id']);
        } catch (_) {}
        await _load();
      }
      _snack('Could not publish event: $e', true);
    } finally {
      if (mounted) {
        setState(() => _publishing = false);
      } else {
        _publishing = false;
      }
    }
  }

  bool _deleting = false;

  Future<void> _deleteEvent(Map<String, dynamic> e) async {
    if (_deleting || !mounted) return;
    final id = e['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final title = e['title']?.toString() ?? 'this event';
    final ok = await showDialog<bool>(
      context: context,
      builder: (x) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text(
            '"$title" will be removed for everyone, including its comments, reactions and views. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(x, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(x, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );
    if (!mounted || ok != true) return;
    setState(() => _deleting = true);
    try {
      final removed = await AppState.instance.removeEvent(id);
      _snack(
          removed
              ? 'Event deleted.'
              : 'Could not delete this event. It may already be removed or you may not have permission.',
          !removed);
      await _load();
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      } else {
        _deleting = false;
      }
    }
  }

  Future<String?> _feedback(String title, String hint) async {
    final c = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (x) => AlertDialog(
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title),
        content: SizedBox(
          width: 440,
          child: TextField(
              controller: c,
              maxLines: 5,
              decoration: InputDecoration(
                  labelText: 'Feedback',
                  hintText: hint,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)))),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(x), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(
                  x,
                  c.text.trim().isEmpty
                      ? 'Please revise the submission.'
                      : c.text.trim()),
              child: const Text('Send')),
        ],
      ),
    );
    c.dispose();
    return result;
  }

  Future<void> _postAnnouncement() async {
    final t = TextEditingController(), m = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (x) => AlertDialog(
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('New Organization Announcement'),
        content: SizedBox(
          width: 440,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: t,
                decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 10),
            TextField(
                controller: m,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Announcement')),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(x, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(x, true),
              child: const Text('Post')),
        ],
      ),
    );
    if (ok != true || t.text.trim().isEmpty || m.text.trim().isEmpty) {
      t.dispose();
      m.dispose();
      return;
    }
    try {
      await _db.from('notifications').insert({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'title': t.text.trim(),
        'message': m.text.trim(),
        'date': DateTime.now().toIso8601String(),
        'read': false,
        'org_id': widget.orgId,
        'student_id': null
      });
      _snack('Announcement posted.');
      await _load();
    } catch (e) {
      _snack('Could not post announcement: $e', true);
    }
    t.dispose();
    m.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 840;
      final body = KeyedSubtree(
        key: _bodyKey,
        child: _loading
            ? _loadingView()
            : IndexedStack(
                index: _tab,
                children: [
                  _home(),
                  _proposals(),
                  _org(),
                  const AdviserProfileScreen(),
                ],
              ),
      );
      return Scaffold(
        backgroundColor: bg,
        body: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _rail(box.maxWidth >= 1200),
                  Expanded(child: body),
                ],
              )
            : body,
        bottomNavigationBar: wide ? null : _nav(),
      );
    });
  }

  Widget _loadingView() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF2F7F3), Color(0xFFFFFFFF)],
          ),
        ),
        child: Column(
          children: [
            AppHeader(
              title: 'Adviser Dashboard',
              subtitle: 'Preparing your organization overview',
              status: _adviserLabel,
              avatarUrl: _avatarUrl,
              icon: Icons.apartment_rounded,
            ),
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: green,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading your organization…',
                      style: TextStyle(
                        color: muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  void _selectTab(int i) {
    if (!mounted || i < 0 || i >= _tabs.length) return;
    if (i == 1) {
      _markProposalNotificationsSeen();
    }
    setState(() => _tab = i);
    if (i == 0) _load();
  }

  Widget _tabIcon(int i, bool selected) {
    final t = _tabs[i];
    final icon = Icon(selected ? t.$2 : t.$1, color: selected ? green : null);
    final n = i == 1 ? _unreadProposalCount : 0;
    return n > 0
        ? Badge(label: Text(n > 99 ? '99+' : '$n'), child: icon)
        : icon;
  }

  Widget _nav() => Container(
        decoration: BoxDecoration(color: Colors.white, boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .055),
              blurRadius: 16,
              offset: const Offset(0, -3))
        ]),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            height: 76,
            backgroundColor: Colors.white,
            indicatorColor: green.withValues(alpha: .10),
            selectedIndex: _tab,
            onDestinationSelected: _selectTab,
            destinations: [
              for (var i = 0; i < _tabs.length; i++)
                NavigationDestination(
                    icon: _tabIcon(i, false),
                    selectedIcon: _tabIcon(i, true),
                    label: _tabs[i].$3),
            ],
          ),
        ),
      );

  Widget _rail(bool extended) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(right: BorderSide(color: line)),
          boxShadow: [
            BoxShadow(
                color: green.withValues(alpha: .06),
                blurRadius: 16,
                offset: const Offset(4, 0))
          ],
        ),
        child: NavigationRail(
          extended: extended,
          backgroundColor: Colors.white,
          indicatorColor: green.withValues(alpha: .12),
          selectedIndex: _tab,
          labelType: extended
              ? NavigationRailLabelType.none
              : NavigationRailLabelType.all,
          selectedLabelTextStyle:
              const TextStyle(color: green, fontWeight: FontWeight.w800),
          onDestinationSelected: _selectTab,
          destinations: [
            for (var i = 0; i < _tabs.length; i++)
              NavigationRailDestination(
                  icon: _tabIcon(i, false),
                  selectedIcon: _tabIcon(i, true),
                  label: Text(_tabs[i].$3)),
          ],
        ),
      );

  Widget _grid(List<Widget> items, double gap,
          {double minW = 320,
          int maxCols = 3,
          bool equal = false,
          bool trailing = true}) =>
      LayoutBuilder(builder: (_, box) {
        final cols = ((box.maxWidth + gap) / (minW + gap))
            .floor()
            .clamp(1, maxCols)
            .toInt();
        Widget gapped(int i) => Padding(
              padding: EdgeInsets.only(
                  bottom: trailing || i + cols < items.length ? gap : 0),
              child: items[i],
            );
        if (cols > 1 && equal) {
          return Column(children: [
            for (var i = 0; i < items.length; i += cols)
              Padding(
                padding: EdgeInsets.only(
                    bottom: trailing || i + cols < items.length ? gap : 0),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var j = i; j < i + cols; j++) ...[
                        if (j > i) SizedBox(width: gap),
                        Expanded(
                            child:
                                j < items.length ? items[j] : const SizedBox()),
                      ],
                    ],
                  ),
                ),
              ),
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var k = 0; k < cols; k++) ...[
            if (k > 0) SizedBox(width: gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = k; i < items.length; i += cols) gapped(i)
                ],
              ),
            ),
          ],
        ]);
      });

  Widget _split(List<Widget> main, List<Widget> side) =>
      LayoutBuilder(builder: (_, box) {
        if (box.maxWidth < 920) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [...main, const SizedBox(height: 18), ...side],
          );
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 3,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, children: main),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, children: side),
          ),
        ]);
      });

  String get _adviserLabel =>
      '${widget.orgName.replaceAll(RegExp('tiatro', caseSensitive: false), 'teatro').toUpperCase()} ADVISER';

  Widget _page(
    String title,
    String subtitle,
    List<Widget> children, {
    bool showAvatar = false,
    String? statusText,
    IconData? icon,
  }) =>
      SafeArea(
        top: false,
        child: Container(
      decoration: const BoxDecoration(
  color: Colors.white,
),
          child: Column(
            children: [
              AppHeader(
                title: title,
                subtitle: subtitle,
                status: statusText ?? _adviserLabel,
                avatarUrl: _avatarUrl,
                icon: showAvatar ? null : (icon ?? Icons.apartment_rounded),
              ),
              Expanded(
                child: LayoutBuilder(builder: (context, box) {
                  final w = box.maxWidth;
                  final side = w >= 640 ? max(24.0, (w - 1180) / 2) : 16.0;
                  return RefreshIndicator(
                    color: green,
                    backgroundColor: card,
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics()),
                      padding: EdgeInsets.fromLTRB(side, 18, side, 36),
                      children: children,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      );

  Widget _home() {
    if (_showAllPublishedEvents) {
      return _page(
          'Published Events',
          'Events already approved and posted for your organization.',
          [
            Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _showAllPublishedEvents = false),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back to Home'),
                  style: TextButton.styleFrom(foregroundColor: green),
                )),
            const SizedBox(height: 6),
            if (_events.isEmpty)
              _empty(
                'Approved event creatives will appear here once they are published.',
                title: 'No published events yet',
                icon: Icons.event_available_rounded,
                actionLabel: 'Review proposals',
                onAction: () => _selectTab(1),
              )
            else
              _grid(_events.map(_eventCard).toList(), 14),
          ],
          showAvatar: true);
    }
    final nameParts = _userName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final displayName =
        nameParts.isEmpty ? 'Adviser' : nameParts.take(2).join(' ');
    return _page(
        'Good day, $displayName 👋',
        'Your organization at a glance',
        [
          _statsRow([
            _stat(Icons.assignment_rounded, 'Proposals',
                _requests.where((r) => r['status'] != 'published').length),
            _stat(Icons.event_rounded, 'Events', _events.length),
            _stat(Icons.campaign_rounded, 'Posts', _posts.length),
          ]),
          const SizedBox(height: 22),
          _split([
            _sectionHeader(
                'Published Events',
                'Events that are already posted with their pictures',
                () => setState(() => _showAllPublishedEvents = true)),
            const SizedBox(height: 10),
            if (_events.isEmpty)
              _empty(
                'Approved event creatives will appear here once they are published.',
                title: 'No published events yet',
                icon: Icons.event_available_rounded,
                actionLabel: 'Review proposals',
                onAction: () => _selectTab(1),
              )
            else
              _grid(
                  (_showAllPublishedEvents ? _events : _events.take(5).toList())
                      .map(_eventCard)
                      .toList(),
                  14),
            if (_events.length > 5)
              Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                      onPressed: () => setState(() =>
                          _showAllPublishedEvents = !_showAllPublishedEvents),
                      child: Text(_showAllPublishedEvents
                          ? 'Show Less'
                          : 'View All Events'))),
          ], [
            _sectionHeader(
                'Announcements', 'Updates shared with your organization', null),
            const SizedBox(height: 10),
            _grid(_posts.take(3).map(_postCard).toList(), 10,
                minW: 300, maxCols: 2, equal: true),
            if (_posts.isEmpty)
              _empty(
                'Share important updates, reminders, and news with your organization.',
                title: 'No announcements yet',
                icon: Icons.campaign_outlined,
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _postAnnouncement,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Announcement'),
              style: FilledButton.styleFrom(
                backgroundColor: green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 1,
                shadowColor: green.withValues(alpha: .16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              ),
            ),
          ]),
        ],
        showAvatar: true);
  }

  Widget _stat(IconData icon, String label, int value) => Container(
        constraints: const BoxConstraints(minHeight: 116),
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .035),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: LayoutBuilder(builder: (_, box) {
          final iconBox = Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: mint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: green, size: 19),
          );
          final number = Text(
            '$value',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 23,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: dark,
            ),
          );
          final text = Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              color: muted,
              fontWeight: FontWeight.w600,
            ),
          );
          if (box.maxWidth < 170) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                iconBox,
                const SizedBox(height: 10),
                number,
                const SizedBox(height: 4),
                text,
              ],
            );
          }
          return Row(
            children: [
              iconBox,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [number, const SizedBox(height: 4), text],
                ),
              ),
            ],
          );
        }),
      );

  Widget _statsRow(List<Widget> items) => LayoutBuilder(
        builder: (_, constraints) {
          if (constraints.maxWidth < 360) {
            final itemWidth = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in items)
                  SizedBox(width: itemWidth, child: item),
              ],
            );
          }
          return Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: items[i]),
              ],
            ],
          );
        },
      );

  Widget _sectionHeader(String title, String subtitle, VoidCallback? action) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: dark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: action,
              style: TextButton.styleFrom(
                foregroundColor: green,
                minimumSize: const Size(48, 44),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text('View all'),
            ),
        ],
      );

  Widget _eventCard(Map<String, dynamic> e) {
    final rawImageUrls = e['image_urls'];
    final imgs = (rawImageUrls is List ? rawImageUrls : <dynamic>[])
        .whereType<String>()
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList();
    final url = e['image_url']?.toString().trim();
    if (url != null && url.isNotEmpty && !imgs.contains(url)) {
      imgs.insert(0, url);
    }
    final eventId = e['id']?.toString() ?? '';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (_, box) {
            final h = box.maxWidth > 420 ? 210.0 : 160.0;
            return imgs.isNotEmpty
                ? SizedBox(
                    height: h,
                    width: double.infinity,
                    child: Image.network(imgs.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imagePlaceholder(h)))
                : _imagePlaceholder(h);
          }),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e['title']?.toString() ?? 'Untitled event',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900, color: dark)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.calendar_month_rounded,
                    size: 15, color: green),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_eventDateTime(e),
                      style: const TextStyle(
                          color: muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700)),
                )
              ]),
              if ((e['description'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(e['description'].toString(),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: muted, height: 1.35, fontSize: 12))
              ],
              if (eventId.isNotEmpty) ...[
                const SizedBox(height: 10),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => showEventComments(context,
                            eventId: eventId,
                            eventTitle: e['title']?.toString() ?? 'Event'),
                        icon: const Icon(Icons.forum_rounded, size: 16),
                        label: EventCommentCountLabel(
                            eventId: eventId,
                            style: const TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: green,
                            side: const BorderSide(color: line),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13))),
                      ),
                      OutlinedButton.icon(
                        onPressed: _deleting ? null : () => _deleteEvent(e),
                        icon: _deleting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.delete_outline_rounded,
                                size: 16),
                        label: Text(
                          _deleting ? 'Deleting…' : 'Delete',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13))),
                      ),
                    ],
                  ),
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  Widget _postCard(Map<String, dynamic> p) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .035),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
                color: green.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.campaign_rounded, color: green, size: 19)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p['title']?.toString() ?? 'Announcement',
              style: const TextStyle(fontWeight: FontWeight.w900, color: dark)),
          const SizedBox(height: 4),
          Text(p['message']?.toString() ?? '',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, height: 1.35, fontSize: 12))
        ]))
      ]));

  Widget _proposals() => _page('Proposal Center',
          'Review proposals clearly and take action when they are ready.', [
        _statsRow([
          _stat(
            Icons.pending_actions_rounded,
            'Waiting',
            _requests
                .where((r) =>
                    r['status'] == 'pending' ||
                    r['status'] == 'creative_submitted')
                .length,
          ),
          _stat(
            Icons.hourglass_top_rounded,
            'In Review',
            _requests.where((r) => r['status'] == 'forwarded_to_admin').length,
          ),
          _stat(
            Icons.verified_rounded,
            'Published',
            _requests.where((r) => r['status'] == 'published').length,
          ),
        ]),
        const SizedBox(height: 22),
        Row(children: [
          const Expanded(
              child: Text('All Proposals',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900, color: dark))),
          Text('${_requests.length} total',
              style: const TextStyle(color: muted, fontWeight: FontWeight.w700))
        ]),
        const SizedBox(height: 10),
        _grid(
            (_showAllProposals ? _requests : _requests.take(5).toList())
                .map(_proposalCard)
                .toList(),
            16,
            minW: 420,
            maxCols: 2),
        if (_requests.length > 5)
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                  onPressed: () =>
                      setState(() => _showAllProposals = !_showAllProposals),
                  child: Text(
                      _showAllProposals ? 'Show Less' : 'View All Proposals'))),
        if (_requests.isEmpty)
          _empty(
            'When officers submit activity requests, they will appear here for your review.',
            title: 'No proposals submitted',
            icon: Icons.assignment_outlined,
            actionLabel: 'Refresh proposals',
            onAction: _load,
          ),
      ]);

  Widget _proposalCard(Map<String, dynamic> r) {
    final s = '${r['status'] ?? 'pending'}';
    final imgs = _images(r);
    final adviserFeedback = _visibleFeedback(r['feedback']);
    final venue = r['venue']?.toString().trim() ?? '';
    final start = r['start_time']?.toString().trim() ?? '';
    final end = r['end_time']?.toString().trim() ?? '';
    final description = r['description']?.toString().trim() ?? '';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 17, 17, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        r['title']?.toString() ?? 'Untitled proposal',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: dark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _chip(s),
                  ],
                ),
                if (s == 'creative_submitted') ...[
                  const SizedBox(height: 9),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            size: 15, color: Color(0xFF2563EB)),
                        SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Final event posting received from Officer',
                            style: TextStyle(
                                color: Color(0xFF1D4ED8),
                                fontWeight: FontWeight.w900,
                                fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(description,
                      style: const TextStyle(
                          color: muted, height: 1.45, fontSize: 12.5)),
                ],
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                      color: mint,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: line.withValues(alpha: .75))),
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded, size: 15, color: green),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text('Date: ${_date(r['date'])}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: dark,
                                fontSize: 11.5)),
                      ),
                    ],
                  ),
                ),
                if (venue.isNotEmpty || start.isNotEmpty || end.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      if (venue.isNotEmpty)
                        _detailPill(Icons.place_rounded, venue),
                      if (start.isNotEmpty)
                        _detailPill(
                            Icons.schedule_rounded,
                            end.isNotEmpty
                                ? '${_time(start)} – ${_time(end)}'
                                : _time(start)),
                    ],
                  ),
                ],
                if (adviserFeedback.isNotEmpty)
                  _feedbackBox(
                      'Adviser feedback / instructions', adviserFeedback),
                if ((r['admin_feedback'] ?? '').toString().isNotEmpty)
                  _feedbackBox(
                      'Admin / CSO feedback', r['admin_feedback'].toString()),
              ],
            ),
          ),
          if (imgs.isNotEmpty) ...[
            const SizedBox(height: 15),
            LayoutBuilder(builder: (context, constraints) {
              final imageHeight = constraints.maxWidth < 420 ? 220.0 : 280.0;
              return SizedBox(
                width: double.infinity,
                height: imageHeight,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                    },
                  ),
                  child: PageView.builder(
                    itemCount: imgs.length,
                    itemBuilder: (_, i) => Image.network(
                      imgs[i],
                      width: double.infinity,
                      height: imageHeight,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: bg,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image_rounded,
                          color: green,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
          Padding(
              padding: const EdgeInsets.fromLTRB(17, 14, 17, 17),
              child: _actions(r, s)),
        ],
      ),
    );
  }

  Widget _detailPill(IconData icon, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
          color: mint,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: line.withValues(alpha: .75))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: green),
        const SizedBox(width: 5),
        Flexible(
          child: Text(text,
              style: const TextStyle(
                  color: dark, fontSize: 10.5, fontWeight: FontWeight.w800)),
        )
      ]));

  Widget _actions(Map<String, dynamic> r, String s) {
    if (s == 'pending') {
      return Row(children: [
        Expanded(
            child: OutlinedButton.icon(
                onPressed: () => _requestRevision(r),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Ask Revision'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: green,
                  side: const BorderSide(color: line),
                  minimumSize: const Size(48, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ))),
        const SizedBox(width: 8),
        Expanded(
            child: FilledButton.icon(
                onPressed: () => _forward(r),
                icon: const Icon(Icons.forward_rounded),
                label: const Text('Forward'),
                style: FilledButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                )))
      ]);
    }
    if (s == 'admin_approved') {
      if (_finalBriefSent(r)) {
        return const _StatusNote(
            icon: Icons.forum_rounded,
            text:
                'The Officer final-layout request was sent in Community Chat. Waiting for the officer to send the finished event post.');
      }
      return _statusAction(
          text: 'Tell Officers in Community Chat',
          icon: Icons.forum_rounded,
          onTap: () => _tellOfficerToPrepareFinalLayout(r));
    }
    if (s == 'adviser_to_officer') {
      return const _StatusNote(
          icon: Icons.forum_rounded,
          text:
              'The officer has been asked in Community Chat to prepare the final event post.');
    }
    if (s == 'admin_rejected') {
      return Row(children: [
        Expanded(
            child: _statusAction(
                text: 'Send to Officers',
                icon: Icons.reply_rounded,
                onTap: () => _sendAdminReturnToOfficers(r)))
      ]);
    }
    if (s == 'creative_submitted') {
      return Row(children: [
        Expanded(
            child: OutlinedButton.icon(
                onPressed: () => _requestRevision(r),
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Return to Officer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: green,
                  side: const BorderSide(color: line),
                  minimumSize: const Size(48, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ))),
        const SizedBox(width: 8),
        Expanded(
            child: FilledButton.icon(
                onPressed: _publishing ? null : () => _publish(r),
                icon: _publishing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.publish_rounded),
                label: Text(_publishing ? 'Publishing…' : 'Approve & Publish'),
                style: FilledButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                )))
      ]);
    }
    if (s == 'revision_requested') {
      return const _StatusNote(
          icon: Icons.edit_note_rounded,
          text:
              'Revision requested. Waiting for officers to resubmit the improved proposal.');
    }
    if (s == 'forwarded_to_admin') return const SizedBox.shrink();
    return const SizedBox.shrink();
  }

  Widget _statusAction(
          {required String text,
          required IconData icon,
          required VoidCallback onTap}) =>
      SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 17),
              label: Text(text),
              style: FilledButton.styleFrom(
                backgroundColor: green,
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              )));

  Widget _feedbackBox(String title, String text) => Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFDE68A))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.chat_bubble_outline_rounded,
            size: 17, color: Color(0xFFD97706)),
        const SizedBox(width: 8),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF92400E))),
          const SizedBox(height: 3),
          Text(text,
              style: const TextStyle(
                  fontSize: 11.5, color: Color(0xFF78350F), height: 1.35))
        ]))
      ]));

  Widget _chip(String s) {
    final c = s == 'published' || s == 'admin_approved'
        ? green
        : s == 'admin_rejected'
            ? Colors.red
            : s == 'creative_submitted'
                ? const Color(0xFF2563EB)
                : s == 'revision_requested'
                    ? const Color(0xFFD97706)
                    : muted;
    final label = s == 'pending'
        ? 'WAITING FOR ADVISER'
        : s == 'forwarded_to_admin'
            ? 'WAITING FOR ADMIN / CSO'
            : s.replaceAll('_', ' ').toUpperCase();
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: c.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(30)),
        child: Text(label,
            style: TextStyle(
                color: c, fontSize: 8.5, fontWeight: FontWeight.w900)));
  }

  Widget _org() =>
      _page('Organization', 'Manage members, impact, profile, and community.', [
        _grid([
          _feature(
            Icons.insights_rounded,
            'Active Members & Impact',
            'Active members and their impact.',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OfficerMembersScreen(
                  organizationId: widget.orgId,
                  showOnlyActive: true,
                  readOnly: true,
                  adviserView: true,
                  title: 'Active Members & Impact',
                ),
              ),
            ),
          ),
          _feature(
            Icons.manage_accounts_rounded,
            'Manage Member Accounts',
            'View members and manage their positions.',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdviserAccountsScreen(
                    orgId: widget.orgId, orgName: widget.orgName),
              ),
            ),
          ),
          _feature(
            Icons.badge_rounded,
            'Organization profile',
            'Edit the public organization information, officers, and highlights.',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => OfficerOrgProfileScreen(orgId: widget.orgId)),
            ),
          ),
          _feature(
            Icons.notes_rounded,
            'Meeting Minutes',
            'Review meeting notes submitted by the Secretary or Assistant Secretary.',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdviserMeetingMinutesScreen(
                    orgId: widget.orgId, orgName: widget.orgName),
              ),
            ),
          ),
          _feature(
            Icons.account_balance_wallet_rounded,
            'Liquidation & Budget',
            'View the budget allocated by Admin / CSO, income, expenses, balance, and liquidation history.',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdviserLiquidationScreen(
                    orgId: widget.orgId, orgName: widget.orgName),
              ),
            ),
          ),
          _feature(
            Icons.forum_rounded,
            'Community Chat',
            'Open the organization conversation with members and officers.',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrgCommunityChatScreen(
                    orgId: widget.orgId, orgName: widget.orgName),
              ),
            ),
          ),
        ], 10, minW: 340, maxCols: 2, equal: true, trailing: false),
      ]);

  Widget _feature(
          IconData icon, String title, String subtitle, VoidCallback onTap) =>
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .035),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: mint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: green, size: 22),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: dark,
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, size: 21, color: muted),
              ],
            ),
          ),
        ),
      );

  Widget _empty(
    String message, {
    String title = 'Nothing here yet',
    IconData icon = Icons.inbox_outlined,
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .025),
              blurRadius: 9,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: mint,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(icon, color: green, size: 25),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: dark,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: muted,
                  fontSize: 12.5,
                  height: 1.5,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                label: Text(actionLabel),
                style: TextButton.styleFrom(
                  foregroundColor: green,
                  minimumSize: const Size(48, 44),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      );

  Widget _imagePlaceholder([double height = 160]) => Container(
      height: height,
      decoration: const BoxDecoration(
          gradient:
              LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF20B77D)])),
      child: const Center(
          child: Icon(Icons.event_rounded, color: Colors.white, size: 42)));
}

class _StatusNote extends StatelessWidget {
  final IconData icon;
  final String text;
  const _StatusNote({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFE1F6EB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFB9E4CF))),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF16A34A), size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Color(0xFF166534),
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    height: 1.35)))
      ]));
}
