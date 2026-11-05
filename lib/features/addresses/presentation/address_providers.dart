import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/api_address_repository.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/fake_address_repository.dart';
import '../domain/address.dart';

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  final dealer = ref.watch(authControllerProvider).value;
  if (!useFakeBackend) return ApiAddressRepository(ref.watch(apiProvider));
  return FakeAddressRepository(ref.watch(dealerStoreProvider), dealer);
});

final addressesProvider = FutureProvider<List<Address>>((ref) => ref.watch(addressRepositoryProvider).addresses());
