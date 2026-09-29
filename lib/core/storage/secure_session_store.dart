import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureSessionStore {
  static const _access = 'soft_access_token';
  static const _refresh = 'soft_refresh_token';
  static const _remember = 'soft_remember_me';
  static const _biometric = 'soft_biometric_enabled';
  static const _customerName = 'soft_customer_name';
  static const _loginIdentifier = 'soft_login_identifier';
  static const _deviceId = 'soft_device_id';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> get accessToken => _storage.read(key: _access);
  Future<String?> get refreshToken => _storage.read(key: _refresh);
  Future<String?> get customerName => _storage.read(key: _customerName);
  Future<String?> get rememberedIdentifier => _storage.read(key: _loginIdentifier);
  Future<String?> get deviceId => _storage.read(key: _deviceId);

  Future<bool> get rememberMe async =>
      (await _storage.read(key: _remember)) == '1';

  Future<bool> get biometricEnabled async =>
      (await _storage.read(key: _biometric)) == '1';

  Future<void> setDeviceId(String value) =>
      _storage.write(key: _deviceId, value: value);

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required bool rememberMe,
    String? customerName,
  }) async {
    await _storage.write(key: _access, value: accessToken);
    await _storage.write(key: _refresh, value: refreshToken);
    await _storage.write(key: _remember, value: rememberMe ? '1' : '0');
    if (customerName != null && customerName.trim().isNotEmpty) {
      await _storage.write(key: _customerName, value: customerName.trim());
    }
  }

  Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _access, value: accessToken);
    await _storage.write(key: _refresh, value: refreshToken);
  }

  Future<void> setBiometricEnabled(bool enabled) =>
      _storage.write(key: _biometric, value: enabled ? '1' : '0');

  Future<void> setRememberedIdentifier(String? value) async {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      await _storage.delete(key: _loginIdentifier);
    } else {
      await _storage.write(key: _loginIdentifier, value: normalized);
    }
  }

  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _access),
      _storage.delete(key: _refresh),
      _storage.delete(key: _remember),
      _storage.delete(key: _biometric),
      _storage.delete(key: _customerName),
    ]);
  }
}
