import 'dart:async';

import 'package:dealer_app/app/app.dart';
import 'package:dealer_app/app/router.dart';
import 'package:dealer_app/app/routes.dart';
import 'package:dealer_app/core/storage/local_store.dart';
import 'package:dealer_app/features/auth/presentation/auth_providers.dart';
import 'package:dealer_app/features/complaints/domain/complaint.dart';
import 'package:dealer_app/features/complaints/presentation/complaint_screens.dart';
import 'package:dealer_app/features/notifications/domain/notification.dart';
import 'package:dealer_app/features/offers/domain/offer.dart';
import 'package:dealer_app/features/orders/domain/order.dart';
import 'package:dealer_app/features/payments/presentation/payment_screens.dart';
import 'package:dealer_app/features/profile/presentation/account_screens.dart';
import 'package:dealer_app/features/tracking/presentation/tracking_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opens every screen on a small phone. Crashes and layout overflows fail the test.
void main() {
  testWidgets('every screen opens on a small phone', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3; // 360 x 640
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [localStoreProvider.overrideWithValue(LocalStore(prefs))]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const DealerApp()));

    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    await settle();
    // Not awaited: its delay only passes while the test pumps frames.
    unawaited(container.read(authControllerProvider.notifier).verifyOtp('9876543210', '123456'));
    await settle();

    final router = container.read(routerProvider);
    final screens = [
      Routes.home,
      Routes.catalog,
      Routes.orders,
      Routes.payments,
      Routes.menu,
      Routes.priceList,
      '/products/cube-5',
      '/products/dry-10',
      Routes.cart,
      Routes.checkout,
      Routes.trackDelivery,
      '/orders/sample-6',
      Routes.notifications,
      Routes.notificationSettings,
      Routes.addresses,
      Routes.offers,
      Routes.iceBoxes,
      Routes.calculator,
      Routes.reports,
      Routes.standingOrders,
      Routes.standingOrderForm,
      Routes.deliverySchedule,
      Routes.ledger,
      Routes.invoices,
      Routes.paymentHistory,
      Routes.recordPayment,
      Routes.complaints,
      '/complaints/sample-c4',
      Routes.newComplaint,
      Routes.support,
      Routes.tickets,
      Routes.newTicket,
      Routes.businessProfile,
      Routes.documents,
      Routes.settings,
      Routes.manageAccount,
      Routes.changePassword,
      for (final status in OrderStatus.values) Routes.orderList(status.name),
      for (final section in TrackSection.values) Routes.trackSection(section.name),
      for (final id in ['tube', 'cube', 'block', 'slab', 'crushed', 'dry']) Routes.category(id),
      Routes.receipts,
      for (final filter in LedgerFilter.values) Routes.ledgerOf(filter.name),
      for (final section in BalanceSection.values) Routes.balance(section.name),
      for (final type in ComplaintType.values) Routes.reportComplaint(type.name),
      for (final section in ComplaintSection.values) Routes.complaintList(section.name),
      for (final record in ComplaintRecord.values) Routes.complaintInfo(record.name),
      Routes.complaintInfo('order'),
      Routes.upcomingDeliveries,
      Routes.requestDelivery,
      for (final kind in OfferKind.values) Routes.offersOf(kind.name),
      for (final section in InvoiceSection.values) Routes.invoicesOf(section.name),
      for (final field in ProfileField.values) Routes.profileField(field.name),
      for (final type in NotificationType.values) Routes.notificationsOf(type.name),
    ];
    final failures = <String>[];
    for (final screen in screens) {
      router.go(screen);
      await settle();
      final error = tester.takeException();
      if (error != null) failures.add('$screen: $error');
      if (find.byType(ErrorWidget).evaluate().isNotEmpty) failures.add('$screen: showed an error');
    }
    expect(failures, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('every field on every form has a placeholder', (tester) async {
    tester.view.physicalSize = const Size(1080, 7500);
    tester.view.devicePixelRatio = 3; // tall, so long forms build all their fields
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [localStoreProvider.overrideWithValue(LocalStore(prefs))]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const DealerApp()));
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    await settle();
    unawaited(container.read(authControllerProvider.notifier).verifyOtp('9876543210', '123456'));
    await settle();

    final router = container.read(routerProvider);
    const forms = [
      Routes.recordPayment,
      Routes.newTicket,
      Routes.newComplaint,
      Routes.standingOrderForm,
      Routes.businessProfile,
      Routes.changePassword,
    ];
    final missing = <String>[];
    for (final screen in forms) {
      router.go(screen);
      await settle();
      var fields = 0;
      for (final decorator in tester.widgetList<InputDecorator>(find.byType(InputDecorator))) {
        fields++;
        // A dropdown that already shows a value doesn't need one.
        if ((decorator.decoration.hintText ?? '').isEmpty && decorator.isEmpty) missing.add(screen);
      }
      expect(fields, greaterThan(0), reason: '$screen has no fields');
    }
    expect(missing, isEmpty);
  });

  testWidgets('the menu shows all sixteen sections and opens a sub-menu', (tester) async {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [localStoreProvider.overrideWithValue(LocalStore(prefs))]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const DealerApp()));
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    await settle();
    unawaited(container.read(authControllerProvider.notifier).verifyOtp('9876543210', '123456'));
    await settle();
    container.read(routerProvider).go(Routes.menu);
    await settle();

    expect(find.text('1. Dashboard'), findsOneWidget);
    expect(find.text('16. Settings'), findsOneWidget);
    expect(find.text('Cancelled orders'), findsNothing);

    await tester.tap(find.text('4. My orders'));
    await settle();
    await tester.tap(find.text('Cancelled orders'));
    await settle();
    expect(find.text('No cancelled orders'), findsOneWidget);
  });
}
