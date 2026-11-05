import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../addresses/presentation/address_providers.dart';
import '../../complaints/domain/complaint.dart';
import '../../complaints/presentation/complaint_screens.dart';
import '../../notifications/domain/notification.dart';
import '../../offers/domain/offer.dart';
import '../../payments/domain/ledger.dart';
import '../../payments/presentation/payment_screens.dart';
import '../../tracking/presentation/tracking_screens.dart';
import '../../auth/domain/dealer.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../auth/presentation/kyc_screens.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/order_providers.dart';
import '../../orders/presentation/order_screens.dart';
import '../../settings/presentation/settings_screens.dart';

class _MenuItem {
  const _MenuItem(this.label, {this.route, this.action});

  final String label;
  final String? route;

  /// Runs instead of opening a screen, such as placing a call.
  final void Function(BuildContext, WidgetRef)? action;
}

class _MenuSection {
  const _MenuSection(this.icon, this.title, {this.items = const [], this.route, this.action});

  final IconData icon;
  final String title;
  final List<_MenuItem> items;

  /// Opens directly when the section has no sub-menu.
  final String? route;
  final void Function(BuildContext, WidgetRef)? action;
}

Future<void> _repeatLastOrder(BuildContext context, WidgetRef ref) async {
  final orders = await ref.read(ordersProvider.future);
  if (!context.mounted) return;
  final last = orders.where((o) => o.status != OrderStatus.cancelled).firstOrNull;
  if (last == null) {
    showMessage(context, 'You have no previous orders yet');
    return;
  }
  await reorder(context, ref, last);
}

/// The dealer app's full menu, in the order of the requirements document.
final _sections = <_MenuSection>[
  const _MenuSection(Icons.dashboard_outlined, 'Dashboard', route: Routes.home),
  const _MenuSection(Icons.add_shopping_cart, 'Place new order', route: Routes.catalog),
  const _MenuSection(Icons.replay, 'Repeat previous order', action: _repeatLastOrder),
  _MenuSection(
    Icons.receipt_long_outlined,
    'My orders',
    items: [
      const _MenuItem('All orders', route: Routes.orders),
      _MenuItem('New orders', route: Routes.orderList(OrderStatus.placed.name)),
      _MenuItem('Accepted orders', route: Routes.orderList(OrderStatus.accepted.name)),
      _MenuItem('Processing orders', route: Routes.orderList(OrderStatus.processing.name)),
      _MenuItem('Ready for dispatch', route: Routes.orderList(OrderStatus.readyForDispatch.name)),
      _MenuItem('Out for delivery', route: Routes.orderList(OrderStatus.outForDelivery.name)),
      _MenuItem('Delivered orders', route: Routes.orderList(OrderStatus.delivered.name)),
      _MenuItem('Cancelled orders', route: Routes.orderList(OrderStatus.cancelled.name)),
    ],
  ),
  _MenuSection(
    Icons.location_on_outlined,
    'Track my delivery',
    items: [
      const _MenuItem('Live rider location', route: Routes.trackDelivery),
      _MenuItem('Delivery status', route: Routes.trackSection(TrackSection.status.name)),
      _MenuItem('Estimated delivery time', route: Routes.trackSection(TrackSection.eta.name)),
    ],
  ),
  _MenuSection(
    Icons.price_change_outlined,
    'Products and price list',
    items: [
      _MenuItem('Tube ice', route: Routes.category('tube')),
      _MenuItem('Cube ice', route: Routes.category('cube')),
      _MenuItem('Block ice', route: Routes.category('block')),
      _MenuItem('Slab ice', route: Routes.category('slab')),
      _MenuItem('Crushed ice', route: Routes.category('crushed')),
      _MenuItem('Dry ice', route: Routes.category('dry')),
      const _MenuItem('Dealer-wise pricing', route: Routes.priceList),
    ],
  ),
  _MenuSection(
    Icons.payments_outlined,
    'Payments',
    items: [
      _MenuItem('Pay online', action: (context, _) => context.push(Routes.recordPayment, extra: PaymentMode.online)),
      _MenuItem('UPI payment', action: (context, _) => context.push(Routes.recordPayment, extra: PaymentMode.upi)),
      const _MenuItem('Payment history', route: Routes.paymentHistory),
      const _MenuItem('Payment receipts', route: Routes.receipts),
    ],
  ),
  _MenuSection(
    Icons.account_balance_wallet_outlined,
    'My account / ledger',
    items: [
      const _MenuItem('Account statement', route: Routes.ledger),
      _MenuItem('Outstanding balance', route: Routes.balance(BalanceSection.outstanding.name)),
      _MenuItem('Credit limit', route: Routes.balance(BalanceSection.creditLimit.name)),
      _MenuItem('Debit entries', route: Routes.ledgerOf(LedgerFilter.debit.name)),
      _MenuItem('Credit entries', route: Routes.ledgerOf(LedgerFilter.credit.name)),
      _MenuItem('Payment history', route: Routes.ledgerOf(LedgerFilter.payments.name)),
    ],
  ),
  _MenuSection(
    Icons.report_gmailerrorred_outlined,
    'Quality and damage complaints',
    items: [
      _MenuItem('Report damaged bags', route: Routes.reportComplaint(ComplaintType.damagedBags.name)),
      _MenuItem('Report melted ice bags', route: Routes.reportComplaint(ComplaintType.meltedBags.name)),
      _MenuItem('Report short quantity', route: Routes.reportComplaint(ComplaintType.shortQuantity.name)),
      _MenuItem('Upload complaint photos', route: Routes.complaintInfo(ComplaintRecord.photos.name)),
      _MenuItem('Automatic date and time', route: Routes.complaintInfo(ComplaintRecord.dateTime.name)),
      _MenuItem('Automatic GPS location', route: Routes.complaintInfo(ComplaintRecord.gps.name)),
      _MenuItem('Select Order ID', route: Routes.complaintInfo('order')),
      _MenuItem('Complaint status', route: Routes.complaintList(ComplaintSection.status.name)),
      _MenuItem('Approved / rejected complaints', route: Routes.complaintList(ComplaintSection.decided.name)),
      _MenuItem('Complaint history', route: Routes.complaintList(ComplaintSection.history.name)),
    ],
  ),
  const _MenuSection(
    Icons.calendar_month_outlined,
    'Delivery schedule',
    items: [
      _MenuItem('Upcoming deliveries', route: Routes.upcomingDeliveries),
      _MenuItem('Delivery calendar', route: Routes.deliverySchedule),
      _MenuItem('Request delivery', route: Routes.requestDelivery),
    ],
  ),
  _MenuSection(
    Icons.local_offer_outlined,
    'Offers and schemes',
    items: [
      _MenuItem('Current offers', route: Routes.offersOf(OfferKind.current.name)),
      _MenuItem('Dealer schemes', route: Routes.offersOf(OfferKind.scheme.name)),
      _MenuItem('Special discounts', route: Routes.offersOf(OfferKind.specialDiscount.name)),
    ],
  ),
  _MenuSection(
    Icons.description_outlined,
    'Invoices and GST bills',
    items: [
      _MenuItem('Download GST invoice', route: Routes.invoicesOf(InvoiceSection.download.name)),
      _MenuItem('Previous bills', route: Routes.invoicesOf(InvoiceSection.previous.name)),
      _MenuItem('Order-wise invoice', route: Routes.invoicesOf(InvoiceSection.orderWise.name)),
    ],
  ),
  _MenuSection(
    Icons.storefront_outlined,
    'My business profile',
    items: [
      for (final field in ProfileField.values) _MenuItem(field.title, route: Routes.profileField(field.name)),
      const _MenuItem('Delivery address', route: Routes.addresses),
      const _MenuItem('Full business profile', route: Routes.businessProfile),
      const _MenuItem('KYC documents', route: Routes.documents),
    ],
  ),
  _MenuSection(
    Icons.notifications_none,
    'Notifications',
    items: [
      for (final type in NotificationType.values) _MenuItem(type.label, route: Routes.notificationsOf(type.name)),
      const _MenuItem('All notifications', route: Routes.notifications),
      const _MenuItem('Notification settings', route: Routes.notificationSettings),
    ],
  ),
  _MenuSection(
    Icons.support_agent_outlined,
    'Customer support',
    items: [
      _MenuItem('Call ICECLUB', action: (_, _) => ContactLauncher.call(AppConstants.supportPhone)),
      _MenuItem('WhatsApp support', action: (_, _) => ContactLauncher.whatsapp()),
      const _MenuItem('Raise support ticket', route: Routes.newTicket),
      const _MenuItem('My support tickets', route: Routes.tickets),
      const _MenuItem('Help and FAQ', route: Routes.support),
    ],
  ),
  const _MenuSection(
    Icons.settings_outlined,
    'Settings',
    items: [
      _MenuItem('Change password', route: Routes.changePassword),
      _MenuItem('Manage account', route: Routes.manageAccount),
      _MenuItem('Logout', action: confirmLogout),
    ],
  ),
  _MenuSection(
    Icons.more_horiz,
    'More',
    items: [
      const _MenuItem('Standing orders', route: Routes.standingOrders),
      const _MenuItem('Ice boxes', route: Routes.iceBoxes),
      const _MenuItem('Ice calculator', route: Routes.calculator),
      const _MenuItem('Purchase reports', route: Routes.reports),
      _MenuItem('Visit website', action: (_, _) => ContactLauncher.website()),
    ],
  ),
];

/// The tabs in the bottom bar, which `go` switches to instead of opening on top.
const _tabRoutes = {Routes.home, Routes.catalog, Routes.orders, Routes.payments, Routes.menu};

void _open(BuildContext context, String route) => _tabRoutes.contains(route) ? context.go(route) : context.push(route);

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dealer = ref.watch(currentDealerProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: AppCard(
              onTap: () => context.push(Routes.businessProfile),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.sky100,
                    child: Icon(Icons.storefront, color: AppColors.sky700),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dealer.businessName, style: text.titleSmall),
                        Text('${dealer.ownerName} · +91 ${dealer.phone}', style: text.bodySmall),
                      ],
                    ),
                  ),
                  StatusChip(dealer.tier),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          for (final (i, section) in _sections.indexed)
            _sectionTile(context, ref, section, i < 16 ? '${i + 1}. ${section.title}' : section.title),
          const SizedBox(height: 6),
          Center(child: Text('${AppConstants.appName} · ${AppConstants.webAppDomain}', style: text.labelSmall)),
        ],
      ),
    );
  }

  Widget _sectionTile(BuildContext context, WidgetRef ref, _MenuSection section, String title) {
    final icon = Icon(section.icon, color: AppColors.sky700);
    if (section.items.isEmpty) {
      return ListTile(
        leading: icon,
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => section.action != null ? section.action!(context, ref) : _open(context, section.route!),
      );
    }
    return ExpansionTile(
      key: PageStorageKey(section.title),
      leading: icon,
      title: Text(title),
      shape: const Border(),
      collapsedShape: const Border(),
      childrenPadding: const EdgeInsets.only(left: 22),
      children: [
        for (final item in section.items)
          ListTile(
            title: Text(item.label),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => item.action != null ? item.action!(context, ref) : _open(context, item.route!),
          ),
      ],
    );
  }
}

/// The My Business Profile sub-menus that show one detail.
enum ProfileField {
  dealerName('Dealer name', Icons.person_outline),
  businessName('Business name', Icons.storefront_outlined),
  gstNumber('GST number', Icons.receipt_outlined),
  fssaiNumber('FSSAI number', Icons.verified_outlined),
  mobileNumber('Mobile number', Icons.call_outlined),
  shopAddress('Shop address', Icons.location_on_outlined);

  const ProfileField(this.title, this.icon);

  final String title;
  final IconData icon;

  String valueOf(Dealer d) => switch (this) {
    ProfileField.dealerName => d.ownerName,
    ProfileField.businessName => d.businessName,
    ProfileField.gstNumber => d.gstin,
    ProfileField.fssaiNumber => d.fssai,
    ProfileField.mobileNumber => '+91 ${d.phone}',
    ProfileField.shopAddress => '${d.addressLine}, ${d.city} - ${d.pincode}',
  };
}

class ProfileFieldScreen extends ConsumerWidget {
  const ProfileFieldScreen({super.key, required this.field});

  final ProfileField field;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dealer = ref.watch(currentDealerProvider);
    final text = Theme.of(context).textTheme;
    final value = field.valueOf(dealer);
    return Scaffold(
      appBar: AppBar(title: Text(field.title)),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(field.icon, color: AppColors.sky700),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(field.title, style: text.labelMedium),
                      const SizedBox(height: 2),
                      Text(value.isEmpty ? 'Not added' : value, style: text.titleSmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (field == ProfileField.dealerName)
            OutlinedButton(onPressed: () => context.push(Routes.businessProfile), child: const Text('Edit dealer name'))
          else
            const NoticeBanner('To change verified details, please contact support.', color: AppColors.sky600),
        ],
      ),
    );
  }
}

class BusinessProfileScreen extends ConsumerStatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  ConsumerState<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends ConsumerState<BusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Dealer _dealer = ref.read(currentDealerProvider);
  late final _owner = TextEditingController(text: _dealer.ownerName);
  late final _email = TextEditingController(text: _dealer.email);
  bool _saving = false;

  @override
  void dispose() {
    _owner.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await ref
        .read(authControllerProvider.notifier)
        .updateProfile(_dealer.copyWith(ownerName: _owner.text.trim(), email: _email.text.trim()));
    if (!mounted) return;
    setState(() => _saving = false);
    showMessage(context, 'Profile updated');
  }

  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(addressesProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('My business profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.page,
          children: [
            LabeledField(
              label: 'Dealer name',
              child: TextFormField(
                controller: _owner,
                validator: Validators.required,
                decoration: InputDecoration(hintText: enterHint('Dealer name')),
              ),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'Email (optional)',
              child: TextFormField(
                controller: _email,
                validator: Validators.email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(hintText: enterHint('Email (optional)')),
              ),
            ),
            const SizedBox(height: 12),
            LoadingButton(label: 'Save changes', loading: _saving, onPressed: _save),
            const SectionTitle('Verified details'),
            AppCard(
              child: Column(
                children: [
                  InfoRow('Business name', _dealer.businessName),
                  InfoRow('Business type', _dealer.businessType),
                  InfoRow('Mobile number', '+91 ${_dealer.phone}'),
                  InfoRow('GST number', _dealer.gstin),
                  InfoRow('FSSAI number', _dealer.fssai),
                  InfoRow('PAN', _dealer.pan),
                  InfoRow('Shop address', '${_dealer.addressLine}, ${_dealer.city} - ${_dealer.pincode}'),
                  InfoRow('Credit limit', money(_dealer.creditLimit)),
                  InfoRow('Credit terms', '${_dealer.creditDays} days'),
                  if (_dealer.joinedOn != null) InfoRow('Member since', formatDate(_dealer.joinedOn!)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const NoticeBanner('To change verified details, please contact support.', color: AppColors.sky600),
            SectionTitle('Delivery address', actionLabel: 'Manage', onAction: () => context.push(Routes.addresses)),
            for (final a in addresses)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(child: Text('${a.label}${a.isDefault ? ' (default)' : ''}\n${a.singleLine}')),
              ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => context.push(Routes.documents), child: const Text('KYC documents')),
          ],
        ),
      ),
    );
  }
}

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dealer = ref.watch(currentDealerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('KYC documents')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          DocumentPicker(
            documents: dealer.documents,
            onChanged: (documents) =>
                ref.read(authControllerProvider.notifier).updateProfile(dealer.copyWith(documents: documents)),
          ),
          for (final e in dealer.documents.entries)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.key, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  LocalImage(e.value),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
