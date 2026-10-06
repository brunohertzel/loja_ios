import 'generated_app_config.dart';
import 'platform_info.dart';

class AppEnvironment {
  static String get platform => PlatformInfo.apiPlatform;

  // Mantem compatibilidade com o fluxo de build usado pela Soft:
  // --dart-define=SOFT_API_BASE_URL=...
  // O valor sincronizado do cliente continua sendo o fallback autoritativo.
  static const String _apiFromBuild = String.fromEnvironment(
    'SOFT_API_BASE_URL',
    defaultValue: '',
  );

  static String get apiBaseUrl => _apiFromBuild.trim().isNotEmpty
      ? _apiFromBuild.trim()
      : GeneratedAppConfig.apiBaseUrl;

  static String get normalizedApiBaseUrl =>
      apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  static bool get isConfigured => normalizedApiBaseUrl.isNotEmpty;
}
