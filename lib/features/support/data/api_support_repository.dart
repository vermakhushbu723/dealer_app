import '../../../core/network/api_client.dart';
import '../domain/ticket.dart';

class ApiSupportRepository implements SupportRepository {
  ApiSupportRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Ticket>> tickets() async => (await _api.get('/dealer/tickets') as Object).mapped(Ticket.fromJson);

  @override
  Future<Ticket> create({required String subject, required String category, required String message, String? orderNumber}) async {
    final body = await _api.post('/dealer/tickets', {'subject': subject, 'category': category, 'message': message, 'orderNumber': orderNumber});
    return Ticket.fromJson(body as Map<String, dynamic>);
  }

  @override
  Future<void> reply(String ticketId, String message) => _api.post('/dealer/tickets/$ticketId/reply', {'message': message});

  @override
  Future<void> resolve(String ticketId) => _api.post('/dealer/tickets/$ticketId/resolve');
}
