import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/api_catalog_repository.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/fake_catalog_repository.dart';
import '../domain/catalog_repository.dart';
import '../domain/product.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => !useFakeBackend ? ApiCatalogRepository(ref.watch(apiProvider)) : FakeCatalogRepository(
    ref.watch(dealerStoreProvider),
    tier: ref.watch(authControllerProvider.select((a) => a.value?.tier)) ?? 'Standard',
  ),
);

final categoriesProvider = FutureProvider<List<IceCategory>>(
  (ref) => ref.watch(catalogRepositoryProvider).categories(),
);

final productsProvider = FutureProvider<List<Product>>((ref) => ref.watch(catalogRepositoryProvider).products());

final productProvider = FutureProvider.family<Product?, String>((ref, id) async {
  final products = await ref.watch(productsProvider.future);
  return products.where((p) => p.id == id).firstOrNull;
});

final favouritesProvider = FutureProvider<Set<String>>((ref) => ref.watch(catalogRepositoryProvider).favourites());

final stockAlertsProvider = FutureProvider<Set<String>>((ref) => ref.watch(catalogRepositoryProvider).stockAlerts());
