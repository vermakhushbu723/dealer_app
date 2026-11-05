import '../../../core/network/api_client.dart';
import '../domain/offer.dart';

class ApiOfferRepository implements OfferRepository {
  ApiOfferRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Offer>> offers() async => (await _api.get('/dealer/offers') as Object).mapped(
    (j) => Offer(
      kind: OfferKind.values.byName(j['kind'] as String),
      code: j['code'] as String,
      title: j['title'] as String,
      description: j['description'] as String,
      percent: (j['percent'] as num).toDouble(),
      maxDiscount: (j['maxDiscount'] as num).toDouble(),
      minOrder: (j['minOrder'] as num).toDouble(),
      validTill: DateTime.parse(j['validTill'] as String),
    ),
  );
}
