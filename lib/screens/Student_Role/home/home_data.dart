import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../core/app_state.dart';

/// Read-only data helpers for the new Home tab.
/// Every method fails safe: on error it returns an empty/zero result.
class HomeData {
  /// org id -> number of members (uses get_org_member_counts()).
  static Future<Map<String, int>> fetchOrgMemberCounts() async {
    try {
      final rows =
          await supabase.Supabase.instance.client.rpc('get_org_member_counts');
      final out = <String, int>{};
      for (final r in (rows as List)) {
        final id = r['org_id']?.toString() ?? '';
        if (id.isEmpty) continue;
        out[id] = (r['member_count'] as num?)?.toInt() ?? 0;
      }
      return out;
    } catch (e) {
      debugPrint('HomeData.fetchOrgMemberCounts failed: $e');
      return <String, int>{};
    }
  }

  /// event id -> number of reactions (shown as "interested").
  static Future<Map<String, int>> fetchEventInterestCounts(
      Iterable<String> eventIds) async {
    final ids = eventIds.where((e) => e.isNotEmpty).toList();
    if (ids.isEmpty) return <String, int>{};
    try {
      final rows = await supabase.Supabase.instance.client
          .from('event_interests')
          .select('event_id')
          .inFilter('event_id', ids);
      final out = <String, int>{};
      for (final r in (rows as List)) {
        final id = r['event_id']?.toString() ?? '';
        if (id.isEmpty) continue;
        out[id] = (out[id] ?? 0) + 1;
      }
      return out;
    } catch (e) {
      debugPrint('HomeData.fetchEventInterestCounts failed: $e');
      return <String, int>{};
    }
  }

  /// Applications still in progress for the signed-in user (badge number).
  static int inProgressApplicationCount() {
    final uid = supabase.Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return 0;
    const active = {
      ApplicationStatus.pending,
      ApplicationStatus.interviewScheduled,
      ApplicationStatus.interviewed,
      ApplicationStatus.forApproval,
    };
    return AppState.instance.applications
        .where((a) => a.userId == uid && active.contains(a.status))
        .length;
  }

  /// Same unread rule the old dashboard used for its bell badge.
  static int unreadNotificationCount() {
    final student = AppState.instance.currentStudent;
    if (student == null) return 0;
    return AppState.instance.notifications.where((n) {
      final title = n.title.toLowerCase();
      final message = n.message.toLowerCase();
      final isInterview = title.contains('interview') ||
          message.contains('scheduled interview');
      final isMember = title.contains('congratulations') ||
          message.contains('officially a member');
      return (n.studentId == student.id || n.studentId == student.studentId) &&
          (isInterview || isMember) &&
          !n.read;
    }).length;
  }

  /// Upcoming events, soonest first. Same visibility rule as before:
  /// not in the past, and posted within the last [maxAgeDays] days.
  static List<Event> upcomingEvents({int maxAgeDays = 30}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = now.subtract(Duration(days: maxAgeDays));
    final list = AppState.instance.events.where((e) {
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      return !day.isBefore(today) && !e.createdAt.isBefore(cutoff);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }
}
