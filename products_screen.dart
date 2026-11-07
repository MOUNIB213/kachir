import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'scanner_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _search = TextEditingController();
  bool _lowOnly = false;
  List<Product> _items = [];
  int _seen = -1;

  Future<void> _load() async {
    final r = await AppDb.i.products(q: _search.text, lowOnly: _lowOnly);
    if (mounted) setState(() => _items = r);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    if (st.version != _seen) {
      _seen = st.version;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.t('products'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, null),
        child: const Icon(Icons.add),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (_) => _load(),
                decoration: InputDecoration(
                  hintText: context.t('search_hint'),
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: Text(context.t('low_stock')),
              selected: _lowOnly,
              avatar: const Icon(Icons.warning_amber, size: 18),
              onSelected: (v) {
                _lowOnly = v;
                _load();
              },
            ),
          ]),
        ),
        Expanded(
          child: _items.isEmpty
              ? Center(child: Text(context.t('no_data')))
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = _items[i];
                    return ListTile(
                      onTap: () => _edit(context, p),
                      leading: CircleAvatar(
                        backgroundColor: p.lowStock
                            ? Colors.red.shade100
                            : Colors.green.shade100,
                        child: Text(qtyStr(p.qty),
                            style: const TextStyle(fontSize: 12)),
                      ),
                      title: Text(p.name),
                      subtitle: Text([
                        if (p.category.isNotEmpty) p.category,
                        if (p.barcode.isNotEmpty) p.barcode,
                        'TVA ${qtyStr(p.tva)}%',
                      ].join('  •  ')),
                      trailing: Text(money(p.sell, st.lang),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Future<void> _edit(BuildContext context, Product? existing) async {
    final p = existing ??
        Product(name: '', tva: double.tryParse(
                context.read<AppState>().getS('tva_default', '19')) ??
            19);
    final name = TextEditingController(text: p.name);
    final barcode = TextEditingController(text: p.barcode);
    final category = TextEditingController(text: p.category);
    final buy = TextEditingController(text: p.id == null ? '' : qtyStr(p.buy));
    final sell = TextEditingController(text: p.id == null ? '' : qtyStr(p.sell));
    final qty = TextEditingController(text: p.id == null ? '' : qtyStr(p.qty));
    final minQty =
        TextEditingController(text: p.id == null ? '' : qtyStr(p.minQty));
    double tva = p.tva;
    final form = GlobalKey<FormState>();

    Widget field(TextEditingController c, String label,
            {bool num = false, bool req = false, Widget? suffix}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextFormField(
            controller: c,
            keyboardType: num
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            decoration: InputDecoration(labelText: label, suffixIcon: suffix),
            validator: (v) =>
                req && (v == null || v.trim().isEmpty) ? context.t('required') : null,
          ),
        );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(existing == null ? ctx.t('add') : ctx.t('edit')),
          content: SizedBox(
            width: 420,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  field(name, ctx.t('name'), req: true),
                  field(
                    barcode,
                    ctx.t('barcode'),
                    suffix: cameraScanSupported
                        ? IconButton(
                            icon: const Icon(Icons.qr_code_scanner),
                            onPressed: () async {
                              final code = await Navigator.of(ctx).push<String>(
                                  MaterialPageRoute(
                                      builder: (_) => const ScannerScreen()));
                              if (code != null) barcode.text = code;
                            },
                          )
                        : null,
                  ),
                  field(category, ctx.t('category')),
                  Row(children: [
                    Expanded(child: field(buy, ctx.t('buy_price'), num: true)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: field(sell, ctx.t('sell_price'),
                            num: true, req: true)),
                  ]),
                  Row(children: [
                    Expanded(child: field(qty, ctx.t('qty'), num: true)),
                    const SizedBox(width: 8),
                    Expanded(child: field(minQty, ctx.t('min_qty'), num: true)),
                  ]),
                  DropdownButtonFormField<double>(
                    value: tva,
                    decoration: const InputDecoration(labelText: 'TVA'),
                    items: const [
                      DropdownMenuItem(value: 19, child: Text('19%')),
                      DropdownMenuItem(value: 9, child: Text('9%')),
                      DropdownMenuItem(value: 0, child: Text('0%')),
                    ],
                    onChanged: (v) => setD(() => tva = v ?? 19),
                  ),
                ]),
              ),
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () async {
                  final sure = await showDialog<bool>(
                    context: ctx,
                    builder: (c2) => AlertDialog(
                      content: Text(c2.t('confirm_delete')),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(c2, false),
                            child: Text(c2.t('cancel'))),
                        FilledButton(
                            onPressed: () => Navigator.pop(c2, true),
                            child: Text(c2.t('delete'))),
                      ],
                    ),
                  );
                  if (sure == true) {
                    await AppDb.i.deleteProduct(existing.id!);
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  }
                },
                child: Text(ctx.t('delete'),
                    style: const TextStyle(color: Colors.red)),
              ),
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ctx.t('cancel'))),
            FilledButton(
              onPressed: () async {
                if (!form.currentState!.validate()) return;
                p
                  ..name = name.text.trim()
                  ..barcode = barcode.text.trim()
                  ..category = category.text.trim()
                  ..buy = double.tryParse(buy.text) ?? 0
                  ..sell = double.tryParse(sell.text) ?? 0
                  ..qty = double.tryParse(qty.text) ?? 0
                  ..minQty = double.tryParse(minQty.text) ?? 0
                  ..tva = tva;
                try {
                  await AppDb.i.saveProduct(p);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (_) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text('${ctx.t('barcode')} ✗')));
                  }
                }
              },
              child: Text(ctx.t('save')),
            ),
          ],
        ),
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppState>().refreshLow();
    }
  }
}
