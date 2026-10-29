import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/app_header.dart';

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
  bool loading = true, sending = false;
  RealtimeChannel? _channel;

  // Green is now used only as a small accent (send button, focus ring, loader).
  static const green = Color(0xFF16A34A);
  static const bright = Color(0xFF22C55E);
  static const bg = Color(0xFFFFFFFF);
  static const dark = Color(0xFF111827);
  static const muted = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const fieldBg = Color(0xFFF3F4F6);
  static const bubbleOther = Color(0xFFF3F4F6);
  static const bubbleMine = Color(0xFF1F2937);
  static const imageMarker = '[[ORGCONNECT_IMAGE]]';

  // Max width of the content column on tablets / desktop / web.
  static const double _contentMaxWidth = 900;

  // Legacy video-call messages were created by an older version of OrgConnect.
  // Video calling has been removed from the app, so these old database rows
  // must never be displayed in the community chat for any role.
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

      // Profile lookup is helpful but must never prevent a message from being sent.
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
          })
          .select()
          .single();

      // Put the confirmed database row on screen immediately.
      if (mounted) {
        setState(() {
          rows.add(Map<String, dynamic>.from(inserted));
          ctrl.clear();
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
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit message',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: dark)),
        content: SizedBox(
          width: 420,
          child: TextField(
              controller: editCtrl,
              autofocus: true,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: muted))),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: bubbleMine),
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
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete message?',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: dark)),
        content: const Text(
            'This message will be removed for everyone in the community chat.',
            style: TextStyle(color: muted, height: 1.4)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel', style: TextStyle(color: muted))),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade600),
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
    if (!isMine) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: const Icon(Icons.edit_rounded, color: dark),
              title: const Text('Edit message'),
              onTap: () {
                Navigator.pop(context);
                _editMessage(row);
              }),
          ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  color: Colors.red.shade600),
              title: Text('Delete message',
                  style: TextStyle(color: Colors.red.shade600)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(row);
              }),
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
        backgroundColor: error ? Colors.red.shade700 : bubbleMine,
        behavior: SnackBarBehavior.floating));
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    ctrl.dispose();
    scroll.dispose();
    super.dispose();
  }

  // ---------- Formatting helpers (display only) ----------

  DateTime? _dateOf(Map<String, dynamic>? r) {
    if (r == null) return null;
    return DateTime.tryParse(r['created_at']?.toString() ?? '')?.toLocal();
  }

  String _timeLabel(DateTime? d) {
    if (d == null) return '';
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _dayLabel(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          AppHeader(
            title: widget.orgName,
            subtitle: 'One shared space for members, officers, and advisers.',
            status: 'COMMUNITY CHAT',
            icon: Icons.forum_rounded,
            onBack: widget.showBackButton
                ? () => Navigator.of(context).maybePop()
                : null,
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(color: green))
                    : rows.isEmpty
                        ? _empty()
                        : LayoutBuilder(builder: (context, c) {
                            final maxBubble =
                                math.min(c.maxWidth * 0.78, 520.0);
                            return ListView.builder(
                              controller: scroll,
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                  c.maxWidth < 380 ? 10 : 16,
                                  12,
                                  c.maxWidth < 380 ? 10 : 16,
                                  16),
                              itemCount: rows.length,
                              itemBuilder: (_, i) => _message(rows[i],
                                  i > 0 ? rows[i - 1] : null, maxBubble),
                            );
                          }),
              ),
            ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _empty() => Center(
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                    color: fieldBg, shape: BoxShape.circle),
                child: const Icon(Icons.forum_outlined, color: green, size: 32)),
            const SizedBox(height: 16),
            const Text('No messages yet',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: dark)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                  'Start a conversation with officers, advisers, and organization members.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, height: 1.45, fontSize: 13.5)),
            ),
          ])));

  Widget _dateChip(String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
                color: fieldBg, borderRadius: BorderRadius.circular(20)),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: muted)),
          ),
        ),
      );

  Widget _avatar(String name) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          shape: BoxShape.circle,
          border: Border.all(color: border)),
      child: Text(initial,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: dark)),
    );
  }

  Widget _message(
      Map<String, dynamic> r, Map<String, dynamic>? prev, double maxBubble) {
    // Defensive guard: legacy video-call rows are never rendered, even if a
    // stale realtime payload or cached list slips through.
    if (_isLegacyVideoCallMessage(r)) return const SizedBox.shrink();
    final me = r['sender_id'] == db.auth.currentUser?.id;
    final role = r['sender_role']?.toString() ?? 'member';
    final name = r['sender_name']?.toString() ?? 'Member';
    final raw = r['message']?.toString() ?? '';
    final isImage = raw.startsWith(imageMarker);
    final imageUrl = isImage ? raw.substring(imageMarker.length).trim() : '';
    final date = _dateOf(r);
    final prevDate = _dateOf(prev);
    final showDate =
        date != null && (prevDate == null || !_sameDay(date, prevDate));
    final showMenuButton = me && MediaQuery.sizeOf(context).width >= 700;
    final imgW = math.max(120.0, math.min(maxBubble - 28, 320.0));
    final imgH = imgW * 0.68;

    final textColor = me ? Colors.white : dark;
    final subColor = me ? Colors.white70 : muted;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxBubble),
      padding: const EdgeInsets.fromLTRB(13, 9, 13, 8),
      decoration: BoxDecoration(
        color: me ? bubbleMine : bubbleOther,
        borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(me ? 16 : 4),
            bottomRight: Radius.circular(me ? 4 : 16)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(me ? 'You' : name,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: textColor)),
                Text(role,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: subColor)),
              ],
            ),
            const SizedBox(height: 5),
            if (isImage)
              ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(imageUrl,
                      width: imgW,
                      height: imgH,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : Container(
                              width: imgW,
                              height: imgH,
                              color: Colors.white,
                              child: const Center(
                                  child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: muted)))),
                      errorBuilder: (_, __, ___) => Container(
                          width: imgW,
                          height: imgH,
                          color: Colors.white,
                          child: const Icon(Icons.broken_image_outlined,
                              color: muted, size: 34))))
            else
              Text(raw,
                  style: TextStyle(color: textColor, height: 1.4, fontSize: 14)),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(_timeLabel(date),
                  style: TextStyle(fontSize: 10, color: subColor)),
            ),
          ]),
    );

    return Column(
      children: [
        if (showDate) _dateChip(_dayLabel(date)),
        GestureDetector(
          onLongPress: me ? () => _messageMenu(r) : null,
          onSecondaryTap: me ? () => _messageMenu(r) : null,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment:
                  me ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!me) ...[_avatar(name), const SizedBox(width: 8)],
                if (showMenuButton)
                  PopupMenuButton<String>(
                    tooltip: 'Message options',
                    padding: EdgeInsets.zero,
                    color: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    icon: const Icon(Icons.more_horiz_rounded,
                        size: 20, color: muted),
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
                Flexible(child: bubble),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _composer() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: border)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: sending ? null : _pickAndSendImages,
                    icon: const Icon(Icons.image_outlined, color: muted),
                    tooltip: 'Send picture',
                  ),
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontSize: 14.5, color: dark),
                      decoration: InputDecoration(
                        hintText: 'Write a message...',
                        hintStyle: const TextStyle(color: muted),
                        filled: true,
                        fillColor: fieldBg,
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide:
                                const BorderSide(color: green, width: 1.2)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 11),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: sending ? const Color(0xFFD1D5DB) : green,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: sending ? null : _send,
                      icon: sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
                      tooltip: 'Send message',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}