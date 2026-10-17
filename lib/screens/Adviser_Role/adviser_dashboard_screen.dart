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
  static const green = Color(0xFF128058);
  static const dark = Color(0xFF073B2A);
  static const muted = Color(0xFF4D6F62);
  static const bg = Color(0xFFE6F7EE);
  static const card = Color(0xFFF5FFF9);
  static const mint = Color(0xFFDDF4E8);
  static const line = Color(0xFFB9E4CF);
  final _db = Supabase.instance.client;
  int _tab = 0;
  bool _loading = true;
  bool _loadedOnce = false; // NEW
  bool _showAllPublishedEvents = false;
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
    // Full-screen spinner only on the very first load.
    // Later calls refresh silently in the background.
    if (mounted && !_loadedOnce) setState(() => _loading = true);
    try {
      final results = await Future.wait([
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
        _db
            .from('profiles')
            .select('name,avatar_url')
            .eq('id', _db.auth.currentUser?.id ?? '')
            .maybeSingle(),
      ]);
      if (!mounted) return;
      setState(() {
        _requests = List<Map<String, dynamic>>.from(results[0] as List);
        _events = List<Map<String, dynamic>>.from(results[1] as List);
        // Announcements are adviser-authored posts. Proposal workflow notifications
        // share the notifications table, so exclude them from the Announcements feed.
        _posts =
            List<Map<String, dynamic>>.from(results[2] as List).where((post) {
          final title = post['title']?.toString().toLowerCase() ?? '';
          final message = post['message']?.toString().toLowerCase() ?? '';
          final combined = '$title $message';
          final isProposalNotice = combined.contains('proposal') ||
              combined.contains('final posting sent to adviser') ||
              combined.contains('final layout') ||
              combined.contains('adviser review') ||
              combined.contains('forwarded to admin / cso') ||
              combined.contains('revision requested') ||
              combined.contains('sent back to officers');
          return !isProposalNotice;
        }).toList();
        final profile = results[3] as Map<String, dynamic>?;
        _avatarUrl = profile?['avatar_url']?.toString() ?? '';
        _userName = profile?['name']?.toString().trim() ?? '';
        _loading = false; // NEW
        _loadedOnce = true; // NEW
      });
      if (_proposalSeenAt == null && _requests.isNotEmpty) {
        final stamps = _requests
            .map(_proposalTimestamp)
            .whereType<DateTime>()
            .where((d) => !d.isAfter(DateTime.now()))
            .toList();
        if (stamps.isNotEmpty) {
          stamps.sort();
          final latest = stamps.last;
          _proposalSeenAt = latest;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('adviser_proposal_seen_at_${widget.orgId}',
              latest.toIso8601String());
        }
      }
      // Keep the shared member store in sync. The Organization member screen
      // reads AppState.members rather than this dashboard's private list.
      await AppState.instance.fetchMembers();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Unable to load adviser dashboard: $e', true);
      }
    }
  }

  Future<void> _loadProposalSeenAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('adviser_proposal_seen_at_${widget.orgId}');
    if (!mounted) return;
    setState(() {
      _proposalSeenAt = raw == null ? null : DateTime.tryParse(raw);
    });
  }

  DateTime? _proposalTimestamp(Map<String, dynamic> r) {
    return DateTime.tryParse(r['created_at']?.toString() ?? '') ??
        DateTime.tryParse(r['updated_at']?.toString() ?? '');
  }

  bool get _hasUnreadProposalNotice {
    final seen = _proposalSeenAt;
    if (seen == null) return false;
    final now = DateTime.now();
    return _requests.any((r) {
      final status = r['status']?.toString();
      if (status != 'admin_approved' && status != 'creative_submitted') {
        return false;
      }
      final stamp = _proposalTimestamp(r);
      if (stamp == null || stamp.isAfter(now)) return false;
      return stamp.isAfter(seen);
    });
  }

  void _markProposalNotificationsSeen() {
    // Clear the badge immediately when Proposals is opened. Persist the cursor
    // in the background so navigation never races the async preferences write.
    final mark = DateTime.now();
    if (mounted) setState(() => _proposalSeenAt = mark);
    SharedPreferences.getInstance().then((prefs) {
      return prefs.setString(
        'adviser_proposal_seen_at_${widget.orgId}',
        mark.toIso8601String(),
      );
    });
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
        'Admin / CSO has approved “$proposalTitle”. Please prepare the final event post with the activity picture, activity details, venue, date, start time, and end time, then send the final layout to me here for review. Organization members can also share design suggestions in this community chat.';
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
        behavior: SnackBarBehavior.floating));
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
    final x = r['image_urls'];
    final y = r['creative_urls'];
    return [
      ...(x is List ? x.whereType<String>() : <String>[]),
      ...(y is List ? y.whereType<String>() : <String>[])
    ];
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
    if (f == null) return;
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

  Future<void> _publish(Map<String, dynamic> r) async {
    try {
      final imgs = _images(r);
      final now = DateTime.now();
      await _db.from('events').insert({
        'title': r['title'],
        'date': _publicDate(r),
        'description': _publicDescription(r),
        'org_name': widget.orgName,
        'org_id': widget.orgId,
        'image_url': imgs.isEmpty ? null : imgs.first,
        'image_urls': imgs,
      });
      await _db.from('event_requests').update({
        'status': 'published',
        'published_at': now.toIso8601String(),
        'adviser_reviewed_at': now.toIso8601String(),
        'reviewed_by': _db.auth.currentUser?.id,
        'updated_at': now.toIso8601String()
      }).eq('id', r['id']);
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
      _snack('Could not publish event: $e', true);
    }
  }

  Future<String?> _feedback(String title, String hint) async {
    final c = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (x) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title),
        content: TextField(
            controller: c,
            maxLines: 5,
            decoration: InputDecoration(
                labelText: 'Feedback',
                hintText: hint,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)))),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('New Organization Announcement'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: t,
              decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 10),
          TextField(
              controller: m,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Announcement')),
        ]),
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
    return Scaffold(
      backgroundColor: bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: green))
          : IndexedStack(
              index: _tab,
              children: [
                _home(),
                _proposals(),
                _org(),
                const AdviserProfileScreen(),
              ],
            ),
      bottomNavigationBar: _nav(),
    );
  }

  Widget _nav() => Container(
        decoration: BoxDecoration(color: Colors.white, boxShadow: [
          BoxShadow(
              color: green.withValues(alpha: .10),
              blurRadius: 20,
              offset: const Offset(0, -5))
        ]),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            height: 74,
            backgroundColor: Colors.white,
            indicatorColor: green.withValues(alpha: .12),
            selectedIndex: _tab,
            onDestinationSelected: (i) {
              if (i == 1) {
                _markProposalNotificationsSeen();
              }
              setState(() => _tab = i);
              if (i == 0) _load();
            },
            destinations: [
              const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded, color: green),
                  label: 'Home'),
              NavigationDestination(
                  icon: Badge(
                      label: _hasUnreadProposalNotice ? const Text('!') : null,
                      child: const Icon(Icons.assignment_outlined)),
                  selectedIcon:
                      const Icon(Icons.assignment_rounded, color: green),
                  label: 'Proposals'),
              const NavigationDestination(
                  icon: Icon(Icons.apartment_outlined),
                  selectedIcon: Icon(Icons.apartment_rounded, color: green),
                  label: 'Organization'),
              const NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person_rounded, color: green),
                  label: 'Profile'),
            ],
          ),
        ),
      );

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
        top: false, // AppHeader already handles the status bar space
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE6F7EE), Color(0xFFDDF4E8), Color(0xFFF5FFF9)],
            ),
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
                child: RefreshIndicator(
                  color: green,
                  backgroundColor: card,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
                    children: children,
                  ),
                ),
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
                  'No published events yet. Approved event creatives will appear here.')
            else
              ..._events.map(_eventCard),
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
          Row(children: [
            Expanded(
                child: _stat(Icons.assignment_rounded, 'Proposals',
                    _requests.where((r) => r['status'] != 'published').length)),
            const SizedBox(width: 10),
            Expanded(
                child: _stat(Icons.event_rounded, 'Events', _events.length)),
            const SizedBox(width: 10),
            Expanded(
                child: _stat(Icons.campaign_rounded, 'Posts', _posts.length)),
          ]),
          const SizedBox(height: 22),
          _sectionHeader(
              'Published Events',
              'Events that are already posted with their pictures',
              () => setState(() => _showAllPublishedEvents = true)),
          const SizedBox(height: 10),
          if (_events.isEmpty)
            _empty(
                'No published events yet. Approved event creatives will appear here.')
          else
            ..._events.take(4).map(_eventCard),
          const SizedBox(height: 18),
          _sectionHeader(
              'Announcements', 'Updates shared with your organization', null),
          const SizedBox(height: 10),
          ..._posts.take(3).map(_postCard),
          if (_posts.isEmpty) _empty('No announcements yet.'),
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
                  borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ],
        showAvatar: true,
        statusText:
            '${widget.orgName.replaceAll(RegExp('tiatro', caseSensitive: false), 'teatro').toUpperCase()} ADVISER');
  }

  Widget _stat(IconData icon, String label, int value) => Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F8F62), Color(0xFF20B77D)]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: .18)),
          boxShadow: [
            BoxShadow(
                color: green.withValues(alpha: .14),
                blurRadius: 18,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: Colors.white, size: 19)),
          const SizedBox(height: 10),
          Text('$value',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.white.withValues(alpha: .82),
                  fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _sectionHeader(String title, String subtitle, VoidCallback? action) =>
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w900, color: dark)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(fontSize: 11.5, color: muted))
        ])),
        if (action != null)
          TextButton(onPressed: action, child: const Text('View all'))
      ]);

  Widget _eventCard(Map<String, dynamic> e) {
    final imgs = (e['image_urls'] is List ? e['image_urls'] : <dynamic>[])
        .whereType<String>()
        .toList();
    final url = e['image_url']?.toString();
    if (url != null && url.isNotEmpty && !imgs.contains(url)) {
      imgs.insert(0, url);
    }
    final eventId = e['id']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE9FFF2), Color(0xFFBDF3D0)]),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: line),
        boxShadow: [
          BoxShadow(
              color: green.withValues(alpha: .08),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imgs.isNotEmpty)
            SizedBox(
                height: 160,
                width: double.infinity,
                child: Image.network(imgs.first,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imagePlaceholder()))
          else
            _imagePlaceholder(),
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
                Text(_eventDateTime(e),
                    style: const TextStyle(
                        color: muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700))
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
                EventReactionBar(eventId: eventId),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => showEventComments(context,
                        eventId: eventId,
                        eventTitle: e['title']?.toString() ?? 'Event'),
                    icon: const Icon(Icons.forum_rounded, size: 16),
                    label: const Text('Comments'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: green,
                        side: const BorderSide(color: line),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13))),
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE9FFF2), Color(0xFFBDF3D0)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: line),
          boxShadow: [
            BoxShadow(
                color: green.withValues(alpha: .06),
                blurRadius: 12,
                offset: const Offset(0, 5))
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
        Row(children: [
          Expanded(
              child: _stat(
                  Icons.pending_actions_rounded,
                  'Waiting',
                  _requests
                      .where((r) =>
                          r['status'] == 'pending' ||
                          r['status'] == 'creative_submitted')
                      .length)),
          const SizedBox(width: 10),
          Expanded(
              child: _stat(
                  Icons.hourglass_top_rounded,
                  'In Review',
                  _requests
                      .where((r) => r['status'] == 'forwarded_to_admin')
                      .length)),
          const SizedBox(width: 10),
          Expanded(
              child: _stat(Icons.verified_rounded, 'Published',
                  _requests.where((r) => r['status'] == 'published').length)),
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
        ..._requests.map(_proposalCard),
        if (_requests.isEmpty)
          _empty('No proposals have been submitted by officers yet.'),
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
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FFFB), Color(0xFFDDF4E8)],
        ),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: line),
        boxShadow: [
          BoxShadow(
              color: green.withValues(alpha: .08),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Keep the important proposal information together at the top.
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
            SizedBox(
              width: double.infinity,
              height: 300,
              child: PageView.builder(
                itemCount: imgs.length,
                itemBuilder: (_, i) => Image.network(
                  imgs[i],
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: bg,
                    child: const Icon(Icons.broken_image_rounded,
                        color: green, size: 40),
                  ),
                ),
              ),
            ),
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
        Text(text,
            style: const TextStyle(
                color: dark, fontSize: 10.5, fontWeight: FontWeight.w800))
      ]));

  Widget _actions(Map<String, dynamic> r, String s) {
    if (s == 'pending') {
      return Row(children: [
        Expanded(
            child: OutlinedButton.icon(
                onPressed: () => _requestRevision(r),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Ask Revision'))),
        const SizedBox(width: 8),
        Expanded(
            child: FilledButton.icon(
                onPressed: () => _forward(r),
                icon: const Icon(Icons.forward_rounded),
                label: const Text('Forward')))
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
                label: const Text('Return to Officer'))),
        const SizedBox(width: 8),
        Expanded(
            child: FilledButton.icon(
                onPressed: () => _publish(r),
                icon: const Icon(Icons.publish_rounded),
                label: const Text('Approve & Publish')))
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
              style: FilledButton.styleFrom(backgroundColor: green)));

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
        const SizedBox(height: 10),
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
        const SizedBox(height: 10),
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
        const SizedBox(height: 10),
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
        const SizedBox(height: 10),
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
      ]);

  Widget _feature(
          IconData icon, String title, String subtitle, VoidCallback onTap) =>
      Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F8F62), Color(0xFF20B77D)]),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: .18)),
              boxShadow: [
                BoxShadow(
                    color: green.withValues(alpha: .13),
                    blurRadius: 18,
                    offset: const Offset(0, 8))
              ],
            ),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: Colors.white, size: 22)),
              const SizedBox(width: 13),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: .82),
                            fontSize: 11.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600)),
                  ])),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 15, color: Colors.white70),
            ]),
          ),
        ),
      );

  Widget _empty(String text) => Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFF8FFFB), Color(0xFFDDF4E8)]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: line),
          boxShadow: [
            BoxShadow(
                color: green.withValues(alpha: .06),
                blurRadius: 15,
                offset: const Offset(0, 6))
          ]),
      child: Column(children: [
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: green.withValues(alpha: .09), shape: BoxShape.circle),
            child: const Icon(Icons.eco_rounded, color: green, size: 25)),
        const SizedBox(height: 10),
        Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, height: 1.4))
      ]));

  Widget _imagePlaceholder() => Container(
      height: 160,
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
