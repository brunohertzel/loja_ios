class AppBootstrap {
  const AppBootstrap({
    required this.moduleVersion,
    required this.platform,
    required this.platformAllowed,
    required this.androidLicensed,
    required this.iosLicensed,
    required this.app,
    required this.security,
    required this.payments,
    required this.sofie,
    required this.features,
  });

  final String moduleVersion;
  final String platform;
  final bool platformAllowed;
  final bool androidLicensed;
  final bool iosLicensed;
  final AppBranding app;
  final SecurityConfig security;
  final PaymentConfig payments;
  final SofieConfig sofie;
  final FeatureConfig features;

  factory AppBootstrap.fromJson(Map<String, dynamic> json) {
    final license = _asMap(json['license']);
    return AppBootstrap(
      moduleVersion: _asString(json['module_version'], fallback: '-'),
      platform: _asString(json['platform'], fallback: 'ANDROID').toUpperCase(),
      platformAllowed: _asBool(json['platform_allowed']),
      androidLicensed: _asBool(license['android']),
      iosLicensed: _asBool(license['ios']),
      app: AppBranding.fromJson(_asMap(json['app'])),
      security: SecurityConfig.fromJson(_asMap(json['security'])),
      payments: PaymentConfig.fromJson(_asMap(json['payments'])),
      sofie: SofieConfig.fromJson(_asMap(json['sofie'])),
      features: FeatureConfig.fromJson(_asMap(json['features'])),
    );
  }
}

class AppBranding {
  const AppBranding({
    required this.name,
    required this.logoUrl,
    required this.iconAndroidUrl,
    required this.iconIosUrl,
    required this.splashUrl,
    required this.primaryColor,
    required this.secondaryColor,
    required this.minVersion,
    required this.currentVersion,
    required this.currentBuild,
    required this.forceUpdate,
    required this.storeUrl,
    required this.themeDefault,
  });

  final String name;
  final String? logoUrl;
  final String? iconAndroidUrl;
  final String? iconIosUrl;
  final String? splashUrl;
  final String primaryColor;
  final String secondaryColor;
  final String? minVersion;
  final String? currentVersion;
  final String? currentBuild;
  final bool forceUpdate;
  final String? storeUrl;
  final String themeDefault;

  factory AppBranding.fromJson(Map<String, dynamic> json) => AppBranding(
    name: _asString(json['name'], fallback: 'Soft Ecommerce'),
    logoUrl: _nullableString(json['logo_url']),
    iconAndroidUrl: _nullableString(json['icon_android_url']),
    iconIosUrl: _nullableString(json['icon_ios_url']),
    splashUrl: _nullableString(json['splash_url']),
    primaryColor: _asString(json['primary_color'], fallback: '#1A73E8'),
    secondaryColor: _asString(json['secondary_color'], fallback: '#202124'),
    minVersion: _nullableString(json['min_version']),
    currentVersion: _nullableString(json['current_version']),
    currentBuild: _nullableString(json['current_build']),
    forceUpdate: _asBool(json['force_update']),
    storeUrl: _nullableString(json['store_url']),
    themeDefault: _asString(
      json['theme_default'],
      fallback: 'SYSTEM',
    ).toUpperCase(),
  );
}

class SecurityConfig {
  const SecurityConfig({
    required this.rememberMe,
    required this.biometrics,
    required this.rememberDays,
    required this.registrationEnabled,
    required this.googleLoginEnabled,
    required this.googleWebClientId,
    required this.passwordRecoveryUrl,
  });

  final bool rememberMe;
  final bool biometrics;
  final int rememberDays;
  final bool registrationEnabled;
  final bool googleLoginEnabled;
  final String? googleWebClientId;
  final String? passwordRecoveryUrl;

  factory SecurityConfig.fromJson(Map<String, dynamic> json) => SecurityConfig(
    rememberMe: _asBool(json['remember_me']),
    biometrics: _asBool(json['biometrics']),
    rememberDays: _asInt(json['remember_days'], fallback: 90),
    registrationEnabled: _asBool(json['registration_enabled']),
    googleLoginEnabled: _asBool(json['google_login_enabled']),
    googleWebClientId: _nullableString(json['google_web_client_id']),
    passwordRecoveryUrl: _nullableString(json['password_recovery_url']),
  );
}

class PaymentConfig {
  const PaymentConfig({
    required this.hubActive,
    required this.hub,
    required this.googlePay,
    required this.applePay,
    required this.payOnDelivery,
    required this.payOnPickup,
    required this.googlePayEnvironment,
    required this.googlePayMerchantId,
    required this.googlePayMerchantName,
  });

  final bool hubActive;
  final String? hub;
  final bool googlePay;
  final bool applePay;
  final bool payOnDelivery;
  final bool payOnPickup;
  final String googlePayEnvironment;
  final String? googlePayMerchantId;
  final String? googlePayMerchantName;

  factory PaymentConfig.fromJson(Map<String, dynamic> json) => PaymentConfig(
    hubActive: _asBool(json['hub_active']),
    hub: _nullableString(json['hub']),
    googlePay: _asBool(json['google_pay']),
    applePay: _asBool(json['apple_pay']),
    payOnDelivery: _asBool(json['pay_on_delivery']),
    payOnPickup: _asBool(json['pay_on_pickup']),
    googlePayEnvironment: _asString(
      json['google_pay_environment'],
      fallback: 'TEST',
    ).toUpperCase(),
    googlePayMerchantId: _nullableString(json['google_pay_merchant_id']),
    googlePayMerchantName: _nullableString(json['google_pay_merchant_name']),
  );
}

class SofieConfig {
  const SofieConfig({
    required this.enabled,
    required this.globalEnabled,
    required this.mobileMode,
    required this.name,
    required this.role,
    required this.avatarUrl,
    required this.iconUrl,
    required this.welcomeMessage,
    required this.primaryColor,
    required this.secondaryColor,
    required this.position,
    required this.humanSupport,
  });

  final bool enabled;
  final bool globalEnabled;
  final String mobileMode;
  final String name;
  final String role;
  final String? avatarUrl;
  final String? iconUrl;
  final String? welcomeMessage;
  final String primaryColor;
  final String secondaryColor;
  final String position;
  final bool humanSupport;

  bool get onLeft => position.toUpperCase() == 'LEFT';

  factory SofieConfig.fromJson(Map<String, dynamic> json) => SofieConfig(
    enabled: _asBool(json['enabled']),
    globalEnabled: _asBool(json['global_enabled']),
    mobileMode: _asString(
      json['mobile_mode'],
      fallback: 'INHERIT',
    ).toUpperCase(),
    name: _asString(json['name'], fallback: 'SOFIE'),
    role: _asString(json['role'], fallback: 'Assistente virtual'),
    avatarUrl: _nullableString(json['avatar_url']),
    iconUrl: _nullableString(json['icon_url'] ?? json['avatar_url']),
    welcomeMessage: _nullableString(json['welcome_message']),
    primaryColor: _asString(json['primary_color'], fallback: '#7C3AED'),
    secondaryColor: _asString(json['secondary_color'], fallback: '#5B21B6'),
    position: _asString(json['position'], fallback: 'RIGHT').toUpperCase(),
    humanSupport: _asBool(json['human_support']),
  );
}

class FeatureConfig {
  const FeatureConfig({
    required this.push,
    required this.ads,
    required this.adsAttribution,
    required this.crmMetrics,
    required this.modules,
  });

  final bool push;
  final bool ads;
  final bool adsAttribution;
  final bool crmMetrics;
  final List<MobileModuleCapability> modules;

  factory FeatureConfig.fromJson(Map<String, dynamic> json) {
    final raw = json['modules'];
    final modules = <MobileModuleCapability>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          modules.add(
            MobileModuleCapability.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        }
      }
    }
    return FeatureConfig(
      push: _asBool(json['push']),
      ads: _asBool(json['ads']),
      adsAttribution: _asBool(json['ads_attribution']),
      crmMetrics: _asBool(json['crm_metrics']),
      modules: modules,
    );
  }
}

class MobileModuleCapability {
  const MobileModuleCapability({
    required this.code,
    required this.name,
    required this.description,
    required this.licensedActive,
    required this.mobileMode,
    required this.mobileActive,
  });

  final String code;
  final String name;
  final String description;
  final bool licensedActive;
  final String mobileMode;
  final bool mobileActive;

  factory MobileModuleCapability.fromJson(Map<String, dynamic> json) =>
      MobileModuleCapability(
        code: _asString(json['codigo']),
        name: _asString(json['nome'], fallback: _asString(json['codigo'])),
        description: _asString(json['descricao']),
        licensedActive: _asBool(json['licenciado_ativo']),
        mobileMode: _asString(json['modo_mobile'], fallback: 'INHERIT'),
        mobileActive: _asBool(json['mobile_ativo']),
      );
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return <String, dynamic>{};
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase();
  return text == '1' || text == 'true' || text == 'yes' || text == 'sim';
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _asString(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullableString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
