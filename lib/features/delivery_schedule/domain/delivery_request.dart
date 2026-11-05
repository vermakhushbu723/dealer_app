/// A dealer asking for a delivery on a date. The company then confirms it.
class DeliveryRequest {
  const DeliveryRequest({
    required this.id,
    required this.date,
    required this.slot,
    required this.addressLabel,
    required this.details,
    required this.requestedAt,
  });

  final String id;
  final DateTime date;
  final String slot;
  final String addressLabel;
  final String details;
  final DateTime requestedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'slot': slot,
    'addressLabel': addressLabel,
    'details': details,
    'requestedAt': requestedAt.toIso8601String(),
  };

  factory DeliveryRequest.fromJson(Map<String, dynamic> j) => DeliveryRequest(
    id: j['id'] as String,
    date: DateTime.parse(j['date'] as String),
    slot: j['slot'] as String,
    addressLabel: j['addressLabel'] as String,
    details: j['details'] as String,
    requestedAt: DateTime.parse(j['requestedAt'] as String),
  );
}

abstract interface class DeliveryRequestRepository {
  Future<List<DeliveryRequest>> requests();

  Future<void> add(DeliveryRequest request);

  Future<void> cancel(String id);
}
