import '../../../core/location/location_service.dart';

enum ComplaintType { damagedBags, meltedBags, shortQuantity }

enum ComplaintStatus { underReview, approved, rejected }

extension ComplaintTypeLabel on ComplaintType {
  String get label => switch (this) {
    ComplaintType.damagedBags => 'Damaged bags',
    ComplaintType.meltedBags => 'Melted ice bags',
    ComplaintType.shortQuantity => 'Short quantity',
  };
}

extension ComplaintStatusLabel on ComplaintStatus {
  String get label => switch (this) {
    ComplaintStatus.underReview => 'Under review',
    ComplaintStatus.approved => 'Approved',
    ComplaintStatus.rejected => 'Rejected',
  };
}

class ComplaintPhoto {
  const ComplaintPhoto({
    required this.path,
    required this.takenAt,
    required this.uploadedAt,
    required this.serverTimestamp,
  });

  final String path;

  /// The photo file's own date and time, kept as evidence.
  final DateTime takenAt;

  /// When the dealer attached and submitted it, by the phone's clock.
  final DateTime uploadedAt;

  /// When the server received it. The dealer can't change this one.
  final DateTime serverTimestamp;

  Map<String, dynamic> toJson() => {
    'path': path,
    'takenAt': takenAt.toIso8601String(),
    'uploadedAt': uploadedAt.toIso8601String(),
    'serverTimestamp': serverTimestamp.toIso8601String(),
  };

  factory ComplaintPhoto.fromJson(Map<String, dynamic> j) => ComplaintPhoto(
    path: j['path'] as String,
    takenAt: DateTime.parse(j['takenAt'] as String),
    uploadedAt: DateTime.parse(j['uploadedAt'] as String),
    serverTimestamp: DateTime.parse(j['serverTimestamp'] as String),
  );
}

/// A photo chosen in the form, before it is uploaded.
class PickedPhoto {
  const PickedPhoto(this.path, this.takenAt);

  final String path;
  final DateTime takenAt;
}

class Complaint {
  const Complaint({
    required this.id,
    required this.number,
    required this.orderId,
    required this.orderNumber,
    required this.type,
    required this.affectedQuantity,
    required this.description,
    required this.photos,
    required this.submittedAt,
    required this.location,
    this.status = ComplaintStatus.underReview,
    this.adminRemark,
    this.decidedAt,
  });

  final String id;
  final String number;

  /// Every complaint belongs to the delivery order it is about.
  final String orderId;
  final String orderNumber;
  final ComplaintType type;
  final int affectedQuantity;
  final String description;
  final List<ComplaintPhoto> photos;
  final DateTime submittedAt;
  final GeoPoint location;

  /// Only the admin can move this to approved or rejected.
  final ComplaintStatus status;
  final String? adminRemark;
  final DateTime? decidedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'orderId': orderId,
    'orderNumber': orderNumber,
    'type': type.name,
    'affectedQuantity': affectedQuantity,
    'description': description,
    'photos': photos.map((p) => p.toJson()).toList(),
    'submittedAt': submittedAt.toIso8601String(),
    'location': location.toJson(),
    'status': status.name,
    'adminRemark': adminRemark,
    'decidedAt': decidedAt?.toIso8601String(),
  };

  factory Complaint.fromJson(Map<String, dynamic> j) => Complaint(
    id: j['id'] as String,
    number: j['number'] as String,
    orderId: j['orderId'] as String,
    orderNumber: j['orderNumber'] as String,
    type: ComplaintType.values.byName(j['type'] as String),
    affectedQuantity: j['affectedQuantity'] as int,
    description: j['description'] as String,
    photos: (j['photos'] as List).map((p) => ComplaintPhoto.fromJson(p as Map<String, dynamic>)).toList(),
    submittedAt: DateTime.parse(j['submittedAt'] as String),
    location: GeoPoint.fromJson(j['location'] as Map<String, dynamic>),
    status: ComplaintStatus.values.byName(j['status'] as String),
    adminRemark: j['adminRemark'] as String?,
    decidedAt: j['decidedAt'] == null ? null : DateTime.parse(j['decidedAt'] as String),
  );
}

abstract interface class ComplaintRepository {
  /// Newest first.
  Future<List<Complaint>> complaints();

  Future<Complaint> submit({
    required String orderId,
    required String orderNumber,
    required ComplaintType type,
    required int affectedQuantity,
    required String description,
    required List<PickedPhoto> photos,
    required GeoPoint location,
  });
}
