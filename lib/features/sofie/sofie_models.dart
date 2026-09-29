class SofieMessage {
  const SofieMessage({
    required this.id,
    required this.origin,
    required this.text,
    this.dateTime,
  });

  final int id;
  final String origin;
  final String text;
  final String? dateTime;

  bool get fromCustomer => origin == 'CLIENTE';
  bool get fromAssistant => origin == 'SOFIE' || origin == 'ATENDENTE';

  factory SofieMessage.fromJson(Map<String, dynamic> json) => SofieMessage(
        id: _i(json['id']),
        origin: _s(json['origem'] ?? json['origin']).toUpperCase(),
        text: _s(json['mensagem'] ?? json['message'] ?? json['text']),
        dateTime: _nullable(json['data_hora'] ?? json['date_time']),
      );
}

class SofiePendingAction {
  const SofiePendingAction({
    required this.id,
    required this.type,
    required this.valueText,
  });

  final int id;
  final String type;
  final String valueText;

  factory SofiePendingAction.fromJson(Map<String, dynamic> json) =>
      SofiePendingAction(
        id: _i(json['id']),
        type: _s(json['tipo'] ?? json['type']),
        valueText: _s(json['valor_formatado'] ?? json['value_text']),
      );
}

class SofieSuggestedProduct {
  const SofieSuggestedProduct({
    required this.id,
    required this.name,
    required this.price,
    this.priceText,
    this.imageUrl,
  });

  final String id;
  final String name;
  final double price;
  final String? priceText;
  final String? imageUrl;

  factory SofieSuggestedProduct.fromJson(Map<String, dynamic> json) =>
      SofieSuggestedProduct(
        id: _s(json['product_id'] ?? json['id']),
        name: _s(json['name'], fallback: 'Produto'),
        price: _d(json['price']),
        priceText: _nullable(json['price_text']),
        imageUrl: _nullable(json['image_url']),
      );
}

class SofieSession {
  const SofieSession({
    required this.enabled,
    required this.status,
    required this.messages,
    required this.pendingActions,
  });

  final bool enabled;
  final String status;
  final List<SofieMessage> messages;
  final List<SofiePendingAction> pendingActions;

  factory SofieSession.fromJson(Map<String, dynamic> json) => SofieSession(
        enabled: _b(json['enabled'], true),
        status: _s(json['status'], fallback: 'ABERTA'),
        messages: _list(json['messages'] ?? json['mensagens'])
            .map(SofieMessage.fromJson)
            .where((m) => m.text.isNotEmpty)
            .toList(),
        pendingActions: _list(json['pending_actions'] ?? json['acoes_pendentes'])
            .map(SofiePendingAction.fromJson)
            .where((a) => a.id > 0)
            .toList(),
      );
}

class SofieReply {
  const SofieReply({
    required this.response,
    required this.lastId,
    required this.status,
    required this.pendingActions,
    required this.suggestedProducts,
    required this.messages,
  });

  final String response;
  final int lastId;
  final String status;
  final List<SofiePendingAction> pendingActions;
  final List<SofieSuggestedProduct> suggestedProducts;
  final List<SofieMessage> messages;

  factory SofieReply.fromJson(Map<String, dynamic> json) => SofieReply(
        response: _s(json['response'] ?? json['resposta']),
        lastId: _i(json['last_id']),
        status: _s(json['status'], fallback: 'ABERTA'),
        pendingActions: _list(json['pending_actions'] ?? json['acoes_pendentes'])
            .map(SofiePendingAction.fromJson)
            .where((a) => a.id > 0)
            .toList(),
        suggestedProducts: _list(json['suggested_products'] ?? json['produtos_sugeridos'])
            .map(SofieSuggestedProduct.fromJson)
            .toList(),
        messages: _list(json['messages'] ?? json['mensagens'])
            .map(SofieMessage.fromJson)
            .where((m) => m.text.isNotEmpty)
            .toList(),
      );
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _list(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value.map(_map).where((e) => e.isNotEmpty).toList();
}

String _s(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullable(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int _i(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _d(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

bool _b(dynamic value, bool fallback) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value.toString().trim().toLowerCase();
  return text == '1' || text == 'true' || text == 'sim' || text == 'yes';
}
