import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/order_providers.dart';

class MonthlyPurchase {
  const MonthlyPurchase(this.month, this.amount, this.orders);

  final DateTime month;
  final double amount;
  final int orders;
}

/// Totals for each of the last [months] months, oldest first, gaps included.
List<MonthlyPurchase> monthlyPurchases(List<Order> delivered, DateTime now, {int months = 6}) {
  return [
    for (var i = months - 1; i >= 0; i--)
      () {
        final month = DateTime(now.year, now.month - i);
        final inMonth = delivered.where((o) => o.placedAt.year == month.year && o.placedAt.month == month.month);
        return MonthlyPurchase(month, inMonth.fold(0.0, (sum, o) => sum + o.total), inMonth.length);
      }(),
  ];
}

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Purchase reports')),
      body: AsyncBody(
        value: ref.watch(ordersProvider),
        builder: (orders) {
          final delivered = orders.where((o) => o.isDelivered).toList();
          if (delivered.isEmpty) {
            return const EmptyState(
              icon: Icons.bar_chart,
              title: 'No purchases yet',
              message: 'Reports appear after your first delivery.',
            );
          }
          return _ReportBody(delivered: delivered);
        },
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.delivered});

  final List<Order> delivered;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final months = monthlyPurchases(delivered, DateTime.now());
    final total = months.fold(0.0, (sum, m) => sum + m.amount);
    final count = months.fold(0, (sum, m) => sum + m.orders);

    final byProduct = <String, double>{};
    for (final order in delivered) {
      for (final line in order.lines) {
        final key = '${line.name} (${line.packSize})';
        byProduct[key] = (byProduct[key] ?? 0) + line.amount;
      }
    }
    final topProducts = byProduct.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: AppSpacing.page,
      children: [
        Row(
          children: [
            Expanded(child: _StatTile('Last 6 months', money(total.roundToDouble()))),
            const SizedBox(width: 8),
            Expanded(child: _StatTile('Orders', '$count')),
            const SizedBox(width: 8),
            Expanded(child: _StatTile('Average', money(count == 0 ? 0 : (total / count).roundToDouble()))),
          ],
        ),
        const SectionTitle('Purchases by month'),
        AppCard(
          child: SizedBox(height: 200, child: _MonthlyChart(months: months)),
        ),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            children: [
              for (final m in months.reversed)
                InfoRow(
                  '${formatMonth(m.month)} ${m.month.year} · ${m.orders} ${m.orders == 1 ? 'order' : 'orders'}',
                  money(m.amount),
                ),
            ],
          ),
        ),
        const SectionTitle('Top products'),
        AppCard(child: Column(children: [for (final e in topProducts.take(5)) InfoRow(e.key, money(e.value))])),
        const SizedBox(height: 8),
        Text('Top product amounts are before GST and discounts.', style: text.bodySmall),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.labelSmall),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: text.titleSmall),
          ),
        ],
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.months});

  final List<MonthlyPurchase> months;

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(fontSize: AppTextStyles.xs, color: AppColors.neutral600);
    return BarChart(
      BarChartData(
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.sky100, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => value == meta.max
                  ? const SizedBox.shrink()
                  : Text('₹${(value / 1000).toStringAsFixed(0)}k', style: labelStyle),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(formatMonth(months[value.toInt()].month), style: labelStyle),
              ),
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.neutral900,
            getTooltipItem: (_, _, rod, _) => BarTooltipItem(
              money(rod.toY),
              const TextStyle(color: Colors.white, fontSize: AppTextStyles.xs, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        barGroups: [
          for (final (i, m) in months.indexed)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: m.amount,
                  width: 18,
                  color: AppColors.sky600,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
