import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdviserLiquidationScreen extends StatefulWidget {
  final String orgId;
  final String orgName;
  const AdviserLiquidationScreen({super.key, required this.orgId, required this.orgName});
  @override
  State<AdviserLiquidationScreen> createState() => _AdviserLiquidationScreenState();
}

class _AdviserLiquidationScreenState extends State<AdviserLiquidationScreen> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  final Set<String> _expandedSemesters = <String>{};
  double _allocated = 0;
  List<Map<String, dynamic>> _transactions = [];
  String? _error;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _load(showLoading: true);
    _realtimeChannel = _db
        .channel('adviser-liquidation-${widget.orgId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'org_financial_transactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'org_id',
            value: widget.orgId,
          ),
          callback: (_) => _load(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'organizations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.orgId,
          ),
          callback: (_) => _load(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    final channel = _realtimeChannel;
    if (channel != null) _db.removeChannel(channel);
    super.dispose();
  }

  Future<void> _load({bool showLoading = false}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() { _loading = true; _error = null; });
    }
    try {
      final results = await Future.wait<dynamic>([
        _db.from('organizations').select('allocated_budget').eq('id', widget.orgId).maybeSingle(),
        _db.from('org_financial_transactions').select('*').eq('org_id', widget.orgId).order('transaction_date', ascending: false),
      ]);
      final org = results[0] as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() {
        _allocated = (org?['allocated_budget'] as num?)?.toDouble() ?? 0;
        _transactions = List<Map<String, dynamic>>.from(results[1] as List);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Could not load liquidation details. Please check organization finance access.'; });
    }
  }

  Map<String, Map<String, double>> _eventSummariesForSemester(String semester) {
    final result = <String, Map<String, double>>{};
    for (final row in _transactions) {
      final date = DateTime.tryParse(row['transaction_date']?.toString() ?? '');
      if (date == null) continue;
      final label = date.month >= 8 || date.month <= 1
          ? 'Semester 1 • ${date.month >= 8 ? date.year : date.year - 1}-${date.month >= 8 ? date.year + 1 : date.year}'
          : 'Semester 2 • ${date.year}';
      if (label != semester) continue;
      final event = row['event_name']?.toString().trim().isNotEmpty == true ? row['event_name'].toString().trim() : 'General organization funds';
      final bucket = result.putIfAbsent(event, () => {'income': 0.0, 'expense': 0.0, 'reimbursement': 0.0});
      final type = row['type']?.toString().toLowerCase() ?? 'expense';
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      if (type == 'income') { bucket['income'] = bucket['income']! + amount; }
      else { bucket['expense'] = bucket['expense']! + amount; if (type == 'reimbursement' || (row['category']?.toString().toLowerCase().startsWith('reimbursement') ?? false) || (row['description']?.toString().toLowerCase().startsWith('reimbursement:') ?? false)) bucket['reimbursement'] = bucket['reimbursement']! + amount; }
    }
    return result;
  }

  Future<void> _copyFinancialReport() async {
    final document = pw.Document();
    final semesterRows = _semesterSummaries().entries.toList();
    final transactions = _transactions;
    pw.Widget cell(String value, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
    document.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => [
        pw.Center(child: pw.Column(children: [
          pw.Text('Financial Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Text(widget.orgName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('Generated ${DateFormat.yMMMMd().format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9)),
        ])),
        pw.SizedBox(height: 18),
        pw.Text('Financial Summary', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Table(border: pw.TableBorder.all(color: PdfColors.grey400, width: .5), children: [
          pw.TableRow(children: [cell('Budget allocated by Admin', bold: true), cell(_money(_allocated))]),
          pw.TableRow(children: [cell('Total income', bold: true), cell(_money(_sum('income')))]),
          pw.TableRow(children: [cell('Total expenses', bold: true), cell(_money(_sum('expense')))]),
          pw.TableRow(children: [cell('Reimbursements', bold: true), cell(_money(_sum('reimbursement')))]),
          pw.TableRow(children: [cell('Available balance', bold: true), cell(_money(_sum('income') - _sum('expense')))]),
        ]),
        pw.SizedBox(height: 16),
        pw.Text('Semester Summary', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        if (semesterRows.isEmpty) pw.Text('No semester transactions recorded.') else pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
          children: [
            pw.TableRow(children: ['Semester', 'Income', 'Expenses', 'Reimbursements', 'Profit'].map((v) => cell(v, bold: true)).toList()),
            ...semesterRows.map((entry) => pw.TableRow(children: [
              cell(entry.key), cell(_money(entry.value['income']!)), cell(_money(entry.value['expense']!)),
              cell(_money(entry.value['reimbursement'] ?? 0)), cell(_money(entry.value['income']! - entry.value['expense']!)),
            ])),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text('Transaction Details', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        if (transactions.isEmpty) pw.Text('No liquidation transactions have been recorded.') else pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
          columnWidths: {0: const pw.FlexColumnWidth(1.1), 1: const pw.FlexColumnWidth(1.5), 2: const pw.FlexColumnWidth(.9), 3: const pw.FlexColumnWidth(2), 4: const pw.FlexColumnWidth(1)},
          children: [
            pw.TableRow(children: ['Date', 'Event', 'Type', 'Description', 'Amount'].map((v) => cell(v, bold: true)).toList()),
            ...transactions.map((row) => pw.TableRow(children: [
              cell(row['transaction_date']?.toString() ?? ''), cell(row['event_name']?.toString() ?? ''),
              cell((row['type'] ?? '').toString().toUpperCase()), cell((row['description'] ?? row['category'] ?? '').toString()),
              cell(_money((row['amount'] as num?)?.toDouble() ?? 0)),
            ])),
          ],
        ),
      ],
    ));
    await Printing.layoutPdf(
      name: 'Financial_Report_${widget.orgName.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')}.pdf',
      onLayout: (_) async => document.save(),
    );
  }

  Map<String, Map<String, double>> _semesterSummaries() {
    final result = <String, Map<String, double>>{};
    for (final row in _transactions) {
      final raw = DateTime.tryParse(row['transaction_date']?.toString() ?? '');
      if (raw == null) continue;
      final semester = raw.month >= 8 || raw.month <= 1 ? 'Semester 1 • ${raw.month >= 8 ? raw.year : raw.year - 1}-${raw.month >= 8 ? raw.year + 1 : raw.year}' : 'Semester 2 • ${raw.year}';
      final bucket = result.putIfAbsent(semester, () => {'income': 0.0, 'expense': 0.0, 'reimbursement': 0.0});
      final type = row['type']?.toString().toLowerCase() ?? 'expense';
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      if (type == 'income') { bucket['income'] = bucket['income']! + amount; }
      else { bucket['expense'] = bucket['expense']! + amount; if (type == 'reimbursement' || (row['category']?.toString().toLowerCase().startsWith('reimbursement') ?? false) || (row['description']?.toString().toLowerCase().startsWith('reimbursement:') ?? false)) bucket['reimbursement'] = bucket['reimbursement']! + amount; }
    }
    return result;
  }

  double _sum(String type) => _transactions.where((r) { final t = r['type']?.toString().toLowerCase(); return type == 'expense' ? (t == 'expense' || t == 'reimbursement') : t == type; }).fold(0.0, (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0));
  String _money(double n) => NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2).format(n);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF0FDF4),
    appBar: AppBar(
      toolbarHeight: 150,
      automaticallyImplyLeading: false,
      centerTitle: true,
      title: const Text(
        'Liquidation & Budget',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800),
      ),
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        tooltip: 'Back',
      ),
      actions: const <Widget>[],
      elevation: 0,
      backgroundColor: const Color(0xFF128058),
      foregroundColor: Colors.white,
      flexibleSpace: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF128058), Color(0xFF16A34A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    ),
    body: _loading ? const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A))) : _error != null ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))) : ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        _amountCard('Budget allocated by Admin / CSO', _allocated, Icons.account_balance_wallet_rounded),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _amountCard('Income', _sum('income'), Icons.trending_up_rounded)), const SizedBox(width: 10), Expanded(child: _amountCard('Expenses', _sum('expense'), Icons.trending_down_rounded))]),
        _amountCard('Available balance', _sum('income') - _sum('expense'), Icons.wallet_rounded),
        const SizedBox(height: 12),
        const Text('Liquidation History', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF073B2A))),
        const SizedBox(height: 8),
        Row(children: [const Expanded(child: Text('Financial Report by Semester', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF14532D)))), TextButton.icon(onPressed: _copyFinancialReport, icon: const Icon(Icons.print_outlined, size: 17), label: const Text('Prepare to print'))]),
        const SizedBox(height: 6),
        ..._semesterSummaries().entries.map((entry) {
          final allEvents = _eventSummariesForSemester(entry.key).entries.toList();
          final visibleEvents = _expandedSemesters.contains(entry.key) ? allEvents : allEvents.take(5).toList();
          return Card(
            elevation: 1,
            shadowColor: const Color(0xFF15803D).withValues(alpha: .08),
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Color(0xFFD1FAE5))),
            child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF128058), Color(0xFF16A34A)]), borderRadius: BorderRadius.circular(16)), child: Row(children: [const Icon(Icons.calendar_month_rounded, color: Colors.white), const SizedBox(width: 10), Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 15)))])),
              const SizedBox(height: 12),
              Text('Semester income: ${_money(entry.value['income']!)}'),
              Text('Semester expenses: ${_money(entry.value['expense']!)}'),
              Text('Semester profit: ${_money(entry.value['income']! - entry.value['expense']!)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF14532D))),
              const Divider(height: 24),
              const Text('EVENT BREAKDOWN', style: TextStyle(fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w900, color: Color(0xFF128058))),
              const SizedBox(height: 8),
              if (allEvents.isEmpty) const Text('No events recorded for this semester.')
              else ...visibleEvents.map((event) => Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFD1FAE5))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(event.key, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF14532D))), const SizedBox(height: 6), _reportLine('Income', event.value['income']!), _reportLine('Expenses', event.value['expense']!), _reportLine('Reimbursements', event.value['reimbursement'] ?? 0), const Divider(height: 15), _reportLine('Profit (income − expenses)', event.value['income']! - event.value['expense']!, bold: true)]))),
              if (allEvents.length > 5) Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => setState(() { if (_expandedSemesters.contains(entry.key)) { _expandedSemesters.remove(entry.key); } else { _expandedSemesters.add(entry.key); } }), icon: Icon(_expandedSemesters.contains(entry.key) ? Icons.expand_less_rounded : Icons.expand_more_rounded), label: Text(_expandedSemesters.contains(entry.key) ? 'Show less' : 'View all ${allEvents.length} events'))),
            ])),
          );
        }),
        const SizedBox(height: 12),
        if (_transactions.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No liquidation transactions have been recorded yet.')))
        else ..._transactions.map((r) {
          final type = r['type']?.toString().toLowerCase() ?? 'transaction';
          final date = DateTime.tryParse(r['transaction_date']?.toString() ?? '');
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFD1FAE5))),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: type == 'income' ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5), child: Icon(type == 'income' ? Icons.trending_up_rounded : Icons.receipt_long_rounded, color: type == 'income' ? const Color(0xFF15803D) : const Color(0xFFB45309))),
              title: Text(r['description']?.toString().trim().isNotEmpty == true ? r['description'].toString() : (r['category']?.toString() ?? type), style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${type.toUpperCase()}${date == null ? '' : ' • ${DateFormat.yMMMd().format(date)}'}${r['category'] == null ? '' : ' • ${r['category']}'}'),
              trailing: Text(_money((r['amount'] as num?)?.toDouble() ?? 0), style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          );
        }),
      ],
    ),
  );

  Widget _reportLine(String label, double value, {bool bold = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: const Color(0xFF496657), fontWeight: bold ? FontWeight.w900 : FontWeight.w500))), Text(_money(value), style: TextStyle(fontSize: 12, color: const Color(0xFF073B2A), fontWeight: bold ? FontWeight.w900 : FontWeight.w700))]));

  Widget _amountCard(String label, double value, IconData icon) => Container(
    margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFD1FAE5)),
      boxShadow: [BoxShadow(color: const Color(0xFF15803D).withValues(alpha: .07), blurRadius: 20, offset: const Offset(0, 7))],
    ),
    child: Row(children: [
      Container(width: 42, height: 42, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFDCFCE7), Color(0xFFCCFBF1)]), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: const Color(0xFF128058))),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4D6F62), fontSize: 12))),
      const SizedBox(width: 8),
      Flexible(child: Text(_money(value), textAlign: TextAlign.end, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF073B2A)))),
    ]),
  );
}
