import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/addresses/presentation/address_screens.dart';
import '../features/auth/domain/dealer.dart';
import '../features/auth/presentation/auth_providers.dart';
import '../features/auth/presentation/kyc_screens.dart';
import '../features/auth/presentation/login_screens.dart';
import '../features/calculator/presentation/calculator_screen.dart';
import '../features/cart/presentation/cart_screen.dart';
import '../features/cart/presentation/checkout_screen.dart';
import '../features/catalog/presentation/catalog_screens.dart';
import '../features/complaints/domain/complaint.dart';
import '../features/complaints/presentation/complaint_screens.dart';
import '../features/delivery_schedule/presentation/delivery_schedule_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/ice_boxes/presentation/ice_boxes_screen.dart';
import '../features/notifications/domain/notification.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/offers/domain/offer.dart';
import '../features/offers/presentation/offers_screen.dart';
import '../features/orders/domain/order.dart';
import '../features/orders/presentation/order_screens.dart';
import '../features/payments/domain/ledger.dart';
import '../features/payments/presentation/payment_screens.dart';
import '../features/profile/presentation/account_screens.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/settings/presentation/settings_screens.dart';
import '../features/standing_orders/domain/standing_order.dart';
import '../features/standing_orders/presentation/standing_order_screens.dart';
import '../features/support/presentation/support_screens.dart';
import '../features/tracking/presentation/tracking_screens.dart';
import 'app_shell.dart';
import 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Where the dealer must be for their account state, or null if they may stay.
String? _redirect(AsyncValue<Dealer?> auth, String location) {
  if (auth.isLoading && !auth.hasValue) return location == Routes.splash ? null : Routes.splash;
  final dealer = auth.value;
  if (dealer == null) {
    return location == Routes.login || location == Routes.otp ? null : Routes.login;
  }
  final required = switch (dealer.kycStatus) {
    KycStatus.notSubmitted || KycStatus.rejected => Routes.kyc,
    KycStatus.pending => Routes.kycPending,
    KycStatus.approved => null,
  };
  if (required != null) return location == required ? null : required;
  const onboarding = [Routes.splash, Routes.login, Routes.otp, Routes.kyc, Routes.kycPending];
  return onboarding.contains(location) ? Routes.home : null;
}

GoRoute _page(String path, Widget Function(GoRouterState state) builder) =>
    GoRoute(path: path, parentNavigatorKey: _rootKey, builder: (_, state) => builder(state));

StatefulShellBranch _tab(String path, Widget screen, {List<RouteBase> routes = const []}) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (_, _) => screen, routes: routes)],
);

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);
  // The page a link or a browser reload asked for, while the app still checks the session.
  String? wanted;

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (_, state) {
      var target = _redirect(ref.read(authControllerProvider), state.matchedLocation);
      if (target == Routes.splash) wanted = state.uri.toString();
      // Once signed in, open that page instead of the dashboard.
      if (target == Routes.home && wanted != null) (target, wanted) = (wanted, null);
      // The OTP screen needs its phone number, which a page reload on the web loses.
      if (target == null && state.matchedLocation == Routes.otp && state.extra == null) return Routes.login;
      return target;
    },
    routes: [
      _page(Routes.splash, (_) => const SplashScreen()),
      _page(Routes.login, (_) => const LoginScreen()),
      _page(Routes.otp, (state) => OtpScreen(phone: state.extra as String)),
      _page(Routes.kyc, (_) => const KycScreen()),
      _page(Routes.kycPending, (_) => const KycPendingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          _tab(Routes.home, const HomeScreen()),
          _tab(
            Routes.catalog,
            const CatalogScreen(),
            routes: [
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootKey,
                builder: (_, state) => ProductDetailScreen(productId: state.pathParameters['id']!),
              ),
            ],
          ),
          _tab(
            Routes.orders,
            const OrdersScreen(),
            routes: [
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootKey,
                builder: (_, state) => OrderDetailScreen(orderId: state.pathParameters['id']!),
              ),
            ],
          ),
          _tab(Routes.payments, const PaymentsScreen()),
          _tab(Routes.menu, const MenuScreen()),
        ],
      ),
      _page(Routes.priceList, (_) => const PriceListScreen()),
      _page(Routes.cart, (_) => const CartScreen()),
      _page(Routes.checkout, (_) => const CheckoutScreen()),
      _page('/order-placed/:id', (state) => OrderPlacedScreen(orderId: state.pathParameters['id']!)),
      _page(Routes.trackDelivery, (_) => const TrackDeliveryScreen()),
      _page('${Routes.trackDelivery}/:id', (state) => TrackOrderScreen(orderId: state.pathParameters['id']!)),
      _page(Routes.notifications, (_) => const NotificationsScreen()),
      _page(Routes.notificationSettings, (_) => const NotificationSettingsScreen()),
      _page(Routes.addresses, (_) => const AddressesScreen()),
      _page(Routes.offers, (_) => const OffersScreen()),
      _page(Routes.iceBoxes, (_) => const IceBoxesScreen()),
      _page(Routes.calculator, (_) => const CalculatorScreen()),
      _page(Routes.reports, (_) => const ReportsScreen()),
      _page(Routes.standingOrders, (_) => const StandingOrdersScreen()),
      _page(Routes.standingOrderForm, (state) => StandingOrderFormScreen(order: state.extra as StandingOrder?)),
      _page(Routes.deliverySchedule, (_) => const DeliveryScheduleScreen()),
      _page(Routes.ledger, (_) => const LedgerScreen()),
      _page(Routes.invoices, (_) => const InvoicesScreen()),
      _page(Routes.paymentHistory, (_) => const PaymentHistoryScreen()),
      _page(
        Routes.recordPayment,
        (state) => RecordPaymentScreen(mode: state.extra as PaymentMode? ?? PaymentMode.online),
      ),
      _page(Routes.complaints, (_) => const ComplaintsScreen()),
      _page('${Routes.complaints}/:id', (state) => ComplaintDetailScreen(complaintId: state.pathParameters['id']!)),
      _page(
        Routes.newComplaint,
        (state) => NewComplaintScreen(
          orderId: state.extra as String?,
          type: ComplaintType.values.asNameMap()[state.uri.queryParameters['type']],
        ),
      ),
      _page(Routes.support, (_) => const SupportScreen()),
      _page(Routes.tickets, (_) => const TicketsScreen()),
      _page('${Routes.tickets}/:id', (state) => TicketDetailScreen(ticketId: state.pathParameters['id']!)),
      _page(Routes.newTicket, (state) => NewTicketScreen(orderNumber: state.extra as String?)),
      _page(Routes.businessProfile, (_) => const BusinessProfileScreen()),
      _page(Routes.documents, (_) => const DocumentsScreen()),
      _page(
        '/order-list/:status',
        (state) => OrderStatusListScreen(status: OrderStatus.values.byName(state.pathParameters['status']!)),
      ),
      _page(
        '/track-section/:section',
        (state) => TrackSectionScreen(section: TrackSection.values.byName(state.pathParameters['section']!)),
      ),
      _page('/category/:id', (state) => CategoryProductsScreen(categoryId: state.pathParameters['id']!)),
      _page(Routes.receipts, (_) => const ReceiptsScreen()),
      _page(
        '${Routes.ledger}/:filter',
        (state) => LedgerScreen(initialFilter: LedgerFilter.values.byName(state.pathParameters['filter']!)),
      ),
      _page(
        '/balance/:section',
        (state) => BalanceScreen(section: BalanceSection.values.byName(state.pathParameters['section']!)),
      ),
      _page(
        '/complaint-list/:section',
        (state) => ComplaintListScreen(section: ComplaintSection.values.byName(state.pathParameters['section']!)),
      ),
      _page(Routes.complaintInfo('order'), (_) => const SelectComplaintOrderScreen()),
      _page(
        '/complaint-info/:section',
        (state) => ComplaintRecordScreen(record: ComplaintRecord.values.byName(state.pathParameters['section']!)),
      ),
      _page(Routes.upcomingDeliveries, (_) => const UpcomingDeliveriesScreen()),
      _page(Routes.requestDelivery, (_) => const RequestDeliveryScreen()),
      _page(
        '${Routes.offers}/:kind',
        (state) => OffersScreen(initial: OfferKind.values.byName(state.pathParameters['kind']!)),
      ),
      _page(
        '${Routes.invoices}/:section',
        (state) => InvoicesScreen(section: InvoiceSection.values.byName(state.pathParameters['section']!)),
      ),
      _page(
        '/profile-field/:field',
        (state) => ProfileFieldScreen(field: ProfileField.values.byName(state.pathParameters['field']!)),
      ),
      _page(
        '${Routes.notifications}/:type',
        (state) => NotificationsScreen(initialFilter: NotificationType.values.byName(state.pathParameters['type']!)),
      ),
      _page(Routes.settings, (_) => const SettingsScreen()),
      _page(Routes.manageAccount, (_) => const ManageAccountScreen()),
      _page(Routes.changePassword, (_) => const ChangePasswordScreen()),
    ],
  );
});
