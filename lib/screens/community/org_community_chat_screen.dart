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
  static const green = Color(0xFF16A34A);
  static const bright = Color(0xFF22C55E);
  static const bg = Color(0xFFF0FDF4);
  static const dark = Color(0xFF12352A);
  static const muted = Color(0xFF64748B);
  static const imageMarker = '[[ORGCONNECT_IMAGE]]';

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
    if (!isMine) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
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
        backgroundColor: error ? Colors.red.shade700 : green,
        behavior: SnackBarBehavior.floating));
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    ctrl.dispose();
    scroll.dispose();
    super.dispose();
  }

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
            child: loading
                ? const Center(child: CircularProgressIndicator(color: green))
                : rows.isEmpty
                    ? _empty()
                    : ListView.builder(
                        controller: scroll,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                        itemCount: rows.length,
                        itemBuilder: (_, i) => _message(rows[i]),
                      ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _orb(double size, Color color) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color));

  Widget _chatLogo() => Container(
        width: 72,
        height: 72,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: .16),
            border: Border.all(
                color: Colors.white.withValues(alpha: .30), width: 2)),
        child: Container(
          decoration: const BoxDecoration(
              shape: BoxShape.circle, color: Color(0xFFE4F7EF)),
          child: const Icon(Icons.forum_rounded, color: green, size: 34),
        ),
      );

  Widget _empty() => Center(
      child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(27),
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF8FFFB), Color(0xFFDDF4E8)]),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: green.withValues(alpha: .10)),
              boxShadow: [
                BoxShadow(
                    color: green.withValues(alpha: .06),
                    blurRadius: 20,
                    offset: const Offset(0, 8))
              ]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [green, bright]),
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
    // Defensive guard: legacy video-call rows are never rendered, even if a
    // stale realtime payload or cached list slips through.
    if (_isLegacyVideoCallMessage(r)) return const SizedBox.shrink();
    final me = r['sender_id'] == db.auth.currentUser?.id;
    final role = r['sender_role']?.toString() ?? 'member';
    final name = r['sender_name']?.toString() ?? 'Member';
    final raw = r['message']?.toString() ?? '';
    final isImage = raw.startsWith(imageMarker);
    final imageUrl = isImage ? raw.substring(imageMarker.length).trim() : '';
    return GestureDetector(
      onLongPress: me ? () => _messageMenu(r) : null,
      onSecondaryTap: me ? () => _messageMenu(r) : null,
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
                gradient: me
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [green, bright])
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF8FFFB), Color(0xFFDDF4E8)]),
                borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(me ? 18 : 5),
                    bottomRight: Radius.circular(me ? 5 : 18)),
                border:
                    me ? null : Border.all(color: green.withValues(alpha: .07)),
                boxShadow: [
                  BoxShadow(
                      color: me
                          ? green.withValues(alpha: .15)
                          : Colors.black.withValues(alpha: .035),
                      blurRadius: 12,
                      offset: const Offset(0, 5)),
                ],
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$name • $role',
                        style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: me ? Colors.white70 : muted)),
                    const SizedBox(height: 7),
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
                                  color: bg,
                                  child: const Icon(Icons.broken_image_rounded,
                                      color: green, size: 34))))
                    else
                      Text(raw,
                          style: TextStyle(
                              color: me ? Colors.white : dark,
                              height: 1.4,
                              fontSize: 13)),
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

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: green.withValues(alpha: .10))),
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
              icon: const Icon(Icons.image_rounded, color: green),
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
                  fillColor: bg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: green, width: 1.5)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [green, bright]),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: sending ? null : _send,
                icon: sending
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, color: Colors.white),
                tooltip: 'Send message',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
