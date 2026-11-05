import 'dart:async';
import '../../../core/network/api_client.dart';
import '../data/api_tracking_repository.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/location/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/order_providers.dart';
import '../../orders/presentation/order_screens.dart';
import '../data/fake_tracking_repository.dart';
import '../domain/delivery_tracking.dart';

final trackingRepositoryProvider = Provider<TrackingRepository>((ref) => useFakeBackend ? FakeTrackingRepository() : ApiTrackingRepository(ref.watch(apiProvider)));

final trackingProvider = FutureProvider.family<DeliveryTracking, Order>(
  (ref, order) => ref.watch(trackingRepositoryProvider).track(order),
);

class TrackDeliveryScreen extends ConsumerWidget {
  const TrackDeliveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track my delivery')),
      body: AsyncBody(
        value: ref.watch(ordersProvider),
        onRetry: () => ref.invalidate(ordersProvider),
        builder: (orders) {
          final active = orders.where((o) => o.isActive).toList();
          if (active.isEmpty) {
            return const EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'Nothing to track',
              message: 'Orders on their way to you will show up here.',
            );
          }
          return ListView.separated(
            padding: AppSpacing.page,
            itemCount: active.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => AppCard(
              onTap: () => context.push(Routes.trackOrder(active[i].id)),
              child: Row(
                children: [
                  Icon(
                    active[i].status == OrderStatus.outForDelivery ? Icons.local_shipping : Icons.inventory_2_outlined,
                    color: AppColors.sky700,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${active[i].number}\n${active[i].status.label}')),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class TrackOrderScreen extends ConsumerStatefulWidget {
  const TrackOrderScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends ConsumerState<TrackOrderScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      ref.invalidate(ordersProvider);
      ref.invalidate(trackingProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Track my delivery')),
      body: AsyncBody(
        value: ref.watch(orderProvider(widget.orderId)),
        builder: (order) {
          if (order == null) return const EmptyState(icon: Icons.local_shipping_outlined, title: 'Order not found');
          final tracking = ref.watch(trackingProvider(order)).value;
          return ListView(
            padding: AppSpacing.page,
            children: [
              Text(order.number, style: text.titleMedium),
              const SizedBox(height: 10),
              if (tracking != null) _TrackingMap(tracking: tracking),
              const SizedBox(height: 4),
              Text('Demo: the rider position is simulated until the Driver App is connected.', style: text.bodySmall),
              const SizedBox(height: 10),
              AppCard(
                child: Column(
                  children: [
                    InfoRow('Delivery status', order.status.label),
                    if (tracking != null && order.isActive) InfoRow('Estimated delivery', formatDateTime(tracking.eta)),
                    if (order.isDelivered && order.timeOf(OrderStatus.delivered) != null)
                      InfoRow('Delivered at', formatDateTime(order.timeOf(OrderStatus.delivered)!)),
                    if (tracking?.updatedAt != null) InfoRow('Last updated', formatDateTime(tracking!.updatedAt!)),
                  ],
                ),
              ),
              if (order.status == OrderStatus.outForDelivery && order.driver != null) ...[
                const SizedBox(height: 10),
                DriverCard(order: order),
              ],
              const SectionTitle('Delivery status'),
              AppCard(child: OrderTimeline(order: order)),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => ContactLauncher.call(AppConstants.supportPhone),
                icon: const Icon(Icons.call_outlined),
                label: const Text('Call ICECLUB'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TrackingMap extends StatelessWidget {
  const _TrackingMap({required this.tracking});

  final DeliveryTracking tracking;

  LatLng _point(GeoPoint p) => LatLng(p.latitude, p.longitude);

  Marker _marker(GeoPoint point, IconData icon, Color color) => Marker(
    point: _point(point),
    width: 36,
    height: 36,
    child: DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 22),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final origin = _point(tracking.origin);
    final destination = _point(tracking.destination);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        height: 260,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: [origin, destination],
              padding: const EdgeInsets.all(48),
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'in.iceclubstore.dealer_app',
            ),
            PolylineLayer(
              polylines: [
                Polyline(points: [origin, destination], strokeWidth: 3, color: AppColors.sky600),
              ],
            ),
            MarkerLayer(
              markers: [
                _marker(tracking.origin, Icons.factory_outlined, AppColors.neutral700),
                _marker(tracking.destination, Icons.storefront, AppColors.green600),
                if (tracking.rider != null) _marker(tracking.rider!, Icons.local_shipping, AppColors.sky700),
              ],
            ),
            const Align(
              alignment: Alignment.bottomRight,
              child: ColoredBox(
                color: Colors.white70,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Track My Delivery sub-menus besides the live map.
enum TrackSection {
  status('Delivery status'),
  eta('Estimated delivery time');

  const TrackSection(this.title);

  final String title;
}

class TrackSectionScreen extends ConsumerWidget {
  const TrackSectionScreen({super.key, required this.section});

  final TrackSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(section.title)),
      body: AsyncBody(
        value: ref.watch(ordersProvider),
        onRetry: () => ref.invalidate(ordersProvider),
        builder: (orders) {
          final active = orders.where((o) => o.isActive).toList();
          if (active.isEmpty) {
            return const EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'Nothing to track',
              message: 'Orders on their way to you will show up here.',
            );
          }
          return ListView(
            padding: AppSpacing.page,
            children: [
              for (final order in active)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    onTap: () => context.push(Routes.trackOrder(order.id)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.number, style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        if (section == TrackSection.status) OrderTimeline(order: order) else _EtaRows(order: order),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EtaRows extends ConsumerWidget {
  const _EtaRows({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(trackingProvider(order)).value;
    return Column(
      children: [
        InfoRow('Delivery status', order.status.label),
        InfoRow('Delivery slot', '${formatDateShort(order.deliveryDate)}, ${order.slot}'),
        if (tracking != null) InfoRow('Estimated delivery', formatDateTime(tracking.eta)),
      ],
    );
  }
}
