import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../cart/presentation/cart_providers.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/presentation/catalog_providers.dart';

/// An estimate only: about 0.5 kg per guest for a drinks event, more for
/// long or hot events. Replace these figures with the company's own if it has them.
double estimateIceKg({required int guests, required int hours, required bool outdoor, required double kgPerGuest}) {
  final extraHours = hours > 3 ? hours - 3 : 0;
  final base = guests * kgPerGuest * (1 + extraHours * 0.1);
  return outdoor ? base * 1.25 : base;
}

/// Packs for [kg]: 20 kg bags from 40 kg up, otherwise 5 kg bags in the sets
/// of five that the product is sold in.
(String productId, int quantity) packsFor(double kg) {
  if (kg >= 40) return ('cube-20', (kg / 20).ceil());
  final sets = (kg / 25).ceil();
  return ('cube-5', (sets < 1 ? 1 : sets) * 5);
}

const _eventTypes = {'Drinks and cocktails': 0.5, 'Dinner with drinks': 0.35, 'Wedding or large event': 0.6};

class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  double _guests = 50;
  double _hours = 4;
  bool _outdoor = false;
  String _event = _eventTypes.keys.first;

  void _addToCart(Product? product, int quantity) {
    if (product == null) return;
    ref.read(cartProvider.notifier).addAll([(product, quantity)]);
    context.push(Routes.cart);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final kg = estimateIceKg(
      guests: _guests.round(),
      hours: _hours.round(),
      outdoor: _outdoor,
      kgPerGuest: _eventTypes[_event]!,
    );
    final (productId, quantity) = packsFor(kg);
    final product = ref.watch(productProvider(productId)).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Ice calculator')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          LabeledField(
            label: 'Type of event',
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              style: Theme.of(context).textTheme.bodyLarge,
              initialValue: _event,
              decoration: InputDecoration(hintText: selectHint('Type of event')),
              items: [for (final e in _eventTypes.keys) DropdownMenuItem(value: e, child: Text(e))],
              onChanged: (v) => setState(() => _event = v!),
            ),
          ),
          const SizedBox(height: 12),
          Text('Guests: ${_guests.round()}', style: text.labelLarge),
          Slider(value: _guests, min: 10, max: 1000, divisions: 99, onChanged: (v) => setState(() => _guests = v)),
          Text('Duration: ${_hours.round()} hours', style: text.labelLarge),
          Slider(value: _hours, min: 1, max: 12, divisions: 11, onChanged: (v) => setState(() => _hours = v)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Outdoor or hot venue'),
            value: _outdoor,
            onChanged: (v) => setState(() => _outdoor = v),
          ),
          const SizedBox(height: 8),
          GradientHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('You will need about', style: TextStyle(fontSize: AppTextStyles.sm)),
                Text('${kg.ceil()} kg of ice', style: text.displaySmall),
                if (product != null) Text('$quantity × ${product.name} ${product.packSize}', style: text.titleSmall),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('This is an estimate. Order extra for hot days.', style: text.bodySmall),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => _addToCart(product, quantity), child: const Text('Add to cart')),
        ],
      ),
    );
  }
}
