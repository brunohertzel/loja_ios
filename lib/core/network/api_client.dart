import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_environment.dart';
import '../config/platform_info.dart';
import '../device/device_service.dart';
import '../storage/secure_session_store.dart';

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.payload,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, dynamic>? payload;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    required this.store,
    required this.device,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final SecureSessionStore store;
  final DeviceService device;
  final http.Client _http;

  String get baseUrl => AppEnvironment.normalizedApiBaseUrl;

  void ensureConfigured() {
    if (!AppEnvironment.isConfigured) {
      throw const ApiException(
        'API Mobile nao configurada. Configure tooling/mobile_app_config.json e execute tooling/apply_local_config.ps1.',
        code: 'API_NOT_CONFIGURED',
      );
    }
  }

  Future<Map<String, dynamic>> bootstrap() =>
      get('/bootstrap.php', authenticated: false);

  Future<Map<String, dynamic>> health() =>
      get('/health.php', authenticated: false);

  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = true,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    ensureConfigured();
    final token = authenticated ? await store.accessToken : null;
    try {
      final response = await _http
          .get(
            Uri.parse('$baseUrl$path'),
            headers: _headers(token: token),
          )
          .timeout(timeout);
      return _decode(response);
    } on TimeoutException {
      throw const ApiException(
        'Tempo esgotado ao comunicar com a API Mobile.',
        code: 'NETWORK_TIMEOUT',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        'Falha de conexao com a API Mobile: $e',
        code: 'NETWORK_ERROR',
      );
    }
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = true,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    ensureConfigured();
    final token = authenticated ? await store.accessToken : null;
    final payload = <String, dynamic>{...body};
    // Nao depender exclusivamente de Authorization/X-Soft-* no Apache/XAMPP.
    // O backend Mobile aceita estes metadados no JSON como fallback seguro.
    payload.putIfAbsent('platform', () => AppEnvironment.platform);
    payload.putIfAbsent('app_version', () => device.appVersion);
    payload.putIfAbsent('app_build', () => device.appBuild);
    if (authenticated && token != null && token.isNotEmpty) {
      payload['_access_token'] = token;
    }
    try {
      final response = await _http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: _headers(token: token),
            body: jsonEncode(payload),
          )
          .timeout(timeout);
      return _decode(response);
    } on TimeoutException {
      throw const ApiException(
        'Tempo esgotado ao comunicar com a API Mobile.',
        code: 'NETWORK_TIMEOUT',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        'Falha de conexao com a API Mobile: $e',
        code: 'NETWORK_ERROR',
      );
    }
  }

  String? resolvePublicUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = Uri.tryParse(text);
    if (parsed != null && parsed.hasScheme) return parsed.toString();
    if (!AppEnvironment.isConfigured) return null;

    final base = Uri.parse(baseUrl);
    if (text.startsWith('/')) {
      return base.replace(path: text, query: null, fragment: null).toString();
    }
    return base
        .replace(path: '/$text', query: null, fragment: null)
        .toString();
  }

  Map<String, String> _headers({String? token}) => <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Soft-Platform': AppEnvironment.platform,
        'X-Soft-App-Version': device.appVersion,
        'X-Soft-App-Build': device.appBuild,
        'X-Soft-Device-Id': device.deviceId,
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        // Fallback proprio da API Mobile. Alguns Apache/XAMPP/CGI removem
        // Authorization antes de chegar ao PHP; o servidor aceita este
        // header somente para o token da sessao Mobile.
        if (token != null && token.isNotEmpty) 'X-Soft-Access-Token': token,
      };

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic>? payload;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) {
        payload = decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      payload = null;
    }

    final result = payload ?? <String, dynamic>{};
    final failed = response.statusCode < 200 ||
        response.statusCode >= 300 ||
        result['ok'] == false;

    if (failed) {
      final code = result['error']?.toString();
      final serverMessage = result['message']?.toString().trim() ?? '';
      throw ApiException(
        serverMessage.isNotEmpty ? serverMessage : _friendlyMessage(code, response.statusCode),
        statusCode: response.statusCode,
        code: code,
        payload: result,
      );
    }

    if (payload == null) {
      throw ApiException(
        'A API respondeu HTTP ${response.statusCode}, mas o conteudo nao e JSON valido.',
        statusCode: response.statusCode,
        code: 'INVALID_JSON_RESPONSE',
      );
    }

    return result;
  }

  String _friendlyMessage(String? code, int status) {
    switch (code) {
      case 'INVALID_PASSWORD':
        return 'Senha incorreta.';
      case 'CUSTOMER_NOT_FOUND':
        return 'Cadastro nao localizado.';
      case 'CUSTOMER_BLOCKED':
        return 'Conta bloqueada. Contate o atendimento.';
      case 'CUSTOMER_INACTIVE':
        return 'Conta inativa.';
      case 'PLATFORM_NOT_LICENSED':
        return '${PlatformInfo.label} nao esta incluido na licenca do modulo Mobile.';
      case 'PLATFORM_DISABLED':
        return '${PlatformInfo.label} esta desabilitado no configurador do modulo Mobile.';
      case 'MOBILE_DISABLED':
        return 'O modulo Mobile esta desabilitado nesta loja.';
      case 'REFRESH_TOKEN_INVALID_OR_EXPIRED':
        return 'Sua sessao expirou. Entre novamente.';
      case 'ACCESS_TOKEN_INVALID_OR_EXPIRED':
      case 'AUTH_REQUIRED':
        return 'Sessao expirada.';
      case 'BIOMETRICS_DISABLED_BY_ADMIN':
        return 'A biometria foi desabilitada pelo administrador da loja.';
      case 'INVALID_INPUT':
        return 'Confira os dados informados.';
      case 'NO_SELECTED_ITEMS':
        return 'Selecione pelo menos um item do carrinho.';
      case 'REQUIRED_OPTION_MISSING':
        return 'Há uma opção obrigatória do produto sem preenchimento.';
      case 'OPTION_NUMBER_BELOW_MIN':
      case 'OPTION_NUMBER_ABOVE_MAX':
        return 'Confira os limites informados nas opções do produto.';
      case 'PRODUCT_NOT_FOUND':
        return 'Um produto selecionado não está mais disponível.';
      case 'CHECKOUT_PREPARE_FAILED':
        return 'Não foi possível preparar o checkout agora.';
      case 'FREIGHT_CALC_FAILED':
        return 'Não foi possível recalcular o frete agora.';
      case 'DOCUMENT_ALREADY_REGISTERED':
        return 'Este CPF já está cadastrado.';
      case 'EMAIL_ALREADY_REGISTERED':
        return 'Este e-mail já está cadastrado.';
      case 'REGISTRATION_DISABLED':
        return 'Novos cadastros pelo aplicativo estão desabilitados.';
      case 'GOOGLE_LOGIN_DISABLED':
        return 'Login com Google está desabilitado nesta loja.';
      case 'GOOGLE_NOT_CONFIGURED':
        return 'Login com Google ainda não foi configurado no módulo Mobile.';
      case 'GOOGLE_REGISTRATION_REQUIRED':
        return 'Complete seu cadastro para continuar com o Google.';
      case 'INVALID_GOOGLE_TOKEN':
        return 'Não foi possível validar sua conta Google.';
      case 'INVALID_DOCUMENT':
        return 'Informe um CPF válido com 11 dígitos.';
      case 'COUPON_INVALID':
        return 'Cupom inválido para este pedido.';
      default:
        return code?.isNotEmpty == true
            ? 'Erro da API: $code'
            : 'Erro HTTP $status ao comunicar com a API Mobile.';
    }
  }
}
