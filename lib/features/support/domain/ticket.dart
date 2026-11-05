enum TicketStatus { open, resolved }

class TicketMessage {
  const TicketMessage({required this.text, required this.fromDealer, required this.at});

  final String text;
  final bool fromDealer;
  final DateTime at;

  Map<String, dynamic> toJson() => {'text': text, 'fromDealer': fromDealer, 'at': at.toIso8601String()};

  factory TicketMessage.fromJson(Map<String, dynamic> j) => TicketMessage(
    text: j['text'] as String,
    fromDealer: j['fromDealer'] as bool,
    at: DateTime.parse(j['at'] as String),
  );
}

class Ticket {
  const Ticket({
    required this.id,
    required this.subject,
    required this.category,
    required this.messages,
    this.status = TicketStatus.open,
    this.orderNumber,
  });

  final String id;
  final String subject;
  final String category;
  final List<TicketMessage> messages;
  final TicketStatus status;
  final String? orderNumber;

  DateTime get createdAt => messages.first.at;

  Ticket copyWith({List<TicketMessage>? messages, TicketStatus? status}) => Ticket(
    id: id,
    subject: subject,
    category: category,
    messages: messages ?? this.messages,
    status: status ?? this.status,
    orderNumber: orderNumber,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'category': category,
    'messages': messages.map((m) => m.toJson()).toList(),
    'status': status.name,
    'orderNumber': orderNumber,
  };

  factory Ticket.fromJson(Map<String, dynamic> j) => Ticket(
    id: j['id'] as String,
    subject: j['subject'] as String,
    category: j['category'] as String,
    messages: (j['messages'] as List).map((m) => TicketMessage.fromJson(m as Map<String, dynamic>)).toList(),
    status: TicketStatus.values.byName(j['status'] as String),
    orderNumber: j['orderNumber'] as String?,
  );
}

abstract interface class SupportRepository {
  Future<List<Ticket>> tickets();

  Future<Ticket> create({
    required String subject,
    required String category,
    required String message,
    String? orderNumber,
  });

  Future<void> reply(String ticketId, String message);

  Future<void> resolve(String ticketId);
}
