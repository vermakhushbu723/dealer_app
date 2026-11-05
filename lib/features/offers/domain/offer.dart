enum OfferKind { current, scheme, specialDiscount }

class Offer {
  const Offer({
    required this.kind,
    required this.code,
    required this.title,
    required this.description,
    required this.percent,
    required this.maxDiscount,
    required this.minOrder,
    required this.validTill,
  });

  final OfferKind kind;

  /// Empty for schemes, which are settled by the accounts team, not at checkout.
  final String code;
  final String title;
  final String description;
  final double percent;
  final double maxDiscount;
  final double minOrder;
  final DateTime validTill;

  /// The discount on [subtotal], or 0 when the order is below [minOrder].
  double discountOn(double subtotal) {
    if (subtotal < minOrder) return 0;
    final discount = subtotal * percent / 100;
    return discount > maxDiscount ? maxDiscount : discount;
  }
}

abstract interface class OfferRepository {
  Future<List<Offer>> offers();
}
