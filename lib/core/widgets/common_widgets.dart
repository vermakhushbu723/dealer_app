import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

/// Lets errors nobody caught still reach the screen.
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showMessage(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? AppColors.red600 : AppColors.neutral900),
    );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmLabel)),
      ],
    ),
  );
  return result ?? false;
}

/// Renders the loading, error and data states of an [AsyncValue].
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.builder, this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => value.when(
    // Keep showing the old data while a provider this depends on reloads.
    skipLoadingOnReload: true,
    data: builder,
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, _) => EmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'Something went wrong',
      message: '$error',
      actionLabel: onRetry == null ? null : 'Try again',
      onAction: onRetry,
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.sky600),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[const SizedBox(height: 6), Text(message!, textAlign: TextAlign.center)],
            if (actionLabel != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
          if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// White, softly shadowed card. Tappable when [onTap] is given.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding = AppSpacing.card});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white, borderRadius: radius, boxShadow: AppTheme.cardShadow),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// The placeholder for a text field, from its label: "Amount" gives "Enter amount".
String enterHint(String label) {
  var text = label.replaceAll(RegExp(r'\s*\(optional\)', caseSensitive: false), '').split(', for example').first.trim();
  if (text.startsWith('Why ')) return 'Enter the reason';
  if (text.startsWith('Tell us ')) return 'Enter ${text.substring(8)}';
  if (text.startsWith('Describe the ')) return 'Enter ${text.substring(13)} details';
  if (text.startsWith('Confirm ')) return 'Enter ${text.substring(8)} again';
  return 'Enter ${_lowerFirst(text)}';
}

/// The placeholder for a dropdown, from its label: "Category" gives "Select category".
String selectHint(String label) => 'Select ${_lowerFirst(label.replaceFirst('Select ', ''))}';

/// Leaves acronyms such as "UPI" and "GSTIN" in capitals.
String _lowerFirst(String text) {
  if (text.length > 1 && text[1] == text[1].toUpperCase() && text[1] != ' ') return text;
  return text.isEmpty ? text : text[0].toLowerCase() + text.substring(1);
}

/// A symbol that stays visible at the start of a field, such as a currency sign.
Widget fieldPrefix(String text) => Padding(
  padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
  child: Text(
    text,
    style: const TextStyle(fontSize: AppTextStyles.base, fontWeight: FontWeight.w600, color: AppColors.neutral700),
  ),
);

/// A field with its label above it.
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.neutral900)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.color = AppColors.sky600});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(fontSize: AppTextStyles.xs, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// One label and value line, used for bills and detail screens.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.bold = false, this.valueColor});

  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? AppTextStyles.base : AppTextStyles.sm,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: bold ? AppColors.neutral900 : AppColors.neutral600,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: style.copyWith(fontWeight: FontWeight.w600, color: valueColor ?? AppColors.neutral900),
            ),
          ),
        ],
      ),
    );
  }
}

class NoticeBanner extends StatelessWidget {
  const NoticeBanner(this.message, {super.key, this.color = AppColors.amber600, this.icon = Icons.info_outline});

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: AppTextStyles.sm)),
          ),
        ],
      ),
    );
  }
}

/// Filled button that shows a spinner and blocks taps while [loading].
class LoadingButton extends StatelessWidget {
  const LoadingButton({super.key, required this.label, required this.onPressed, this.loading = false});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.4))
          : Text(label),
    );
  }
}

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.step = 1,
    this.max,
  });

  final int value;
  final int min;
  final int step;
  final int? max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final canAdd = max == null || value + step <= max!;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.sky200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Decrease quantity',
            icon: const Icon(Icons.remove, size: 18),
            onPressed: value > min ? () => onChanged(value - step < min ? min : value - step) : null,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 28),
            child: Text('$value', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelLarge),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Increase quantity',
            icon: const Icon(Icons.add, size: 18),
            onPressed: canAdd ? () => onChanged(value + step) : null,
          ),
        ],
      ),
    );
  }
}

/// Shows a picked photo. On the web the picker returns a blob URL, not a file path.
class LocalImage extends StatelessWidget {
  const LocalImage(this.path, {super.key, this.height = 160, this.width = double.infinity});

  final String path;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    Widget missing(BuildContext _, Object _, StackTrace? _) => SizedBox(
      height: height,
      width: width,
      child: const Center(child: Text('Photo is not available on this device')),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: kIsWeb || path.startsWith('http')
          ? Image.network(path, height: height, width: width, fit: BoxFit.cover, errorBuilder: missing)
          : Image.file(File(path), height: height, width: width, fit: BoxFit.cover, errorBuilder: missing),
    );
  }
}

class GradientHeader extends StatelessWidget {
  const GradientHeader({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(gradient: AppColors.accentGradient, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: child,
    );
  }
}
