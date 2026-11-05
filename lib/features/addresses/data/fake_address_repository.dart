import '../../../core/error/app_exception.dart';
import '../../../core/storage/local_store.dart';
import '../../auth/domain/dealer.dart';
import '../domain/address.dart';

class FakeAddressRepository implements AddressRepository {
  FakeAddressRepository(this._store, this._dealer);

  final LocalStore _store;
  final Dealer? _dealer;

  static const _key = 'addresses';

  List<Address> _read() {
    final stored = _store.readList(_key);
    if (stored != null) return stored.map(Address.fromJson).toList();
    final dealer = _dealer;
    // The registered business address is the first delivery address.
    if (dealer == null || dealer.addressLine.isEmpty) return [];
    return [
      Address(
        id: 'business',
        label: 'Business address',
        contactName: dealer.ownerName,
        phone: dealer.phone,
        line: dealer.addressLine,
        city: dealer.city,
        pincode: dealer.pincode,
        isDefault: true,
      ),
    ];
  }

  Future<void> _write(List<Address> items) => _store.writeList(_key, items.map((a) => a.toJson()).toList());

  @override
  Future<List<Address>> addresses() async {
    await fakeLatency();
    return _read();
  }

  @override
  Future<void> save(Address address) async {
    final items = _read();
    final index = items.indexWhere((a) => a.id == address.id);
    index >= 0 ? items[index] = address : items.add(address);
    await _write(address.isDefault ? _withDefault(items, address.id) : items);
  }

  @override
  Future<void> delete(String id) async {
    final items = _read();
    if (items.length == 1) throw const AppException('Keep at least one delivery address');
    final removed = items.firstWhere((a) => a.id == id);
    items.remove(removed);
    await _write(removed.isDefault ? _withDefault(items, items.first.id) : items);
  }

  @override
  Future<void> setDefault(String id) => _write(_withDefault(_read(), id));

  List<Address> _withDefault(List<Address> items, String id) => [
    for (final a in items) a.copyWith(isDefault: a.id == id),
  ];
}
