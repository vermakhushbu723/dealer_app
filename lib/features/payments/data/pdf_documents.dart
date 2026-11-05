import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/domain/dealer.dart';
import '../../orders/domain/order.dart';
import '../domain/ledger.dart';

/// The PDF's built-in font has no rupee sign, so amounts use "Rs.".
String _rs(num value) => money(value).replaceAll('₹', 'Rs. ');

pw.Widget _header(String title, String reference) => pw.Row(
  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(AppConstants.companyName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Text(AppConstants.serviceArea),
        pw.Text(AppConstants.supportPhone),
        if (AppConstants.companyGstin.isNotEmpty) pw.Text('GSTIN: ${AppConstants.companyGstin}'),
        if (AppConstants.companyFssai.isNotEmpty) pw.Text('FSSAI: ${AppConstants.companyFssai}'),
      ],
    ),
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0084CC)),
        ),
        pw.Text(reference),
      ],
    ),
  ],
);

pw.Widget _dealerBlock(String heading, Dealer dealer) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(heading, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
    pw.Text(dealer.businessName),
    pw.Text('${dealer.addressLine}, ${dealer.city} - ${dealer.pincode}'),
    if (dealer.gstin.isNotEmpty) pw.Text('GSTIN: ${dealer.gstin}'),
    if (dealer.fssai.isNotEmpty) pw.Text('FSSAI: ${dealer.fssai}'),
  ],
);

pw.Widget _table(List<String> headers, List<List<String>> rows, Set<int> rightAligned) => pw.TableHelper.fromTextArray(
  headers: headers,
  data: rows,
  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFDFF2FE)),
  border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColor.fromInt(0xFFDFF2FE))),
  cellAlignments: {for (final i in rightAligned) i: pw.Alignment.centerRight},
);

pw.Widget _totalRow(String label, String value, {bool bold = false}) {
  final style = pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.SizedBox(width: 120, child: pw.Text(label, style: style)),
        pw.SizedBox(
          width: 90,
          child: pw.Text(value, style: style, textAlign: pw.TextAlign.right),
        ),
      ],
    ),
  );
}

Future<Uint8List> buildInvoicePdf(Order order, Dealer dealer) {
  // Same state means CGST + SGST, another state means IGST.
  final isIntraState = dealer.gstin.isEmpty || dealer.gstin.startsWith(AppConstants.companyStateCode);
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _header(AppConstants.companyGstin.isEmpty ? 'INVOICE' : 'TAX INVOICE', order.invoiceNumber),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _dealerBlock('Bill to', dealer)),
              pw.SizedBox(width: 20),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Order: ${order.number}'),
                  pw.Text('Date: ${formatDate(order.placedAt)}'),
                  pw.Text('Delivery: ${formatDate(order.deliveryDate)}, ${order.slot}'),
                  pw.Text('Payment: ${order.paymentMethod.label} (${order.paymentStatus.label})'),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text('Deliver to: ${order.address.singleLine}'),
          pw.SizedBox(height: 16),
          _table(
            ['Item', 'HSN', 'Qty', 'Rate', 'GST', 'Amount'],
            [
              for (final l in order.lines)
                [
                  '${l.name} (${l.packSize})',
                  l.hsnCode,
                  '${l.quantity} ${l.unit}',
                  _rs(l.unitPrice),
                  '${l.gstPercent.toStringAsFixed(0)}%',
                  _rs(l.amount),
                ],
            ],
            {2, 3, 4, 5},
          ),
          pw.SizedBox(height: 12),
          _totalRow('Subtotal', _rs(order.subtotal)),
          if (order.discount > 0) _totalRow('Discount', '- ${_rs(order.discount)}'),
          if (isIntraState) ...[
            _totalRow('CGST', _rs(roundMoney(order.gst / 2))),
            _totalRow('SGST', _rs(order.gst - roundMoney(order.gst / 2))),
          ] else
            _totalRow('IGST', _rs(order.gst)),
          _totalRow('Delivery', _rs(order.deliveryFee)),
          pw.Divider(color: PdfColor.fromInt(0xFFDFF2FE)),
          _totalRow('Total', _rs(order.total), bold: true),
        ],
      ),
    ),
  );
  return doc.save();
}

Future<Uint8List> buildStatementPdf(List<LedgerEntry> entries, CreditSummary summary, Dealer dealer) {
  final oldestFirst = entries.reversed.toList();
  var balance = 0.0;
  final rows = <List<String>>[];
  for (final e in oldestFirst) {
    balance += e.isDebit ? e.amount : -e.amount;
    rows.add([
      formatDate(e.date),
      '${e.type.label} ${e.reference}',
      e.isDebit ? _rs(e.amount) : '',
      e.isDebit ? '' : _rs(e.amount),
      _rs(balance),
    ]);
  }
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (_) => [
        _header('STATEMENT', formatDate(DateTime.now())),
        pw.SizedBox(height: 20),
        _dealerBlock('Account', dealer),
        pw.SizedBox(height: 16),
        _table(['Date', 'Details', 'Debit', 'Credit', 'Balance'], rows, {2, 3, 4}),
        pw.SizedBox(height: 12),
        _totalRow('Outstanding', _rs(summary.outstanding), bold: true),
        _totalRow('Overdue', _rs(summary.overdue)),
        _totalRow('Credit limit', _rs(summary.limit)),
      ],
    ),
  );
  return doc.save();
}

Future<Uint8List> buildReceiptPdf(LedgerEntry payment, Dealer dealer) {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _header('RECEIPT', payment.receiptNumber),
          pw.SizedBox(height: 20),
          _dealerBlock('Received from', dealer),
          pw.SizedBox(height: 16),
          pw.Text('Date: ${formatDateTime(payment.date)}'),
          pw.Text('Paid by: ${payment.description}'),
          pw.Text('Reference: ${payment.reference}'),
          pw.SizedBox(height: 16),
          pw.Text(
            'Amount received: ${_rs(payment.amount)}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}
