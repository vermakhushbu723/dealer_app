import '../../../core/storage/local_store.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/data/fake_auth_repository.dart';
import '../../notifications/domain/notification.dart';
import '../domain/ledger.dart';

class FakePaymentRepository implements PaymentRepository {
  FakePaymentRepository(this._store, this._notifications, {required this.creditLimit, required this.creditDays});

  final LocalStore _store;
  final NotificationRepository _notifications;
  final double creditLimit;
  final int creditDays;

  static const _key = 'ledger';
  static const _reminderKey = 'payment_reminder';

  List<LedgerEntry> _read() {
    final stored = _store.readList(_key);
    if (stored != null) return stored.map(LedgerEntry.fromJson).toList();
    return _store.scope == demoDealerId ? _sampleLedger() : [];
  }

  Future<void> _add(LedgerEntry entry) => _store.writeList(_key, [
    for (final e in [..._read(), entry]) e.toJson(),
  ]);

  @override
  Future<CreditSummary> creditSummary() async {
    final entries = _read();
    final outstanding = entries.fold<double>(0, (sum, e) => sum + (e.isDebit ? e.amount : -e.amount));
    // Payments settle the oldest invoices first, so whatever is still unpaid
    // beyond the invoices inside the credit period is overdue.
    final cutoff = DateTime.now().subtract(Duration(days: creditDays));
    final notYetDue = entries
        .where((e) => e.isDebit && e.date.isAfter(cutoff))
        .fold<double>(0, (sum, e) => sum + e.amount);
    final overdue = outstanding - notYetDue;
    return CreditSummary(
      limit: creditLimit,
      outstanding: roundMoney(outstanding),
      overdue: overdue < 0 ? 0 : roundMoney(overdue),
      creditDays: creditDays,
    );
  }

  @override
  Future<List<LedgerEntry>> ledger() async {
    await fakeLatency();
    return _read()..sort((a, b) => b.date.compareTo(a.date));
  }

  LedgerEntry _entry(LedgerType type, double amount, String reference, String description) {
    final now = DateTime.now();
    return LedgerEntry(
      id: 'l-${now.microsecondsSinceEpoch}',
      type: type,
      amount: amount,
      date: now,
      reference: reference,
      description: description,
    );
  }

  @override
  Future<void> postInvoice(String reference, double amount) =>
      _add(_entry(LedgerType.invoice, amount, reference, 'Order on credit'));

  @override
  Future<void> postCreditNote(String invoiceReference, double amount) =>
      _add(_entry(LedgerType.creditNote, amount, invoiceReference, 'Order cancelled'));

  @override
  Future<void> remindIfOverdue() async {
    final summary = await creditSummary();
    final today = dateOnly(DateTime.now()).toIso8601String();
    if (summary.overdue <= 0 || _store.readMap(_reminderKey)?['date'] == today) return;
    await _store.writeMap(_reminderKey, {'date': today});
    await _notifications.add(
      NotificationType.payment,
      'Payment overdue',
      '${money(summary.overdue)} is overdue. Please pay to keep your credit active.',
      route: '/payments',
    );
  }

  @override
  Future<void> recordPayment({required double amount, required PaymentMode mode, required String reference}) async {
    await fakeLatency();
    await _add(_entry(LedgerType.payment, amount, reference, mode.label));
    await _notifications.add(
      NotificationType.payment,
      'Payment recorded',
      '${money(amount)} by ${mode.label} (ref. $reference).',
      route: '/payments',
    );
  }

  /// Matches the sample orders in FakeOrderRepository.
  List<LedgerEntry> _sampleLedger() {
    LedgerEntry entry(int daysAgo, LedgerType type, double amount, String reference, String description) => LedgerEntry(
      id: 'sample-$daysAgo-${type.name}',
      type: type,
      amount: amount,
      date: DateTime.now().subtract(Duration(days: daysAgo)),
      reference: reference,
      description: description,
    );
    String invoice(int daysAgo, int serial) =>
        'INV-${DateTime.now().subtract(Duration(days: daysAgo)).year}-${100 + serial}';
    return [
      entry(146, LedgerType.invoice, 10313.2, invoice(146, 1), 'Order on credit'),
      entry(130, LedgerType.payment, 10313.2, 'UTR-SAMPLE-1', 'Bank transfer'),
      entry(115, LedgerType.invoice, 4177.2, invoice(115, 2), 'Order on credit'),
      entry(100, LedgerType.payment, 4177.2, 'UPI-SAMPLE-2', 'UPI'),
      entry(83, LedgerType.invoice, 2360, invoice(83, 3), 'Order on credit'),
      entry(70, LedgerType.payment, 2360, 'UPI-SAMPLE-3', 'UPI'),
      entry(52, LedgerType.invoice, 7953.2, invoice(52, 4), 'Order on credit'),
      entry(40, LedgerType.payment, 7953.2, 'UTR-SAMPLE-4', 'Bank transfer'),
      entry(24, LedgerType.invoice, 3776, invoice(24, 5), 'Order on credit'),
      entry(5, LedgerType.invoice, 6537.2, invoice(5, 6), 'Order on credit'),
    ];
  }
}
