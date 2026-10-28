import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Counts chat messages from other people that are newer than my
/// last_read_at in org_chat_reads, for one org. Used for the red badge.
class ChatUnread {
  ChatUnread._();
  static final ChatUnread instance = ChatUnread._();

  final ValueNotifier<int> count = ValueNotifier<int>(0);
  RealtimeChannel? _channel;
  String? _orgId;

  SupabaseClient get _db => Supabase.instance.client;

  Future<void> start(String orgId) async {
    if (_orgId == orgId && _channel != null) {
      await refresh();
      return;
    }
    stop();
    _orgId = orgId;
    await refresh();
    _channel = _db.channel('chat-unread-$orgId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'org_chat_messages',
        filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq, column: 'org_id', value: orgId),
        callback: (_) => refresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'org_chat_reads',
        filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq, column: 'org_id', value: orgId),
        callback: (_) => refresh(),
      )
      ..subscribe();
  }

  void stop() {
    final c = _channel;
    if (c != null) _db.removeChannel(c);
    _channel = null;
    _orgId = null;
    count.value = 0;
  }

  Future<void> refresh() async {
    final orgId = _orgId;
    final uid = _db.auth.currentUser?.id;
    if (orgId == null || uid == null) {
      count.value = 0;
      return;
    }
    try {
      final read = await _db
          .from('org_chat_reads')
          .select('last_read_at')
          .eq('org_id', orgId)
          .eq('user_id', uid)
          .maybeSingle();
      var q = _db
          .from('org_chat_messages')
          .select('id')
          .eq('org_id', orgId)
          .neq('sender_id', uid);
      final last = read?['last_read_at']?.toString();
      if (last != null) q = q.gt('created_at', last);
      final rows = await q;
      count.value = (rows as List).length;
    } catch (_) {}
  }
}
