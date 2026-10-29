import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// If this path is wrong, copy the AppHeader import line from any other
// screen that already uses AppHeader (same line as in the liquidation screen).
import 'package:my_app/widgets/app_header.dart';

class AdviserMeetingMinutesScreen extends StatefulWidget {
  final String orgId;
  final String orgName;
  const AdviserMeetingMinutesScreen({
    super.key,
    required this.orgId,
    required this.orgName,
  });

  @override
  State<AdviserMeetingMinutesScreen> createState() =>
      _AdviserMeetingMinutesScreenState();
}

class _AdviserMeetingMinutesScreenState
    extends State<AdviserMeetingMinutesScreen> {
  static const green = Color(0xFF128058);
  static const dark = Color(0xFF073B2A);
  static const _muted = Color(0xFF557365);
  static const _border = Color(0xFFD1FAE5);
  static const double _maxContentWidth = 880;

  final _db = Supabase.instance.client;
  RealtimeChannel? _channel;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _minutes = [];

  // ───────────────────────── Lifecycle ─────────────────────────

  @override
  void initState() {
    super.initState();
    _load();
    _channel = _db.channel('adviser-meeting-minutes-${widget.orgId}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'organization_meeting_minutes',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'org_id',
          value: widget.orgId,
        ),
        callback: (_) => _load(),
      )
      ..subscribe();
  }

  @override
  void dispose() {
    final c = _channel;
    if (c != null) _db.removeChannel(c);
    super.dispose();
  }

  // ───────────────────────── Data ─────────────────────────

  Future<void> _load() async {
    try {
      final rows = await _db
          .from('organization_meeting_minutes')
          .select('title,meeting_date,minutes,submitted_at')
          .eq('org_id', widget.orgId)
          .order('meeting_date', ascending: false);
      if (!mounted) return;
      setState(() {
        _minutes = List<Map<String, dynamic>>.from(rows as List);
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Could not load meeting minutes. Please check organization access permissions.';
      });
    }
  }

  String _formatDate(dynamic raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return 'Date not specified';
    final parsed = DateTime.tryParse(text);
    return parsed == null ? text : DateFormat.yMMMMd().format(parsed);
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          AppHeader(
            title: 'Meeting Minutes',
            subtitle: 'Organization records',
            status: 'ADVISER • MEETING MINUTES',
            icon: Icons.menu_book_rounded,
            onBack: () => Navigator.maybePop(context),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: green));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _load();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Centers the content and caps its width on tablets / wide screens.
        final side = width > _maxContentWidth + 32
            ? (width - _maxContentWidth) / 2
            : (width < 360 ? 12.0 : 16.0);
        final bottomInset = MediaQuery.of(context).padding.bottom;

        return RefreshIndicator(
          color: green,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(side, 18, side, 28 + bottomInset),
            children: [
              _summaryCard(),
              const SizedBox(height: 18),
              if (_minutes.isEmpty)
                _emptyCard()
              else
                for (var i = 0; i < _minutes.length; i++)
                  _minuteTile(i, _minutes[i]),
            ],
          ),
        );
      },
    );
  }

  // ───────────────────────── Widgets ─────────────────────────

  Widget _summaryCard() {
    final count = _minutes.length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE0F8E9), Colors.white],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFC5EBD4)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(15),
            ),
            child:
                const Icon(Icons.menu_book_rounded, color: green, size: 27),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.orgName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: dark,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$count saved meeting record${count == 1 ? '' : 's'}',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: const Column(
        children: [
          Icon(Icons.description_outlined, size: 42, color: Color(0xFF86B99A)),
          SizedBox(height: 10),
          Text(
            'No meeting minutes yet',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900, color: dark),
          ),
          SizedBox(height: 5),
          Text(
            'Minutes submitted by the secretary team will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _minuteTile(int index, Map<String, dynamic> m) {
    final title = m['title']?.toString().trim() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: green.withValues(alpha: .05),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Theme(
          // Removes the default divider lines ExpansionTile draws.
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: green,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            title: Text(
              title.isEmpty ? 'Meeting' : title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: dark,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 13, color: green),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      _formatDate(m['meeting_date']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ),
                ],
              ),
            ),
            trailing:
                const Icon(Icons.keyboard_arrow_down_rounded, color: green),
            children: [
              const Divider(height: 1, color: _border),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  m['minutes']?.toString() ?? '',
                  style: const TextStyle(
                    height: 1.65,
                    color: Color(0xFF30483B),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}