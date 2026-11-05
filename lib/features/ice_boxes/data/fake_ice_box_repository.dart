import '../../../core/error/app_exception.dart';
import '../../../core/storage/local_store.dart';
import '../../auth/data/fake_auth_repository.dart';
import '../domain/ice_box.dart';

class FakeIceBoxRepository implements IceBoxRepository {
  FakeIceBoxRepository(this._store);

  final LocalStore _store;

  static const _movementsKey = 'box_movements';
  static const _pickupsKey = 'box_pickups';

  List<BoxMovement> _movements() {
    final stored = _store.readList(_movementsKey);
    if (stored != null) return stored.map(BoxMovement.fromJson).toList();
    if (_store.scope != demoDealerId) return [];
    return [
      BoxMovement(
        type: BoxMovementType.issued,
        quantity: 6,
        date: DateTime.now().subtract(const Duration(days: 60)),
        reference: 'ORD-SAMPLE-1',
      ),
      BoxMovement(
        type: BoxMovementType.returned,
        quantity: 2,
        date: DateTime.now().subtract(const Duration(days: 20)),
        reference: 'Pickup',
      ),
    ];
  }

  List<PickupRequest> _pickups() => (_store.readList(_pickupsKey) ?? const []).map(PickupRequest.fromJson).toList();

  @override
  Future<IceBoxAccount> account() async {
    await fakeLatency();
    final movements = _movements()..sort((a, b) => b.date.compareTo(a.date));
    return IceBoxAccount(movements: movements, pickups: _pickups());
  }

  @override
  Future<void> recordIssued(int quantity, String reference) => _store.writeList(_movementsKey, [
    for (final m in _movements()) m.toJson(),
    BoxMovement(type: BoxMovementType.issued, quantity: quantity, date: DateTime.now(), reference: reference).toJson(),
  ]);

  @override
  Future<void> requestPickup(int quantity, DateTime date) async {
    final account = IceBoxAccount(movements: _movements(), pickups: _pickups());
    if (quantity > account.boxesHeld - account.boxesInPickup) {
      throw const AppException('You cannot return more boxes than you hold.');
    }
    final now = DateTime.now();
    await _store.writeList(_pickupsKey, [
      for (final p in account.pickups) p.toJson(),
      PickupRequest(id: 'p-${now.microsecondsSinceEpoch}', quantity: quantity, date: date, requestedAt: now).toJson(),
    ]);
  }

  @override
  Future<void> cancelPickup(String id) => _store.writeList(_pickupsKey, [
    for (final p in _pickups())
      if (p.id != id) p.toJson(),
  ]);
}
