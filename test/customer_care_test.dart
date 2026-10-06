import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_ecommerce_mobile/core/device/device_service.dart';
import 'package:soft_ecommerce_mobile/core/network/api_client.dart';
import 'package:soft_ecommerce_mobile/core/storage/secure_session_store.dart';
import 'package:soft_ecommerce_mobile/features/store/customer_care_pages.dart';
import 'package:soft_ecommerce_mobile/features/store/store_repository.dart';

class CareFakeApi extends ApiClient {
  CareFakeApi(this.responses)
      : super(
            store: SecureSessionStore(),
            device: DeviceService(SecureSessionStore()));
  final Map<String, Map<String, dynamic>> responses;
  final posts = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> get(String path,
          {bool authenticated = true,
          Duration timeout = const Duration(seconds: 25)}) async =>
      responses[path]!;
  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body,
      {bool authenticated = true,
      Duration timeout = const Duration(seconds: 25)}) async {
    posts.add({'path': path, ...body});
    return responses['POST:$path']!;
  }
}

void main() {
  testWidgets('aceite exige ação explícita e envia a versão exibida',
      (tester) async {
    final api = CareFakeApi({
      '/account/legal.php': {
        'documents': [
          {
            'type': 'TERMOS_USO',
            'version': '2.0',
            'hash': 'current-hash',
            'title': 'Termos de uso',
            'html': '<p>Documento atual da loja.</p>',
            'required': true,
            'accepted': false
          }
        ],
        'needs_acceptance': true
      },
      'POST:/account/legal.php': {'needs_acceptance': false},
    });
    var accepted = false;
    await tester.pumpWidget(MaterialApp(
        home: LegalDocumentsPage(
            repository: StoreRepository(api),
            requireAcceptance: true,
            onAccepted: () => accepted = true)));
    await tester.pumpAndSettle();
    expect(find.text('Documento atual da loja.'), findsOneWidget);
    final button = find.widgetWithText(FilledButton, 'Confirmar e continuar');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(api.posts, isEmpty);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(accepted, isTrue);
    expect(api.posts.single['documents'], [
      {'type': 'TERMOS_USO', 'version': '2.0', 'hash': 'current-hash'}
    ]);
  });

  testWidgets('formulário registra SAC antes de oferecer WhatsApp da empresa',
      (tester) async {
    final api = CareFakeApi({
      '/orders/issue.php?id=22': {
        'available': true,
        'can_create': true,
        'types': [
          {'id': 'RECLAMACAO', 'label': 'Reclamação / Disputa'}
        ],
        'requests': [],
        'store_contact': {}
      },
      'POST:/orders/issue.php': {
        'request_id': 15,
        'available': true,
        'can_create': false,
        'requests': [],
        'store_contact': {
          'name': 'Loja cliente',
          'whatsapp_url': 'https://wa.me/5541888888888'
        }
      },
    });
    await tester.pumpWidget(MaterialApp(
        home: OrderIssuePage(repository: StoreRepository(api), orderId: 22)));
    await tester.pumpAndSettle();
    expect(find.text('Falar no WhatsApp'), findsNothing);
    await tester.tap(find.text('Motivo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Produto faltando').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField), 'Faltou um produto na entrega.');
    await tester.ensureVisible(find.text('Enviar solicitação'));
    await tester.tap(find.text('Enviar solicitação'));
    await tester.pumpAndSettle();
    expect(api.posts.single['order_id'], 22);
    expect(api.posts.single['reason'], 'Produto faltando');
    expect(api.posts.single['description'], 'Faltou um produto na entrega.');
    expect(find.text('Solicitação #15 registrada'), findsOneWidget);
    expect(find.text('Falar no WhatsApp'), findsOneWidget);
  });
}
