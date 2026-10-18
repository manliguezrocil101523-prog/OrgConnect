import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdviserMeetingMinutesScreen extends StatefulWidget {
  final String orgId;
  final String orgName;
  const AdviserMeetingMinutesScreen({super.key, required this.orgId, required this.orgName});
  @override
  State<AdviserMeetingMinutesScreen> createState() => _AdviserMeetingMinutesScreenState();
}

class _AdviserMeetingMinutesScreenState extends State<AdviserMeetingMinutesScreen> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _minutes = [];
  RealtimeChannel? _channel;
  static const green = Color(0xFF128058);
  static const dark = Color(0xFF073B2A);
  static const bg = Color(0xFFF0FDF4);

  @override
  void initState() {
    super.initState(); _load();
    _channel = _db.channel('adviser-meeting-minutes-${widget.orgId}')
      ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'organization_meeting_minutes', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'org_id', value: widget.orgId), callback: (_) => _load())
      ..subscribe();
  }
  @override
  void dispose() { final c = _channel; if (c != null) _db.removeChannel(c); super.dispose(); }
  Future<void> _load() async {
    try {
      final rows = await _db.from('organization_meeting_minutes').select('title,meeting_date,minutes,submitted_at').eq('org_id', widget.orgId).order('meeting_date', ascending: false);
      if (!mounted) return;
      setState(() { _minutes = List<Map<String, dynamic>>.from(rows as List); _loading = false; _error = null; });
    } catch (_) { if (!mounted) return; setState(() { _loading = false; _error = 'Could not load meeting minutes. Please check organization access permissions.'; }); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: bg,
    appBar: AppBar(toolbarHeight: 112, centerTitle: true, foregroundColor: Colors.white, elevation: 0,
      title: const Column(mainAxisSize: MainAxisSize.min, children: [Text('Meeting Minutes', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)), SizedBox(height: 4), Text('Organization records', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500))]),
      flexibleSpace: const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0B6848), Color(0xFF16A34A)]))),
    ),
    body: _loading ? const Center(child: CircularProgressIndicator(color: green)) : _error != null ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))) : RefreshIndicator(onRefresh: _load, color: green, child: ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 28), children: [
      Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFE0F8E9), Colors.white]), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFC5EBD4))), child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.menu_book_rounded, color: green, size: 27)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.orgName, style: const TextStyle(color: dark, fontWeight: FontWeight.w900, fontSize: 17)), const SizedBox(height: 3), Text('${_minutes.length} saved meeting record${_minutes.length == 1 ? '' : 's'}', style: const TextStyle(color: Color(0xFF557365), fontSize: 12))]))])),
      const SizedBox(height: 18),
      if (_minutes.isEmpty) Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFD1FAE5))), child: const Column(children: [Icon(Icons.description_outlined, size: 42, color: Color(0xFF86B99A)), SizedBox(height: 10), Text('No meeting minutes yet', style: TextStyle(fontWeight: FontWeight.w900, color: dark)), SizedBox(height: 5), Text('Minutes submitted by the secretary team will appear here.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF557365)))]))
      else ..._minutes.asMap().entries.map((entry) { final i = entry.key; final m = entry.value; return Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFD1FAE5)), boxShadow: [BoxShadow(color: green.withValues(alpha: .05), blurRadius: 16, offset: const Offset(0, 5))]), child: ExpansionTile(tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18), leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(14)), child: Center(child: Text('${i + 1}', style: const TextStyle(color: green, fontWeight: FontWeight.w900, fontSize: 16)))), title: Text(m['title']?.toString() ?? 'Meeting', style: const TextStyle(fontWeight: FontWeight.w900, color: dark)), subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Row(children: [const Icon(Icons.calendar_today_rounded, size: 13, color: green), const SizedBox(width: 5), Text(m['meeting_date']?.toString() ?? 'Date not specified', style: const TextStyle(fontSize: 12, color: Color(0xFF557365)))])), trailing: const Icon(Icons.keyboard_arrow_down_rounded, color: green), children: [const Divider(height: 1, color: Color(0xFFD1FAE5)), const SizedBox(height: 12), Align(alignment: Alignment.centerLeft, child: SelectableText(m['minutes']?.toString() ?? '', style: const TextStyle(height: 1.65, color: Color(0xFF30483B), fontSize: 14)))])); }),
    ])),
  );
}
