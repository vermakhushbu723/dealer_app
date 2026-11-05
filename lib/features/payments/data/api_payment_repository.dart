import '../../../core/network/api_client.dart';
import '../domain/ledger.dart';

/// Invoices and credit notes are posted by the server when orders change.
class ApiPaymentRepository implements PaymentRepository {
  ApiPaymentRepository(this._api);

  final ApiClient _api;

  @override
  Future<CreditSummary> creditSummary() async {
    final j = await _api.get('/dealer/credit-summary') as Map<String, dynamic>;
    return CreditSummary(limit: (j['limit'] as num).toDouble(), outstanding: (j['outstanding'] as num).toDouble(), overdue: (j['overdue'] as num).toDouble(), creditDays: j['creditDays'] as int);
  }

  @override
  Future<List<LedgerEntry>> ledger() async => (await _api.get('/dealer/ledger') as Object).mapped(LedgerEntry.fromJson);

  @override
  Future<void> postInvoice(String reference, double amount) async {}

  @override
  Future<void> postCreditNote(String invoiceReference, double amount) async {}

  @override
  Future<void> remindIfOverdue() => _api.post('/dealer/payments/remind');

  @override
  Future<void> recordPayment({required double amount, required PaymentMode mode, required String reference}) =>
      _api.post('/dealer/payments', {'amount': amount, 'mode': mode.name, 'reference': reference});
}
