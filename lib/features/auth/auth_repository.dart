import '../../core/device/device_service.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_session_store.dart';

class AuthRepository {
  AuthRepository({
    required this.api,
    required this.store,
    required this.device,
  });

  final ApiClient api;
  final SecureSessionStore store;
  final DeviceService device;

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
    required bool rememberMe,
  }) async {
    final json = await api.post('/auth/login.php', <String, dynamic>{
      'identifier': identifier,
      'password': password,
      'remember_me': rememberMe,
      'device_id': device.deviceId,
      'app_version': device.appVersion,
      'app_build': device.appBuild,
    }, authenticated: false);

    await _saveAuthResponse(json, rememberMe: rememberMe);
    await store.setRememberedIdentifier(rememberMe ? identifier : null);
    return json;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String document,
    required String email,
    required String phone,
    required String password,
    required bool rememberMe,
    required Map<String, String> address,
  }) async {
    final json = await api.post('/auth/register.php', <String, dynamic>{
      'name': name,
      'document': document,
      'email': email,
      'phone': phone,
      'password': password,
      'remember_me': rememberMe,
      'device_id': device.deviceId,
      'address': address,
      'accept_terms': true,
    }, authenticated: false);
    await _saveAuthResponse(json, rememberMe: rememberMe);
    await store.setRememberedIdentifier(rememberMe ? email : null);
    return json;
  }

  Future<Map<String, dynamic>> googleLogin({
    required String idToken,
    required bool rememberMe,
    Map<String, String>? registration,
  }) async {
    final json = await api.post('/auth/google.php', <String, dynamic>{
      'id_token': idToken,
      'remember_me': rememberMe,
      'device_id': device.deviceId,
      if (registration != null) 'registration': registration,
      if (registration != null) 'accept_terms': true,
    }, authenticated: false);
    await _saveAuthResponse(json, rememberMe: rememberMe);
    return json;
  }

  Future<void> _saveAuthResponse(
    Map<String, dynamic> json, {
    required bool rememberMe,
  }) async {
    final customer = _map(json['customer']);
    await store.saveSession(
      accessToken: json['access_token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString() ?? '',
      rememberMe: rememberMe,
      customerName: customer['name']?.toString(),
    );
  }

  Future<bool>? _refreshInFlight;

  Future<bool> refresh() {
    final running = _refreshInFlight;
    if (running != null) return running;
    final future = _refreshTokens().whenComplete(() => _refreshInFlight = null);
    _refreshInFlight = future;
    return future;
  }

  Future<bool> _refreshTokens() async {
    final refreshToken = (await store.refreshToken)?.trim() ?? '';
    if (refreshToken.isEmpty) return false;

    try {
      final json = await api.post('/auth/refresh.php', <String, dynamic>{
        'refresh_token': refreshToken,
        'device_id': device.deviceId,
        'app_version': device.appVersion,
        'app_build': device.appBuild,
      }, authenticated: false);
      await store.updateTokens(
        accessToken: json['access_token']?.toString() ?? '',
        refreshToken: json['refresh_token']?.toString() ?? '',
      );
      if (json.containsKey('biometric_enabled')) {
        await store.setBiometricEnabled(json['biometric_enabled'] == true);
      }
      return true;
    } on ApiException catch (e) {
      // So tratamos como sessao encerrada quando o servidor confirma 401.
      // Falha de rede/HTTP 5xx nao pode apagar uma sessao valida nem abrir
      // a tela de login por engano.
      if (e.isUnauthorized) return false;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> me() =>
      _withRefresh(() => api.post('/auth/me.php', const <String, dynamic>{}));

  /// Confirma a sessao no servidor antes de uma acao protegida.
  ///
  /// A API atual recebe o access token tambem no JSON, entao nao dependemos
  /// mais apenas do header Authorization no Apache/XAMPP. Isso permite
  /// validar silenciosamente a sessao e renovar o token expirado ANTES de
  /// abrir o checkout, sem mandar um cliente ja logado para a tela de login.
  Future<bool> ensureAuthenticated() async {
    final access = (await store.accessToken)?.trim() ?? '';
    final refreshToken = (await store.refreshToken)?.trim() ?? '';
    if (access.isEmpty && refreshToken.isEmpty) return false;

    if (access.isEmpty) {
      return refresh();
    }

    try {
      await me();
      return true;
    } on ApiException catch (e) {
      // me() ja tenta refresh automaticamente em um 401. Se ainda chegou
      // 401 aqui, o refresh foi recusado e a sessao realmente acabou.
      if (e.isUnauthorized) return false;
      rethrow;
    }
  }

  Future<void> setBiometric(bool enabled) async {
    await _withRefresh(
      () => api.post('/security/biometric.php', <String, dynamic>{
        'enabled': enabled,
      }),
    );
    await store.setBiometricEnabled(enabled);
    await event(enabled ? 'biometric_enabled' : 'biometric_disabled');
  }

  Future<void> event(
    String event, [
    Map<String, dynamic> payload = const <String, dynamic>{},
  ]) async {
    try {
      final token = await store.accessToken;
      await api.post('/metrics/event.php', <String, dynamic>{
        'event': event,
        'payload': payload,
      }, authenticated: token != null && token.isNotEmpty);
    } catch (_) {
      // Telemetria nunca deve bloquear a experiencia do cliente.
    }
  }

  Future<void> logout() async {
    final refreshToken = await store.refreshToken;
    try {
      await api.post('/auth/logout.php', <String, dynamic>{
        'refresh_token': refreshToken,
      });
    } catch (_) {
      try {
        await api.post('/auth/logout.php', <String, dynamic>{
          'refresh_token': refreshToken,
        }, authenticated: false);
      } catch (_) {}
    }
    await store.clearSession();
  }

  Future<T> _withRefresh<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException catch (e) {
      if (!e.isUnauthorized) rethrow;
      final refreshed = await refresh();
      if (!refreshed) {
        await store.clearSession();
        rethrow;
      }
      return action();
    }
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return <String, dynamic>{};
  }
}
