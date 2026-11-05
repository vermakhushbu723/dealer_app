import '../../../core/network/api_client.dart';
import '../domain/catalog_repository.dart';
import '../domain/product.dart';

class ApiCatalogRepository implements CatalogRepository {
  ApiCatalogRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<IceCategory>> categories() async =>
      (await _api.get('/dealer/categories') as Object).mapped((j) => IceCategory(j['id'] as String, j['name'] as String));

  Product _product(Map<String, dynamic> j) => Product(
    id: j['id'] as String,
    name: j['name'] as String,
    categoryId: j['categoryId'] as String,
    description: j['description'] as String,
    image: j['image'] as String,
    unit: j['unit'] as String,
    packSize: j['packSize'] as String,
    slabs: (j['slabs'] as Object).mapped((s) => PriceSlab(s['minQty'] as int, (s['price'] as num).toDouble())),
    minOrderQty: j['minOrderQty'] as int,
    stepQty: j['stepQty'] as int,
    gstPercent: (j['gstPercent'] as num).toDouble(),
    availableQty: j['availableQty'] as int,
    uses: (j['uses'] as List).cast<String>(),
    usageWarning: j['usageWarning'] as String?,
    isReturnable: j['isReturnable'] as bool,
    hsnCode: j['hsnCode'] as String,
    standardPrice: (j['standardPrice'] as num?)?.toDouble(),
  );

  @override
  Future<List<Product>> products() async => (await _api.get('/dealer/products') as Object).mapped(_product);

  Future<Set<String>> _ids(String path) async => ((await _api.get(path)) as List).cast<String>().toSet();

  @override
  Future<Set<String>> favourites() => _ids('/dealer/favourites');

  @override
  Future<void> setFavourite(String productId, bool favourite) => _api.put('/dealer/favourites/$productId', {'on': favourite});

  @override
  Future<Set<String>> stockAlerts() => _ids('/dealer/stock-alerts');

  @override
  Future<void> setStockAlert(String productId, bool enabled) => _api.put('/dealer/stock-alerts/$productId', {'on': enabled});
}
