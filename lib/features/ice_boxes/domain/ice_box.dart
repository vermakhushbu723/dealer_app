enum BoxMovementType { issued, returned }

class BoxMovement {
  const BoxMovement({required this.type, required this.quantity, required this.date, required this.reference});

  final BoxMovementType type;
  final int quantity;
  final DateTime date;
  final String reference;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'quantity': quantity,
    'date': date.toIso8601String(),
    'reference': reference,
  };

  factory BoxMovement.fromJson(Map<String, dynamic> j) => BoxMovement(
    type: BoxMovementType.values.byName(j['type'] as String),
    quantity: j['quantity'] as int,
    date: DateTime.parse(j['date'] as String),
    reference: j['reference'] as String,
  );
}

class PickupRequest {
  const PickupRequest({required this.id, required this.quantity, required this.date, required this.requestedAt});

  final String id;
  final int quantity;
  final DateTime date;
  final DateTime requestedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'quantity': quantity,
    'date': date.toIso8601String(),
    'requestedAt': requestedAt.toIso8601String(),
  };

  factory PickupRequest.fromJson(Map<String, dynamic> j) => PickupRequest(
    id: j['id'] as String,
    quantity: j['quantity'] as int,
    date: DateTime.parse(j['date'] as String),
    requestedAt: DateTime.parse(j['requestedAt'] as String),
  );
}

class IceBoxAccount {
  const IceBoxAccount({required this.movements, required this.pickups});

  final List<BoxMovement> movements;
  final List<PickupRequest> pickups;

  int get boxesHeld =>
      movements.fold(0, (sum, m) => sum + (m.type == BoxMovementType.issued ? m.quantity : -m.quantity));

  int get boxesInPickup => pickups.fold(0, (sum, p) => sum + p.quantity);
}

abstract interface class IceBoxRepository {
  Future<IceBoxAccount> account();

  Future<void> recordIssued(int quantity, String reference);

  Future<void> requestPickup(int quantity, DateTime date);

  Future<void> cancelPickup(String id);
}
