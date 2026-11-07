import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/invoice_pdf.dart';
import '../state/app_state.dart';
import 'scanner_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  List<Product> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await AppDb.i.products(q: _search.text);
    if (mounted) setState(() => _items = r);
  }

  void _toast(String key) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.t(key))));
  }

  void _add(Product p) {
    final err = context.read<AppState>().addProduct(p);
    if (err != null) _toast(err);
  }

  /// قارئ USB يكتب الباركود ثم Enter؛ نبحث عن تطابق تام أولًا.
  Future<void> _submit(String v) async {
    final code = v.trim();
    if (code.isEmpty) return;
    final p = await AppDb.i.productByBarcode(code);
    if (p != null) {
      _add(p);
      _search.clear();
      await _load();
    } else if (_items.length == 1) {
      _add(_items.first);
      _search.clear();
      await _load();
    }
    _focus.requestFocus();
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const ScannerScreen()));
    if (code == null) return;
    final p = await AppDb.i.productByBarcode(code);
    if (!mounted) return;
    if (p != null) {
      _add(p);
    } else {
      _search.text = code;
      await _load();
    }
  }

  int _seen = -1;

  @override
  Widget build(BuildContext context) {
    final v = context.watch<AppState>().version;
    if (v != _seen) {
      _seen = v;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    final wide = MediaQuery.of(context).size.width >= 800;
    final catalog = _catalog(context);
    if (wide) {
      return Row(children: [
        Expanded(flex: 3, child: catalog),
        const VerticalDivider(width: 1),
        const Expanded(flex: 2, child: CartPanel()),
      ]);
    }
    final st = context.watch<AppState>();
    return Column(children: [
      Expanded(child: catalog),
      Material(
        elevation: 8,
        child: ListTile(
          leading: Badge(
            label: Text('${st.cart.length}'),
            isLabelVisible: st.cart.isNotEmpty,
            child: const Icon(Icons.shopping_cart),
          ),
          title: Text(money(st.grandTotal, st.lang),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          trailing: FilledButton(
            onPressed: st.cart.isEmpty
                ? null
                : () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => const CartPanel(),
                    ),
            child: Text(context.t('cart')),
          ),
        ),
      ),
    ]);
  }

  Widget _catalog(BuildContext context) {
    final lang = context.watch<AppState>().lang;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _search,
              focusNode: _focus,
              autofocus: true,
              onChanged: (_) => _load(),
              onSubmitted: _submit,
              decoration: InputDecoration(
                hintText: context.t('search_hint'),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          if (cameraScanSupported) ...[
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: context.t('scan'),
              onPressed: _scan,
              icon: const Icon(Icons.qr_code_scanner),
            ),
          ],
        ]),
      ),
      Expanded(
        child: _items.isEmpty
            ? Center(child: Text(context.t('no_data')))
            : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 190,
                  mainAxisExtent: 112,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final p = _items[i];
                  final out = p.qty <= 0;
                  return Card(
                    color: out
                        ? Theme.of(context).colorScheme.errorContainer
                        : null,
                    child: InkWell(
                      onTap: out ? null : () => _add(p),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            const Spacer(),
                            Text(money(p.sell, lang),
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold)),
                            Text(
                              '${context.t('qty')}: ${qtyStr(p.qty)}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: p.lowStock ? Colors.red : null),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}

class CartPanel extends StatelessWidget {
  const CartPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final lang = st.lang;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Row(children: [
          Text(context.t('cart'),
              style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          TextButton.icon(
            onPressed: st.cart.isEmpty ? null : st.clearCart,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: Text(context.t('clear')),
          ),
        ]),
      ),
      Expanded(
        child: st.cart.isEmpty
            ? Center(child: Text(context.t('cart_empty')))
            : ListView.separated(
                itemCount: st.cart.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final l = st.cart[i];
                  return ListTile(
                    title: Text(l.product.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: InkWell(
                      onTap: () => _editPrice(context, st, l),
                      child: Text(
                          '${money(l.price, lang)}  •  TVA ${qtyStr(l.product.tva)}%'),
                    ),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => st.setQty(l, l.qty - 1),
                      ),
                      InkWell(
                        onTap: () => _editQty(context, st, l),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(qtyStr(l.qty),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          final e = st.setQty(l, l.qty + 1);
                          if (e != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(context.t(e))));
                          }
                        },
                      ),
                      SizedBox(
                          width: 90,
                          child: Text(money(l.total, lang),
                              textAlign: TextAlign.end)),
                    ]),
                  );
                },
              ),
      ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: st.method,
                decoration:
                    InputDecoration(labelText: context.t('payment_method')),
                items: [
                  for (final m in ['cash', 'card', 'cheque', 'credit'])
                    DropdownMenuItem(value: m, child: Text(context.t(m))),
                ],
                onChanged: (v) => st.setMethod(v ?? 'cash'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickCustomer(context, st),
                icon: const Icon(Icons.person_outline),
                label: Text(st.customer?.name ?? context.t('no_customer'),
                    overflow: TextOverflow.ellipsis),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Text(context.t('discount')),
            const Spacer(),
            SizedBox(
              width: 110,
              child: TextFormField(
                key: ValueKey('disc${st.cart.length}'),
                initialValue: st.discount == 0 ? '' : qtyStr(st.discount),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.end,
                onChanged: (v) => st.setDiscount(double.tryParse(v) ?? 0),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          _row(context.t('total_ht'),
              money(st.grandTotal - st.stamp - st.tvaAmount, lang)),
          _row(context.t('tva'), money(st.tvaAmount, lang)),
          if (st.stamp > 0) _row(context.t('stamp'), money(st.stamp, lang)),
          _row(context.t('total'), money(st.grandTotal, lang), big: true),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: st.cart.isEmpty ? null : () => _pay(context, st),
              icon: const Icon(Icons.check),
              label: Text(context.t('pay')),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _row(String a, String b, {bool big = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Text(a,
              style: TextStyle(
                  fontSize: big ? 18 : 14,
                  fontWeight: big ? FontWeight.bold : null)),
          const Spacer(),
          Text(b,
              style: TextStyle(
                  fontSize: big ? 18 : 14,
                  fontWeight: big ? FontWeight.bold : null)),
        ]),
      );

  Future<void> _editQty(BuildContext context, AppState st, CartLine l) async {
    final v = await _numberDialog(context, context.t('qty'), l.qty);
    if (v != null) st.setQty(l, v);
  }

  Future<void> _editPrice(BuildContext context, AppState st, CartLine l) async {
    final v = await _numberDialog(context, context.t('unit_price'), l.price);
    if (v != null && v >= 0) st.setPrice(l, v);
  }

  Future<void> _pickCustomer(BuildContext context, AppState st) async {
    final list = await AppDb.i.customers();
    if (!context.mounted) return;
    final res = await showDialog<Customer?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(ctx.t('customer')),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(ctx.t('no_customer')),
          ),
          for (final c in list)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, c),
              child: Text(c.name),
            ),
        ],
      ),
    );
    st.setCustomer(res);
  }

  Future<void> _pay(BuildContext context, AppState st) async {
    double? paid;
    if (st.method == 'credit') {
      paid = await _numberDialog(context, context.t('paid'), 0);
      if (paid == null) return;
    }
    final r = await st.checkout(paid);
    if (!context.mounted) return;
    if (r.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.t(r.error!))));
      return;
    }
    final sale = r.sale!;
    final rootNav = Navigator.of(context, rootNavigator: true);
    if (Navigator.of(context).canPop()) Navigator.of(context).pop(); // يغلق السلة
    final items = await AppDb.i.saleItems(sale.id!);
    showDialog(
      context: rootNav.context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: Text(ctx.t('sale_done')),
        content: Text('${sale.invoiceNo}\n${money(sale.total, st.lang)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('close'))),
          TextButton.icon(
              onPressed: () => shareInvoice(st, sale, items),
              icon: const Icon(Icons.share),
              label: Text(ctx.t('share'))),
          FilledButton.icon(
              onPressed: () => printInvoice(st, sale, items),
              icon: const Icon(Icons.print),
              label: Text(ctx.t('print'))),
        ],
      ),
    );
  }
}

Future<double?> _numberDialog(
    BuildContext context, String title, double initial) {
  final c = TextEditingController(text: initial == 0 ? '' : qtyStr(initial));
  return showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onSubmitted: (v) => Navigator.pop(ctx, double.tryParse(v) ?? 0),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('cancel'))),
        FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(c.text) ?? 0),
            child: Text(ctx.t('save'))),
      ],
    ),
  );
}
