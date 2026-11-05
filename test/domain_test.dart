import 'package:dealer_app/features/calculator/presentation/calculator_screen.dart';
import 'package:dealer_app/features/cart/domain/cart_pricing.dart';
import 'package:dealer_app/features/cart/domain/delivery_slots.dart';
import 'package:dealer_app/features/catalog/domain/product.dart';
import 'package:dealer_app/features/orders/domain/order.dart';
import 'package:dealer_app/features/standing_orders/domain/standing_order.dart';
import 'package:flutter_test/flutter_test.dart';

const _product = Product(
  id: 'p',
  name: 'Cube Ice',
  categoryId: 'cube',
  description: '',
  image: '',
  unit: 'bag',
  packSize: '20 kg',
  slabs: [PriceSlab(1, 100), PriceSlab(10, 90), PriceSlab(25, 80)],
  minOrderQty: 2,
  stepQty: 1,
  gstPercent: 18,
  availableQty: 100,
  uses: [],
);

void main() {
  group('price slabs', () {
    test('picks the slab for the quantity, including its boundaries', () {
      expect(_product.priceFor(1), 100);
      expect(_product.priceFor(9), 100);
      expect(_product.priceFor(10), 90);
      expect(_product.priceFor(24), 90);
      expect(_product.priceFor(25), 80);
    });
  });

  group('dealer pricing', () {
    test('applies the dealer rate to every slab and keeps the list price', () {
      final gold = _product.withDealerRate(0.95);
      expect(gold.slabs.map((s) => s.price), [95, 86, 76]);
      expect(gold.standardPrice, 100);
      expect(identical(_product.withDealerRate(1), _product), isTrue);
    });
  });

  group('cart bill', () {
    test('charges delivery below the free delivery amount', () {
      final bill = CartBill.calculate(const [CartLine(_product, 10)]); // 900
      expect(bill.subtotal, 900);
      expect(bill.gst, 162);
      expect(bill.deliveryFee, 250);
      expect(bill.total, 1312);
      expect(bill.meetsMinimumOrder, isFalse);
    });

    test('delivers free above the threshold and charges GST after discount', () {
      final bill = CartBill.calculate(const [CartLine(_product, 100)], discount: 1000); // 8000
      expect(bill.deliveryFee, 0);
      expect(bill.gst, 1260); // 18% of 7000
      expect(bill.total, 8260);
    });

    test('a discount cannot exceed the subtotal', () {
      final bill = CartBill.calculate(const [CartLine(_product, 2)], discount: 5000);
      expect(bill.discount, 200);
      expect(bill.gst, 0);
    });

    test('an empty cart costs nothing', () {
      expect(CartBill.calculate(const []).total, 0);
    });
  });

  group('delivery slots', () {
    test('today only offers slots far enough ahead', () {
      final now = DateTime(2026, 11, 2, 10, 30);
      expect(availableSlots(now, now), ['3 PM - 6 PM', '6 PM - 9 PM']);
    });

    test('other days offer every slot', () {
      final now = DateTime(2026, 11, 2, 23);
      expect(availableSlots(DateTime(2026, 11, 3), now), hasLength(5));
    });

    test('the first delivery date moves to tomorrow after the last slot closes', () {
      expect(firstDeliveryDate(DateTime(2026, 11, 2, 22)), DateTime(2026, 11, 3));
      expect(firstDeliveryDate(DateTime(2026, 11, 2, 8)), DateTime(2026, 11, 2));
    });
  });

  group('standing order schedule', () {
    StandingOrder schedule({Set<DateTime> skipped = const {}, bool active = true}) => StandingOrder(
      id: 's',
      name: 'Weekly',
      items: const {'p': 2},
      weekdays: const {DateTime.monday},
      slot: '6 AM - 9 AM',
      addressId: 'a',
      paymentMethod: PaymentMethod.credit,
      lastRun: DateTime(2026, 11, 2), // a Monday
      isActive: active,
      skippedDates: skipped,
    );

    test('does not run again on the day it last ran', () {
      expect(schedule().isDueOn(DateTime(2026, 11, 2, 9)), isFalse);
      expect(schedule().nextRun(DateTime(2026, 11, 2)), DateTime(2026, 11, 9));
    });

    test('skipping moves the next run on a week', () {
      final skipped = schedule(skipped: {DateTime(2026, 11, 9)});
      expect(skipped.nextRun(DateTime(2026, 11, 2)), DateTime(2026, 11, 16));
    });

    test('a paused schedule has no next run', () {
      expect(schedule(active: false).nextRun(DateTime(2026, 11, 2)), isNull);
    });
  });

  group('ice calculator', () {
    test('adds time for long events and extra for hot venues', () {
      expect(estimateIceKg(guests: 100, hours: 3, outdoor: false, kgPerGuest: 0.5), 50);
      expect(estimateIceKg(guests: 100, hours: 5, outdoor: false, kgPerGuest: 0.5), 60);
      expect(estimateIceKg(guests: 100, hours: 3, outdoor: true, kgPerGuest: 0.5), 62.5);
    });

    test('suggests packs that can actually be ordered', () {
      expect(packsFor(10), ('cube-5', 5));
      expect(packsFor(30), ('cube-5', 10));
      expect(packsFor(50), ('cube-20', 3));
    });
  });
}
