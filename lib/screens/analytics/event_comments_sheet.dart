import 'package:flutter/material.dart';
import '../../core/analytics_service.dart';
import '../../core/app_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventCommentsSheet extends StatefulWidget {
  final String eventId;
  final String eventTitle;

  const EventCommentsSheet({super.key, required this.eventId, required this.eventTitle});

  @override
  State<EventCommentsSheet> createState() => _EventCommentsSheetState();
}

class _EventCommentsSheetState extends State<EventCommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final AnalyticsService _service = AnalyticsService.instance;
  bool _loading = true;
  bool _sending = false;
  List<EventComment> _comments = <EventComment>[];

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onRealtimeCommentsChanged);
    _load();
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onRealtimeCommentsChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onRealtimeCommentsChanged() {
    if (!mounted) return;
    _load();
  }

  Future<void> _load() async {
    final comments = await _service.fetchComments(widget.eventId);
    if (!mounted) return;
    setState(() {
      _comments = comments;
      _loading = false;
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    final ok = await _service.addComment(eventId: widget.eventId, comment: text);
    if (!mounted) return;

    if (ok) {
      _controller.clear();
      await _load();
    } else {
      final hasLoggedInProfile = AppState.instance.currentStudent != null;
      final hasSession = Supabase.instance.client.auth.currentUser != null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasLoggedInProfile || hasSession
                ? 'Your session needs to be refreshed. Please try again.'
                : 'Your comment could not be posted. Please try again.',
          ),
        ),
      );
    }

    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 650),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF102016) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    const Icon(Icons.forum_rounded, color: Color(0xFF16A34A)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.eventTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _comments.isEmpty
                        ? const Center(child: Text('No comments yet. Start the conversation.'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                            itemCount: _comments.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              final comment = _comments[index];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: dark ? const Color(0xFF172B1D) : const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(comment.userName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(comment.comment),
                                    const SizedBox(height: 5),
                                    Text(
                                      _time(comment.createdAt),
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          hintText: 'Write a comment…',
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                          ),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded),
                      style: IconButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _time(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.month}/${date.day}/${date.year} $hour:$minute';
  }
}

Future<void> showEventComments(
  BuildContext context, {
  required String eventId,
  required String eventTitle,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => EventCommentsSheet(eventId: eventId, eventTitle: eventTitle),
  );
}


/// Facebook-style reactions shared by event cards across the app.
/// Uses the existing public.event_reactions table and the signed-in Supabase user.
class EventReactionBar extends StatefulWidget {
  final String eventId;
  const EventReactionBar({super.key, required this.eventId});

  @override
  State<EventReactionBar> createState() => _EventReactionBarState();
}

class _EventReactionBarState extends State<EventReactionBar> {
  static const _choices = <String, String>{
    'like': '👍',
    'heart': '❤️',
    'wow': '😮',
    'laugh': '😂',
    'sad': '😢',
    'angry': '😡',
  };
  final _db = Supabase.instance.client;
  Map<String, int> _counts = {};
  String? _mine;
  bool _busy = false;
  RealtimeChannel? _reactionChannel;

  @override
  void initState() {
    super.initState();
    _load();
    _reactionChannel = _db.channel('event-reactions-${widget.eventId}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'event_reactions',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'event_id', value: widget.eventId),
        callback: (_) => _load(),
      )
      ..subscribe();
  }

  @override
  void dispose() {
    final channel = _reactionChannel;
    if (channel != null) _db.removeChannel(channel);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await _db.from('event_reactions').select('user_id,reaction').eq('event_id', widget.eventId);
      final counts = <String, int>{};
      String? mine;
      final userId = _db.auth.currentUser?.id;
      for (final raw in rows as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final reaction = row['reaction']?.toString() ?? '';
        counts[reaction] = (counts[reaction] ?? 0) + 1;
        if (userId != null && row['user_id']?.toString() == userId) mine = reaction;
      }
      if (mounted) setState(() { _counts = counts; _mine = mine; });
    } catch (_) {
      // Reactions remain optional if the current user's RLS policy disallows reads.
    }
  }

  Future<void> _toggle(String reaction) async {
    final user = _db.auth.currentUser;
    if (user == null || _busy) {
      if (user == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to react to events.')));
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final existing = await _db.from('event_reactions').select('id,reaction')
          .eq('event_id', widget.eventId).eq('user_id', user.id).maybeSingle();
      if (existing != null) {
        if (existing['reaction']?.toString() == reaction) {
          await _db.from('event_reactions').delete().eq('id', existing['id']);
        } else {
          await _db.from('event_reactions').update({'reaction': reaction, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', existing['id']);
        }
      } else {
        await _db.from('event_reactions').insert({'event_id': widget.eventId, 'user_id': user.id, 'reaction': reaction});
      }
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save your reaction. Please check your connection and permissions.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 2),
          child: Text('React', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF4D6F62))),
        ),
        ..._choices.entries.map((entry) {
        final selected = _mine == entry.key;
        final count = _counts[entry.key] ?? 0;
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _busy ? null : () => _toggle(entry.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFDDF7E8) : const Color(0xFFF5F8F6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? const Color(0xFF16A34A) : const Color(0xFFE2E8E5)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(entry.value, style: const TextStyle(fontSize: 17)),
              if (count > 0) ...[const SizedBox(width: 4), Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: selected ? const Color(0xFF166534) : const Color(0xFF64748B)))],
            ]),
          ),
        );
      }),
      ],
    );
  }
}
