import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  double _sum(String type) => _transactions.where((r) => r['type']?.toString().toLowerCase() == type).fold(0.0, (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0));
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
        _amountCard('Available balance', _allocated + _sum('income') - _sum('expense'), Icons.wallet_rounded),
        const SizedBox(height: 12),
        const Text('Liquidation History', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF073B2A))),
        const SizedBox(height: 8),
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
