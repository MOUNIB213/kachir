import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/app_state.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _search = TextEditingController();
  List<Customer> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await AppDb.i.customers(q: _search.text);
    if (mounted) setState(() => _items = r);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;
    final totalDebt =
        _items.fold<double>(0, (s, c) => s + (c.balance > 0 ? c.balance : 0));
    return Scaffold(
      appBar: AppBar(title: Text(context.t('customers'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(null),
        child: const Icon(Icons.person_add_alt_1),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _search,
            onChanged: (_) => _load(),
            decoration: InputDecoration(
              hintText: context.t('search_hint'),
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(context.t('total_debts')),
            trailing: Text(money(totalDebt, lang),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        Expanded(
          child: _items.isEmpty
              ? Center(child: Text(context.t('no_data')))
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = _items[i];
                    return ListTile(
                      onTap: () => _edit(c),
                      leading: CircleAvatar(
                          child: Text(c.name.isEmpty ? '?' : c.name[0])),
                      title: Text(c.name),
                      subtitle: Text(c.phone),
                      trailing: c.balance > 0
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(money(c.balance, lang),
                                  style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold)),
                              IconButton(
                                tooltip: context.t('pay_debt'),
                                icon: const Icon(Icons.payments_outlined),
                                onPressed: () => _payDebt(c),
                              ),
                            ])
                          : null,
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Future<void> _payDebt(Customer c) async {
    final lang = context.read<AppState>().lang;
    final ctrl = TextEditingController(text: qtyStr(c.balance));
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${ctx.t('pay_debt')} - ${c.name}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${ctx.t('debt')}: ${money(c.balance, lang)}'),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: ctx.t('amount')),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('cancel'))),
          FilledButton(
              onPressed: () {
                final v = double.tryParse(ctrl.text) ?? 0;
                Navigator.pop(ctx, v.clamp(0, c.balance).toDouble());
              },
              child: Text(ctx.t('save'))),
        ],
      ),
    );
    if (amount != null && amount > 0) {
      await AppDb.i.payDebt(c.id!, amount);
      await _load();
    }
  }

  Future<void> _edit(Customer? existing) async {
    final c = existing ?? Customer(name: '');
    final name = TextEditingController(text: c.name);
    final phone = TextEditingController(text: c.phone);
    final address = TextEditingController(text: c.address);
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? ctx.t('add') : ctx.t('edit')),
        content: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: name,
              decoration: InputDecoration(labelText: ctx.t('name')),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? ctx.t('required') : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: ctx.t('phone')),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: address,
              decoration: InputDecoration(labelText: ctx.t('address')),
            ),
          ]),
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () async {
                await AppDb.i.deleteCustomer(existing.id!);
                if (ctx.mounted) Navigator.pop(ctx, true);
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
              c
                ..name = name.text.trim()
                ..phone = phone.text.trim()
                ..address = address.text.trim();
              await AppDb.i.saveCustomer(c);
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: Text(ctx.t('save')),
          ),
        ],
      ),
    );
    if (ok == true) await _load();
  }
}
