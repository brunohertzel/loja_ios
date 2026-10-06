import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soft_ecommerce_mobile/core/device/device_service.dart';
import 'package:soft_ecommerce_mobile/core/models/bootstrap_config.dart';
import 'package:soft_ecommerce_mobile/core/network/api_client.dart';
import 'package:soft_ecommerce_mobile/core/storage/secure_session_store.dart';
import 'package:soft_ecommerce_mobile/features/auth/auth_repository.dart';
import 'package:soft_ecommerce_mobile/features/auth/biometric_service.dart';
import 'package:soft_ecommerce_mobile/features/store/store_shell.dart';

class MemoryStore extends SecureSessionStore {
  String? access = 'valid-access';
  String? refreshValue = 'rotating-refresh';
  int clears = 0;
  @override
  Future<String?> get accessToken async => access;
  @override
  Future<String?> get refreshToken async => refreshValue;
  @override
  Future<String?> get customerName async => 'Cliente';
  @override
  Future<bool> get biometricEnabled async => false;
  @override
  Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    access = accessToken;
    refreshValue = refreshToken;
  }

  @override
  Future<void> clearSession() async {
    clears++;
    access = null;
    refreshValue = null;
  }
}

void main() {
  test(
    'simultaneous refreshes use one rotating refresh token request',
    () async {
      final store = MemoryStore();
      final gate = Completer<void>();
      var calls = 0;
      final device = DeviceService(store);
      final api = ApiClient(
        store: store,
        device: device,
        httpClient: MockClient((request) async {
          calls++;
          await gate.future;
          return http.Response(
            jsonEncode({
              'ok': true,
              'access_token': 'new-access',
              'refresh_token': 'new-refresh',
            }),
            200,
          );
        }),
      );
      final auth = AuthRepository(api: api, store: store, device: device);
      final pending = List.generate(8, (_) => auth.refresh());
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      gate.complete();
      expect(await Future.wait(pending), everyElement(isTrue));
      expect(store.refreshValue, 'new-refresh');
      expect(store.clears, 0);
    },
  );

  test(
    'network failure releases refresh guard and retains session for retry',
    () async {
      final store = MemoryStore();
      final device = DeviceService(store);
      var calls = 0;
      final api = ApiClient(
        store: store,
        device: device,
        httpClient: MockClient((request) async {
          if (++calls == 1) throw Exception('Failed host lookup');
          return http.Response(
            '{"ok":true,"access_token":"new","refresh_token":"new-refresh"}',
            200,
          );
        }),
      );
      final auth = AuthRepository(api: api, store: store, device: device);
      await expectLater(auth.refresh(), throwsA(isA<ApiException>()));
      expect(store.clears, 0);
      expect(await auth.refresh(), isTrue);
      expect(calls, 2);
    },
  );

  test('HTML with HTTP 200 is reported as invalid JSON', () async {
    final store = MemoryStore();
    final device = DeviceService(store);
    final api = ApiClient(
      store: store,
      device: device,
      httpClient: MockClient(
        (_) async => http.Response('<html>gateway</html>', 200),
      ),
    );
    await expectLater(
      api.health(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          'INVALID_JSON_RESPONSE',
        ),
      ),
    );
  });

  testWidgets(
    'only Home loads at startup; account exits loading after network failure',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = MemoryStore();
      final device = DeviceService(store);
      final paths = <String>[];
      final api = ApiClient(
        store: store,
        device: device,
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path.endsWith('/auth/me.php'))
            throw Exception('Failed host lookup');
          return http.Response(
            '{"ok":true,"data":{"products":[],"banners":[],"categories":[]}}',
            200,
          );
        }),
      );
      final auth = AuthRepository(api: api, store: store, device: device);
      await tester.pumpWidget(
        MaterialApp(
          home: StoreShell(
            api: api,
            auth: auth,
            store: store,
            biometrics: BiometricService(),
            bootstrap: AppBootstrap.fromJson({'platform_allowed': true}),
            onLoggedOut: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(paths.where((path) => path.endsWith('/store/home.php')).length, 1);
      expect(
        paths.any((path) => path.endsWith('/store/categories.php')),
        isFalse,
      );
      expect(
        paths.any((path) => path.endsWith('/store/products.php')),
        isFalse,
      );
      expect(paths.any((path) => path.endsWith('/auth/me.php')), isFalse);
      await tester.tap(find.text('Conta'));
      await tester.pumpAndSettle();
      expect(find.text('Meus pedidos'), findsOneWidget);
      expect(store.clears, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
