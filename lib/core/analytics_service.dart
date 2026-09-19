import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_state.dart';

class EventComment {
  final String id;
  final String eventId;
  final String userName;
  final String comment;
  final DateTime createdAt;

  EventComment({required this.id, required this.eventId, required this.userName, required this.comment, required this.createdAt});

  factory EventComment.fromMap(Map<String, dynamic> row) => EventComment(
        id: row['id']?.toString() ?? '',
        eventId: row['event_id']?.toString() ?? '',
        userName: row['user_name']?.toString() ?? 'Member',
        comment: row['comment']?.toString() ?? '',
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
}

class OrgAnalyticsRow {
  final String name;
  final int members;
  final int events;
  final int comments;
  final int views;

  const OrgAnalyticsRow({required this.name, required this.members, required this.events, required this.comments, required this.views});
}

class AnalyticsSnapshot {
  final int activeMembers;
  final int totalMembers;
  final int totalEvents;
  final int totalComments;
  final int totalViews;
  final List<OrgAnalyticsRow> organizations;
  final Map<String, int> usageByAction;

  const AnalyticsSnapshot({required this.activeMembers, required this.totalMembers, required this.totalEvents, required this.totalComments, required this.totalViews, required this.organizations, required this.usageByAction});
}

class AnalyticsService {
  AnalyticsService._();
  static final instance = AnalyticsService._();
  final SupabaseClient _db = Supabase.instance.client;

  Future<void> logUsage(String action, {String? route, Map<String, dynamic>? metadata}) async {
    try {
      final userId = _db.auth.currentUser?.id;
      await _db.from('usage_logs').insert({
        'user_id': userId,
        'action': action,
        'route': route,
        'metadata': metadata ?? <String, dynamic>{},
      });
      if (userId != null) {
        await _db.from('profiles').update({'last_seen_at': DateTime.now().toIso8601String()}).eq('id', userId);
      }
    } catch (_) {
      // Telemetry must never block the app when the optional analytics table is absent.
    }
  }

  Future<void> logEventView(String eventId) async {
    try {
      await _db.from('event_views').insert({'event_id': eventId, 'user_id': _db.auth.currentUser?.id});
    } catch (_) {}
  }

  Future<List<EventComment>> fetchComments(String eventId) async {
    try {
      final rows = await _db.from('event_comments').select().eq('event_id', eventId).order('created_at', ascending: true);
      return (rows as List).map((e) => EventComment.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> addComment({required String eventId, required String comment}) async {
    if (comment.trim().isEmpty) return false;

    // The app's student state and Supabase session must stay in sync.
    // If a valid refresh token exists, recover the session before deciding
    // that the user is a guest. This prevents a false "sign in to comment"
    // message after the app has already restored the student's profile.
    var user = _db.auth.currentUser;
    if (user == null && AppState.instance.currentStudent != null) {
      try {
        final refreshed = await _db.auth.refreshSession();
        user = refreshed.session?.user ?? _db.auth.currentUser;
      } catch (_) {
        user = _db.auth.currentUser;
      }
    }

    try {
      String name;
      if (user == null) {
        name = 'Guest';
      } else {
        final profile = await _db.from('profiles').select('name').eq('id', user.id).maybeSingle();
        final profileName = profile?['name']?.toString().trim();
        final localName = AppState.instance.currentStudent?.name.trim();
        name = profileName?.isNotEmpty == true
            ? profileName!
            : (localName?.isNotEmpty == true
                ? localName!
                : (user.email?.split('@').first ?? 'Member'));
      }

      await _db.from('event_comments').insert({
        'event_id': eventId,
        'user_id': user?.id,
        'user_name': name,
        'comment': comment.trim(),
      });
      await logUsage('comment_event', route: 'event:$eventId');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<AnalyticsSnapshot> loadSnapshot() async {
    var activeMembers = 0;
    var totalMembers = 0;
    var totalEvents = 0;
    var totalComments = 0;
    var totalViews = 0;
    final rows = <OrgAnalyticsRow>[];
    final usage = <String, int>{};

    try {
      final members = await _db.from('members').select('id,org_name');
      totalMembers = (members as List).length;
      final counts = <String, int>{};
      for (final row in members) {
        final name = row['org_name']?.toString() ?? 'Unknown';
        counts[name] = (counts[name] ?? 0) + 1;
      }

      try {
        final profiles = await _db.from('profiles').select('id,active,last_seen_at,role');
        final now = DateTime.now();
        activeMembers = (profiles as List).where((p) {
          final role = p['role']?.toString();
          if (role != 'student') return false;
          if (p['active'] == false) return false;
          final last = DateTime.tryParse(p['last_seen_at']?.toString() ?? '');
          return last != null && now.difference(last).inMinutes <= 30;
        }).length;
      } catch (_) {}

      final events = await _db.from('events').select('id,org_name');
      totalEvents = (events as List).length;
      final eventCounts = <String, int>{};
      for (final row in events) {
        final name = row['org_name']?.toString() ?? 'Unknown';
        eventCounts[name] = (eventCounts[name] ?? 0) + 1;
      }

      try {
        final comments = await _db.from('event_comments').select('event_id');
        totalComments = (comments as List).length;
      } catch (_) {}
      try {
        final views = await _db.from('event_views').select('event_id');
        totalViews = (views as List).length;
      } catch (_) {}
      try {
        final logs = await _db.from('usage_logs').select('action');
        for (final row in (logs as List)) {
          final action = row['action']?.toString() ?? 'unknown';
          usage[action] = (usage[action] ?? 0) + 1;
        }
      } catch (_) {}

      final orgNames = {...counts.keys, ...eventCounts.keys}.toList()..sort();
      for (final name in orgNames) {
        rows.add(OrgAnalyticsRow(
          name: name,
          members: counts[name] ?? 0,
          events: eventCounts[name] ?? 0,
          comments: 0,
          views: 0,
        ));
      }
    } catch (_) {}

    return AnalyticsSnapshot(activeMembers: activeMembers, totalMembers: totalMembers, totalEvents: totalEvents, totalComments: totalComments, totalViews: totalViews, organizations: rows, usageByAction: usage);
  }

  Future<List<Map<String, dynamic>>> loadImpactForStudent(String studentId) async {
    try {
      final rows = await _db.from('student_impact').select().eq('student_id', studentId).order('updated_at', ascending: false);
      return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }
}
