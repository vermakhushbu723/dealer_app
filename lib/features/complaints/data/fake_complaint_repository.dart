import '../../../core/location/location_service.dart';
import '../../../core/storage/local_store.dart';
import '../../auth/data/fake_auth_repository.dart';
import '../../notifications/domain/notification.dart';
import '../domain/complaint.dart';

/// New complaints stay under review, because only the admin may decide them.
/// The demo account has one approved and one rejected sample to show those states.
class FakeComplaintRepository implements ComplaintRepository {
  FakeComplaintRepository(this._store, this._notifications);

  final LocalStore _store;
  final NotificationRepository _notifications;

  static const _key = 'complaints';

  List<Complaint> _read() {
    final stored = _store.readList(_key);
    if (stored != null) return stored.map(Complaint.fromJson).toList();
    return _store.scope == demoDealerId ? _samples() : [];
  }

  @override
  Future<List<Complaint>> complaints() async {
    await fakeLatency();
    return _read()..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
  }

  @override
  Future<Complaint> submit({
    required String orderId,
    required String orderNumber,
    required ComplaintType type,
    required int affectedQuantity,
    required String description,
    required List<PickedPhoto> photos,
    required GeoPoint location,
  }) async {
    await fakeLatency();
    final now = DateTime.now();
    final complaint = Complaint(
      id: 'c-${now.microsecondsSinceEpoch}',
      number: 'CMP-${now.microsecondsSinceEpoch.toRadixString(36).toUpperCase()}',
      orderId: orderId,
      orderNumber: orderNumber,
      type: type,
      affectedQuantity: affectedQuantity,
      description: description,
      photos: [
        // In production serverTimestamp comes from the server, not this clock.
        for (final p in photos) ComplaintPhoto(path: p.path, takenAt: p.takenAt, uploadedAt: now, serverTimestamp: now),
      ],
      submittedAt: now,
      location: location,
    );
    await _store.writeList(_key, [
      for (final c in [..._read(), complaint]) c.toJson(),
    ]);
    await _notifications.add(
      NotificationType.order,
      'Complaint received',
      '${complaint.number} for order $orderNumber is under review.',
      route: '/complaints/${complaint.id}',
    );
    return complaint;
  }

  List<Complaint> _samples() {
    Complaint sample(int daysAgo, int serial, ComplaintType type, int quantity, ComplaintStatus status, String remark) {
      final at = DateTime.now().subtract(Duration(days: daysAgo));
      return Complaint(
        id: 'sample-c$serial',
        number: 'CMP-SAMPLE$serial',
        orderId: 'sample-$serial',
        orderNumber: 'ICE-${at.year}-${100 + serial}',
        type: type,
        affectedQuantity: quantity,
        description: 'Sample complaint for the demo account.',
        photos: const [],
        submittedAt: at,
        location: const GeoPoint(19.1136, 72.8697),
        status: status,
        adminRemark: remark,
        decidedAt: at.add(const Duration(days: 1)),
      );
    }

    return [
      sample(50, 4, ComplaintType.meltedBags, 2, ComplaintStatus.approved, 'Approved. Credit note issued for 2 bags.'),
      sample(
        80,
        3,
        ComplaintType.shortQuantity,
        1,
        ComplaintStatus.rejected,
        'Delivery record shows the full quantity.',
      ),
    ];
  }
}
