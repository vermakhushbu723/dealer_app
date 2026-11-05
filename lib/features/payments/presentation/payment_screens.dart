import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/order_providers.dart';
import '../../orders/presentation/order_screens.dart';
import '../data/pdf_documents.dart';
import '../domain/ledger.dart';

class CreditCard extends StatelessWidget {
  const CreditCard({super.key, required this.credit, this.onTap});

  final CreditSummary credit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final used = credit.limit == 0 ? 0.0 : (credit.outstanding / credit.limit).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: onTap,
      child: GradientHeader(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Outstanding balance', style: text.labelMedium?.copyWith(color: AppColors.neutral900)),
            Text(money(credit.outstanding), style: text.displaySmall),
            if (credit.hasCreditAccount) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: used,
                  minHeight: 6,
                  backgroundColor: Colors.white54,
                  color: AppColors.sky700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${money(credit.available)} available of ${money(credit.limit)} · ${credit.creditDays} day terms',
                style: text.labelMedium?.copyWith(color: AppColors.neutral900),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _shareReceipt(WidgetRef ref, LedgerEntry payment) async {
  final bytes = await buildReceiptPdf(payment, ref.read(currentDealerProvider));
  await Printing.sharePdf(bytes: bytes, filename: '${payment.receiptNumber}.pdf');
}

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: AsyncBody(
        value: ref.watch(creditSummaryProvider),
        onRetry: () => ref.invalidate(creditSummaryProvider),
        builder: (credit) {
          final recent = (ref.watch(ledgerProvider).value ?? const <LedgerEntry>[])
              .where((e) => e.isPayment)
              .take(5)
              .toList();
          return RefreshIndicator(
            onRefresh: () async => refreshOrdersAndBalance(ref),
            child: ListView(
              padding: AppSpacing.page,
              children: [
                CreditCard(credit: credit),
                if (credit.overdue > 0) ...[
                  const SizedBox(height: 10),
                  NoticeBanner(
                    '${money(credit.overdue)} is overdue. Please pay to keep your credit active.',
                    color: AppColors.red600,
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => context.push(Routes.recordPayment, extra: PaymentMode.online),
                  icon: const Icon(Icons.credit_card),
                  label: const Text('Pay online'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.push(Routes.recordPayment, extra: PaymentMode.upi),
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('UPI payment'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.push(Routes.recordPayment, extra: PaymentMode.bankTransfer),
                  icon: const Icon(Icons.account_balance_outlined),
                  label: const Text('Record bank, cheque or cash payment'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.push(Routes.invoices),
                        child: const Text('GST bills'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(onPressed: () => context.push(Routes.ledger), child: const Text('Ledger')),
                    ),
                  ],
                ),
                SectionTitle(
                  'Payment history',
                  actionLabel: 'See all',
                  onAction: () => context.push(Routes.paymentHistory),
                ),
                if (recent.isEmpty) const Text('No payments yet.'),
                for (final entry in recent) _LedgerTile(entry: entry),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LedgerTile extends ConsumerWidget {
  const _LedgerTile({required this.entry});

  final LedgerEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              entry.isDebit ? Icons.receipt_long_outlined : Icons.check_circle_outline,
              color: entry.isDebit ? AppColors.sky600 : AppColors.green600,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${entry.type.label} · ${entry.reference}', style: text.labelMedium),
                  Text('${formatDate(entry.date)} · ${entry.description}', style: text.bodySmall),
                ],
              ),
            ),
            Text(
              '${entry.isDebit ? 'Dr' : 'Cr'} ${money(entry.amount)}',
              style: text.labelLarge?.copyWith(color: entry.isDebit ? AppColors.neutral900 : AppColors.green600),
            ),
            if (entry.isPayment)
              IconButton(
                tooltip: 'Download receipt',
                icon: const Icon(Icons.download_outlined),
                onPressed: () => _shareReceipt(ref, entry),
              ),
          ],
        ),
      ),
    );
  }
}

class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment history and receipts')),
      body: AsyncBody(
        value: ref.watch(ledgerProvider),
        builder: (entries) {
          final payments = entries.where((e) => e.isPayment).toList();
          if (payments.isEmpty) return const EmptyState(icon: Icons.payments_outlined, title: 'No payments yet');
          return ListView(
            padding: AppSpacing.page,
            children: [for (final p in payments) _LedgerTile(entry: p)],
          );
        },
      ),
    );
  }
}

enum LedgerFilter { all, debit, credit, payments }

const _filterLabels = {
  LedgerFilter.all: 'Statement',
  LedgerFilter.debit: 'Debit entries',
  LedgerFilter.credit: 'Credit entries',
  LedgerFilter.payments: 'Payment history',
};

class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key, this.initialFilter = LedgerFilter.all});

  final LedgerFilter initialFilter;

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  DateTimeRange? _range;
  late LedgerFilter _filter = widget.initialFilter;

  List<LedgerEntry> _filtered(List<LedgerEntry> entries) {
    final range = _range;
    final end = range?.end.add(const Duration(days: 1));
    return entries.where((e) {
      if (range != null && (e.date.isBefore(range.start) || !e.date.isBefore(end!))) return false;
      return switch (_filter) {
        LedgerFilter.all => true,
        LedgerFilter.debit => e.isDebit,
        LedgerFilter.credit => !e.isDebit,
        LedgerFilter.payments => e.isPayment,
      };
    }).toList();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _download(List<LedgerEntry> entries) async {
    final summary = await ref.read(creditSummaryProvider.future);
    final bytes = await buildStatementPdf(entries, summary, ref.read(currentDealerProvider));
    await Printing.sharePdf(bytes: bytes, filename: 'statement-${formatDate(DateTime.now())}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(ledgerProvider);
    final credit = ref.watch(creditSummaryProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My account / ledger'),
        actions: [
          IconButton(tooltip: 'Filter by date', icon: const Icon(Icons.date_range), onPressed: _pickRange),
          IconButton(
            tooltip: 'Download account statement',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            // The PDF always has the full ledger, so its running balance is correct.
            onPressed: ledger.hasValue ? () => _download(ledger.value!) : null,
          ),
        ],
      ),
      body: AsyncBody(
        value: ledger,
        onRetry: () => ref.invalidate(ledgerProvider),
        builder: (entries) {
          final items = _filtered(entries);
          return ListView(
            padding: AppSpacing.page,
            children: [
              if (credit != null)
                AppCard(
                  child: Column(
                    children: [
                      InfoRow('Outstanding balance', money(credit.outstanding), bold: true),
                      InfoRow('Credit limit', money(credit.limit)),
                      InfoRow('Available credit', money(credit.available)),
                      InfoRow(
                        'Overdue',
                        money(credit.overdue),
                        valueColor: credit.overdue > 0 ? AppColors.red600 : null,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in _filterLabels.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: _filter == e.key,
                      onSelected: (_) => setState(() => _filter = e.key),
                    ),
                ],
              ),
              if (_range != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InputChip(
                      label: Text('${formatDate(_range!.start)} - ${formatDate(_range!.end)}'),
                      onDeleted: () => setState(() => _range = null),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              if (items.isEmpty) const Text('No entries for this filter.'),
              for (final entry in items) _LedgerTile(entry: entry),
            ],
          );
        },
      ),
    );
  }
}

/// The Invoices and GST Bills sub-menus.
enum InvoiceSection {
  download('Download GST invoice'),
  previous('Previous bills'),
  orderWise('Order-wise invoice');

  const InvoiceSection(this.title);

  final String title;
}

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key, this.section = InvoiceSection.download});

  final InvoiceSection section;

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.section.title)),
      body: AsyncBody(
        value: ref.watch(ordersProvider),
        builder: (orders) {
          final query = _query.trim().toLowerCase();
          final invoiced = orders
              .where(
                (o) => widget.section == InvoiceSection.previous ? o.isDelivered : o.status != OrderStatus.cancelled,
              )
              .where((o) => '${o.invoiceNumber} ${o.number}'.toLowerCase().contains(query))
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 12, 13, 0),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search by invoice or order ID',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: invoiced.isEmpty
                    ? const EmptyState(icon: Icons.description_outlined, title: 'No bills found')
                    : ListView.separated(
                        padding: AppSpacing.page,
                        itemCount: invoiced.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final order = invoiced[i];
                          return AppCard(
                            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                            onTap: () => context.push(Routes.order(order.id)),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.section == InvoiceSection.orderWise
                                        ? 'Order ${order.number}\n'
                                              '${order.lines.map((l) => '${l.name} × ${l.quantity}').join(', ')}\n'
                                              'Invoice ${order.invoiceNumber} · ${money(order.total)}'
                                        : '${order.invoiceNumber}\nOrder ${order.number}\n'
                                              '${formatDate(order.placedAt)} · ${money(order.total)} · ${order.paymentStatus.label}',
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Download GST invoice',
                                  icon: const Icon(Icons.download_outlined),
                                  onPressed: () => shareInvoice(ref, order),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class RecordPaymentScreen extends ConsumerStatefulWidget {
  const RecordPaymentScreen({super.key, this.mode = PaymentMode.online});

  final PaymentMode mode;

  @override
  ConsumerState<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends ConsumerState<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  late PaymentMode _mode = widget.mode;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _openUpiApp() async {
    if (Validators.positiveAmount(_amount.text) != null) {
      showMessage(context, 'Enter the amount first', isError: true);
      return;
    }
    final uri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': AppConstants.companyUpiId,
        'pn': AppConstants.companyName,
        'am': double.parse(_amount.text.trim()).toStringAsFixed(2),
        'cu': 'INR',
        'tn': 'Dealer payment',
      },
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) showMessage(context, 'No UPI app found on this device', isError: true);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final reference = _mode == PaymentMode.online
        ? 'ONL-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}'
        : _reference.text.trim();
    await ref
        .read(paymentRepositoryProvider)
        .recordPayment(amount: double.parse(_amount.text.trim()), mode: _mode, reference: reference);
    refreshOrdersAndBalance(ref);
    if (!mounted) return;
    showMessage(context, useFakeBackend ? 'Payment recorded. Your receipt is in Payment history.' : 'Payment submitted. Your balance updates once our accounts team has checked it.');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final credit = ref.watch(creditSummaryProvider).value;
    final isOnline = _mode == PaymentMode.online;
    final isUpi = _mode == PaymentMode.upi;
    return Scaffold(
      appBar: AppBar(title: const Text('Make a payment')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.page,
          children: [
            if (credit != null) ...[
              InfoRow('Outstanding', money(credit.outstanding), bold: true),
              if (credit.overdue > 0) InfoRow('Overdue', money(credit.overdue), valueColor: AppColors.red600),
              const SizedBox(height: 12),
            ],
            LabeledField(
              label: 'Pay by',
              child: DropdownButtonFormField<PaymentMode>(
                isExpanded: true,
                style: Theme.of(context).textTheme.bodyLarge,
                initialValue: _mode,
                decoration: InputDecoration(hintText: selectHint('Pay by')),
                items: [for (final m in PaymentMode.values) DropdownMenuItem(value: m, child: Text(m.label))],
                onChanged: (m) => setState(() => _mode = m!),
              ),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'Amount',
              child: TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                validator: Validators.positiveAmount,
                decoration: InputDecoration(hintText: enterHint('Amount'), prefixIcon: fieldPrefix('₹')),
              ),
            ),
            if (credit != null && credit.outstanding > 0)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _amount.text = credit.outstanding.toStringAsFixed(2),
                  child: const Text('Pay full balance'),
                ),
              ),
            const SizedBox(height: 8),
            if (isOnline)
              const NoticeBanner('Demo: no payment gateway is connected yet, so this is marked as paid straight away.')
            else ...[
              if (isUpi)
                AppConstants.companyUpiId.isEmpty
                    ? const NoticeBanner('The company UPI ID has not been added yet, so the UPI app cannot be opened.')
                    : OutlinedButton.icon(
                        onPressed: _openUpiApp,
                        icon: const Icon(Icons.qr_code_2),
                        label: const Text('Open UPI app'),
                      ),
              const SizedBox(height: 12),
              LabeledField(
                label: isUpi ? 'UPI transaction ID (UTR)' : 'Transaction, cheque or receipt number',
                child: TextFormField(
                  controller: _reference,
                  validator: Validators.required,
                  decoration: InputDecoration(
                    hintText: enterHint(isUpi ? 'UPI transaction ID (UTR)' : 'Transaction, cheque or receipt number'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const NoticeBanner(
                'Demo: your balance updates straight away. In production the accounts team confirms this first.',
                color: AppColors.sky600,
              ),
            ],
            const SizedBox(height: 12),
            LoadingButton(label: isOnline ? 'Pay online' : 'Record payment', loading: _saving, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

class ReceiptsScreen extends ConsumerWidget {
  const ReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Payment receipts')),
      body: AsyncBody(
        value: ref.watch(ledgerProvider),
        onRetry: () => ref.invalidate(ledgerProvider),
        builder: (entries) {
          final payments = entries.where((e) => e.isPayment).toList();
          if (payments.isEmpty) return const EmptyState(icon: Icons.receipt_outlined, title: 'No receipts yet');
          return ListView.separated(
            padding: AppSpacing.page,
            itemCount: payments.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final payment = payments[i];
              return AppCard(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(payment.receiptNumber, style: text.labelLarge),
                          Text('${formatDate(payment.date)} · ${payment.description}', style: text.bodySmall),
                          Text(money(payment.amount), style: text.labelLarge?.copyWith(color: AppColors.green600)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Download receipt',
                      icon: const Icon(Icons.download_outlined),
                      onPressed: () => _shareReceipt(ref, payment),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// The Outstanding Balance and Credit Limit sub-menus.
enum BalanceSection {
  outstanding('Outstanding balance'),
  creditLimit('Credit limit');

  const BalanceSection(this.title);

  final String title;
}

class BalanceScreen extends ConsumerWidget {
  const BalanceScreen({super.key, required this.section});

  final BalanceSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(section.title)),
      body: AsyncBody(
        value: ref.watch(creditSummaryProvider),
        onRetry: () => ref.invalidate(creditSummaryProvider),
        builder: (credit) => ListView(
          padding: AppSpacing.page,
          children: [
            CreditCard(credit: credit),
            const SizedBox(height: 10),
            AppCard(
              child: Column(
                children: section == BalanceSection.outstanding
                    ? [
                        InfoRow('Outstanding balance', money(credit.outstanding), bold: true),
                        InfoRow(
                          'Overdue',
                          money(credit.overdue),
                          valueColor: credit.overdue > 0 ? AppColors.red600 : null,
                        ),
                        InfoRow('Not yet due', money(roundMoney(credit.outstanding - credit.overdue))),
                      ]
                    : [
                        InfoRow('Credit limit', money(credit.limit), bold: true),
                        InfoRow('Used', money(credit.outstanding)),
                        InfoRow('Available', money(credit.available)),
                        InfoRow('Credit terms', '${credit.creditDays} days'),
                      ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.push(Routes.recordPayment, extra: PaymentMode.online),
              child: const Text('Pay now'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => context.push(Routes.ledger), child: const Text('View account statement')),
          ],
        ),
      ),
    );
  }
}
