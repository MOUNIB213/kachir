import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database.dart';
import '../models/models.dart';

class AppState extends ChangeNotifier {
  late SharedPreferences prefs;
  String lang = 'ar';

  // سلة البيع الحالية
  final List<CartLine> cart = [];
  double discount = 0;
  Customer? customer;
  String method = 'cash';
  int lowStock = 0;
  int version = 0; // يزيد عند تغيّر المخزون ليعيد شاشة البيع تحميل المنتجات

  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    lang = prefs.getString('lang') ?? 'ar';
    await AppDb.i.init();
    await refreshLow();
  }

  Future<void> refreshLow() async {
    lowStock = await AppDb.i.lowStockCount();
    version++;
    notifyListeners();
  }

  // ---------- الإعدادات ----------
  String getS(String k, [String d = '']) => prefs.getString(k) ?? d;
  Future<void> setS(String k, String v) => prefs.setString(k, v);
  bool get thermal => prefs.getBool('thermal') ?? false;
  bool get stampOn => prefs.getBool('stamp_on') ?? false;
  double get stampRate => double.tryParse(getS('stamp_rate', '1')) ?? 1;

  Future<void> setLang(String l) async {
    lang = l;
    await prefs.setString('lang', l);
    notifyListeners();
  }

  Future<void> setBool(String k, bool v) async {
    await prefs.setBool(k, v);
    notifyListeners();
  }

  // ---------- السلة ----------
  double get subtotal => cart.fold(0.0, (s, l) => s + l.total);
  double get afterDiscount => max(0, subtotal - discount);
  double get _factor => subtotal > 0 ? afterDiscount / subtotal : 1;

  double get tvaAmount => cart.fold(0.0, (s, l) {
        final r = l.product.tva / 100;
        return s + l.total * _factor * r / (1 + r);
      });

  double get stamp {
    if (!stampOn || method != 'cash' || afterDiscount <= 0) return 0;
    final v = afterDiscount * stampRate / 100;
    return v.clamp(5, 2500).ceilToDouble();
  }

  double get grandTotal => afterDiscount + stamp;

  /// يرجع null عند النجاح أو مفتاح رسالة الخطأ.
  String? addProduct(Product p, {double qty = 1}) {
    final i = cart.indexWhere((l) => l.product.id == p.id);
    final current = i >= 0 ? cart[i].qty : 0;
    if (current + qty > p.qty) return 'out_of_stock';
    if (i >= 0) {
      cart[i].qty += qty;
    } else {
      cart.add(CartLine(p, qty: qty));
    }
    notifyListeners();
    return null;
  }

  String? setQty(CartLine l, double q) {
    if (q <= 0) {
      cart.remove(l);
    } else if (q > l.product.qty) {
      return 'out_of_stock';
    } else {
      l.qty = q;
    }
    notifyListeners();
    return null;
  }

  void setPrice(CartLine l, double p) {
    l.price = p;
    notifyListeners();
  }

  void removeLine(CartLine l) {
    cart.remove(l);
    notifyListeners();
  }

  void setDiscount(double d) {
    discount = d < 0 ? 0 : d;
    notifyListeners();
  }

  void setCustomer(Customer? c) {
    customer = c;
    notifyListeners();
  }

  void setMethod(String m) {
    method = m;
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    discount = 0;
    customer = null;
    method = 'cash';
    notifyListeners();
  }

  /// إتمام البيع. paid = المبلغ المدفوع (للكريدي قد يكون أقل من الإجمالي).
  Future<({Sale? sale, String? error})> checkout(double? paidAmount) async {
    if (cart.isEmpty) return (sale: null, error: 'cart_empty');
    final total = grandTotal;
    final paid = method == 'credit' ? (paidAmount ?? 0) : total;
    if (paid < total && customer == null) {
      return (sale: null, error: 'need_customer');
    }
    final sale = Sale(
      date: DateTime.now(),
      customerId: customer?.id,
      customerName: customer?.name ?? '',
      subtotal: subtotal,
      discount: discount,
      tva: tvaAmount,
      stamp: stamp,
      total: total,
      paid: paid,
      method: method,
    );
    final lines = List<CartLine>.from(cart);
    final saved = await AppDb.i.createSale(sale, lines);
    clearCart();
    await refreshLow();
    return (sale: saved, error: null);
  }
}
