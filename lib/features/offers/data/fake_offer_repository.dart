import '../domain/offer.dart';

/// Sample offers. In production these are set in the Admin Panel.
class FakeOfferRepository implements OfferRepository {
  FakeOfferRepository({required this.tier});

  final String tier;

  @override
  Future<List<Offer>> offers() async {
    final inAMonth = DateTime.now().add(const Duration(days: 30));
    return [
      Offer(
        kind: OfferKind.current,
        code: 'BULK10',
        title: '10% off bulk orders',
        description: 'On orders of ₹10,000 or more. Maximum discount ₹2,000.',
        percent: 10,
        maxDiscount: 2000,
        minOrder: 10000,
        validTill: inAMonth,
      ),
      Offer(
        kind: OfferKind.current,
        code: 'ICE5',
        title: '5% off your order',
        description: 'On orders of ₹2,000 or more. Maximum discount ₹500.',
        percent: 5,
        maxDiscount: 500,
        minOrder: 2000,
        validTill: inAMonth,
      ),
      Offer(
        kind: OfferKind.scheme,
        code: '',
        title: 'Monthly volume scheme',
        description: 'Buy 500 bags in a month and get a 2% credit note on that month\'s purchases.',
        percent: 0,
        maxDiscount: 0,
        minOrder: 0,
        validTill: inAMonth,
      ),
      Offer(
        kind: OfferKind.specialDiscount,
        code: '${tier.toUpperCase()}3',
        title: 'Special discount for $tier dealers',
        description: '3% off on orders of ₹5,000 or more. Maximum discount ₹1,000.',
        percent: 3,
        maxDiscount: 1000,
        minOrder: 5000,
        validTill: inAMonth,
      ),
    ];
  }
}
