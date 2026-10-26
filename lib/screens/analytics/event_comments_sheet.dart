import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/analytics_service.dart';
import '../../core/app_state.dart';
import '../auth/unified_login_page.dart';
import '../auth/sign_up_page.dart';

const _textColor = Color(0xFF262626);
const _secondaryColor = Color(0xFF737373);
const _dividerColor = Color(0xFFEFEFEF);
const _heartColor = Color(0xFFED4956);
const _mentionColor = Color(0xFF3B5BDB);
const _sendColor = Color(0xFF16A34A);

class EventCommentsSheet extends StatefulWidget {
  final String eventId;
  final String eventTitle;
  final bool asDialog;

  const EventCommentsSheet({
    super.key,
    required this.eventId,
    required this.eventTitle,
    this.asDialog = false,
  });

  @override
  State<EventCommentsSheet> createState() => _EventCommentsSheetState();
}

enum _CommentSort { top, newest, oldest }

class _ReplyTarget {
  final String parentCommentId;
  final String username;

  const _ReplyTarget(this.parentCommentId, this.username);
}

class _EventCommentsSheetState extends State<EventCommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final AnalyticsService _service = AnalyticsService.instance;

  bool _loading = true;
  bool _loadError = false;
  bool _sending = false;
  bool _promptingLogin = false;
  List<EventComment> _comments = <EventComment>[];
  Map<String, List<Map<String, dynamic>>> _repliesByComment = {};
  Map<String, int> _commentLikeCounts = {};
  Map<String, int> _replyLikeCounts = {};
  Map<String, String> _replyAvatars = {};
  Set<String> _likedCommentIds = {};

  Set<String> _likedReplyIds = {};
  final Set<String> _pendingCommentLikes = {};
  final Set<String> _pendingReplyLikes = {};
  _ReplyTarget? _replyingTo;
  final Set<String> _expandedThreads = {};
  _CommentSort _sort = _CommentSort.newest;

  RealtimeChannel? _commentChannel;

  RealtimeChannel? _reactionChannel;
  RealtimeChannel? _replyChannel;
  RealtimeChannel? _replyLikeChannel;
  Timer? _reloadDebounce;
  Timer? _relativeTimeTimer;
  int _loadGeneration = 0;

  SupabaseClient get _db => Supabase.instance.client;
  String? get _currentUserId => _db.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onDraftChanged);
    AppState.instance.addListener(_onAppStateChanged);
    _subscribeToChanges();
    _relativeTimeTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (mounted) setState(() {});
      },
    );
    _load();
  }

  void _subscribeToChanges() {
    _commentChannel = _db.channel('event-comments-sheet-${widget.eventId}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'event_comments',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'event_id',
          value: widget.eventId,
        ),
        callback: (_) => _scheduleReload(),
      ).subscribe();

    _reactionChannel = _db.channel('event-comment-reactions-${widget.eventId}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'event_comment_reactions',
        callback: (_) => _scheduleReload(),
      ).subscribe();

    _replyChannel = _db.channel('event-comment-replies-${widget.eventId}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'event_comment_replies',
        callback: (_) => _scheduleReload(),
      ).subscribe();

    _replyLikeChannel = _db.channel('event-reply-likes-${widget.eventId}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'event_reply_likes',
        callback: (_) => _scheduleReload(),
      ).subscribe();
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onAppStateChanged);
    _controller.removeListener(_onDraftChanged);
    _controller.dispose();
    _focusNode.dispose();
    _reloadDebounce?.cancel();
    _relativeTimeTimer?.cancel();

    if (_commentChannel != null) _db.removeChannel(_commentChannel!);
    if (_reactionChannel != null) _db.removeChannel(_reactionChannel!);
    if (_replyChannel != null) _db.removeChannel(_replyChannel!);
    if (_replyLikeChannel != null) _db.removeChannel(_replyLikeChannel!);

    super.dispose();
  }

  void _onDraftChanged() {
    if (mounted) setState(() {});
  }

  void _onAppStateChanged() => _scheduleReload();

  void _scheduleReload() {
    if (!mounted) return;
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 300), _load);
  }

  List<Map<String, dynamic>> _rows(dynamic value) => (value as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();

  Future<void> _load() async {
    final generation = ++_loadGeneration;

    if (mounted) {
      setState(() {
        if (_comments.isEmpty) _loading = true;
        _loadError = false;
      });
    }

    try {
      final comments = await _service.fetchComments(widget.eventId);
      if (!mounted || generation != _loadGeneration) return;

      final commentIds = comments.map((comment) => comment.id).toSet().toList();

      if (commentIds.isEmpty) {
        setState(() {
          _comments = comments;
          _repliesByComment = {};
          _commentLikeCounts = {};
          _replyLikeCounts = {};
          _replyAvatars = {};
          _likedCommentIds = {};
          _likedReplyIds = {};
          _loading = false;
          _loadError = false;
        });
        return;
      }

      final results = await Future.wait<dynamic>([
        _db
            .from('event_comment_reactions')
            .select('comment_id,user_id,reaction')
            .inFilter('comment_id', commentIds),
        _db
            .from('event_comment_replies')
            .select('id,comment_id,user_id,user_name,reply,created_at')
            .inFilter('comment_id', commentIds)
            .order('created_at'),
      ]);

      if (!mounted || generation != _loadGeneration) return;

      final reactionRows = _rows(results[0]);
      final replyRows = _rows(results[1]);

      final commentCounts = <String, int>{};
      final likedComments = <String>{};
      final userId = _currentUserId;

      for (final row in reactionRows) {
        final id = row['comment_id']?.toString();
        if (id == null) continue;

        commentCounts[id] = (commentCounts[id] ?? 0) + 1;

        if (userId != null && row['user_id']?.toString() == userId) {
          likedComments.add(id);
        }
      }

      final repliesByComment = <String, List<Map<String, dynamic>>>{};

      for (final row in replyRows) {
        final parentId = row['comment_id']?.toString();
        if (parentId == null) continue;

        repliesByComment.putIfAbsent(parentId, () => []).add(row);
      }

      final replyIds = replyRows
          .map((row) => row['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final replyUserIds = replyRows
          .map((row) => row['user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      var replyCounts = <String, int>{};
      var likedReplies = <String>{};
      var replyAvatars = <String, String>{};

      if (replyIds.isNotEmpty || replyUserIds.isNotEmpty) {
        final extraResults = await Future.wait<dynamic>([
          if (replyIds.isNotEmpty)
            _db
                .from('event_reply_likes')
                .select('reply_id,user_id')
                .inFilter('reply_id', replyIds)
          else
            Future.value(<Map<String, dynamic>>[]),
          if (replyUserIds.isNotEmpty)
            _db
                .from('profiles')
                .select('id,avatar_url')
                .inFilter('id', replyUserIds)
          else
            Future.value(<Map<String, dynamic>>[]),
        ]);

        if (!mounted || generation != _loadGeneration) return;

        for (final row in _rows(extraResults[0])) {
          final id = row['reply_id']?.toString();
          if (id == null) continue;

          replyCounts[id] = (replyCounts[id] ?? 0) + 1;

          if (userId != null && row['user_id']?.toString() == userId) {
            likedReplies.add(id);
          }
        }

        for (final row in _rows(extraResults[1])) {
          final id = row['id']?.toString();
          final url = row['avatar_url']?.toString();

          if (id != null && url != null && url.isNotEmpty) {
            replyAvatars[id] = url;
          }
        }
      }

      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        _comments = comments;
        _repliesByComment = repliesByComment;
        _commentLikeCounts = commentCounts;
        _replyLikeCounts = replyCounts;
        _replyAvatars = replyAvatars;
        _likedCommentIds = likedComments;
        _likedReplyIds = likedReplies;
        _loading = false;
        _loadError = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _requireLogin() async {
    if (!mounted || _promptingLogin) return;
    _promptingLogin = true;
    final navigator = Navigator.of(context);
    String? choice;

    try {
      choice = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: const Text('Log in to continue'),
          content: const Text(
            'Please log in or create an account to comment, reply, or react.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Not now'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('signup'),
              child: const Text('Create account'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop('login'),
              style: FilledButton.styleFrom(backgroundColor: _sendColor),
              child: const Text('Log in'),
            ),
          ],
        ),
      );
    } finally {
      _promptingLogin = false;
    }

    if (choice == null || !navigator.mounted) return;
    await navigator.push(
      MaterialPageRoute(
        builder: (_) =>
            choice == 'signup' ? const SignUpPage() : const UnifiedLoginPage(),
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final user = _db.auth.currentUser;
    if (text.isEmpty || _sending) return;
    if (user == null) {
      unawaited(_requireLogin());
      return;
    }

    final target = _replyingTo;

    setState(() => _sending = true);

    try {
      if (target == null) {
        final ok = await _service.addComment(
          eventId: widget.eventId,
          comment: text,
        );

        if (!mounted) return;

        if (!ok) {
          _showSnack(
            'Your session needs to be refreshed. Please try again.',
          );
          return;
        }
      } else {
        var authorName = '';

        try {
          final profile = await _db
              .from('profiles')
              .select('name')
              .eq('id', user.id)
              .maybeSingle();

          authorName = profile?['name']?.toString().trim() ?? '';
        } catch (_) {}

        if (authorName.isEmpty) {
          final emailPrefix = user.email?.split('@').first.trim() ?? '';
          authorName = emailPrefix.isNotEmpty ? emailPrefix : 'Member';
        }

        await _db.from('event_comment_replies').insert({
          'comment_id': target.parentCommentId,
          'user_id': user.id,
          'user_name': authorName,
          'reply': text,
        });

        if (!mounted) return;
      }

      _controller.clear();
      setState(() {
        if (target != null) _expandedThreads.add(target.parentCommentId);
        _replyingTo = null;
      });
      await _load();
    } catch (_) {
      if (mounted) {
        _showSnack(
          target == null
              ? 'Your comment could not be posted. Please try again.'
              : 'Could not send reply. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _beginReply(String parentCommentId, String username) {
    if (_currentUserId == null) {
      unawaited(_requireLogin());
      return;
    }

    final safeName = username.trim().isEmpty ? 'Member' : username.trim();

    setState(() => _replyingTo = _ReplyTarget(parentCommentId, safeName));

    _controller.value = TextEditingValue(
      text: '@$safeName ',
      selection: TextSelection.collapsed(offset: '@$safeName '.length),
    );

    _focusNode.requestFocus();
  }

  Future<void> _toggleCommentLike(EventComment comment) async {
    final user = _db.auth.currentUser;

    if (user == null) {
      unawaited(_requireLogin());
      return;
    }

    final id = comment.id;
    if (!_pendingCommentLikes.add(id)) return;

    final wasLiked = _likedCommentIds.contains(id);
    final oldCount = _commentLikeCounts[id] ?? 0;

    setState(() {
      if (wasLiked) {
        _likedCommentIds.remove(id);
      } else {
        _likedCommentIds.add(id);
      }

      final nextCount = oldCount + (wasLiked ? -1 : 1);
      _commentLikeCounts[id] = nextCount < 0 ? 0 : nextCount;
    });

    try {
      if (wasLiked) {
        await _db
            .from('event_comment_reactions')
            .delete()
            .eq('comment_id', id)
            .eq('user_id', user.id);
      } else {
        await _db.from('event_comment_reactions').upsert({
          'comment_id': id,
          'user_id': user.id,
          'reaction': 'heart',
        }, onConflict: 'comment_id,user_id');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (wasLiked) {
            _likedCommentIds.add(id);
          } else {
            _likedCommentIds.remove(id);
          }

          _commentLikeCounts[id] = oldCount;
        });

        _showSnack('Could not update like. Please try again.');
      }
    } finally {
      _pendingCommentLikes.remove(id);
    }
  }

  Future<void> _toggleReplyLike(Map<String, dynamic> reply) async {
    final user = _db.auth.currentUser;

    if (user == null) {
      unawaited(_requireLogin());
      return;
    }

    final id = reply['id']?.toString();
    if (id == null || id.isEmpty || !_pendingReplyLikes.add(id)) return;

    final wasLiked = _likedReplyIds.contains(id);
    final oldCount = _replyLikeCounts[id] ?? 0;

    setState(() {
      if (wasLiked) {
        _likedReplyIds.remove(id);
      } else {
        _likedReplyIds.add(id);
      }

      final nextCount = oldCount + (wasLiked ? -1 : 1);
      _replyLikeCounts[id] = nextCount < 0 ? 0 : nextCount;
    });

    try {
      if (wasLiked) {
        await _db
            .from('event_reply_likes')
            .delete()
            .eq('reply_id', id)
            .eq('user_id', user.id);
      } else {
        await _db.from('event_reply_likes').insert({
          'reply_id': id,
          'user_id': user.id,
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (wasLiked) {
            _likedReplyIds.add(id);
          } else {
            _likedReplyIds.remove(id);
          }

          _replyLikeCounts[id] = oldCount;
        });

        _showSnack('Could not update like. Please try again.');
      }
    } finally {
      _pendingReplyLikes.remove(id);
    }
  }

  Future<bool> _confirmDelete(String title, String description) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(title, style: const TextStyle(color: _textColor)),
        content: Text(
          description,
          style: const TextStyle(color: _secondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: _heartColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Future<void> _deleteComment(EventComment comment) async {
    final user = _db.auth.currentUser;

    if (user == null || comment.userId != user.id) return;

    if (!await _confirmDelete(
      'Delete comment?',
      'This comment will be removed.',
    )) {
      return;
    }

    try {
      await _db
          .from('event_comments')
          .delete()
          .eq('id', comment.id)
          .eq('user_id', user.id);

      await _load();
    } catch (_) {
      _showSnack('Could not delete this comment.');
    }
  }

  Future<void> _deleteReply(Map<String, dynamic> reply) async {
    final user = _db.auth.currentUser;
    final id = reply['id']?.toString();

    if (user == null || id == null || reply['user_id']?.toString() != user.id) {
      return;
    }

    if (!await _confirmDelete(
      'Delete reply?',
      'This reply will be removed.',
    )) {
      return;
    }

    try {
      await _db
          .from('event_comment_replies')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);

      await _load();
    } catch (_) {
      _showSnack('Could not delete this reply.');
    }
  }

  Future<void> _showItemMenu({
    required Offset globalPosition,
    required String parentCommentId,
    required String username,
    required Future<void> Function()? onDelete,
  }) async {
    if (!mounted) return;

    unawaited(HapticFeedback.selectionClick());

    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final overlaySize = overlay?.size ?? MediaQuery.sizeOf(context);
    final localPosition =
        overlay?.globalToLocal(globalPosition) ?? globalPosition;

    final dx = localPosition.dx.clamp(8.0, overlaySize.width - 8.0).toDouble();
    final dy = localPosition.dy.clamp(8.0, overlaySize.height - 8.0).toDouble();

    final selected = await showMenu<String>(
      context: context,
      color: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      position: RelativeRect.fromLTRB(
        dx,
        dy,
        overlaySize.width - dx,
        overlaySize.height - dy,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'reply',
          height: 42,
          child: Row(
            children: [
              Icon(Icons.reply_rounded, size: 19, color: _textColor),
              SizedBox(width: 10),
              Text('Reply', style: TextStyle(color: _textColor)),
            ],
          ),
        ),
        if (onDelete != null)
          const PopupMenuItem<String>(
            value: 'delete',
            height: 42,
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 19,
                  color: _heartColor,
                ),
                SizedBox(width: 10),
                Text('Delete', style: TextStyle(color: _heartColor)),
              ],
            ),
          ),
      ],
    );

    if (!mounted || selected == null) return;

    if (selected == 'reply') {
      _beginReply(parentCommentId, username);
    }

    if (selected == 'delete' && onDelete != null) {
      await onDelete();
    }
  }

  Offset _rowCenter(BuildContext context) {
    final object = context.findRenderObject();

    if (object is RenderBox) {
      return object.localToGlobal(object.size.center(Offset.zero));
    }

    return const Offset(24, 80);
  }

  Widget _avatar(String? url, double radius) {
    final validUrl = url?.trim() ?? '';

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFF0F0F0),
      child: validUrl.isEmpty
          ? Icon(
              Icons.person_rounded,
              size: radius + 2,
              color: _secondaryColor,
            )
          : ClipOval(
              child: SizedBox(
                width: radius * 2,
                height: radius * 2,
                child: Image.network(
                  validUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.person_rounded,
                    size: radius + 2,
                    color: _secondaryColor,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _heartButton({
    required bool liked,
    required int count,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 40,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              onPressed: onTap,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
              splashRadius: 20,
              tooltip: liked ? 'Unlike' : 'Like',
              icon: AnimatedScale(
                scale: liked ? 1.12 : 1,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                child: Icon(
                  liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 22,
                  color: liked ? _heartColor : _secondaryColor,
                ),
              ),
            ),
          ),
          if (count > 0)
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 10,
                color: _secondaryColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _commentRow(EventComment comment) {
    final isOwner = comment.userId != null && comment.userId == _currentUserId;
    final replies = _repliesByComment[comment.id] ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Builder(
          builder: (rowContext) => GestureDetector(
            onSecondaryTapUp: (details) => _showItemMenu(
              globalPosition: details.globalPosition,
              parentCommentId: comment.id,
              username: comment.userName,
              onDelete: isOwner ? () => _deleteComment(comment) : null,
            ),
            child: InkWell(
              onLongPress: () => _showItemMenu(
                globalPosition: _rowCenter(rowContext),
                parentCommentId: comment.id,
                username: comment.userName,
                onDelete: isOwner ? () => _deleteComment(comment) : null,
              ),
              borderRadius: BorderRadius.circular(8),
              highlightColor: const Color(0x0A000000),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _avatar(comment.avatarUrl, 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  comment.userName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _textColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                _time(comment.createdAt),
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _secondaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            comment.comment,
                            softWrap: true,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.32,
                              color: _textColor,
                            ),
                          ),
                          const SizedBox(height: 5),
                          GestureDetector(
                            onTap: () =>
                                _beginReply(comment.id, comment.userName),
                            child: const Text(
                              'Reply',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _secondaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 2),
                    _heartButton(
                      liked: _likedCommentIds.contains(comment.id),
                      count: _commentLikeCounts[comment.id] ?? 0,
                      onTap: () => _toggleCommentLike(comment),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (replies.isNotEmpty) _repliesSection(comment.id, replies),
      ],
    );
  }

  Widget _repliesSection(
    String commentId,
    List<Map<String, dynamic>> replies,
  ) {
    final expanded = _expandedThreads.contains(commentId);
    final count = replies.length;

    return Padding(
      padding: const EdgeInsets.only(left: 48, top: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (expanded)
            for (final reply in replies) _replyRow(commentId, reply),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => setState(() {
              if (expanded) {
                _expandedThreads.remove(commentId);
              } else {
                _expandedThreads.add(commentId);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 24, height: 1, color: _secondaryColor),
                  const SizedBox(width: 8),
                  Text(
                    expanded
                        ? 'Hide replies'
                        : 'View $count ${count == 1 ? 'reply' : 'replies'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _secondaryColor,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: _secondaryColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Every name that can be mentioned (comment authors + reply authors).
  List<String> _mentionableNames() {
    final names = <String>{
      for (final c in _comments) c.userName.trim(),
      for (final list in _repliesByComment.values)
        for (final r in list) (r['user_name']?.toString() ?? '').trim(),
    }..removeWhere((n) => n.isEmpty);

    // Longest first so "Gon Manliguez" wins over "Gon".
    return names.toList()..sort((a, b) => b.length.compareTo(a.length));
  }

  Widget _replyMessage(String message) {
    const style = TextStyle(
      color: _textColor,
      fontSize: 13,
      height: 1.3,
    );

    String? mention;
    final lower = message.toLowerCase();

    for (final name in _mentionableNames()) {
      final tag = '@$name';
      if (!lower.startsWith(tag.toLowerCase())) continue;

      // The name must end at a word boundary (space, punctuation, or end).
      final end = tag.length;
      if (end == message.length ||
          RegExp(r'[\s,.!?:;]').hasMatch(message[end])) {
        mention = message.substring(0, end);
        break;
      }
    }

    // Fallback for names we don't know (e.g. a deleted account).
    mention ??= RegExp(r'^(@[^\s]+)').firstMatch(message)?.group(0);

    if (mention == null) {
      return Text(message, style: style, softWrap: true);
    }

    return RichText(
      softWrap: true,
      text: TextSpan(
        style: style,
        children: [
          TextSpan(
            text: mention,
            style: const TextStyle(color: _mentionColor),
          ),
          TextSpan(text: message.substring(mention.length)),
        ],
      ),
    );
  }

  Widget _replyRow(String parentCommentId, Map<String, dynamic> reply) {
    final replyId = reply['id']?.toString() ?? '';
    final username = reply['user_name']?.toString() ?? 'Member';
    final userId = reply['user_id']?.toString();
    final isOwner = userId != null && userId == _currentUserId;

    final createdAt =
        DateTime.tryParse(reply['created_at']?.toString() ?? '') ??
            DateTime.now();

    final message = reply['reply']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Builder(
        builder: (rowContext) => GestureDetector(
          onSecondaryTapUp: (details) => _showItemMenu(
            globalPosition: details.globalPosition,
            parentCommentId: parentCommentId,
            username: username,
            onDelete: isOwner ? () => _deleteReply(reply) : null,
          ),
          child: InkWell(
            onLongPress: () => _showItemMenu(
              globalPosition: _rowCenter(rowContext),
              parentCommentId: parentCommentId,
              username: username,
              onDelete: isOwner ? () => _deleteReply(reply) : null,
            ),
            borderRadius: BorderRadius.circular(8),
            highlightColor: const Color(0x0A000000),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _avatar(_replyAvatars[userId], 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _textColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _time(createdAt),
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 10,
                                color: _secondaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        _replyMessage(message),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => _beginReply(parentCommentId, username),
                          child: const Text(
                            'Reply',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _secondaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 2),
                  _heartButton(
                    liked: _likedReplyIds.contains(replyId),
                    count: _replyLikeCounts[replyId] ?? 0,
                    onTap: () => _toggleReplyLike(reply),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  int get _totalCount =>
      _comments.length +
      _repliesByComment.values.fold<int>(0, (sum, list) => sum + list.length);

  String get _titleText {
    if (_loading || _loadError) return 'Comments';
    final n = _totalCount;
    return '$n ${n == 1 ? 'Comment' : 'Comments'}';
  }

  List<EventComment> _sortedComments() {
    final list =
        List<EventComment>.of(_comments); // copy, never sort the original

    int newestFirst(EventComment a, EventComment b) =>
        b.createdAt.compareTo(a.createdAt);

    if (_sort == _CommentSort.newest) {
      list.sort(newestFirst);
    } else if (_sort == _CommentSort.oldest) {
      list.sort((a, b) => newestFirst(b, a));
    } else {
      list.sort((a, b) {
        final diff =
            (_commentLikeCounts[b.id] ?? 0) - (_commentLikeCounts[a.id] ?? 0);
        return diff != 0 ? diff : newestFirst(a, b); // tie-breaker
      });
    }
    return list;
  }

  PopupMenuItem<_CommentSort> _sortItem(_CommentSort value, String label) {
    final selected = _sort == value;
    return PopupMenuItem<_CommentSort>(
      value: value,
      height: 42,
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: selected
                ? const Icon(Icons.check_rounded, size: 18, color: _textColor)
                : null,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: _textColor,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sortButton() {
    return PopupMenuButton<_CommentSort>(
      tooltip: 'Sort comments',
      padding: EdgeInsets.zero,
      enabled: _comments.isNotEmpty, // nothing to sort when empty
      color: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      icon: const Icon(Icons.filter_list_rounded, size: 20, color: _textColor),
      onSelected: (value) {
        if (value != _sort) setState(() => _sort = value);
      },
      itemBuilder: (_) => [
        _sortItem(_CommentSort.top, 'Top'),
        _sortItem(_CommentSort.newest, 'Newest'),
        _sortItem(_CommentSort.oldest, 'Oldest'),
      ],
    );
  }

  Widget _emptyState() => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 34,
                color: Color(0xFFBDBDBD),
              ),
              SizedBox(height: 12),
              Text(
                'No comments yet',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Be the first to comment.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: _secondaryColor,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _body() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.3,
            color: _secondaryColor,
          ),
        ),
      );
    }

    if (_loadError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Could not load comments.',
              style: TextStyle(
                fontSize: 13,
                color: _secondaryColor,
              ),
            ),
            TextButton(
              onPressed: _load,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    if (_comments.isEmpty) return _emptyState();

    final sorted = _sortedComments();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) => _commentRow(sorted[index]),
    );
  }

  Widget _composer() {
    final profile = AppState.instance.currentStudent;
    final avatarUrl = profile?.avatarUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingTo != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(10, 6, 5, 6),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFDBDBDB)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Replying to ${_replyingTo!.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _secondaryColor,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cancel reply',
                    onPressed: () {
                      setState(() => _replyingTo = null);
                      _controller.clear();
                      _focusNode.unfocus();
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: _secondaryColor,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 30,
                      minHeight: 30,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4, right: 9),
                child: _avatar(avatarUrl, 17),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 4, 5, 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFDBDBDB)),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 500,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _send(),
                          style: const TextStyle(
                            fontSize: 14,
                            color: _textColor,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Join the conversation…',
                            hintStyle: TextStyle(
                              color: _secondaryColor,
                              fontSize: 14,
                            ),
                            counterText: '',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      if (_controller.text.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 1),
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: Material(
                              color: _sendColor,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _sending ? null : _send,
                                child: Center(
                                  child: _sending
                                      ? const SizedBox(
                                          width: 15,
                                          height: 15,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.arrow_upward_rounded,
                                          size: 19,
                                          color: Colors.white,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Header + list + composer. Shared by the bottom sheet and the desktop dialog.
  Widget _sheetContent({required bool showHandle}) {
    return Column(
      children: [
        if (showHandle) ...[
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD0D0D0),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _titleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, 2),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: _sortButton(),
                      ),
                    ),
                  ],
                ),
              ),
              // Desktop dialog only: there is no drag handle, so show a close button.
              if (!showHandle)
                Positioned(
                  right: 6,
                  child: IconButton(
                    tooltip: 'Close',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: _textColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: _dividerColor),
        Expanded(child: _body()),
        const Divider(height: 1, thickness: 1, color: _dividerColor),
        _composer(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Desktop dialog: the Dialog already provides the card, size, rounded
    // corners and tap-outside-to-close, so only the content is needed.
    if (widget.asDialog) {
      return _sheetContent(showHandle: false);
    }

    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.viewInsets.bottom;
    final sheetHeight = availableHeight * 0.85;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).maybePop(), // tap outside closes
      child: Padding(
        padding:
            EdgeInsets.only(bottom: media.viewInsets.bottom), // above keyboard
        child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {}, // taps inside the sheet must not close it
              child: SizedBox(
                height: sheetHeight,
                width: double.infinity,
                child: Material(
                  color: Colors.white,
                  clipBehavior: Clip.antiAlias,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: _sheetContent(showHandle: true),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _time(DateTime date) {
    var difference = DateTime.now().difference(date);
    if (difference.isNegative) difference = Duration.zero;

    if (difference.inSeconds < 60) return 'now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    if (difference.inDays < 365) return '${difference.inDays ~/ 7}w';

    return '${difference.inDays ~/ 365}y';
  }
}

class EventCommentCountLabel extends StatefulWidget {
  final String eventId;
  final TextStyle? style;

  const EventCommentCountLabel({
    super.key,
    required this.eventId,
    this.style,
  });

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
      'event-comment-count-${widget.eventId}-${identityHashCode(this)}',
    )..onPostgresChanges(
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
      'event-comment-count-replies-${widget.eventId}-${identityHashCode(this)}',
    )..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'event_comment_replies',
        callback: (_) => _loadCount(),
      ).subscribe();

    _reactionChannel = Supabase.instance.client.channel(
      'event-comment-count-reactions-${widget.eventId}-${identityHashCode(this)}',
    )..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'event_comment_reactions',
        callback: (_) => _loadCount(),
      ).subscribe();
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

      if (mounted) {
        setState(() {
          _count = commentRows.length + replyCount;
          _reactionCount = reactionCount;
        });
      }
    } catch (_) {
      if (mounted && _count == null) setState(() => _count = 0);
    }
  }

  @override
  void didUpdateWidget(covariant EventCommentCountLabel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.eventId != widget.eventId) {
      if (_channel != null) {
        Supabase.instance.client.removeChannel(_channel!);
      }

      _count = null;
      _loadCount();

      _channel = Supabase.instance.client.channel(
        'event-comment-count-${widget.eventId}-${identityHashCode(this)}',
      )..onPostgresChanges(
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
    }
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    if (_replyChannel != null) {
      Supabase.instance.client.removeChannel(_replyChannel!);
    }
    if (_reactionChannel != null) {
      Supabase.instance.client.removeChannel(_reactionChannel!);
    }

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
  final screen = MediaQuery.sizeOf(context);
  final isDesktop = screen.width >= 900 && screen.height >= 500;

  if (isDesktop) {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        // Smaller than the event details dialog (620 wide, up to 88% / 820 tall).
        final dialogHeight = (MediaQuery.sizeOf(dialogContext).height * 0.72)
            .clamp(380.0, 640.0)
            .toDouble();
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: SizedBox(
            width: 500,
            height: dialogHeight,
            child: EventCommentsSheet(
              eventId: eventId,
              eventTitle: eventTitle,
              asDialog: true,
            ),
          ),
        );
      },
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => EventCommentsSheet(
      eventId: eventId,
      eventTitle: eventTitle,
    ),
  );
}
