enum LedgerType { invoice, payment, creditNote }

enum PaymentMode { online, upi, bankTransfer, cheque, cash }

extension PaymentModeLabel on PaymentMode {
  String get label => switch (this) {
    PaymentMode.online => 'Online',
    PaymentMode.upi => 'UPI',
    PaymentMode.bankTransfer => 'Bank transfer',
    PaymentMode.cheque => 'Cheque',
    PaymentMode.cash => 'Cash',
  };
}

extension LedgerTypeLabel on LedgerType {
  String get label => switch (this) {
    LedgerType.invoice => 'Invoice',
    LedgerType.payment => 'Payment',
    LedgerType.creditNote => 'Credit note',
  };
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.reference,
    this.description = '',
  });

  final String id;
  final LedgerType type;

  /// Always positive. [isDebit] says which way it moves the balance.
  final double amount;
  final DateTime date;
  final String reference;
  final String description;

  bool get isDebit => type == LedgerType.invoice;
  bool get isPayment => type == LedgerType.payment;

  /// Payments only.
  String get receiptNumber => 'RCPT-${id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase()}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'date': date.toIso8601String(),
    'reference': reference,
    'description': description,
  };

  factory LedgerEntry.fromJson(Map<String, dynamic> j) => LedgerEntry(
    id: j['id'] as String,
    type: LedgerType.values.byName(j['type'] as String),
    amount: (j['amount'] as num).toDouble(),
    date: DateTime.parse(j['date'] as String),
    reference: j['reference'] as String,
    description: j['description'] as String,
  );
}

class CreditSummary {
  const CreditSummary({
    required this.limit,
    required this.outstanding,
    required this.overdue,
    required this.creditDays,
  });

  final double limit;
  final double outstanding;
  final double overdue;
  final int creditDays;

  double get available => limit - outstanding < 0 ? 0 : limit - outstanding;
  bool get hasCreditAccount => limit > 0;
}

abstract interface class PaymentRepository {
  Future<CreditSummary> creditSummary();

  /// Newest first.
  Future<List<LedgerEntry>> ledger();

  Future<void> postInvoice(String reference, double amount);

  Future<void> postCreditNote(String invoiceReference, double amount);

  /// Sends a payment reminder if money is overdue, at most once a day.
  Future<void> remindIfOverdue();

  Future<void> recordPayment({required double amount, required PaymentMode mode, required String reference});
}
