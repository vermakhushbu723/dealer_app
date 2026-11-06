@Tags(['contract'])
library;

import 'dart:io';

import 'package:dealer_app/core/location/location_service.dart';
import 'package:dealer_app/core/network/api_client.dart';
import 'package:dealer_app/core/storage/local_store.dart';
import 'package:dealer_app/features/addresses/data/api_address_repository.dart';
import 'package:dealer_app/features/addresses/domain/address.dart';
import 'package:dealer_app/features/auth/data/api_auth_repository.dart';
import 'package:dealer_app/features/auth/domain/dealer.dart';
import 'package:dealer_app/features/cart/domain/cart_pricing.dart';
import 'package:dealer_app/features/catalog/data/api_catalog_repository.dart';
import 'package:dealer_app/features/complaints/data/api_complaint_repository.dart';
import 'package:dealer_app/features/complaints/domain/complaint.dart';
import 'package:dealer_app/features/delivery_schedule/data/api_delivery_request_repository.dart';
import 'package:dealer_app/features/delivery_schedule/domain/delivery_request.dart';
import 'package:dealer_app/features/ice_boxes/data/api_ice_box_repository.dart';
import 'package:dealer_app/features/notifications/data/api_notification_repository.dart';
import 'package:dealer_app/features/notifications/domain/notification.dart';
import 'package:dealer_app/features/offers/data/api_offer_repository.dart';
import 'package:dealer_app/features/orders/data/api_order_repository.dart';
import 'package:dealer_app/features/orders/domain/order.dart';
import 'package:dealer_app/features/payments/data/api_payment_repository.dart';
import 'package:dealer_app/features/payments/domain/ledger.dart';
import 'package:dealer_app/features/standing_orders/data/api_standing_order_repository.dart';
import 'package:dealer_app/features/standing_orders/domain/standing_order.dart';
import 'package:dealer_app/features/support/data/api_support_repository.dart';
import 'package:dealer_app/features/tracking/data/api_tracking_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runs the app's real data code against a real server, so every reply is read by the app's
/// own fromJson. Needs: node scripts/serve-test.js, then
/// flutter test test/api_contract_test.dart --dart-define=API_URL=http://127.0.0.1:4100/api
void main() {
  late ApiClient api;
  late ApiClient adminApi;

  Future<String> tempPhoto() async {
    final file = File('${Directory.systemTemp.path}/iceclub_contract_dealer.png');
    await file.writeAsBytes(const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0]);
    return file.path;
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    api = ApiClient(LocalStore(prefs, scope: 'dealer'));
    adminApi = ApiClient(LocalStore(prefs, scope: 'admin'));
    final login = await adminApi.post('/auth/admin/login', {'email': 'admin@iceclub.online', 'password': 'Admin@1234'}) as Map<String, dynamic>;
    await adminApi.saveToken(login['token'] as String);
  });

  test('the demo account, end to end', () async {
    final auth = ApiAuthRepository(api);
    expect(await auth.currentDealer(), isNull);
    await expectLater(auth.signInWithPassword('9876543210', 'wrong'), throwsA(isA<ApiException>()));
    final dealer = await auth.signInWithPassword('9876543210', 'Demo@1234');
    expect(dealer.isApproved, isTrue);
    expect((await auth.currentDealer())!.id, dealer.id);
    expect(await auth.hasPassword(), isTrue);
    await auth.updateProfile(dealer.copyWith(ownerName: 'Ramesh Patil'));
    expect((await auth.refreshKycStatus()).ownerName, 'Ramesh Patil');

    final catalog = ApiCatalogRepository(api);
    expect((await catalog.categories()).length, 7);
    final products = await catalog.products();
    expect(products.length, 8);
    expect(products.firstWhere((p) => p.id == 'tube-20').basePrice, 262);
    await catalog.setFavourite('block-50', true);
    expect(await catalog.favourites(), contains('block-50'));
    await catalog.setStockAlert('dry-10', true);
    expect(await catalog.stockAlerts(), contains('dry-10'));

    final addresses = ApiAddressRepository(api);
    final list = await addresses.addresses();
    expect(list, isNotEmpty);
    await addresses.save(const Address(id: 'contract', label: 'Contract', contactName: 'A', phone: '9876543210', line: '1 Road', city: 'Mumbai', pincode: '400001', instructions: 'Gate'));
    expect((await addresses.addresses()).any((a) => a.id == 'contract'), isTrue);
    await addresses.setDefault('contract');
    await addresses.setDefault(list.first.id);
    await addresses.delete('contract');

    final orders = ApiOrderRepository(api);
    final history = await orders.orders();
    expect(history, isNotEmpty);

    // The app's own bill has to match what the server charges.
    final block = products.firstWhere((p) => p.id == 'block-50');
    final bill = CartBill.calculate([CartLine(block, 5)]);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final placed = await orders.place(PlaceOrderRequest(bill: bill, address: list.first, deliveryDate: tomorrow, slot: '9 AM - 12 PM', paymentMethod: PaymentMethod.cashOnDelivery, notes: 'Contract'));
    expect(placed.total, bill.total);
    expect(placed.status, OrderStatus.placed);
    expect(placed.deliveryOtp, isEmpty, reason: 'dealers give no OTP');

    final tracking = await ApiTrackingRepository(api).track(placed);
    expect(tracking.rider, isNull);

    final another = await orders.place(PlaceOrderRequest(bill: CartBill.calculate([CartLine(block, 8)]), address: list.first, deliveryDate: tomorrow, slot: '9 AM - 12 PM', paymentMethod: PaymentMethod.cashOnDelivery));
    await orders.cancel(another.id, 'Contract test');
    expect((await orders.orders()).firstWhere((o) => o.id == another.id).status, OrderStatus.cancelled);

    // Staff move it to the rider, then the rider's own code path is covered by that app's test.
    for (var i = 0; i < 3; i++) {
      await adminApi.post('/admin/actions/advanceOrder', {'args': [placed.id]});
    }
    await adminApi.post('/admin/actions/assignRider', {'args': [placed.id, 'R1']});
    await adminApi.post('/admin/actions/advanceOrder', {'args': [placed.id]});
    final moving = (await orders.orders()).firstWhere((o) => o.id == placed.id);
    expect(moving.status, OrderStatus.outForDelivery);
    expect(moving.driver, isNotNull);
    await adminApi.post('/admin/actions/confirmDelivery', {'args': [placed.id, {'mode': 'cash'}]});
    final done = (await orders.orders()).firstWhere((o) => o.id == placed.id);
    expect(done.status, OrderStatus.delivered);
    expect(done.paymentStatus, PaymentStatus.paid);
    await orders.rate(done.id, 5, 'Good');
    expect((await orders.orders()).firstWhere((o) => o.id == placed.id).rating, 5);

    final payments = ApiPaymentRepository(api);
    final summary = await payments.creditSummary();
    expect(summary.limit, greaterThan(0));
    expect(await payments.ledger(), isNotEmpty);
    await payments.remindIfOverdue();
    await payments.recordPayment(amount: 500, mode: PaymentMode.upi, reference: 'CONTRACT-UPI');
    expect((await payments.creditSummary()).outstanding, summary.outstanding);

    final complaints = ApiComplaintRepository(api);
    final complaint = await complaints.submit(orderId: done.id, orderNumber: done.number, type: ComplaintType.meltedBags, affectedQuantity: 1, description: 'Contract', photos: [PickedPhoto(await tempPhoto(), DateTime.now())], location: const GeoPoint(19.1, 72.8));
    expect(complaint.status, ComplaintStatus.underReview);
    expect(complaint.photos.single.path, startsWith('http'));
    expect((await complaints.complaints()).any((c) => c.id == complaint.id), isTrue);

    final standing = ApiStandingOrderRepository(api);
    await standing.save(StandingOrder(id: 'contract', name: 'Contract', items: const {'block-50': 5}, weekdays: const {1, 2, 3, 4, 5, 6, 7}, slot: '9 AM - 12 PM', addressId: list.first.id, paymentMethod: PaymentMethod.cashOnDelivery, lastRun: DateTime.now()));
    final saved = await standing.standingOrders();
    expect(saved.single.items['block-50'], 5);
    expect(await standing.placeDueOrders(), 0);
    await standing.delete(saved.single.id);

    final boxes = ApiIceBoxRepository(api);
    expect((await boxes.account()).boxesHeld, 4);
    await boxes.requestPickup(1, tomorrow);
    final pending = (await boxes.account()).pickups.single;
    await boxes.cancelPickup(pending.id);

    final offers = await ApiOfferRepository(api).offers();
    expect(offers, isNotEmpty);
    expect(offers.every((o) => o.code.isEmpty), isTrue, reason: 'no coupon codes for dealers');

    final requests = ApiDeliveryRequestRepository(api);
    await requests.add(DeliveryRequest(id: 'x', date: tomorrow, slot: '9 AM - 12 PM', addressLabel: 'Shop', details: 'Contract', requestedAt: DateTime.now()));
    final asked = await requests.requests();
    await requests.cancel(asked.single.id);

    final notifications = ApiNotificationRepository(api);
    expect(await notifications.notifications(), isNotEmpty);
    await notifications.setMuted(NotificationType.payment, true);
    expect(await notifications.mutedTypes(), contains(NotificationType.payment));
    await notifications.setMuted(NotificationType.payment, false);
    await notifications.markRead((await notifications.notifications()).first.id);
    await notifications.markAllRead();
    await notifications.clearAll();

    final support = ApiSupportRepository(api);
    final ticket = await support.create(subject: 'Contract', category: 'Delivery', message: 'Hello', orderNumber: done.number);
    expect(ticket.messages.first.fromDealer, isTrue);
    await support.reply(ticket.id, 'More');
    await support.resolve(ticket.id);
    expect((await support.tickets()).any((t) => t.id == ticket.id), isTrue);

    await auth.logout();
    expect(await auth.currentDealer(), isNull);
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('a new dealer registers and gets approved', () async {
    final auth = ApiAuthRepository(api);
    await auth.sendOtp('9812400001');
    final fresh = await auth.verifyOtp('9812400001', '123456');
    expect(fresh.kycStatus, KycStatus.notSubmitted);
    expect(await auth.hasPassword(), isFalse);
    await auth.changePassword(current: '', next: 'Dealer@123');
    expect(await auth.hasPassword(), isTrue);

    final submitted = await auth.submitKyc(fresh.copyWith(
      ownerName: 'New Dealer',
      businessName: 'Contract Ice',
      businessType: 'Retailer',
      gstin: '27ABCDE1234F1Z7',
      pan: 'ABCDE1234F',
      fssai: '12345678901234',
      addressLine: '5 Dock Road',
      city: 'Mumbai',
      pincode: '400001',
      documents: {'GST certificate': await tempPhoto()},
    ));
    expect(submitted.kycStatus, KycStatus.pending);
    expect(submitted.documents['GST certificate'], isNotEmpty);
    await adminApi.post('/admin/actions/decideKyc', {'args': [submitted.id, true, '', 10000]});
    final approved = await auth.refreshKycStatus();
    expect(approved.isApproved, isTrue);
    expect(approved.creditLimit, 10000);
    await auth.deleteAccount();
    expect(await auth.currentDealer(), isNull);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
