class Product {
  int? id;
  String name;
  String barcode;
  String category;
  double buy; // سعر الشراء
  double sell; // سعر البيع (TTC)
  double qty;
  double minQty;
  double tva; // 0, 9, 19

  Product({
    this.id,
    required this.name,
    this.barcode = '',
    this.category = '',
    this.buy = 0,
    this.sell = 0,
    this.qty = 0,
    this.minQty = 0,
    this.tva = 19,
  });

  bool get lowStock => qty <= minQty;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'barcode': barcode.isEmpty ? null : barcode,
        'category': category,
        'buy': buy,
        'sell': sell,
        'qty': qty,
        'min_qty': minQty,
        'tva': tva,
      };

  factory Product.fromMap(Map<String, Object?> m) => Product(
        id: m['id'] as int?,
        name: m['name'] as String,
        barcode: (m['barcode'] as String?) ?? '',
        category: (m['category'] as String?) ?? '',
        buy: (m['buy'] as num).toDouble(),
        sell: (m['sell'] as num).toDouble(),
        qty: (m['qty'] as num).toDouble(),
        minQty: (m['min_qty'] as num).toDouble(),
        tva: (m['tva'] as num).toDouble(),
      );
}

class Customer {
  int? id;
  String name;
  String phone;
  String address;
  double balance; // الدين المتبقي على الزبون

  Customer({
    this.id,
    required this.name,
    this.phone = '',
    this.address = '',
    this.balance = 0,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'balance': balance,
      };

  factory Customer.fromMap(Map<String, Object?> m) => Customer(
        id: m['id'] as int?,
        name: m['name'] as String,
        phone: (m['phone'] as String?) ?? '',
        address: (m['address'] as String?) ?? '',
        balance: (m['balance'] as num).toDouble(),
      );
}

class CartLine {
  final Product product;
  double qty;
  double price; // سعر الوحدة TTC (قابل للتعديل)

  CartLine(this.product, {this.qty = 1, double? price})
      : price = price ?? product.sell;

  double get total => qty * price;
}

class SaleItem {
  final int? productId;
  final String name;
  final double qty;
  final double price;
  final double cost;
  final double tva;

  SaleItem({
    this.productId,
    required this.name,
    required this.qty,
    required this.price,
    required this.cost,
    required this.tva,
  });

  double get total => qty * price;

  factory SaleItem.fromMap(Map<String, Object?> m) => SaleItem(
        productId: m['product_id'] as int?,
        name: m['name'] as String,
        qty: (m['qty'] as num).toDouble(),
        price: (m['price'] as num).toDouble(),
        cost: (m['cost'] as num).toDouble(),
        tva: (m['tva'] as num).toDouble(),
      );
}

class Sale {
  int? id;
  String invoiceNo;
  DateTime date;
  int? customerId;
  String customerName;
  double subtotal; // مجموع TTC قبل التخفيض
  double discount;
  double tva; // مبلغ TVA المتضمن
  double stamp; // حق الطابع
  double total; // المبلغ النهائي
  double paid;
  String method; // cash | card | cheque | credit

  Sale({
    this.id,
    this.invoiceNo = '',
    required this.date,
    this.customerId,
    this.customerName = '',
    required this.subtotal,
    this.discount = 0,
    required this.tva,
    this.stamp = 0,
    required this.total,
    required this.paid,
    this.method = 'cash',
  });

  double get rest => total - paid;
  double get ht => total - stamp - tva;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'invoice_no': invoiceNo,
        'date': date.toIso8601String(),
        'customer_id': customerId,
        'customer_name': customerName,
        'subtotal': subtotal,
        'discount': discount,
        'tva': tva,
        'stamp': stamp,
        'total': total,
        'paid': paid,
        'method': method,
      };

  factory Sale.fromMap(Map<String, Object?> m) => Sale(
        id: m['id'] as int?,
        invoiceNo: m['invoice_no'] as String,
        date: DateTime.parse(m['date'] as String),
        customerId: m['customer_id'] as int?,
        customerName: (m['customer_name'] as String?) ?? '',
        subtotal: (m['subtotal'] as num).toDouble(),
        discount: (m['discount'] as num).toDouble(),
        tva: (m['tva'] as num).toDouble(),
        stamp: (m['stamp'] as num).toDouble(),
        total: (m['total'] as num).toDouble(),
        paid: (m['paid'] as num).toDouble(),
        method: m['method'] as String,
      );
}

class Summary {
  final double revenue;
  final int count;
  final double profit;
  final double debts;
  const Summary(this.revenue, this.count, this.profit, this.debts);
}
