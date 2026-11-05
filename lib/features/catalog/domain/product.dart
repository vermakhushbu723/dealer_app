/// Quantities from [minQty] upward are charged at [price] per unit.
class PriceSlab {
  const PriceSlab(this.minQty, this.price);

  final int minQty;
  final double price;
}

class IceCategory {
  const IceCategory(this.id, this.name);

  final String id;
  final String name;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.description,
    required this.image,
    required this.unit,
    required this.packSize,
    required this.slabs,
    required this.minOrderQty,
    required this.stepQty,
    required this.gstPercent,
    required this.availableQty,
    required this.uses,
    this.usageWarning,
    this.isReturnable = false,
    this.hsnCode = '',
    this.standardPrice,
  });

  final String id;
  final String name;
  final String categoryId;
  final String description;
  final String image;
  final String unit;
  final String packSize;

  /// Sorted by ascending [PriceSlab.minQty]; the first slab is the base price.
  final List<PriceSlab> slabs;
  final int minOrderQty;
  final int stepQty;
  final double gstPercent;
  final int availableQty;
  final List<String> uses;

  /// Shown wherever the product can be ordered, for example "industrial use only".
  final String? usageWarning;

  /// Ice boxes are returned to the company, so they are tracked on the dealer's account.
  final bool isReturnable;
  final String hsnCode;

  /// The list price before this dealer's pricing, when it differs from theirs.
  final double? standardPrice;

  bool get inStock => availableQty >= minOrderQty;
  double get basePrice => slabs.first.price;

  /// A copy with every slab multiplied by the rate the admin set for this dealer.
  Product withDealerRate(double rate) => rate == 1 || isReturnable
      ? this
      : Product(
          id: id,
          name: name,
          categoryId: categoryId,
          description: description,
          image: image,
          unit: unit,
          packSize: packSize,
          slabs: [for (final s in slabs) PriceSlab(s.minQty, (s.price * rate).roundToDouble())],
          minOrderQty: minOrderQty,
          stepQty: stepQty,
          gstPercent: gstPercent,
          availableQty: availableQty,
          uses: uses,
          usageWarning: usageWarning,
          isReturnable: isReturnable,
          hsnCode: hsnCode,
          standardPrice: basePrice,
        );

  double priceFor(int qty) {
    var price = basePrice;
    for (final slab in slabs) {
      if (qty >= slab.minQty) price = slab.price;
    }
    return price;
  }
}
