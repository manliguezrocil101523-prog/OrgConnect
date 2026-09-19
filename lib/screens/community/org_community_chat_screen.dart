import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrgCommunityChatScreen extends StatefulWidget {
  final String orgId, orgName;
  final bool showBackButton;
  const OrgCommunityChatScreen({super.key, required this.orgId, required this.orgName, this.showBackButton = true});
  @override State<OrgCommunityChatScreen> createState()=>_OrgCommunityChatScreenState();
}
class _OrgCommunityChatScreenState extends State<OrgCommunityChatScreen>{
  final db=Supabase.instance.client; final ctrl=TextEditingController(); final scroll=ScrollController();
  List<Map<String,dynamic>> rows=[]; bool loading=true, sending=false;
  static const green=Color(0xFF16A34A), bg=Color(0xFFF0FDF4), dark=Color(0xFF12352A), muted=Color(0xFF64748B);
  @override void initState(){super.initState(); _load();}
  Future<void> _load() async {try{final r=await db.from('org_chat_messages').select('*').eq('org_id',widget.orgId).order('created_at'); if(mounted)setState(()=>rows=List<Map<String,dynamic>>.from(r));}catch(_){ }finally{if(mounted)setState(()=>loading=false);}}
  Future<void> _send() async {
    final text = ctrl.text.trim();
    final user = db.auth.currentUser;
    if (text.isEmpty || user == null || sending) return;
    setState(() => sending = true);
    try {
      final profile = await db.from('profiles').select('name,role').eq('id', user.id).maybeSingle();
      final senderName = profile == null ? 'Member' : (profile['name']?.toString() ?? 'Member');
      final senderRole = profile == null ? 'member' : (profile['role']?.toString() ?? 'member');
      await db.from('org_chat_messages').insert({
        'org_id': widget.orgId,
        'sender_id': user.id,
        'sender_name': senderName,
        'sender_role': senderRole,
        'message': text,
      });
      ctrl.clear();
      await _load();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) {
          scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not send message.')));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }
  @override void dispose(){ctrl.dispose();scroll.dispose();super.dispose();}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: green,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: widget.showBackButton,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Community Chat', style: TextStyle(fontWeight: FontWeight.w900)),
          Text(widget.orgName, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Material(
              color: Colors.white.withOpacity(.16),
              shape: const CircleBorder(),
              child: IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                tooltip: 'Refresh chat',
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: green))
                : rows.isEmpty
                    ? Center(
                        child: Container(
                          margin: const EdgeInsets.all(24),
                          padding: const EdgeInsets.all(26),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: green.withOpacity(.12)),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 18, offset: Offset(0, 8))],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 68, height: 68,
                                decoration: BoxDecoration(color: green.withOpacity(.10), shape: BoxShape.circle),
                                child: const Icon(Icons.forum_rounded, color: green, size: 34),
                              ),
                              const SizedBox(height: 14),
                              const Text('Your community space', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: dark)),
                              const SizedBox(height: 6),
                              const Text('Start the conversation with your officers and organization members.', textAlign: TextAlign.center, style: TextStyle(color: muted, height: 1.4)),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scroll,
                        padding: const EdgeInsets.all(16),
                        itemCount: rows.length,
                        itemBuilder: (_, i) {
                          final r = rows[i];
                          final me = r['sender_id'] == db.auth.currentUser?.id;
                          return Align(
                            alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 330),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: me ? green : Colors.white,
                                borderRadius: BorderRadius.circular(17),
                                boxShadow: [BoxShadow(color: me ? green.withOpacity(.18) : Colors.black12, blurRadius: 12, offset: const Offset(0, 5))],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${r['sender_name'] ?? 'Member'} • ${r['sender_role'] ?? ''}',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: me ? Colors.white70 : muted),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(r['message']?.toString() ?? '', style: TextStyle(color: me ? Colors.white : dark, height: 1.35)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: green.withOpacity(.10))),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -3))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Write a message...',
                      filled: true,
                      fillColor: const Color(0xFFF0FDF4),
                      border: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(18)), borderSide: BorderSide(color: green.withOpacity(.12))),
                      enabledBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(18)), borderSide: BorderSide(color: green.withOpacity(.12))),
                      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18)), borderSide: BorderSide(color: green, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: green,
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: sending ? null : _send,
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    tooltip: 'Send message',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
