import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// TODO: adjust this path to wherever your AppHeader file lives.
import 'package:my_app/widgets/app_header.dart';

class AdviserLiquidationScreen extends StatefulWidget {
  final String orgId;
  final String orgName;
  const AdviserLiquidationScreen({
    super.key,
    required this.orgId,
    required this.orgName,
  });

  @override
  State<AdviserLiquidationScreen> createState() =>
      _AdviserLiquidationScreenState();
}

class _AdviserLiquidationScreenState extends State<AdviserLiquidationScreen> {
  static const double _maxContentWidth = 880;

  final _db = Supabase.instance.client;
  final Set<String> _expandedSemesters = <String>{};
  RealtimeChannel? _realtimeChannel;

  bool _loading = true;
  String? _error;
  double _allocated = 0;
  List<Map<String, dynamic>> _transactions = [];

  // ───────────────────────── Lifecycle ─────────────────────────

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

  // ───────────────────────── Data ─────────────────────────

  Future<void> _load({bool showLoading = false}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<dynamic>([
        _db
            .from('organizations')
            .select('allocated_budget')
            .eq('id', widget.orgId)
            .maybeSingle(),
        _db
            .from('org_financial_transactions')
            .select('*')
            .eq('org_id', widget.orgId)
            .order('transaction_date', ascending: false),
      ]);
      final org = results[0] as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() {
        _allocated = (org?['allocated_budget'] as num?)?.toDouble() ?? 0;
        _transactions = List<Map<String, dynamic>>.from(results[1] as List);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Could not load liquidation details. Please check organization finance access.';
      });
    }
  }

  // ───────────────────────── Helpers ─────────────────────────

  double _amount(Map<String, dynamic> r) =>
      (r['amount'] as num?)?.toDouble() ?? 0;

  bool _isIncome(Map<String, dynamic> r) =>
      (r['type']?.toString().toLowerCase() ?? 'expense') == 'income';

  bool _isReimbursement(Map<String, dynamic> r) {
    final t = r['type']?.toString().toLowerCase();
    return t == 'reimbursement' ||
        (r['category']?.toString().toLowerCase().startsWith('reimbursement') ??
            false) ||
        (r['description']
                ?.toString()
                .toLowerCase()
                .startsWith('reimbursement') ??
            false);
  }

  String _semesterLabel(DateTime d) {
    if (d.month >= 8) return 'Semester 1 • ${d.year}-${d.year + 1}';
    if (d.month <= 1) return 'Semester 1 • ${d.year - 1}-${d.year}';
    return 'Semester 2 • ${d.year}';
  }

  String _eventName(Map<String, dynamic> r) {
    final name = r['event_name']?.toString().trim() ?? '';
    return name.isNotEmpty ? name : 'General organization funds';
  }

  void _accumulate(Map<String, double> bucket, Map<String, dynamic> row) {
    final amount = _amount(row);
    if (_isIncome(row)) {
      bucket['income'] = bucket['income']! + amount;
    } else {
      bucket['expense'] = bucket['expense']! + amount;
      if (_isReimbursement(row)) {
        bucket['reimbursement'] = bucket['reimbursement']! + amount;
      }
    }
  }

  /// semester → event → {income, expense, reimbursement}
  Map<String, Map<String, Map<String, double>>> _grouped() {
    final out = <String, Map<String, Map<String, double>>>{};
    for (final row in _transactions) {
      final date = DateTime.tryParse(row['transaction_date']?.toString() ?? '');
      if (date == null) continue;
      final events = out.putIfAbsent(
          _semesterLabel(date), () => <String, Map<String, double>>{});
      final bucket = events.putIfAbsent(
        _eventName(row),
        () => <String, double>{
          'income': 0.0,
          'expense': 0.0,
          'reimbursement': 0.0,
        },
      );
      _accumulate(bucket, row);
    }
    return out;
  }

  Map<String, double> _semesterTotals(Map<String, Map<String, double>> events) {
    final t = <String, double>{
      'income': 0.0,
      'expense': 0.0,
      'reimbursement': 0.0,
    };
    for (final e in events.values) {
      for (final k in t.keys.toList()) {
        t[k] = t[k]! + (e[k] ?? 0);
      }
    }
    return t;
  }

  double _sum(String type) {
    var total = 0.0;
    for (final r in _transactions) {
      final income = _isIncome(r);
      if (type == 'income' && income) total += _amount(r);
      if (type == 'expense' && !income) total += _amount(r);
      if (type == 'reimbursement' && !income && _isReimbursement(r)) {
        total += _amount(r);
      }
    }
    return total;
  }

  double get _balance => _allocated + _sum('income') - _sum('expense');

  String _money(double n) =>
      NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2)
          .format(n);

  // The default PDF font has no "₱" glyph, so the PDF uses "PHP ".
  String _pdfMoney(double n) =>
      NumberFormat.currency(locale: 'en_PH', symbol: 'PHP ', decimalDigits: 2)
          .format(n);

  // ───────────────────────── PDF ─────────────────────────

  Future<void> _printFinancialReport() async {
    try {
      final document = pw.Document();
      final grouped = _grouped();
      final semesterRows = grouped.entries.toList();
      final transactions = _transactions;

      pw.Widget cell(String value, {bool bold = false}) => pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          );

      pw.Widget heading(String text) => pw.Text(text,
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold));

      document.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Center(
            child: pw.Column(children: [
              pw.Text('Financial Report',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Text(widget.orgName,
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                'Generated ${DateFormat.yMMMMd().format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ]),
          ),
          pw.SizedBox(height: 18),
          heading('Financial Summary'),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
            children: [
              pw.TableRow(children: [
                cell('Budget allocated by Admin', bold: true),
                cell(_pdfMoney(_allocated)),
              ]),
              pw.TableRow(children: [
                cell('Total income', bold: true),
                cell(_pdfMoney(_sum('income'))),
              ]),
              pw.TableRow(children: [
                cell('Total expenses', bold: true),
                cell(_pdfMoney(_sum('expense'))),
              ]),
              pw.TableRow(children: [
                cell('Reimbursements', bold: true),
                cell(_pdfMoney(_sum('reimbursement'))),
              ]),
              pw.TableRow(children: [
                cell('Available balance', bold: true),
                cell(_pdfMoney(_balance)),
              ]),
            ],
          ),
          pw.SizedBox(height: 16),
          heading('Semester Summary'),
          pw.SizedBox(height: 6),
          if (semesterRows.isEmpty)
            pw.Text('No semester transactions recorded.')
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
              children: [
                pw.TableRow(
                  children: [
                    'Semester',
                    'Income',
                    'Expenses',
                    'Reimbursements',
                    'Profit',
                  ].map((v) => cell(v, bold: true)).toList(),
                ),
                ...semesterRows.map((entry) {
                  final t = _semesterTotals(entry.value);
                  return pw.TableRow(children: [
                    cell(entry.key.replaceAll('•', '-')),
                    cell(_pdfMoney(t['income']!)),
                    cell(_pdfMoney(t['expense']!)),
                    cell(_pdfMoney(t['reimbursement']!)),
                    cell(_pdfMoney(t['income']! - t['expense']!)),
                  ]);
                }),
              ],
            ),
          pw.SizedBox(height: 16),
          heading('Transaction Details'),
          pw.SizedBox(height: 6),
          if (transactions.isEmpty)
            pw.Text('No liquidation transactions have been recorded.')
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.1),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(.9),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  children: ['Date', 'Event', 'Type', 'Description', 'Amount']
                      .map((v) => cell(v, bold: true))
                      .toList(),
                ),
                ...transactions.map((row) => pw.TableRow(children: [
                      cell(row['transaction_date']?.toString() ?? ''),
                      cell(row['event_name']?.toString() ?? ''),
                      cell((row['type'] ?? '').toString().toUpperCase()),
                      cell((row['description'] ?? row['category'] ?? '')
                          .toString()),
                      cell(_pdfMoney(_amount(row))),
                    ])),
              ],
            ),
        ],
      ));

      await Printing.layoutPdf(
        name:
            'Financial_Report_${widget.orgName.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')}.pdf',
        onLayout: (_) async => document.save(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not prepare the report.')),
      );
    }
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
  return Scaffold(
  backgroundColor: Colors.white,
  body: Column(
        children: [
          AppHeader(
            title: 'Liquidation & Budget',
            subtitle: widget.orgName,
            status: 'ADVISER • ORGANIZATION FINANCE',
            icon: Icons.account_balance_wallet_rounded,
            onBack: () => Navigator.maybePop(context),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF16A34A)),
      );
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
                onPressed: () => _load(showLoading: true),
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
        final contentWidth = width - side * 2;
        final stackSummary = contentWidth < 380;
        final bottomInset = MediaQuery.of(context).padding.bottom;
        final grouped = _grouped();

        return RefreshIndicator(
          color: const Color(0xFF16A34A),
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(side, 16, side, 28 + bottomInset),
            children: [
              _amountCard('Budget allocated by Admin / CSO', _allocated,
                  Icons.account_balance_wallet_rounded),
              if (stackSummary) ...[
                _amountCard(
                    'Income', _sum('income'), Icons.trending_up_rounded),
                _amountCard(
                    'Expenses', _sum('expense'), Icons.trending_down_rounded),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _amountCard(
                          'Income', _sum('income'), Icons.trending_up_rounded),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _amountCard('Expenses', _sum('expense'),
                          Icons.trending_down_rounded),
                    ),
                  ],
                ),
              _amountCard('Available balance', _balance, Icons.wallet_rounded),
              const SizedBox(height: 12),
              const Text(
                'Liquidation History',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF073B2A),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 0,
                children: [
                  const Text(
                    'Financial Report by Semester',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF14532D),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _printFinancialReport,
                    icon: const Icon(Icons.print_outlined, size: 17),
                    label: const Text('Prepare to print'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...grouped.entries.map((entry) => _semesterCard(entry.key,
                  entry.value)),
              const SizedBox(height: 12),
              if (_transactions.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                        'No liquidation transactions have been recorded yet.'),
                  ),
                )
              else
                ..._transactions.map(_transactionTile),
            ],
          ),
        );
      },
    );
  }

  // ───────────────────────── Widgets ─────────────────────────

  Widget _semesterCard(
    String semester,
    Map<String, Map<String, double>> events,
  ) {
    final totals = _semesterTotals(events);
    final allEvents = events.entries.toList();
    final expanded = _expandedSemesters.contains(semester);
    final visibleEvents = expanded ? allEvents : allEvents.take(5).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shadowColor: const Color(0xFF15803D).withValues(alpha: .08),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFD1FAE5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF128058), Color(0xFF16A34A)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded,
                      color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      semester,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Semester income: ${_money(totals['income']!)}'),
            Text('Semester expenses: ${_money(totals['expense']!)}'),
            Text(
              'Semester profit: ${_money(totals['income']! - totals['expense']!)}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF14532D),
              ),
            ),
            const Divider(height: 24),
            const Text(
              'EVENT BREAKDOWN',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1,
                fontWeight: FontWeight.w900,
                color: Color(0xFF128058),
              ),
            ),
            const SizedBox(height: 8),
            if (allEvents.isEmpty)
              const Text('No events recorded for this semester.')
            else
              ...visibleEvents.map(_eventBox),
            if (allEvents.length > 5)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    if (expanded) {
                      _expandedSemesters.remove(semester);
                    } else {
                      _expandedSemesters.add(semester);
                    }
                  }),
                  icon: Icon(expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded),
                  label: Text(expanded
                      ? 'Show less'
                      : 'View all ${allEvents.length} events'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _eventBox(MapEntry<String, Map<String, double>> event) {
    final v = event.value;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFD1FAE5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.key,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF14532D),
            ),
          ),
          const SizedBox(height: 6),
          _reportLine('Income', v['income'] ?? 0),
          _reportLine('Expenses', v['expense'] ?? 0),
          _reportLine('Reimbursements', v['reimbursement'] ?? 0),
          const Divider(height: 15),
          _reportLine(
            'Profit (income − expenses)',
            (v['income'] ?? 0) - (v['expense'] ?? 0),
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _transactionTile(Map<String, dynamic> r) {
    final type = r['type']?.toString().toLowerCase() ?? 'transaction';
    final date = DateTime.tryParse(r['transaction_date']?.toString() ?? '');
    final isIncome = type == 'income';
    final description = r['description']?.toString().trim() ?? '';
    final title = description.isNotEmpty
        ? description
        : (r['category']?.toString() ?? type);
    final subtitle =
        '${type.toUpperCase()}${date == null ? '' : ' • ${DateFormat.yMMMd().format(date)}'}${r['category'] == null ? '' : ' • ${r['category']}'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD1FAE5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor:
                isIncome ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5),
            child: Icon(
              isIncome
                  ? Icons.trending_up_rounded
                  : Icons.receipt_long_rounded,
              color:
                  isIncome ? const Color(0xFF15803D) : const Color(0xFFB45309),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4D6F62),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                _money(_amount(r)),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportLine(String label, double value, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFF496657),
                  fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  _money(value),
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF073B2A),
                    fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _amountCard(String label, double value, IconData icon) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD1FAE5)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF15803D).withValues(alpha: .07),
              blurRadius: 20,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDCFCE7), Color(0xFFCCFBF1)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF128058)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4D6F62),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  _money(value),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF073B2A),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}