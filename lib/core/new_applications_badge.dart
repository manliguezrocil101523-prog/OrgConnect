import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Counts applications that arrived since the officer last opened the
/// applications screen. Seen-state is stored on this device and uses the
/// server's created_at, so device clock differences don't matter.
class NewApplicationsBadge {
  NewApplicationsBadge._();
  static final NewApplicationsBadge instance = NewApplicationsBadge._();

  final ValueNotifier<int> count = ValueNotifier<int>(0);
  RealtimeChannel? _channel;
  String? _orgId;

  SupabaseClient get _db => Supabase.instance.client;

  String _key(String orgId) =>
      'officer_apps_seen_${_db.auth.currentUser?.id ?? 'local'}_$orgId';

  Future<DateTime?> _latestCreatedAt(String orgId) async {
    final rows = await _db
        .from('applications')
        .select('created_at')
        .eq('org_id', orgId)
        .order('created_at', ascending: false)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return DateTime.tryParse(list.first['created_at']?.toString() ?? '');
  }

  Future<void> _saveSeen(String orgId) async {
    final latest = await _latestCreatedAt(orgId) ?? DateTime.utc(1970);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(orgId), latest.toUtc().toIso8601String());
  }

  Future<void> start(String orgId) async {
    if (_orgId == orgId && _channel != null) {
      await refresh();
      return;
    }
    await stop();
    _orgId = orgId;
    await refresh();
    _channel = _db.channel('officer-new-apps-$orgId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'applications',
        filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq, column: 'org_id', value: orgId),
        callback: (_) => refresh(),
      )
      ..subscribe();
  }

  Future<void> stop() async {
    final ch = _channel;
    _channel = null;
    _orgId = null;
    count.value = 0;
    if (ch != null) await _db.removeChannel(ch);
  }

  Future<void> refresh() async {
    final orgId = _orgId;
    if (orgId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(orgId));
      final seen = raw == null ? null : DateTime.tryParse(raw);
      if (seen == null) {
        await _saveSeen(orgId); // first run: don't flood with old items
        count.value = 0;
        return;
      }
      final rows = await _db
          .from('applications')
          .select('id')
          .eq('org_id', orgId)
          .gt('created_at', seen.toUtc().toIso8601String());
      count.value = (rows as List).length;
    } catch (_) {
      // The badge is cosmetic and must never block a screen.
    }
  }

  Future<void> markSeen() async {
    final orgId = _orgId;
    if (orgId == null) return;
    count.value = 0;
    try {
      await _saveSeen(orgId);
    } catch (_) {}
  }
}
