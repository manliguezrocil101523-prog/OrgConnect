import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class OrgCommunityChatScreen extends StatefulWidget {
  final String orgId, orgName;
  final bool showBackButton;
  final String? initialMessage;
  final Future<void> Function()? onMessageSent;
  const OrgCommunityChatScreen(
      {super.key,
      required this.orgId,
      required this.orgName,
      this.showBackButton = true,
      this.initialMessage,
      this.onMessageSent});
  @override
  State<OrgCommunityChatScreen> createState() => _OrgCommunityChatScreenState();
}

class _OrgCommunityChatScreenState extends State<OrgCommunityChatScreen> {
  final db = Supabase.instance.client;
  final ctrl = TextEditingController();
  final scroll = ScrollController();
  List<Map<String, dynamic>> rows = [];
  Map<String, dynamic>? _replyingTo;
  final Map<String, DateTime> _reads = {};
  RealtimeChannel? _readsChannel;
  DateTime? _lastMarked;
  bool loading = true, sending = false;
  RealtimeChannel? _channel;
  RealtimeChannel? _typingChannel;
  final Map<String, Timer> _typingTimers = {};
  final Map<String, String> _typingNames = {};
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);
  String _myTypingName = 'Someone';

  static const primaryGreen = Color(0xFF0B6B4D);
  static const accentGreen = Color(0xFF16A34A);
  static const bubbleBg1 = Color(0xFFF8FFFB);
  static const bubbleBg2 = Color(0xFFDDF4E8);
  static const dark = Color(0xFF12352A);
  static const muted = Color(0xFF64748B);
  static const imageMarker = '[[ORGCONNECT_IMAGE]]';

  bool _isLegacyVideoCallMessage(Map<String, dynamic> row) {
    final raw = row['message']?.toString().trim().toLowerCase() ?? '';
    if (raw.isEmpty) return false;
    return raw.contains('[[orgconnect_video_call]]') ||
        raw.contains('orgconnect_video_call') ||
        raw.contains('meet.jit.si') ||
        raw.contains('jitsi') ||
        raw.contains('webrtc') ||
        raw.contains('video call') ||
        raw.contains('videocall');
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null &&
        widget.initialMessage!.trim().isNotEmpty) {
      ctrl.text = widget.initialMessage!.trim();
      ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
    }

    _load();
    _subscribeToMessages();
    _subscribeReads();
    _initTyping();
  }

  void _subscribeToMessages() {
    _channel = db.channel('org-community-chat-${widget.orgId}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'org_chat_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'org_id',
          value: widget.orgId,
        ),
        callback: (payload) {
          final row = Map<String, dynamic>.from(payload.newRecord);
          if (_isLegacyVideoCallMessage(row)) return;
          if (!mounted ||
              rows.any((m) => m['id']?.toString() == row['id']?.toString())) {
            return;
          }
          setState(() {
            rows.add(row);
            rows.sort((a, b) =>
                (DateTime.tryParse(a['created_at']?.toString() ?? '') ??
                        DateTime.fromMillisecondsSinceEpoch(0))
                    .compareTo(
                        DateTime.tryParse(b['created_at']?.toString() ?? '') ??
                            DateTime.fromMillisecondsSinceEpoch(0)));
          });
          _scrollToBottom();
          _markRead();
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'org_chat_messages',
        filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'org_id',
            value: widget.orgId),
        callback: (payload) {
          final row = Map<String, dynamic>.from(payload.newRecord);
          if (_isLegacyVideoCallMessage(row) || !mounted) return;
          final id = row['id']?.toString();
          if (id == null) return;
          final index = rows.indexWhere((m) => m['id']?.toString() == id);
          if (index == -1) return;
          setState(() => rows[index] = row);
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'org_chat_messages',
        callback: (payload) {
          final row = Map<String, dynamic>.from(payload.oldRecord);
          final id = row['id']?.toString();
          if (!mounted || id == null) return;
          setState(() => rows.removeWhere((m) => m['id']?.toString() == id));
        },
      ).subscribe();
  }

  Future<void> _load() async {
    try {
      final r = await db
          .from('org_chat_messages')
          .select('*')
          .eq('org_id', widget.orgId)
          .order('created_at', ascending: true);
      if (!mounted) return;
      final loaded = List<Map<String, dynamic>>.from(r as List)
          .where((row) => !_isLegacyVideoCallMessage(row))
          .toList();
      loaded.sort((a, b) =>
          (DateTime.tryParse(a['created_at']?.toString() ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(DateTime.tryParse(b['created_at']?.toString() ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0)));
      setState(() => rows = loaded);
      _loadReads();
      _markRead();
      _scrollToBottom();
    } catch (e) {
      if (mounted) _snack('Could not load community messages: $e', true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _send() async {
    final text = ctrl.text.trim();
    final user = db.auth.currentUser;
    if (text.isEmpty || user == null || sending) return;

    FocusScope.of(context).unfocus();
    setState(() => sending = true);

    try {
      String senderName = user.userMetadata?['name']?.toString() ??
          user.email?.split('@').first ??
          'Member';
      String senderRole = user.userMetadata?['role']?.toString() ?? 'member';

      try {
        final profile = await db
            .from('profiles')
            .select('name,role')
            .eq('id', user.id)
            .maybeSingle();
        if (profile != null) {
          final name = profile['name']?.toString().trim();
          if (name != null && name.isNotEmpty) senderName = name;
          final role = profile['role']?.toString().trim();
          if (role != null && role.isNotEmpty) senderRole = role;
        }
      } catch (_) {}

      final inserted = await db
          .from('org_chat_messages')
          .insert({
            'org_id': widget.orgId,
            'sender_id': user.id,
            'sender_name': senderName,
            'sender_role': senderRole,
            'message': text,
            if (_replyingTo != null) 'reply_to_id': _replyingTo!['id'],
          })
          .select()
          .single();

      if (mounted) {
        setState(() {
          rows.add(Map<String, dynamic>.from(inserted));
          ctrl.clear();
          _replyingTo = null;
        });
      }
      try {
        await widget.onMessageSent?.call();
      } catch (_) {}
      _scrollToBottom();
    } on PostgrestException catch (e) {
      if (mounted) _snack('Message was not sent: ${e.message}', true);
    } catch (e) {
      if (mounted) _snack('Message was not sent: $e', true);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _pickAndSendImages() async {
    final user = db.auth.currentUser;
    if (user == null || sending) return;
    final files = await FilePicker.platform
        .pickFiles(type: FileType.image, allowMultiple: true, withData: true);
    if (files == null || files.files.isEmpty) return;
    setState(() => sending = true);
    try {
      String senderName = user.userMetadata?['name']?.toString() ??
          user.email?.split('@').first ??
          'Member';
      String senderRole = user.userMetadata?['role']?.toString() ?? 'member';
      try {
        final profile = await db
            .from('profiles')
            .select('name,role')
            .eq('id', user.id)
            .maybeSingle();
        if (profile != null) {
          final name = profile['name']?.toString().trim();
          if (name != null && name.isNotEmpty) senderName = name;
          final role = profile['role']?.toString().trim();
          if (role != null && role.isNotEmpty) senderRole = role;
        }
      } catch (_) {}
      for (final file in files.files) {
        if (file.bytes == null) continue;
        final ext = (file.extension ?? 'jpg').toLowerCase();
        final contentType = ext == 'png'
            ? 'image/png'
            : ext == 'webp'
                ? 'image/webp'
                : 'image/jpeg';
        final path =
            'community_chat/${widget.orgId}/${user.id}_${DateTime.now().microsecondsSinceEpoch}.$ext';
        await db.storage.from('org-assets').uploadBinary(path, file.bytes!,
            fileOptions: FileOptions(contentType: contentType, upsert: true));
        final url = db.storage.from('org-assets').getPublicUrl(path);
        final inserted = await db
            .from('org_chat_messages')
            .insert({
              'org_id': widget.orgId,
              'sender_id': user.id,
              'sender_name': senderName,
              'sender_role': senderRole,
              'message': '$imageMarker$url',
            })
            .select()
            .single();
        if (mounted) {
          setState(() => rows.add(Map<String, dynamic>.from(inserted)));
        }
      }
      _snack('Picture sent to the community chat.');
      _scrollToBottom();
    } on PostgrestException catch (e) {
      if (mounted) _snack('Picture was not sent: ${e.message}', true);
    } catch (e) {
      if (mounted) _snack('Picture was not sent: $e', true);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _editMessage(Map<String, dynamic> row) async {
    final userId = db.auth.currentUser?.id;
    if (userId == null || row['sender_id']?.toString() != userId) return;
    final raw = row['message']?.toString() ?? '';
    if (raw.startsWith(imageMarker)) {
      _snack('Pictures cannot be edited. You can delete the message instead.');
      return;
    }
    final editCtrl = TextEditingController(text: raw);
    final edited = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
            controller: editCtrl,
            autofocus: true,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, editCtrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    editCtrl.dispose();
    if (edited == null || edited.isEmpty || edited == raw) return;
    try {
      final updated = await db
          .from('org_chat_messages')
          .update({'message': edited})
          .eq('id', row['id'])
          .select();
      if ((updated as List).isEmpty) {
        if (mounted) {
          _snack('Could not edit message. You can only edit your own messages.',
              true);
        }
        return;
      }
      if (mounted) {
        setState(() {
          final i = rows
              .indexWhere((m) => m['id']?.toString() == row['id']?.toString());
          if (i != -1) rows[i] = {...rows[i], 'message': edited};
        });
      }
    } on PostgrestException catch (e) {
      if (mounted) _snack('Could not edit message: ${e.message}', true);
    }
  }

  Future<void> _deleteMessage(Map<String, dynamic> row) async {
    final userId = db.auth.currentUser?.id;
    if (userId == null || row['sender_id']?.toString() != userId) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text(
            'This message will be removed for everyone in the community chat.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final deleted = await db
          .from('org_chat_messages')
          .delete()
          .eq('id', row['id'])
          .select();
      if ((deleted as List).isEmpty) {
        if (mounted) {
          _snack(
              'Could not delete message. You can only delete your own messages.',
              true);
        }
        return;
      }
      if (mounted) {
        setState(() => rows
            .removeWhere((m) => m['id']?.toString() == row['id']?.toString()));
      }
    } on PostgrestException catch (e) {
      if (mounted) _snack('Could not delete message: ${e.message}', true);
    }
  }

  void _messageMenu(Map<String, dynamic> row) {
    final isMine = row['sender_id']?.toString() == db.auth.currentUser?.id;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyingTo = row);
              }),
          if (isMine) ...[
            ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Edit message'),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(row);
                }),
            ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Delete message'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(row);
                }),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
      }
    });
  }

  void _snack(String message, [bool error = false]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : primaryGreen,
        behavior: SnackBarBehavior.floating));
  }

  @override
  void dispose() {
    ctrl.removeListener(_onComposerChanged);
    for (final t in _typingTimers.values) {
      t.cancel();
    }
    final typingChannel = _typingChannel;
    if (typingChannel != null) db.removeChannel(typingChannel);
    _channel?.unsubscribe();
    _readsChannel?.unsubscribe();
    ctrl.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(color: primaryGreen))
                    : rows.isEmpty
                        ? _empty()
                        : ListView.builder(
                            controller: scroll,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                            itemCount: rows.length,
                            itemBuilder: (_, i) => Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [_message(rows[i]), _seenLabel(i)],
                            ),
                          ),
              ),
              _composer(),
            ],
          ),
        ),
      ),
    );
  }

  // Custom straight-bottom header with no icon before the title
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(widget.showBackButton ? 8 : 16,
          MediaQuery.paddingOf(context).top + 12, 16, 16),
      decoration: const BoxDecoration(
        color: primaryGreen,
        borderRadius: BorderRadius.zero, // Completely straight bottom edge
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.showBackButton)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          if (widget.showBackButton) const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4ADE80),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'COMMUNITY CHAT',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.orgName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  'One shared space for members, officers, and advisers.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => Center(
      child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(27),
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [bubbleBg1, bubbleBg2]),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: primaryGreen.withValues(alpha: .10)),
              boxShadow: [
                BoxShadow(
                    color: primaryGreen.withValues(alpha: .06),
                    blurRadius: 20,
                    offset: const Offset(0, 8))
              ]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                    gradient:
                        LinearGradient(colors: [primaryGreen, accentGreen]),
                    shape: BoxShape.circle),
                child: const Icon(Icons.forum_rounded,
                    color: Colors.white, size: 34)),
            const SizedBox(height: 14),
            const Text('Your community space',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900, color: dark)),
            const SizedBox(height: 6),
            const Text(
                'Start a conversation with officers, advisers, and organization members.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, height: 1.4, fontSize: 12.5))
          ])));

  Widget _message(Map<String, dynamic> r) {
    if (_isLegacyVideoCallMessage(r)) return const SizedBox.shrink();
    final me = r['sender_id'] == db.auth.currentUser?.id;
    final role = r['sender_role']?.toString() ?? 'member';
    final name = r['sender_name']?.toString() ?? 'Member';
    final raw = r['message']?.toString() ?? '';
    final isImage = raw.startsWith(imageMarker);
    final imageUrl = isImage ? raw.substring(imageMarker.length).trim() : '';

    return GestureDetector(
      onLongPress: () => _messageMenu(r),
      onSecondaryTap: () => _messageMenu(r),
      child: Align(
        alignment: me ? Alignment.centerRight : Alignment.centerLeft,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 350),
              margin: const EdgeInsets.only(bottom: 11),
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
              decoration: BoxDecoration(
                // Both user and adviser messages now share the exact same clean background style
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [bubbleBg1, bubbleBg2]),
                borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(me ? 18 : 5),
                    bottomRight: Radius.circular(me ? 5 : 18)),
                border: Border.all(color: primaryGreen.withValues(alpha: .12)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: .035),
                      blurRadius: 12,
                      offset: const Offset(0, 5)),
                ],
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$name • $role',
                        style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: muted)),
                    const SizedBox(height: 7),
                    if (r['reply_to_id'] != null)
                      _replyQuote(r['reply_to_id'], me),
                    if (isImage)
                      ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(imageUrl,
                              width: 300,
                              height: 190,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                  width: 300,
                                  height: 190,
                                  color: Colors.white,
                                  child: const Icon(Icons.broken_image_rounded,
                                      color: primaryGreen, size: 34))))
                    else
                      Text(raw,
                          style: const TextStyle(
                              color: dark, height: 1.4, fontSize: 13)),
                  ]),
            ),
            if (me && MediaQuery.sizeOf(context).width >= 700)
              Positioned(
                right: -46,
                top: 2,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 2,
                  child: PopupMenuButton<String>(
                    tooltip: 'Message options',
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_horiz_rounded, size: 20),
                    onSelected: (value) {
                      if (value == 'edit') _editMessage(r);
                      if (value == 'delete') _deleteMessage(r);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.edit_rounded),
                              title: Text('Edit message'))),
                      PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.delete_outline_rounded),
                              title: Text('Delete message'))),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  DateTime? _ts(dynamic v) => DateTime.tryParse(v?.toString() ?? '');

  Future<void> _loadReads() async {
    try {
      final r = await db
          .from('org_chat_reads')
          .select('user_id,last_read_at')
          .eq('org_id', widget.orgId);
      if (!mounted) return;
      setState(() {
        for (final x in List<Map<String, dynamic>>.from(r as List)) {
          final t = _ts(x['last_read_at']);
          if (t != null) _reads[x['user_id'].toString()] = t;
        }
      });
    } catch (_) {}
  }

  Future<void> _markRead() async {
    final user = db.auth.currentUser;
    if (user == null || rows.isEmpty) return;
    final latest = _ts(rows.last['created_at']);
    if (latest == null) return;
    if (_lastMarked != null && !latest.isAfter(_lastMarked!)) return;
    _lastMarked = latest;
    try {
      await db.from('org_chat_reads').upsert({
        'org_id': widget.orgId,
        'user_id': user.id,
        'last_read_at': rows.last['created_at'],
      }, onConflict: 'org_id,user_id');
    } catch (_) {}
  }

  void _subscribeReads() {
    _readsChannel = db.channel('org-chat-reads-${widget.orgId}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'org_chat_reads',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'org_id',
          value: widget.orgId,
        ),
        callback: (payload) {
          final row = payload.newRecord;
          final uid = row['user_id']?.toString();
          final t = _ts(row['last_read_at']);
          if (!mounted || uid == null || t == null) return;
          setState(() => _reads[uid] = t);
        },
      ).subscribe();
  }

  Widget _seenLabel(int i) {
    final me = db.auth.currentUser?.id;
    final r = rows[i];
    if (me == null || r['sender_id']?.toString() != me) {
      return const SizedBox.shrink();
    }
    final lastMine =
        rows.lastIndexWhere((m) => m['sender_id']?.toString() == me);
    if (i != lastMine) return const SizedBox.shrink();
    final sent = _ts(r['created_at']);
    if (sent == null) return const SizedBox.shrink();
    final n = _reads.entries
        .where((e) => e.key != me && !e.value.isBefore(sent))
        .length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(n > 0 ? 'Seen by $n' : 'Sent',
            style: const TextStyle(fontSize: 10.5, color: muted)),
      ),
    );
  }

  String _previewText(String raw) =>
      raw.startsWith(imageMarker) ? 'Photo' : raw;

  Widget _replyQuote(dynamic replyToId, bool me) {
    final id = replyToId.toString();
    final i = rows.indexWhere((m) => m['id']?.toString() == id);
    final original = i == -1 ? null : rows[i];
    final label = original == null
        ? 'Message deleted'
        : (original['sender_name']?.toString() ?? 'Member');
    final body = original == null
        ? ''
        : _previewText(original['message']?.toString() ?? '');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: primaryGreen.withValues(alpha: .10),
        border: const Border(left: BorderSide(color: primaryGreen, width: 3)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    fontStyle:
                        original == null ? FontStyle.italic : FontStyle.normal,
                    color: dark)),
            if (body.isNotEmpty)
              Text(body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: muted)),
          ]),
    );
  }

  Future<void> _initTyping() async {
    final user = db.auth.currentUser;
    if (user == null) return;
    _myTypingName = user.userMetadata?['name']?.toString() ??
        user.email?.split('@').first ??
        'Someone';
    try {
      final p = await db
          .from('profiles')
          .select('name')
          .eq('id', user.id)
          .maybeSingle();
      final n = p?['name']?.toString().trim();
      if (n != null && n.isNotEmpty) _myTypingName = n;
    } catch (_) {}
    if (!mounted) return;
    _typingChannel = db.channel('org-typing-${widget.orgId}')
      ..onBroadcast(event: 'typing', callback: _onTypingEvent)
      ..subscribe();
    ctrl.addListener(_onComposerChanged);
  }

  void _onComposerChanged() {
    if (ctrl.text.trim().isEmpty) return;
    final now = DateTime.now();
    if (now.difference(_lastTypingSent).inMilliseconds < 2000) return;
    _lastTypingSent = now;
    _sendTyping();
  }

  Future<void> _sendTyping() async {
    final user = db.auth.currentUser;
    if (user == null) return;
    try {
      await _typingChannel?.sendBroadcastMessage(
        event: 'typing',
        payload: {'user_id': user.id, 'name': _myTypingName},
      );
    } catch (_) {}
  }

  void _onTypingEvent(Map<String, dynamic> payload) {
    final data = payload['payload'] is Map
        ? Map<String, dynamic>.from(payload['payload'] as Map)
        : payload;
    final uid = data['user_id']?.toString() ?? '';
    if (uid.isEmpty || uid == db.auth.currentUser?.id || !mounted) return;
    _typingNames[uid] = data['name']?.toString() ?? 'Someone';
    _typingTimers[uid]?.cancel();
    _typingTimers[uid] = Timer(const Duration(seconds: 3), () {
      _typingTimers.remove(uid);
      _typingNames.remove(uid);
      if (mounted) setState(() {});
    });
    setState(() {});
  }

  Widget _typingLabel() {
    if (_typingNames.isEmpty) return const SizedBox.shrink();
    final names = _typingNames.values.toList();
    final text = names.length == 1
        ? '${names[0]} is typing...'
        : names.length == 2
            ? '${names[0]} and ${names[1]} are typing...'
            : 'Several people are typing...';
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11.5, fontStyle: FontStyle.italic, color: muted)),
    );
  }

  Widget _replyBar() {
    final r = _replyingTo;
    if (r == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(children: [
        const Icon(Icons.reply_rounded, size: 18, color: primaryGreen),
        const SizedBox(width: 8),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Replying to ${r['sender_name'] ?? 'Member'}',
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: primaryGreen)),
            Text(_previewText(r['message']?.toString() ?? ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: muted)),
          ]),
        ),
        IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () => setState(() => _replyingTo = null)),
      ]),
    );
  }

  Widget _composer() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [_typingLabel(), _replyBar(), _composerBar()],
      );

  Widget _composerBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border:
            Border(top: BorderSide(color: primaryGreen.withValues(alpha: .10))),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 12, offset: Offset(0, -3))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: sending ? null : _pickAndSendImages,
              icon: const Icon(Icons.image_rounded, color: primaryGreen),
              tooltip: 'Send picture',
            ),
            Expanded(
              child: TextField(
                controller: ctrl,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Write a message...',
                  filled: true,
                  fillColor: bubbleBg1,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide:
                          const BorderSide(color: primaryGreen, width: 1.5)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: sending ? null : _send,
              icon: sending
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: primaryGreen))
                  : const Icon(Icons.send_rounded, color: primaryGreen),
              tooltip: 'Send message',
            ),
          ],
        ),
      ),
    );
  }
}
