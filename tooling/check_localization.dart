import '../lib/core/localization/message_catalog.dart';
void check(bool value, String message) { if (!value) throw StateError(message); }
void main() {
  final placeholders = RegExp(r'\{(\d+)\}');
  for (final entry in MessageCatalog.messages.entries) {
    check(entry.value.length == 2, 'Missing language: ${entry.key}');
    final example = entry.key.replaceAllMapped(placeholders, (m) => '⟦${m[1]}⟧');
    for (final language in ['en','es']) {
      final expected = entry.value[language == 'en' ? 0 : 1].replaceAllMapped(placeholders, (m) => '⟦${m[1]}⟧');
      check(MessageCatalog.translate(example, language) == expected, '$language: ${entry.key}');
    }
    check(MessageCatalog.translate(example, 'pt') == example, 'Portuguese changed');
  }
  check(MessageCatalog.translate('Código: 123', 'en') == 'Code: 123', 'Template rendering');
  check(MessageCatalog.translate('Pedido #42', 'es') == 'Pedido #42', 'Order ID preservation');
  check(MessageCatalog.translate('Digite o código do cupom.', 'es') == 'Introduce el código del cupón.', 'Checkout');
  check(MessageCatalog.translate('Produto não localizado.', 'en') == 'Product not found.', 'API fallback');
  check(MessageCatalog.translate('Falar com Favoritos', 'en') == 'Talk to Favoritos', 'Opaque company name');
  check(MessageCatalog.translate('Filé de costela 500 g', 'en') == 'Filé de costela 500 g', 'Catalog stays verbatim');
  check(MessageCatalog.translate('https://loja.test/pedido?id=42', 'es') == 'https://loja.test/pedido?id=42', 'URL preservation');
  check(MessageCatalog.translate('Preço: menor → maior','xx') == 'Preço: menor → maior', 'Unknown locale');
  print('PASS: ${MessageCatalog.messages.length} messages, PT/EN/ES, placeholders, IDs and opaque server content.');
}
