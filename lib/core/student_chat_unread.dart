import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Unread chat messages (from others, newer than my last_read_at)
/// across every org the student joined (members.profile_id).
class StudentChatUnread {
  StudentChatUnread._();
  static final StudentChatUnread instance = StudentChatUnread._();

  final ValueNotifier<int> count = ValueNotifier<int>(0);
  RealtimeChannel? _channel;
  bool _running = false;

  SupabaseClient get _db => Supabase.instance.client;

  Future<void> start() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    if (_running) {
      await refresh();
      return;
    }
    _running = true;
    await refresh();
    _channel = _db.channel('student-chat-unread-$uid')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'org_chat_messages',
        callback: (_) => refresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'org_chat_reads',
        filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
        callback: (_) => refresh(),
      )
      ..subscribe();
  }

  void stop() {
    final c = _channel;
    if (c != null) _db.removeChannel(c);
    _channel = null;
    _running = false;
    count.value = 0;
  }

  Future<void> refresh() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) {
      count.value = 0;
      return;
    }
    try {
      final mem =
          await _db.from('members').select('org_id').eq('profile_id', uid);
      final orgIds = <String>{
        for (final r in (mem as List))
          if (r['org_id'] != null) r['org_id'].toString()
      };
      if (orgIds.isEmpty) {
        count.value = 0;
        return;
      }
      final reads = await _db
          .from('org_chat_reads')
          .select('org_id,last_read_at')
          .eq('user_id', uid);
      final lastRead = <String, String>{
        for (final r in (reads as List))
          r['org_id'].toString(): r['last_read_at'].toString()
      };
      var total = 0;
      for (final org in orgIds) {
        var q = _db
            .from('org_chat_messages')
            .select('id')
            .eq('org_id', org)
            .neq('sender_id', uid);
        final last = lastRead[org];
        if (last != null) q = q.gt('created_at', last);
        final rows = await q.limit(100);
        total += (rows as List).length;
      }
      count.value = total;
    } catch (_) {}
  }
}
