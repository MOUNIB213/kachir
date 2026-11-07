import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/models.dart';

class AppDb {
  AppDb._();
  static final AppDb i = AppDb._();

  late Database db;

  Future<void> init() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dir = await databaseFactory.getDatabasesPath();
    db = await databaseFactory.openDatabase(
      p.join(dir, 'dz_cashier.db'),
      options: OpenDatabaseOptions(version: 1, onCreate: _create),
    );
  }

  Future<void> _create(Database d, int v) async {
    await d.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        barcode TEXT UNIQUE,
        category TEXT DEFAULT '',
        buy REAL DEFAULT 0,
        sell REAL DEFAULT 0,
        qty REAL DEFAULT 0,
        min_qty REAL DEFAULT 0,
        tva REAL DEFAULT 19
      )''');
    await d.execute('''
      CREATE TABLE customers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT DEFAULT '',
        address TEXT DEFAULT '',
        balance REAL DEFAULT 0
      )''');
    await d.execute('''
      CREATE TABLE sales(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_no TEXT,
        date TEXT NOT NULL,
        customer_id INTEGER,
        customer_name TEXT DEFAULT '',
        subtotal REAL, discount REAL, tva REAL, stamp REAL,
        total REAL, paid REAL, method TEXT
      )''');
    await d.execute('''
      CREATE TABLE sale_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER,
        name TEXT, qty REAL, price REAL, cost REAL, tva REAL
      )''');
    await d.execute('''
      CREATE TABLE debt_payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT DEFAULT ''
      )''');
  }

  // ---------- المنتجات ----------
  Future<List<Product>> products({String q = '', bool lowOnly = false}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (q.trim().isNotEmpty) {
      where.add('(name LIKE ? OR barcode LIKE ? OR category LIKE ?)');
      args.addAll(['%$q%', '%$q%', '%$q%']);
    }
    if (lowOnly) where.add('qty <= min_qty');
    final rows = await db.query('products',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: args,
        orderBy: 'name COLLATE NOCASE');
    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> productByBarcode(String code) async {
    final rows =
        await db.query('products', where: 'barcode = ?', whereArgs: [code]);
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  Future<void> saveProduct(Product x) async {
    if (x.id == null) {
      await db.insert('products', x.toMap());
    } else {
      await db.update('products', x.toMap(), where: 'id = ?', whereArgs: [x.id]);
    }
  }

  Future<void> deleteProduct(int id) =>
      db.delete('products', where: 'id = ?', whereArgs: [id]);

  Future<int> lowStockCount() async {
    final r = await db
        .rawQuery('SELECT COUNT(*) c FROM products WHERE qty <= min_qty');
    return (r.first['c'] as int?) ?? 0;
  }

  // ---------- الزبائن ----------
  Future<List<Customer>> customers({String q = ''}) async {
    final rows = await db.query('customers',
        where: q.isEmpty ? null : 'name LIKE ? OR phone LIKE ?',
        whereArgs: q.isEmpty ? null : ['%$q%', '%$q%'],
        orderBy: 'name COLLATE NOCASE');
    return rows.map(Customer.fromMap).toList();
  }

  Future<void> saveCustomer(Customer c) async {
    if (c.id == null) {
      await db.insert('customers', c.toMap());
    } else {
      await db.update('customers', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
    }
  }

  Future<void> deleteCustomer(int id) =>
      db.delete('customers', where: 'id = ?', whereArgs: [id]);

  Future<void> payDebt(int customerId, double amount, {String note = ''}) async {
    await db.transaction((t) async {
      await t.insert('debt_payments', {
        'customer_id': customerId,
        'amount': amount,
        'date': DateTime.now().toIso8601String(),
        'note': note,
      });
      await t.rawUpdate(
          'UPDATE customers SET balance = balance - ? WHERE id = ?',
          [amount, customerId]);
    });
  }

  // ---------- المبيعات ----------
  Future<Sale> createSale(Sale s, List<CartLine> lines) async {
    return db.transaction((t) async {
      s.invoiceNo = 'TMP';
      final id = await t.insert('sales', s.toMap());
      s.id = id;
      s.invoiceNo = 'F${s.date.year}-${id.toString().padLeft(6, '0')}';
      await t.update('sales', {'invoice_no': s.invoiceNo},
          where: 'id = ?', whereArgs: [id]);
      for (final l in lines) {
        await t.insert('sale_items', {
          'sale_id': id,
          'product_id': l.product.id,
          'name': l.product.name,
          'qty': l.qty,
          'price': l.price,
          'cost': l.product.buy,
          'tva': l.product.tva,
        });
        await t.rawUpdate('UPDATE products SET qty = qty - ? WHERE id = ?',
            [l.qty, l.product.id]);
      }
      if (s.customerId != null && s.rest > 0) {
        await t.rawUpdate(
            'UPDATE customers SET balance = balance + ? WHERE id = ?',
            [s.rest, s.customerId]);
      }
      return s;
    });
  }

  Future<List<Sale>> sales({DateTime? from}) async {
    final rows = await db.query('sales',
        where: from == null ? null : 'date >= ?',
        whereArgs: from == null ? null : [from.toIso8601String()],
        orderBy: 'date DESC');
    return rows.map(Sale.fromMap).toList();
  }

  Future<List<SaleItem>> saleItems(int saleId) async {
    final rows = await db
        .query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
    return rows.map(SaleItem.fromMap).toList();
  }

  Future<Summary> summary({DateTime? from}) async {
    final w = from == null ? '' : 'WHERE date >= ?';
    final a = from == null ? <Object?>[] : [from.toIso8601String()];
    final r = await db.rawQuery(
        'SELECT COALESCE(SUM(total),0) rev, COUNT(*) c, COALESCE(SUM(discount),0) disc FROM sales $w',
        a);
    final w2 = from == null ? '' : 'WHERE s.date >= ?';
    final pr = await db.rawQuery(
        'SELECT COALESCE(SUM(si.qty*(si.price-si.cost)),0) gp FROM sale_items si JOIN sales s ON s.id = si.sale_id $w2',
        a);
    final d = await db
        .rawQuery('SELECT COALESCE(SUM(balance),0) b FROM customers WHERE balance > 0');
    final gp = (pr.first['gp'] as num).toDouble();
    final disc = (r.first['disc'] as num).toDouble();
    return Summary(
      (r.first['rev'] as num).toDouble(),
      (r.first['c'] as int),
      gp - disc,
      (d.first['b'] as num).toDouble(),
    );
  }
}
