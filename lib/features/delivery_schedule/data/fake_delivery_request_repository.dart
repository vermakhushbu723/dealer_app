import '../../../core/storage/local_store.dart';
import '../domain/delivery_request.dart';

class FakeDeliveryRequestRepository implements DeliveryRequestRepository {
  FakeDeliveryRequestRepository(this._store);

  final LocalStore _store;

  static const _key = 'delivery_requests';

  List<DeliveryRequest> _read() => (_store.readList(_key) ?? const []).map(DeliveryRequest.fromJson).toList();

  Future<void> _write(List<DeliveryRequest> items) => _store.writeList(_key, items.map((r) => r.toJson()).toList());

  @override
  Future<List<DeliveryRequest>> requests() async => _read()..sort((a, b) => a.date.compareTo(b.date));

  @override
  Future<void> add(DeliveryRequest request) => _write([..._read(), request]);

  @override
  Future<void> cancel(String id) => _write(_read()..removeWhere((r) => r.id == id));
}
