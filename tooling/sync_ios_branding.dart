import 'dart:convert';
import 'dart:io';

String _s(dynamic v, [String fallback = '']) {
  final x = (v ?? '').toString().trim();
  return x.isEmpty ? fallback : x;
}

bool _b(dynamic v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  final x = _s(v).toLowerCase();
  if (['1', 'true', 'yes', 'sim', 'on'].contains(x)) return true;
  if (['0', 'false', 'no', 'nao', 'não', 'off'].contains(x)) return false;
  return fallback;
}

Map<String, dynamic> _m(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, v) => MapEntry(k.toString(), v));
  return <String, dynamic>{};
}

String _dart(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll("'", r"\'")
    .replaceAll(r'$', r'\$')
    .replaceAll('\r', r'\r')
    .replaceAll('\n', r'\n');

Future<void> _writeText(String path, String value) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(value, flush: true);
}

Future<void> _download(String url, String destination) async {
  if (url.trim().isEmpty) return;
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return;
  final client = HttpClient();
  try {
    final req = await client.getUrl(uri);
    final res = await req.close();
    if (res.statusCode < 200 || res.statusCode >= 300) return;
    final bytes = await consolidateHttpClientResponseBytes(res);
    final file = File(destination);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  } finally {
    client.close(force: true);
  }
}

Future<List<int>> consolidateHttpClientResponseBytes(HttpClientResponse response) async {
  final chunks = <List<int>>[];
  var length = 0;
  await for (final chunk in response) {
    chunks.add(chunk);
    length += chunk.length;
  }
  final out = List<int>.filled(length, 0);
  var offset = 0;
  for (final chunk in chunks) {
    out.setRange(offset, offset + chunk.length, chunk);
    offset += chunk.length;
  }
  return out;
}

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first.trim().isEmpty) {
    stderr.writeln('Uso: dart run tooling/sync_ios_branding.dart <API_BASE_URL>');
    exit(2);
  }

  final api = args.first.trim().replaceAll(RegExp(r'/+$'), '');
  final uri = Uri.parse('$api/bootstrap.php');
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 25);
  Map<String, dynamic> boot;
  try {
    final req = await client.getUrl(uri);
    req.headers.set('Accept', 'application/json');
    req.headers.set('X-Soft-Platform', 'IOS');
    req.headers.set('X-Soft-App-Version', '1.6.20');
    req.headers.set('X-Soft-Build', '178');
    final res = await req.close();
    final text = await utf8.decoder.bind(res).join();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('Bootstrap HTTP ${res.statusCode}: $text', uri: uri);
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw const FormatException('JSON do bootstrap invalido.');
    boot = decoded.map((k, v) => MapEntry(k.toString(), v));
  } finally {
    client.close(force: true);
  }

  if (!_b(boot['platform_allowed'])) {
    throw StateError('iOS nao esta liberado para este cliente/licenca no modulo Mobile. Habilite iOS no Admin > Mobile > iOS.');
  }

  final app = _m(boot['app']);
  final security = _m(boot['security']);
  final payments = _m(boot['payments']);
  final appName = _s(app['name'], 'Soft Ecommerce');
  final bundleId = _s(app['package_id']);
  if (bundleId.isEmpty) {
    throw StateError('Bundle ID iOS vazio. Configure em Admin > Mobile > iOS antes de compilar.');
  }

  final iconIos = _s(app['icon_ios_url'], _s(app['logo_url']));
  final buildAt = DateTime.now().toIso8601String();
  final cfg = <String, dynamic>{
    'schema': 4,
    'branding_synced': true,
    'source_api_base_url': api,
    'synced_at': buildAt,
    'app_name': appName,
    'api_base_url': api,
    'ios_bundle_id': bundleId,
    'theme_default': _s(app['theme_default'], 'SYSTEM').toUpperCase(),
    'primary_color': _s(app['primary_color'], '#1A73E8'),
    'secondary_color': _s(app['secondary_color'], '#202124'),
    'logo_url': _s(app['logo_url']),
    'splash_url': _s(app['splash_url']),
    'icon_ios_url': iconIos,
    'google_web_client_id': _s(security['google_web_client_id']),
    'apple_pay': <String, dynamic>{
      'enabled': _b(payments['apple_pay']),
    },
    'release': <String, dynamic>{
      'module_version': _s(boot['module_version']),
      'current_version': _s(app['current_version']),
      'current_build': _s(app['current_build']),
      'min_version': _s(app['min_version']),
      'force_update': _b(app['force_update']),
      'store_url': _s(app['store_url']),
    },
  };

  await _writeText('tooling/mobile_app_config_ios.json', const JsonEncoder.withIndent('  ').convert(cfg));
  final generated = '''// Gerado por tooling/sync_ios_branding.dart. Nao editar manualmente.\nclass GeneratedAppConfig {\n  static const int schema = 4;\n  static const String appName = '${_dart(appName)}';\n  static const String apiBaseUrl = '${_dart(api)}';\n  static const String androidPackageId = '';\n  static const String iosBundleId = '${_dart(bundleId)}';\n  static const String themeDefault = '${_dart(_s(app['theme_default'], 'SYSTEM').toUpperCase())}';\n  static const String primaryColor = '${_dart(_s(app['primary_color'], '#1A73E8'))}';\n  static const String secondaryColor = '${_dart(_s(app['secondary_color'], '#202124'))}';\n  static const String logoUrl = '${_dart(_s(app['logo_url']))}';\n  static const String splashUrl = '${_dart(_s(app['splash_url']))}';\n  static const String iconAndroidUrl = '';\n  static const String iconIosUrl = '${_dart(iconIos)}';\n  static const String googleWebClientId = '${_dart(_s(security['google_web_client_id']))}';\n  static const bool googlePayEnabled = false;\n  static const String googlePayEnvironment = 'TEST';\n  static const String googlePayMerchantId = '';\n  static const String googlePayMerchantName = '';\n  static const String releaseModuleVersion = '${_dart(_s(boot['module_version']))}';\n  static const String releaseCurrentVersion = '${_dart(_s(app['current_version']))}';\n  static const String releaseCurrentBuild = '${_dart(_s(app['current_build']))}';\n  static const String releaseMinVersion = '${_dart(_s(app['min_version']))}';\n  static const bool releaseForceUpdate = ${_b(app['force_update'])};\n  static const String releaseStoreUrl = '${_dart(_s(app['store_url']))}';\n  static const String buildGeneratedAt = '${_dart(buildAt)}';\n}\n''';
  await _writeText('lib/core/config/generated_app_config.dart', generated);

  final syncDir = Directory('tooling/.ios_sync');
  await syncDir.create(recursive: true);
  await _writeText('${syncDir.path}/app_name', appName);
  await _writeText('${syncDir.path}/bundle_id', bundleId);
  await _writeText('${syncDir.path}/api_url', api);
  await _writeText('${syncDir.path}/icon_url', iconIos);
  await _writeText('${syncDir.path}/build_at', buildAt);
  await _writeText('${syncDir.path}/current_version', _s(app['current_version']));
  await _writeText('${syncDir.path}/current_build', _s(app['current_build']));

  if (iconIos.isNotEmpty) {
    await _download(iconIos, '${syncDir.path}/icon_source');
  }

  stdout.writeln('Branding iOS sincronizado: $appName / $bundleId');
  stdout.writeln('API: $api');
  stdout.writeln('Versao configurada no servidor: ${_s(app['current_version'], '-')}+${_s(app['current_build'], '-')}');
}
