import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/analytics_service.dart';
import '../../core/app_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventCommentsSheet extends StatefulWidget {
  final String eventId;
  final String eventTitle;

  const EventCommentsSheet(
      {super.key, required this.eventId, required this.eventTitle});

  @override
  State<EventCommentsSheet> createState() => _EventCommentsSheetState();
}

class _EventCommentsSheetState extends State<EventCommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final AnalyticsService _service = AnalyticsService.instance;
  bool _loading = true;
  bool _sending = false;
  List<EventComment> _comments = <EventComment>[];
  RealtimeChannel? _commentChannel;
  RealtimeChannel? _reactionChannel;
  RealtimeChannel? _replyChannel;

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onRealtimeCommentsChanged);
    final db = Supabase.instance.client;
    _commentChannel = db.channel('event-comments-sheet-${widget.eventId}')
      ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'event_comments',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'event_id',
              value: widget.eventId),
          callback: (_) => _load()).subscribe();
    _reactionChannel = db.channel('event-comment-reactions-${widget.eventId}')
      ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'event_comment_reactions',
          callback: (_) {
            if (mounted) setState(() {});
          }).subscribe();
    _replyChannel = db.channel('event-comment-replies-${widget.eventId}')
      ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'event_comment_replies',
          callback: (_) {
            if (mounted) setState(() {});
          }).subscribe();
    _load();
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onRealtimeCommentsChanged);
    final db = Supabase.instance.client;
    if (_commentChannel != null) db.removeChannel(_commentChannel!);
    if (_reactionChannel != null) db.removeChannel(_reactionChannel!);
    if (_replyChannel != null) db.removeChannel(_replyChannel!);
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
    final ok =
        await _service.addComment(eventId: widget.eventId, comment: text);
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

  Future<void> _showCommentActions(
      EventComment comment, BuildContext anchorContext) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login required to react or reply.')));
      return;
    }
    const choices = <String, String>{
      'like': '👍',
      'heart': '❤️',
      'wow': '😮',
      'laugh': '😂',
      'sad': '😢',
      'angry': '😡'
    };
    final anchor = anchorContext.findRenderObject();
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    final anchorBox = anchor is RenderBox ? anchor : null;
    final position = anchorBox != null && overlayBox != null
        ? anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox)
        : const Offset(20, 120);
    final completer = Completer<String?>();
    late OverlayEntry picker;
    picker = OverlayEntry(
        builder: (ctx) => Stack(children: [
              Positioned.fill(
                  child: GestureDetector(
                      onTap: () {
                        if (!completer.isCompleted) completer.complete(null);
                        picker.remove();
                      },
                      child: Container(color: Colors.transparent))),
              Positioned(
                left: (position.dx - 12)
                    .clamp(8.0, MediaQuery.of(context).size.width - 270)
                    .toDouble(),
                top: (position.dy - 54)
                    .clamp(8.0, MediaQuery.of(context).size.height - 70)
                    .toDouble(),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 12,
                              offset: Offset(0, 3))
                        ]),
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: choices.entries
                            .map((entry) => InkWell(
                                  onTap: () {
                                    if (!completer.isCompleted)
                                      completer.complete(entry.key);
                                    picker.remove();
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 3),
                                      child: Text(entry.value,
                                          style:
                                              const TextStyle(fontSize: 20))),
                                ))
                            .toList()),
                  ),
                ),
              ),
            ]));
    overlay.insert(picker);
    final picked = await completer.future;
    if (picker.mounted) picker.remove();
    if (picked != null) {
      try {
        await Supabase.instance.client.from('event_comment_reactions').upsert({
          'comment_id': comment.id,
          'user_id': user.id,
          'reaction': picked,
        }, onConflict: 'comment_id,user_id');
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.selectionClick();
        _showFloatingReaction(choices[picked] ?? '👍');
        if (mounted) setState(() {});
      } catch (_) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Could not save reaction. Check Supabase permissions.')));
      }
    }
  }

  Future<void> _deleteComment(EventComment comment) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || comment.userId != user.id) return;
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Delete comment?'),
              content: const Text('This comment will be removed.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete'))
              ],
            ));
    if (confirm != true) return;
    try {
      await Supabase.instance.client
          .from('event_comments')
          .delete()
          .eq('id', comment.id)
          .eq('user_id', user.id);
      await _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete this comment.')));
    }
  }

  Future<void> _deleteReply(Map<String, dynamic> reply) async {
    final user = Supabase.instance.client.auth.currentUser;
    final replyId = reply['id']?.toString();
    if (user == null ||
        replyId == null ||
        reply['user_id']?.toString() != user.id) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete reply?'),
        content: const Text('This reply will be permanently deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await Supabase.instance.client
          .from('event_comment_replies')
          .delete()
          .eq('id', replyId)
          .eq('user_id', user.id);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete this reply.')),
        );
      }
    }
  }

  void _showFloatingReaction(String emoji) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _FloatingReaction(emoji: emoji));
    overlay.insert(entry);
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (entry.mounted) entry.remove();
    });
  }

  Future<void> _replyToComment(EventComment comment) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login required to reply.')));
      return;
    }
    final replyCtrl = TextEditingController();
    final text = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Reply to comment'),
              content: TextField(
                  controller: replyCtrl,
                  autofocus: true,
                  maxLength: 500,
                  decoration:
                      const InputDecoration(hintText: 'Write a reply…')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, replyCtrl.text.trim()),
                    child: const Text('Reply'))
              ],
            ));
    replyCtrl.dispose();
    if (text == null || text.isEmpty) return;
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('name')
          .eq('id', user.id)
          .maybeSingle();
      await Supabase.instance.client.from('event_comment_replies').insert({
        'comment_id': comment.id,
        'user_id': user.id,
        'user_name': profile?['name']?.toString() ??
            user.email?.split('@').first ??
            'Member',
        'reply': text
      });
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Could not send reply. Check Supabase permissions.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.eventTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          Text('${_comments.length} comments',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _comments.isEmpty
                        ? const Center(
                            child: Text(
                                'No comments yet. Start the conversation.'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                            itemCount: _comments.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              final comment = _comments[index];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: dark
                                      ? const Color(0xFF172B1D)
                                      : const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                              radius: 17,
                                              backgroundColor:
                                                  const Color(0xFFDDF7E8),
                                              backgroundImage:
                                                  (comment.avatarUrl != null &&
                                                          comment.avatarUrl!
                                                              .isNotEmpty)
                                                      ? NetworkImage(
                                                          comment.avatarUrl!)
                                                      : null,
                                              child: (comment.avatarUrl ==
                                                          null ||
                                                      comment
                                                          .avatarUrl!.isEmpty)
                                                  ? const Icon(
                                                      Icons.person_rounded,
                                                      color: Color(0xFF16804A),
                                                      size: 19)
                                                  : null),
                                          const SizedBox(width: 9),
                                          Expanded(
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                Text(comment.userName,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700)),
                                                const SizedBox(height: 4),
                                                GestureDetector(
                                                    onLongPress: () =>
                                                        _showCommentActions(
                                                            comment, context),
                                                    child:
                                                        Text(comment.comment)),
                                                const SizedBox(height: 5),
                                                Row(children: [
                                                  Text(_time(comment.createdAt),
                                                      style: const TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.grey)),
                                                  const SizedBox(width: 12),
                                                  InkWell(
                                                      onTap: () =>
                                                          _replyToComment(
                                                              comment),
                                                      child: const Text('Reply',
                                                          style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              color: Color(
                                                                  0xFF16804A)))),
                                                  const SizedBox(width: 10),
                                                  InkWell(
                                                      onTap: () =>
                                                          _showCommentActions(
                                                              comment, context),
                                                      child: const Text('React',
                                                          style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              color: Color(
                                                                  0xFF16804A)))),
                                                  if (comment.userId != null &&
                                                      comment.userId ==
                                                          Supabase
                                                              .instance
                                                              .client
                                                              .auth
                                                              .currentUser
                                                              ?.id) ...[
                                                    const SizedBox(width: 10),
                                                    InkWell(
                                                        onTap: () =>
                                                            _deleteComment(
                                                                comment),
                                                        child: const Text(
                                                            'Delete',
                                                            style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: Colors
                                                                    .redAccent))),
                                                  ],
                                                ]),
                                                FutureBuilder<
                                                    List<Map<String, dynamic>>>(
                                                  future: Supabase
                                                      .instance.client
                                                      .from(
                                                          'event_comment_reactions')
                                                      .select('reaction')
                                                      .eq('comment_id',
                                                          comment.id)
                                                      .then((rows) => (rows
                                                              as List)
                                                          .map((e) => Map<
                                                              String,
                                                              dynamic>.from(e))
                                                          .toList())
                                                      .catchError((_) => <Map<
                                                          String, dynamic>>[]),
                                                  builder: (context,
                                                      reactionSnapshot) {
                                                    final reactions =
                                                        reactionSnapshot.data ??
                                                            const <Map<String,
                                                                dynamic>>[];
                                                    if (reactions.isEmpty)
                                                      return const SizedBox
                                                          .shrink();
                                                    const emojiMap = {
                                                      'like': '👍',
                                                      'heart': '❤️',
                                                      'wow': '😮',
                                                      'laugh': '😂',
                                                      'sad': '😢',
                                                      'angry': '😡'
                                                    };
                                                    final counts =
                                                        <String, int>{};
                                                    for (final item
                                                        in reactions) {
                                                      final key = item[
                                                                  'reaction']
                                                              ?.toString() ??
                                                          '';
                                                      counts[key] =
                                                          (counts[key] ?? 0) +
                                                              1;
                                                    }
                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              top: 6),
                                                      child: Wrap(
                                                          spacing: 5,
                                                          children: counts
                                                              .entries
                                                              .map(
                                                                  (entry) =>
                                                                      Container(
                                                                        padding: const EdgeInsets
                                                                            .symmetric(
                                                                            horizontal:
                                                                                7,
                                                                            vertical:
                                                                                3),
                                                                        decoration: BoxDecoration(
                                                                            color: dark
                                                                                ? const Color(0xFF294533)
                                                                                : Colors.white,
                                                                            borderRadius: BorderRadius.circular(12)),
                                                                        child: Text(
                                                                            '${emojiMap[entry.key] ?? '👍'} ${entry.value}',
                                                                            style:
                                                                                const TextStyle(fontSize: 11)),
                                                                      ))
                                                              .toList()),
                                                    );
                                                  },
                                                ),
                                              ])),
                                        ]),
                                    FutureBuilder<List<Map<String, dynamic>>>(
                                      future: Supabase.instance.client
                                          .from('event_comment_replies')
                                          .select(
                                              'id,user_id,user_name,reply,created_at')
                                          .eq('comment_id', comment.id)
                                          .order('created_at')
                                          .then((rows) => (rows as List)
                                              .map((e) =>
                                                  Map<String, dynamic>.from(e))
                                              .toList())
                                          .catchError(
                                              (_) => <Map<String, dynamic>>[]),
                                      builder: (context, snapshot) {
                                        final replies = snapshot.data ??
                                            const <Map<String, dynamic>>[];
                                        if (replies.isEmpty)
                                          return const SizedBox.shrink();
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              left: 42, top: 9),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: replies.map<Widget>((r) {
                                              return Container(
                                                margin: const EdgeInsets.only(
                                                    bottom: 5),
                                                padding:
                                                    const EdgeInsets.all(9),
                                                decoration: BoxDecoration(
                                                  color: dark
                                                      ? const Color(0xFF203A29)
                                                      : Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: RichText(
                                                        text: TextSpan(
                                                          style: TextStyle(
                                                            color: dark
                                                                ? Colors.white
                                                                : const Color(
                                                                    0xFF20352B),
                                                            fontSize: 12,
                                                          ),
                                                          children: [
                                                            TextSpan(
                                                              text:
                                                                  '${r['user_name'] ?? 'Member'}  ',
                                                              style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800),
                                                            ),
                                                            TextSpan(
                                                                text: r['reply']
                                                                        ?.toString() ??
                                                                    ''),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    if (r['user_id']
                                                            ?.toString() ==
                                                        Supabase
                                                            .instance
                                                            .client
                                                            .auth
                                                            .currentUser
                                                            ?.id)
                                                      IconButton(
                                                        tooltip:
                                                            'Delete your reply',
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                        constraints:
                                                            const BoxConstraints(
                                                                minWidth: 28,
                                                                minHeight: 28),
                                                        padding:
                                                            EdgeInsets.zero,
                                                        icon: const Icon(
                                                            Icons
                                                                .delete_outline_rounded,
                                                            size: 16,
                                                            color: Colors
                                                                .redAccent),
                                                        onPressed: () =>
                                                            _deleteReply(r),
                                                      ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        );
                                      },
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
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded),
                      style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A)),
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

class EventCommentCountLabel extends StatefulWidget {
  final String eventId;
  final TextStyle? style;
  const EventCommentCountLabel({super.key, required this.eventId, this.style});

  @override
  State<EventCommentCountLabel> createState() => _EventCommentCountLabelState();
}

class _EventCommentCountLabelState extends State<EventCommentCountLabel> {
  int? _count;
  int _reactionCount = 0;
  RealtimeChannel? _channel;
  RealtimeChannel? _replyChannel;
  RealtimeChannel? _reactionChannel;

  @override
  void initState() {
    super.initState();
    _loadCount();
    _channel = Supabase.instance.client.channel(
        'event-comment-count-${widget.eventId}-${identityHashCode(this)}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'event_comments',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'event_id',
          value: widget.eventId,
        ),
        callback: (_) => _loadCount(),
      ).subscribe();
    _replyChannel = Supabase.instance.client.channel(
        'event-comment-count-replies-${widget.eventId}-${identityHashCode(this)}')
      ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'event_comment_replies',
          callback: (_) => _loadCount()).subscribe();
    _reactionChannel = Supabase.instance.client.channel(
        'event-comment-count-reactions-${widget.eventId}-${identityHashCode(this)}')
      ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'event_comment_reactions',
          callback: (_) => _loadCount()).subscribe();
  }

  Future<void> _loadCount() async {
    try {
      final db = Supabase.instance.client;
      final rows = await db
          .from('event_comments')
          .select('id')
          .eq('event_id', widget.eventId);
      final commentRows = (rows as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      final ids = commentRows
          .map((r) => r['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      var replyCount = 0;
      var reactionCount = 0;
      if (ids.isNotEmpty) {
        try {
          final replies = await db
              .from('event_comment_replies')
              .select('id')
              .inFilter('comment_id', ids);
          replyCount = (replies as List).length;
        } catch (_) {}
        try {
          final reactions = await db
              .from('event_comment_reactions')
              .select('id')
              .inFilter('comment_id', ids);
          reactionCount = (reactions as List).length;
        } catch (_) {}
      }
      if (mounted)
        setState(() {
          _count = commentRows.length + replyCount;
          _reactionCount = reactionCount;
        });
    } catch (_) {
      if (mounted && _count == null) setState(() => _count = 0);
    }
  }

  @override
  void didUpdateWidget(covariant EventCommentCountLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId) {
      if (_channel != null) Supabase.instance.client.removeChannel(_channel!);
      _count = null;
      _loadCount();
      _channel = Supabase.instance.client.channel(
          'event-comment-count-${widget.eventId}-${identityHashCode(this)}')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'event_comments',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'event_id',
              value: widget.eventId),
          callback: (_) => _loadCount(),
        ).subscribe();
    }
  }

  @override
  void dispose() {
    if (_channel != null) Supabase.instance.client.removeChannel(_channel!);
    if (_replyChannel != null)
      Supabase.instance.client.removeChannel(_replyChannel!);
    if (_reactionChannel != null)
      Supabase.instance.client.removeChannel(_reactionChannel!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
        'Comments${_count == null ? '' : ' ($_count)'} · Reactions ($_reactionCount)',
        style: widget.style,
      );
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
    builder: (_) =>
        EventCommentsSheet(eventId: eventId, eventTitle: eventTitle),
  );
}

class _FloatingReaction extends StatefulWidget {
  final String emoji;
  const _FloatingReaction({required this.emoji});
  @override
  State<_FloatingReaction> createState() => _FloatingReactionState();
}

class _FloatingReactionState extends State<_FloatingReaction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))
    ..forward();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => Align(
              alignment: Alignment(0.55, 0.8 - _controller.value * 1.6),
              child: Opacity(
                opacity: (1 - _controller.value).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.7 + _controller.value * 1.2,
                  child: Text(widget.emoji,
                      style: const TextStyle(fontSize: 38, shadows: [
                        Shadow(color: Color(0x66880000), blurRadius: 8)
                      ])),
                ),
              ),
            ),
          ),
        ),
      );
}
