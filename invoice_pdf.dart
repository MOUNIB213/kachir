import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/app_state.dart';

/// يحاول تحميل خط Cairo من assets/fonts ثم يرجع إلى خط Google (يحتاج إنترنت).
Future<pw.Font> _font(String file, bool bold) async {
  try {
    final data = await rootBundle.load('assets/fonts/$file');
    return pw.Font.ttf(data);
  } catch (_) {
    return bold ? PdfGoogleFonts.cairoBold() : PdfGoogleFonts.cairoRegular();
  }
}

Future<Uint8List> buildInvoicePdf(
    AppState st, Sale sale, List<SaleItem> items) async {
  final lang = st.lang;
  final rtl = lang == 'ar';
  final thermal = st.thermal;
  final regular = await _font('Cairo-Regular.ttf', false);
  final bold = await _font('Cairo-Bold.ttf', true);
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);
  // MultiPage لا يقبل ارتفاعًا لانهائيًا (roll80)، لذا نستعمل عرض 80mm بارتفاع ثابت.
  final fmt = PdfPageFormat(
      80 * PdfPageFormat.mm, 297 * PdfPageFormat.mm,
      marginAll: 4 * PdfPageFormat.mm);
  final df = DateFormat('dd/MM/yyyy HH:mm');

  String m(double v) => money(v, lang);
  String t(String k) => tr(k, lang);

  pw.Widget line(String a, String b, {bool strong = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(a,
                style: pw.TextStyle(
                    fontWeight: strong ? pw.FontWeight.bold : null)),
            pw.Text(b,
                style: pw.TextStyle(
                    fontWeight: strong ? pw.FontWeight.bold : null)),
          ],
        ),
      );

  final idLines = <String>[
    if (st.getS('nif').isNotEmpty) 'NIF: ${st.getS('nif')}',
    if (st.getS('nis').isNotEmpty) 'NIS: ${st.getS('nis')}',
    if (st.getS('rc').isNotEmpty) 'RC: ${st.getS('rc')}',
    if (st.getS('ai').isNotEmpty) 'AI: ${st.getS('ai')}',
  ];

  final doc = pw.Document(theme: theme);
  doc.addPage(pw.MultiPage(
    pageFormat: thermal ? fmt : PdfPageFormat.a4,
    textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
    margin: thermal ? null : const pw.EdgeInsets.all(32),
    build: (ctx) => [
      pw.Center(
        child: pw.Column(children: [
          pw.Text(st.getS('store_name', t('app')),
              style: pw.TextStyle(
                  fontSize: thermal ? 14 : 20, fontWeight: pw.FontWeight.bold)),
          if (st.getS('address').isNotEmpty) pw.Text(st.getS('address')),
          if (st.getS('phone').isNotEmpty) pw.Text(st.getS('phone')),
          for (final l in idLines) pw.Text(l, style: const pw.TextStyle(fontSize: 9)),
        ]),
      ),
      pw.SizedBox(height: 8),
      pw.Divider(),
      line('${t('invoice')}', sale.invoiceNo, strong: true),
      line(t('date'), df.format(sale.date)),
      if (sale.customerName.isNotEmpty) line(t('customer'), sale.customerName),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        headers: [t('items'), t('qty'), t('unit_price'), t('total')],
        data: [
          for (final i in items)
            [i.name, qtyStr(i.qty), m(i.price), m(i.total)],
        ],
        headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold, fontSize: thermal ? 8 : 10),
        cellStyle: pw.TextStyle(fontSize: thermal ? 8 : 10),
        cellAlignment: pw.Alignment.center,
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      ),
      pw.SizedBox(height: 8),
      pw.Divider(),
      line(t('subtotal'), m(sale.subtotal)),
      if (sale.discount > 0) line(t('discount'), '- ${m(sale.discount)}'),
      line(t('total_ht'), m(sale.ht)),
      line(t('tva'), m(sale.tva)),
      if (sale.stamp > 0) line(t('stamp'), m(sale.stamp)),
      pw.Divider(),
      line(t('total'), m(sale.total), strong: true),
      line(t('paid'), m(sale.paid)),
      if (sale.rest > 0) line(t('rest'), m(sale.rest), strong: true),
      line(t('payment_method'), t(sale.method)),
      pw.SizedBox(height: 12),
      pw.Center(child: pw.Text(t('merci'))),
    ],
  ));
  return doc.save();
}

Future<void> printInvoice(AppState st, Sale sale, List<SaleItem> items) async {
  final bytes = await buildInvoicePdf(st, sale, items);
  await Printing.layoutPdf(
    name: sale.invoiceNo,
    onLayout: (_) async => bytes,
  );
}

Future<void> shareInvoice(AppState st, Sale sale, List<SaleItem> items) async {
  final bytes = await buildInvoicePdf(st, sale, items);
  await Printing.sharePdf(bytes: bytes, filename: '${sale.invoiceNo}.pdf');
}
