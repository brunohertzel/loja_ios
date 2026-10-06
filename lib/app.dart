import 'core/localization/localized_widgets.dart';
import 'core/localization/locale_controller.dart';
import 'core/config/platform_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/config/generated_app_config.dart';
import 'core/device/device_service.dart';
import 'core/models/bootstrap_config.dart';
import 'core/network/api_client.dart';
import 'core/storage/secure_session_store.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'core/version/version_utils.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/biometric_service.dart';
import 'features/auth/login_page.dart';
import 'features/store/store_shell.dart';
import 'features/store/customer_care_pages.dart';
import 'features/store/store_repository.dart';

class SoftEcommerceApp extends StatefulWidget {
  const SoftEcommerceApp({super.key});

  @override
  State<SoftEcommerceApp> createState() => _SoftEcommerceAppState();
}

enum _AppState {
  loading,
  authentication,
  legal,
  store,
  blocked,
  updateRequired,
}

class _SoftEcommerceAppState extends State<SoftEcommerceApp> {
  late final SecureSessionStore _store;
  late final DeviceService _device;
  late final ApiClient _api;
  late final AuthRepository _auth;
  late final BiometricService _biometrics;

  _AppState _state = _AppState.loading;
  AppBootstrap? _bootstrap;
  String? _message;

  @override
  void initState() {
    super.initState();
    _store = SecureSessionStore();
    _device = DeviceService(_store);
    _api = ApiClient(store: _store, device: _device);
    _auth = AuthRepository(api: _api, store: _store, device: _device);
    _biometrics = BiometricService();
    _initialize();
  }

  Future<void> _initialize() async {
    if (mounted) {
      setState(() {
        _state = _AppState.loading;
        _message = null;
      });
    }

    try {
      await AppLocaleController.instance.load();
      await _device.initialize();
      final bootstrapJson = await _api.bootstrap();
      final bootstrap = AppBootstrap.fromJson(bootstrapJson);
      _bootstrap = bootstrap;
      await AppThemeModeController.instance.load(
        localDefault: GeneratedAppConfig.themeDefault,
      );

      // O splash/branding vem do modulo Mobile. O Android mostra um splash
      // nativo antes do Flutter; assim que o bootstrap chega, exibimos a
      // imagem configurada no modulo (splash -> logo -> icone Android).
      if (mounted) setState(() {});
      final startupImage = _firstNonEmpty([
        GeneratedAppConfig.splashUrl,
        GeneratedAppConfig.logoUrl,
        PlatformInfo.isIOS
            ? GeneratedAppConfig.iconIosUrl
            : GeneratedAppConfig.iconAndroidUrl,
      ]);
      if (startupImage != null && startupImage.isNotEmpty && mounted) {
        try {
          await precacheImage(
            NetworkImage(startupImage),
            context,
          ).timeout(const Duration(seconds: 3));
        } catch (_) {
          // Se a imagem estiver indisponivel, a inicializacao continua.
        }
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }

      if (!bootstrap.platformAllowed) {
        _message = (PlatformInfo.isIOS
                ? bootstrap.iosLicensed
                : bootstrap.androidLicensed)
            ? '${PlatformInfo.label} está licenciado, mas foi desabilitado no configurador do módulo Mobile.'
            : '${PlatformInfo.label} não está incluído na licença do módulo Soft Ecommerce Mobile.';
        _state = _AppState.blocked;
        return;
      }

      final minVersion = bootstrap.app.minVersion;
      if (bootstrap.app.forceUpdate &&
          minVersion != null &&
          VersionUtils.isLowerThan(_device.appVersion, minVersion)) {
        _message =
            'Esta versão do aplicativo precisa ser atualizada. Versão mínima: $minVersion.';
        _state = _AppState.updateRequired;
        return;
      }

      // A loja nunca entra em modo autenticado silenciosamente. Primeiro o
      // cliente confirma sua identidade. Se houver uma sessao persistente e
      // biometria habilitada, a tela de acesso abre a biometria automaticamente;
      // caso contrario, pede CPF/CNPJ/e-mail + senha. Depois da confirmacao a
      // Home da loja e aberta e o checkout nao pede login novamente.
      _state = _AppState.authentication;
    } on ApiException catch (e) {
      _message = e.message;
      _state = _AppState.blocked;
    } catch (e) {
      _message = 'Falha ao iniciar o aplicativo: $e';
      _state = _AppState.blocked;
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _authenticated() async {
    if (!mounted) return;
    if (_bootstrap?.customerCareEnabled == true) {
      try {
        final status = await StoreRepository(
          _api,
          auth: _auth,
        ).careGet('/account/legal.php');
        if (!mounted) return;
        if (status['needs_acceptance'] == true) {
          setState(() => _state = _AppState.legal);
          return;
        }
      } catch (e) {
        if (mounted)
          setState(() {
            _message = 'Não foi possível consultar os termos da loja: $e';
            _state = _AppState.blocked;
          });
        return;
      }
    }
    setState(() => _state = _AppState.store);
    await _auth.event('app_open', <String, dynamic>{
      'package': _device.packageName,
    });
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = _bootstrap;
    const primary = GeneratedAppConfig.primaryColor;
    const secondary = GeneratedAppConfig.secondaryColor;

    return ValueListenableBuilder<Locale>(
      valueListenable: AppLocaleController.instance,
      builder: (context, locale, _) => ValueListenableBuilder<ThemeMode>(
        valueListenable: AppThemeModeController.instance,
        builder: (context, themeMode, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: GeneratedAppConfig.appName,
          theme: AppTheme.lightFromHex(primary, secondary),
          darkTheme: AppTheme.darkFromHex(primary, secondary),
          themeMode: themeMode,
          locale: locale,
          supportedLocales: AppLocaleController.supported,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: switch (_state) {
            _AppState.loading => _LoadingPage(bootstrap: bootstrap),
            _AppState.authentication => bootstrap == null
                ? _LoadingPage(bootstrap: bootstrap)
                : LoginPage(
                    api: _api,
                    auth: _auth,
                    store: _store,
                    biometrics: _biometrics,
                    bootstrap: bootstrap,
                    autoTryBiometric: true,
                    onLoggedIn: _authenticated,
                  ),
            _AppState.legal => LegalDocumentsPage(
                repository: StoreRepository(_api, auth: _auth),
                requireAcceptance: true,
                onAccepted: _authenticated,
              ),
            _AppState.store => bootstrap == null
                ? _LoadingPage(bootstrap: bootstrap)
                : StoreShell(
                    api: _api,
                    auth: _auth,
                    store: _store,
                    biometrics: _biometrics,
                    bootstrap: bootstrap,
                    onLoggedOut: () {
                      if (mounted)
                        setState(() => _state = _AppState.authentication);
                    },
                  ),
            _AppState.blocked => _MessagePage(
                icon: Icons.cloud_off,
                title: 'Não foi possível iniciar',
                message: _message ?? 'Falha desconhecida.',
                buttonLabel: 'Tentar novamente',
                onPressed: _initialize,
              ),
            _AppState.updateRequired => _MessagePage(
                icon: Icons.system_update,
                title: 'Atualização obrigatória',
                message: _message ?? 'Atualize o aplicativo para continuar.',
                buttonLabel: 'Verificar novamente',
                onPressed: _initialize,
              ),
          },
        ),
      ),
    );
  }
}

String? _firstNonEmpty(List<String> values) {
  for (final value in values) {
    final v = value.trim();
    if (v.isNotEmpty) return v;
  }
  return null;
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage({this.bootstrap});

  final AppBootstrap? bootstrap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _firstNonEmpty([
      GeneratedAppConfig.splashUrl,
      GeneratedAppConfig.logoUrl,
      PlatformInfo.isIOS
          ? GeneratedAppConfig.iconIosUrl
          : GeneratedAppConfig.iconAndroidUrl,
    ]);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 42,
                        vertical: 70,
                      ),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 34,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessagePage extends StatelessWidget {
  const _MessagePage({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });
  final IconData icon;
  final String title;
  final String message;
  final String buttonLabel;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 58,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      LText(
                        title,
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 10),
                      LText(message, textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      FilledButton(
                          onPressed: onPressed, child: LText(buttonLabel)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
