import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../data/api_complaint_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/routes.dart';
import '../../../core/location/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/order_providers.dart';
import '../data/fake_complaint_repository.dart';
import '../domain/complaint.dart';

final complaintRepositoryProvider = Provider<ComplaintRepository>(
  (ref) => useFakeBackend ? FakeComplaintRepository(ref.watch(dealerStoreProvider), ref.watch(notificationRepositoryProvider)) : ApiComplaintRepository(ref.watch(apiProvider)),
);

final complaintsProvider = FutureProvider<List<Complaint>>(
  (ref) => ref.watch(complaintRepositoryProvider).complaints(),
);

Color _statusColor(ComplaintStatus status) => switch (status) {
  ComplaintStatus.underReview => AppColors.amber600,
  ComplaintStatus.approved => AppColors.green600,
  ComplaintStatus.rejected => AppColors.red600,
};

Widget _complaintList(List<Complaint> items, String empty) {
  if (items.isEmpty) return EmptyState(icon: Icons.report_gmailerrorred_outlined, title: empty);
  return ListView.separated(
    padding: AppSpacing.pageWithFab,
    itemCount: items.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (context, i) {
      final c = items[i];
      final text = Theme.of(context).textTheme;
      return AppCard(
        onTap: () => context.push(Routes.complaint(c.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(c.type.label, style: text.titleSmall)),
                StatusChip(c.status.label, color: _statusColor(c.status)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Order ${c.orderNumber}'),
            Text('${c.number} · ${formatDateTime(c.submittedAt)}', style: text.bodySmall),
          ],
        ),
      );
    },
  );
}

class ComplaintsScreen extends ConsumerWidget {
  const ComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quality and damage complaints'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.sky700,
            indicatorColor: AppColors.sky700,
            tabs: [
              Tab(text: 'History'),
              Tab(text: 'Under review'),
              Tab(text: 'Approved'),
              Tab(text: 'Rejected'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(Routes.newComplaint),
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('New complaint'),
        ),
        body: AsyncBody(
          value: ref.watch(complaintsProvider),
          onRetry: () => ref.invalidate(complaintsProvider),
          builder: (complaints) {
            List<Complaint> withStatus(ComplaintStatus s) => complaints.where((c) => c.status == s).toList();
            return TabBarView(
              children: [
                _complaintList(complaints, 'No complaints yet'),
                _complaintList(withStatus(ComplaintStatus.underReview), 'Nothing under review'),
                _complaintList(withStatus(ComplaintStatus.approved), 'No approved complaints'),
                _complaintList(withStatus(ComplaintStatus.rejected), 'No rejected complaints'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class NewComplaintScreen extends ConsumerStatefulWidget {
  const NewComplaintScreen({super.key, this.orderId, this.type});

  final String? orderId;
  final ComplaintType? type;

  @override
  ConsumerState<NewComplaintScreen> createState() => _NewComplaintScreenState();
}

class _NewComplaintScreenState extends ConsumerState<NewComplaintScreen> {
  static const _maxPhotos = 5;

  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _description = TextEditingController();
  late String? _orderId = widget.orderId;
  late ComplaintType _type = widget.type ?? ComplaintType.damagedBags;
  final List<PickedPhoto> _photos = [];
  bool _submitting = false;

  @override
  void dispose() {
    _quantity.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _addPhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 1920);
      if (file == null) return;
      final takenAt = await file.lastModified();
      if (mounted) setState(() => _photos.add(PickedPhoto(file.path, takenAt)));
    } on PlatformException {
      if (mounted) {
        showMessage(
          context,
          'Please allow camera access for this app in your phone settings, then try again.',
          isError: true,
        );
      }
    }
  }

  Future<void> _submit(List<Order> orders) async {
    if (!_formKey.currentState!.validate()) return;
    final order = orders.where((o) => o.id == _orderId).firstOrNull;
    if (order == null) return;
    if (_photos.isEmpty) {
      showMessage(context, 'Please add at least one photo', isError: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      // The location is read at the moment of submitting, not earlier.
      final location = await LocationService.current();
      await ref
          .read(complaintRepositoryProvider)
          .submit(
            orderId: order.id,
            orderNumber: order.number,
            type: _type,
            affectedQuantity: int.parse(_quantity.text),
            description: _description.text.trim(),
            photos: _photos,
            location: location,
          );
      ref.invalidate(complaintsProvider);
      ref.invalidate(notificationsProvider);
      if (!mounted) return;
      showMessage(context, 'Complaint submitted. We will review it soon.');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showMessage(context, '$e', isError: true);
    }
  }

  String? _validateQuantity(String? v, List<Order> orders) {
    final quantity = int.tryParse(v ?? '');
    if (quantity == null || quantity < 1) return 'Enter the number of bags affected';
    final order = orders.where((o) => o.id == _orderId).firstOrNull;
    if (order != null && quantity > order.itemCount) return 'This order had only ${order.itemCount} items';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New complaint')),
      body: AsyncBody(
        value: ref.watch(ordersProvider),
        builder: (allOrders) {
          final delivered = allOrders.where((o) => o.isDelivered).toList();
          if (delivered.isEmpty) {
            return const EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'No delivered orders',
              message: 'Complaints are linked to a delivered order, so you can raise one after your first delivery.',
            );
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: AppSpacing.page,
              children: [
                LabeledField(
                  label: 'Select Order ID',
                  child: DropdownButtonFormField<String>(
                    initialValue: delivered.any((o) => o.id == _orderId) ? _orderId : null,
                    isExpanded: true,
                    decoration: InputDecoration(hintText: selectHint('Select Order ID')),
                    items: [
                      for (final o in delivered)
                        DropdownMenuItem(
                          value: o.id,
                          child: Text('${o.number} · ${formatDate(o.deliveryDate)}', overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    validator: (v) => v == null ? 'Select the order this is about' : null,
                    onChanged: (v) => setState(() => _orderId = v),
                  ),
                ),
                const SectionTitle('What went wrong?'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in ComplaintType.values)
                      ChoiceChip(
                        label: Text(t.label),
                        selected: _type == t,
                        onSelected: (_) => setState(() => _type = t),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                LabeledField(
                  label: 'Number of bags affected',
                  child: TextFormField(
                    controller: _quantity,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => _validateQuantity(v, delivered),
                    decoration: InputDecoration(hintText: enterHint('Number of bags affected')),
                  ),
                ),
                const SizedBox(height: 12),
                LabeledField(
                  label: 'Describe the problem',
                  child: TextFormField(
                    controller: _description,
                    maxLines: 3,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please describe the problem' : null,
                    decoration: InputDecoration(hintText: enterHint('Describe the problem')),
                  ),
                ),
                SectionTitle('Photos (${_photos.length} of $_maxPhotos)'),
                if (_photos.isNotEmpty)
                  SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => Stack(
                        children: [
                          LocalImage(_photos[i].path, height: 110, width: 110),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: IconButton.filledTonal(
                              tooltip: 'Remove photo',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () => setState(() => _photos.removeAt(i)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_photos.length < _maxPhotos) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _addPhoto(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Camera'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _addPhoto(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Gallery'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                const NoticeBanner(
                  'The date, time and your GPS location are recorded automatically when you submit.',
                  color: AppColors.sky600,
                  icon: Icons.my_location,
                ),
                const SizedBox(height: 12),
                LoadingButton(label: 'Submit complaint', loading: _submitting, onPressed: () => _submit(delivered)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ComplaintDetailScreen extends ConsumerWidget {
  const ComplaintDetailScreen({super.key, required this.complaintId});

  final String complaintId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complaint details')),
      body: AsyncBody(
        value: ref.watch(complaintsProvider),
        builder: (complaints) {
          final c = complaints.where((c) => c.id == complaintId).firstOrNull;
          if (c == null) {
            return const EmptyState(icon: Icons.report_gmailerrorred_outlined, title: 'Complaint not found');
          }
          final text = Theme.of(context).textTheme;
          final mapUrl = Uri.https('www.google.com', '/maps/search/', {
            'api': '1',
            'query': '${c.location.latitude},${c.location.longitude}',
          });
          return ListView(
            padding: AppSpacing.page,
            children: [
              Row(
                children: [
                  Expanded(child: Text(c.type.label, style: text.titleMedium)),
                  StatusChip(c.status.label, color: _statusColor(c.status)),
                ],
              ),
              const SizedBox(height: 10),
              if (c.status == ComplaintStatus.underReview)
                const NoticeBanner(
                  'Our team is reviewing this complaint. You will get a notification when it is decided.',
                )
              else
                NoticeBanner(
                  '${c.status.label}${c.decidedAt == null ? '' : ' on ${formatDate(c.decidedAt!)}'}: ${c.adminRemark ?? ''}',
                  color: _statusColor(c.status),
                ),
              const SizedBox(height: 10),
              AppCard(
                child: Column(
                  children: [
                    InfoRow('Complaint no.', c.number),
                    InfoRow('Order ID', c.orderNumber),
                    InfoRow('Bags affected', '${c.affectedQuantity}'),
                    InfoRow('Submitted', formatDateTime(c.submittedAt)),
                    InfoRow(
                      'GPS location',
                      '${c.location.latitude.toStringAsFixed(5)}, ${c.location.longitude.toStringAsFixed(5)}',
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => launchUrl(mapUrl, mode: LaunchMode.externalApplication),
                        child: const Text('Open in maps'),
                      ),
                    ),
                  ],
                ),
              ),
              const SectionTitle('Description'),
              Text(c.description),
              if (c.photos.isNotEmpty) const SectionTitle('Photos'),
              for (final p in c.photos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        LocalImage(p.path),
                        const SizedBox(height: 6),
                        InfoRow('Photo date and time', formatDateTime(p.takenAt)),
                        InfoRow('Uploaded', formatDateTime(p.uploadedAt)),
                        InfoRow('Server timestamp', formatDateTime(p.serverTimestamp)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => context.push(Routes.order(c.orderId)), child: const Text('View order')),
            ],
          );
        },
      ),
    );
  }
}

/// The complaint sub-menus that list complaints.
enum ComplaintSection {
  status('Complaint status', 'Nothing under review'),
  decided('Approved / rejected complaints', 'No decided complaints yet'),
  history('Complaint history', 'No complaints yet');

  const ComplaintSection(this.title, this.emptyTitle);

  final String title;
  final String emptyTitle;

  bool includes(Complaint c) => switch (this) {
    ComplaintSection.status => c.status == ComplaintStatus.underReview,
    ComplaintSection.decided => c.status != ComplaintStatus.underReview,
    ComplaintSection.history => true,
  };
}

class ComplaintListScreen extends ConsumerWidget {
  const ComplaintListScreen({super.key, required this.section});

  final ComplaintSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(section.title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newComplaint),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('New complaint'),
      ),
      body: AsyncBody(
        value: ref.watch(complaintsProvider),
        onRetry: () => ref.invalidate(complaintsProvider),
        builder: (complaints) => _complaintList(complaints.where(section.includes).toList(), section.emptyTitle),
      ),
    );
  }
}

/// The complaint sub-menus about what each complaint records.
enum ComplaintRecord {
  photos(
    'Upload complaint photos',
    'Add photos when you report a problem. Each keeps its date, time and server timestamp.',
  ),
  dateTime('Automatic date and time', 'The date and time are saved automatically when you submit a complaint.'),
  gps('Automatic GPS location', 'Your GPS location is saved automatically when you submit a complaint.');

  const ComplaintRecord(this.title, this.message);

  final String title;
  final String message;
}

class ComplaintRecordScreen extends ConsumerWidget {
  const ComplaintRecordScreen({super.key, required this.record});

  final ComplaintRecord record;

  List<Widget> _details(Complaint c) => switch (record) {
    ComplaintRecord.photos => [
      if (c.photos.isEmpty) const InfoRow('Photos', 'None'),
      for (final photo in c.photos) ...[
        LocalImage(photo.path, height: 120),
        InfoRow('Photo date and time', formatDateTime(photo.takenAt)),
        InfoRow('Server timestamp', formatDateTime(photo.serverTimestamp)),
      ],
    ],
    ComplaintRecord.dateTime => [InfoRow('Submitted', formatDateTime(c.submittedAt))],
    ComplaintRecord.gps => [
      InfoRow('GPS location', '${c.location.latitude.toStringAsFixed(5)}, ${c.location.longitude.toStringAsFixed(5)}'),
    ],
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(record.title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newComplaint),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('New complaint'),
      ),
      body: AsyncBody(
        value: ref.watch(complaintsProvider),
        onRetry: () => ref.invalidate(complaintsProvider),
        builder: (complaints) => ListView(
          padding: AppSpacing.pageWithFab,
          children: [
            NoticeBanner(record.message, color: AppColors.sky600, icon: Icons.verified_outlined),
            const SizedBox(height: 10),
            for (final c in complaints)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  onTap: () => context.push(Routes.complaint(c.id)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${c.type.label} · ${c.number}', style: text.labelLarge),
                      const SizedBox(height: 4),
                      ..._details(c),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Picks the delivered order a new complaint is about.
class SelectComplaintOrderScreen extends ConsumerWidget {
  const SelectComplaintOrderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Select Order ID')),
      body: AsyncBody(
        value: ref.watch(ordersProvider),
        onRetry: () => ref.invalidate(ordersProvider),
        builder: (orders) {
          final delivered = orders.where((o) => o.isDelivered).toList();
          if (delivered.isEmpty) {
            return const EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'No delivered orders',
              message: 'Complaints are linked to a delivered order.',
            );
          }
          return ListView.separated(
            padding: AppSpacing.page,
            itemCount: delivered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final order = delivered[i];
              return AppCard(
                onTap: () => context.push(Routes.newComplaint, extra: order.id),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order.number, style: text.labelLarge),
                          Text(formatDate(order.deliveryDate), style: text.bodySmall),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
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
