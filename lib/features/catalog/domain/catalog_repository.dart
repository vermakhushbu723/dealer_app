import 'product.dart';

abstract interface class CatalogRepository {
  Future<List<IceCategory>> categories();

  Future<List<Product>> products();

  Future<Set<String>> favourites();

  Future<void> setFavourite(String productId, bool favourite);

  /// Products the dealer wants to hear about when they are back in stock.
  Future<Set<String>> stockAlerts();

  Future<void> setStockAlert(String productId, bool enabled);
}
