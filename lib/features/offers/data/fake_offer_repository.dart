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
        kind: OfferKind.scheme,
        code: '',
        title: 'Monthly volume scheme',
        description: 'Buy 500 bags in a month and get a 2% credit note on that month\'s purchases.',
        percent: 0,
        maxDiscount: 0,
        minOrder: 0,
        validTill: inAMonth,
      ),
    ];
  }
}
