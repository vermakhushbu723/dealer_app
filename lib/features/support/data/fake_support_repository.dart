import '../../../core/storage/local_store.dart';
import '../domain/ticket.dart';

class FakeSupportRepository implements SupportRepository {
  FakeSupportRepository(this._store);

  final LocalStore _store;

  static const _key = 'tickets';

  List<Ticket> _read() => (_store.readList(_key) ?? const []).map(Ticket.fromJson).toList();

  Future<void> _write(List<Ticket> items) => _store.writeList(_key, items.map((t) => t.toJson()).toList());

  Future<void> _update(String id, Ticket Function(Ticket) change) =>
      _write([for (final t in _read()) t.id == id ? change(t) : t]);

  @override
  Future<List<Ticket>> tickets() async {
    await fakeLatency();
    return _read()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<Ticket> create({
    required String subject,
    required String category,
    required String message,
    String? orderNumber,
  }) async {
    await fakeLatency();
    final now = DateTime.now();
    final ticket = Ticket(
      id: 't-${now.millisecondsSinceEpoch}',
      subject: subject,
      category: category,
      orderNumber: orderNumber,
      messages: [
        TicketMessage(text: message, fromDealer: true, at: now),
        // Stands in for the support team until the admin panel exists.
        TicketMessage(
          text: 'Thanks, we have received your request and will get back to you soon.',
          fromDealer: false,
          at: now,
        ),
      ],
    );
    await _write([..._read(), ticket]);
    return ticket;
  }

  @override
  Future<void> reply(String ticketId, String message) => _update(
    ticketId,
    (t) => t.copyWith(
      messages: [
        ...t.messages,
        TicketMessage(text: message, fromDealer: true, at: DateTime.now()),
      ],
    ),
  );

  @override
  Future<void> resolve(String ticketId) => _update(ticketId, (t) => t.copyWith(status: TicketStatus.resolved));
}
