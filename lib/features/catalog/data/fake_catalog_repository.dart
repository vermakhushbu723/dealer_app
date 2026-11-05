import '../../../core/constants/app_constants.dart';
import '../../../core/storage/local_store.dart';
import '../domain/catalog_repository.dart';
import '../domain/product.dart';

const _cubeImage = 'assets/images/CubeIce.png';
const _crushedImage = 'assets/images/CrushedBlockIce.png';
const _dryImage = 'assets/images/DryIce.png';
const _boxImage = 'assets/images/IceBox.png';

// Placeholders: have your accountant confirm the HSN codes and tax rates.
const _iceHsn = '22019010';
const _boxHsn = '39231090';

const _industrialWarning =
    'For industrial use and chilling purposes only. Not for human consumption. Use tube ice in crushed form for drinks.';

/// The product types and uses come from iceclubstore.in. The site publishes no
/// pack sizes, prices, tax rates or stock, so those values are placeholders.
const _products = [
  Product(
    id: 'cube-5',
    name: 'Cube Ice',
    categoryId: 'cube',
    description: 'Purified water cube ice for parties, weddings, BBQs, corporate events and daily use.',
    image: _cubeImage,
    unit: 'bag',
    packSize: '5 kg bag',
    slabs: [PriceSlab(1, 90), PriceSlab(20, 82), PriceSlab(50, 75)],
    minOrderQty: 5,
    stepQty: 5,
    gstPercent: 18,
    hsnCode: _iceHsn,
    availableQty: 500,
    uses: ['Homes', 'Restaurants', 'Hotels', 'Cafes', 'Bars'],
  ),
  Product(
    id: 'cube-20',
    name: 'Cube Ice',
    categoryId: 'cube',
    description: 'Purified water cube ice in a bulk bag for events and high-volume outlets.',
    image: _cubeImage,
    unit: 'bag',
    packSize: '20 kg bag',
    slabs: [PriceSlab(1, 320), PriceSlab(10, 295), PriceSlab(25, 270)],
    minOrderQty: 2,
    stepQty: 1,
    gstPercent: 18,
    hsnCode: _iceHsn,
    availableQty: 200,
    uses: ['Weddings', 'Catering', 'Corporate events'],
  ),
  Product(
    id: 'tube-20',
    name: 'Tube Ice (Crushed)',
    categoryId: 'tube',
    description: 'Tube ice in crushed form, the option for human consumption where crushed ice is needed.',
    image: _crushedImage,
    unit: 'bag',
    packSize: '20 kg bag',
    slabs: [PriceSlab(1, 300), PriceSlab(10, 280), PriceSlab(25, 255)],
    minOrderQty: 2,
    stepQty: 1,
    gstPercent: 18,
    hsnCode: _iceHsn,
    availableQty: 150,
    uses: ['Bars', 'Hotels', 'Catering'],
  ),
  Product(
    id: 'crushed-25',
    name: 'Crushed Ice',
    categoryId: 'crushed',
    description: 'Crushed ice for seafood displays and chilling.',
    image: _crushedImage,
    unit: 'bag',
    packSize: '25 kg bag',
    slabs: [PriceSlab(1, 220), PriceSlab(10, 200), PriceSlab(25, 180)],
    minOrderQty: 2,
    stepQty: 1,
    gstPercent: 18,
    hsnCode: _iceHsn,
    availableQty: 300,
    uses: ['Seafood displays', 'Chilling'],
    usageWarning: _industrialWarning,
  ),
  Product(
    id: 'block-50',
    name: 'Block Ice',
    categoryId: 'block',
    description: 'Large, slow-melting ice blocks for industrial chilling.',
    image: _crushedImage,
    unit: 'block',
    packSize: '50 kg block',
    slabs: [PriceSlab(1, 350), PriceSlab(10, 320), PriceSlab(20, 290)],
    minOrderQty: 1,
    stepQty: 1,
    gstPercent: 18,
    hsnCode: _iceHsn,
    availableQty: 120,
    uses: ['Industrial chilling', 'Fish transport'],
    usageWarning: _industrialWarning,
  ),
  Product(
    id: 'slab-25',
    name: 'Slab Ice',
    categoryId: 'slab',
    description: 'Flat ice slabs for display counters and chilling.',
    image: _crushedImage,
    unit: 'slab',
    packSize: '25 kg slab',
    slabs: [PriceSlab(1, 190), PriceSlab(10, 175), PriceSlab(25, 160)],
    minOrderQty: 2,
    stepQty: 1,
    gstPercent: 18,
    hsnCode: _iceHsn,
    availableQty: 160,
    uses: ['Display counters', 'Chilling'],
    usageWarning: _industrialWarning,
  ),
  Product(
    id: 'dry-10',
    name: 'Dry Ice',
    categoryId: 'dry',
    description: 'For frozen food transport, medical storage, laboratories and special cooling.',
    image: _dryImage,
    unit: 'pack',
    packSize: '10 kg pack',
    slabs: [PriceSlab(1, 950), PriceSlab(5, 900), PriceSlab(10, 850)],
    minOrderQty: 1,
    stepQty: 1,
    gstPercent: 18,
    hsnCode: _iceHsn,
    availableQty: 0,
    uses: ['Frozen food transport', 'Medical storage', 'Laboratories'],
    usageWarning: 'Handle with insulated gloves and keep in a ventilated area. Do not touch with bare hands.',
  ),
  Product(
    id: 'box-50',
    name: 'Ice Box',
    categoryId: 'box',
    description:
        'Durable box for transporting and storing ice, for delivery, outdoor events and commercial use. '
        'The price is a deposit, refunded when the box is returned.',
    image: _boxImage,
    unit: 'box',
    packSize: '50 L box',
    slabs: [PriceSlab(1, AppConstants.iceBoxDeposit)],
    minOrderQty: 1,
    stepQty: 1,
    gstPercent: 0,
    hsnCode: _boxHsn,
    availableQty: 40,
    uses: ['Delivery', 'Outdoor events', 'Commercial use'],
    isReturnable: true,
  ),
];

class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository(this._store, {required this.tier});

  final LocalStore _store;
  final String tier;

  /// Stands in for the per-dealer rates the admin will set in the Admin Panel.
  static const _tierRates = {'Standard': 1.0, 'Silver': 0.97, 'Gold': 0.95};

  static const _favouritesKey = 'favourites';
  static const _alertsKey = 'stock_alerts';

  @override
  Future<List<IceCategory>> categories() async => const [
    IceCategory('tube', 'Tube Ice'),
    IceCategory('cube', 'Cube Ice'),
    IceCategory('block', 'Block Ice'),
    IceCategory('slab', 'Slab Ice'),
    IceCategory('crushed', 'Crushed Ice'),
    IceCategory('dry', 'Dry Ice'),
    IceCategory('box', 'Ice Boxes'),
  ];

  @override
  Future<List<Product>> products() async {
    await fakeLatency();
    final rate = _tierRates[tier] ?? 1.0;
    return [for (final p in _products) p.withDealerRate(rate)];
  }

  Set<String> _readSet(String key) => ((_store.readMap(key)?['ids'] as List?) ?? const []).cast<String>().toSet();

  Future<void> _toggle(String key, String id, bool add) {
    final ids = _readSet(key);
    add ? ids.add(id) : ids.remove(id);
    return _store.writeMap(key, {'ids': ids.toList()});
  }

  @override
  Future<Set<String>> favourites() async => _readSet(_favouritesKey);

  @override
  Future<void> setFavourite(String productId, bool favourite) => _toggle(_favouritesKey, productId, favourite);

  @override
  Future<Set<String>> stockAlerts() async => _readSet(_alertsKey);

  @override
  Future<void> setStockAlert(String productId, bool enabled) => _toggle(_alertsKey, productId, enabled);
}
