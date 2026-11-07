import 'package:flutter/material.dart' hide Summary;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../db/database.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/invoice_pdf.dart';
import '../state/app_state.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  String _range = 'today';
  List<Sale> _sales = [];
  Summary _sum = const Summary(0, 0, 0, 0);
  int _seen = -1;

  DateTime? get _from {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_range) {
      case 'today':
        return today;
      case 'week':
        return today.subtract(const Duration(days: 6));
      case 'month':
        return today.subtract(const Duration(days: 29));
      default:
        return null;
    }
  }

  Future<void> _load() async {
    final s = await AppDb.i.sales(from: _from);
    final sm = await AppDb.i.summary(from: _from);
    if (mounted) {
      setState(() {
        _sales = s;
        _sum = sm;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    if (st.version != _seen) {
      _seen = st.version;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    final df = DateFormat('dd/MM/yyyy HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('sales')),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(spacing: 8, children: [
            for (final r in ['today', 'week', 'month', 'all'])
              ChoiceChip(
                label: Text(context.t(r)),
                selected: _range == r,
                onSelected: (_) {
                  _range = r;
                  _load();
                },
              ),
          ]),
        ),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _card(context.t('revenue'), money(_sum.revenue, st.lang),
                  Icons.trending_up, Colors.green),
              _card(context.t('profit'), money(_sum.profit, st.lang),
                  Icons.savings_outlined, Colors.blue),
              _card(context.t('count'), '${_sum.count}',
                  Icons.receipt_long, Colors.orange),
              _card(context.t('total_debts'), money(_sum.debts, st.lang),
                  Icons.account_balance_wallet_outlined, Colors.red),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _sales.isEmpty
              ? Center(child: Text(context.t('no_data')))
              : ListView.separated(
                  itemCount: _sales.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final s = _sales[i];
                    return ListTile(
                      onTap: () => _detail(s),
                      title: Text(s.invoiceNo),
                      subtitle: Text(
                          '${df.format(s.date)}  •  ${s.customerName.isEmpty ? context.t('no_customer') : s.customerName}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(money(s.total, st.lang),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          if (s.rest > 0)
                            Text('${context.t('rest')}: ${money(s.rest, st.lang)}',
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 12)),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _card(String title, String value, IconData icon, Color color) => Card(
        child: Container(
          width: 170,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 6),
              FittedBox(
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );

  Future<void> _detail(Sale s) async {
    final st = context.read<AppState>();
    final items = await AppDb.i.saleItems(s.id!);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.invoiceNo),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final i in items)
                ListTile(
                  dense: true,
                  title: Text(i.name),
                  subtitle: Text('${qtyStr(i.qty)} × ${money(i.price, st.lang)}'),
                  trailing: Text(money(i.total, st.lang)),
                ),
              const Divider(),
              _r(ctx.t('total_ht'), money(s.ht, st.lang)),
              _r(ctx.t('tva'), money(s.tva, st.lang)),
              if (s.stamp > 0) _r(ctx.t('stamp'), money(s.stamp, st.lang)),
              if (s.discount > 0)
                _r(ctx.t('discount'), money(s.discount, st.lang)),
              _r(ctx.t('total'), money(s.total, st.lang), bold: true),
              _r(ctx.t('paid'), money(s.paid, st.lang)),
              if (s.rest > 0) _r(ctx.t('rest'), money(s.rest, st.lang)),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('close'))),
          TextButton.icon(
              onPressed: () => shareInvoice(st, s, items),
              icon: const Icon(Icons.share),
              label: Text(ctx.t('share'))),
          FilledButton.icon(
              onPressed: () => printInvoice(st, s, items),
              icon: const Icon(Icons.print),
              label: Text(ctx.t('print'))),
        ],
      ),
    );
  }

  Widget _r(String a, String b, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        child: Row(children: [
          Text(a,
              style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
          const Spacer(),
          Text(b,
              style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
        ]),
      );
}
