import '../../core/localization/localized_widgets.dart';
import '../../core/localization/locale_controller.dart';
import 'package:flutter/material.dart';

import '../../core/config/platform_info.dart';
import '../../core/notifications/notification_permission_service.dart';
import '../../core/models/bootstrap_config.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_session_store.dart';
import '../auth/auth_repository.dart';
import '../auth/biometric_service.dart';
import 'customer_care_pages.dart';
import 'store_repository.dart';

class LocalSecurityPage extends StatefulWidget {
  const LocalSecurityPage(
      {super.key,
      required this.auth,
      required this.store,
      required this.biometrics,
      required this.bootstrap,
      required this.repository});
  final AuthRepository auth;
  final SecureSessionStore store;
  final BiometricService biometrics;
  final AppBootstrap bootstrap;
  final StoreRepository repository;
  @override
  State<LocalSecurityPage> createState() => _LocalSecurityPageState();
}

class _LocalSecurityPageState extends State<LocalSecurityPage>
    with WidgetsBindingObserver {
  final _permissions = NotificationPermissionService();
  String _permission = 'unknown';
  bool _languageChanging = false, _permissionRefreshing = false;
  bool _loading = true, _biometricEnabled = false, _available = false;
  bool _biometricChanging = false,
      _notifications = false,
      _notificationsChanging = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  void _message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: LText(text)));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final enabled = await widget.store.biometricEnabled;
      final available = widget.bootstrap.security.biometrics &&
          await widget.biometrics.isAvailable();
      if (mounted)
        setState(() {
          _biometricEnabled = enabled;
          _available = available;
        });
      final permission = await _permissions.status();
      final pref = await widget.repository.notificationPreference(
          permission: permission,
          language: AppLocaleController.instance.value.languageCode);
      if (mounted)
        setState(() {
          _notifications = pref['enabled'] == true;
          _permission = permission;
        });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleBiometric(bool enabled) async {
    if (_biometricChanging || !widget.bootstrap.security.biometrics) return;
    if (enabled && !_available) {
      _message(
          'Cadastre uma digital ou reconhecimento facial em ${PlatformInfo.biometricSettingsLabel}.');
      return;
    }
    final refresh = await widget.store.refreshToken;
    if (!mounted) return;
    if (enabled && (refresh == null || refresh.isEmpty)) {
      _message(
          'Ative “Manter conectado” no próximo login para usar a biometria.');
      return;
    }
    setState(() => _biometricChanging = true);
    try {
      if (enabled &&
          !await widget.biometrics.authenticate(
            reason:
                'Confirme sua biometria para habilitar o acesso ao aplicativo',
            locale: Localizations.localeOf(context),
          )) return;
      await widget.auth.setBiometric(enabled);
      if (mounted) setState(() => _biometricEnabled = enabled);
      _message(enabled
          ? 'Acesso por biometria ativado.'
          : 'Acesso por biometria desativado.');
    } on ApiException catch (e) {
      _message(e.message);
    } catch (e) {
      _message('Não foi possível alterar a biometria. Tente novamente.');
    } finally {
      if (mounted) setState(() => _biometricChanging = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_notificationsChanging &&
        !_loading) _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    if (_permissionRefreshing) return;
    _permissionRefreshing = true;
    try {
      final permission = await _permissions.status();
      final pref = await widget.repository.notificationPreference(
          permission: permission,
          language: AppLocaleController.instance.value.languageCode);
      if (mounted)
        setState(() {
          _permission = permission;
          _notifications = pref['enabled'] == true;
        });
    } catch (_) {
      _message('Não foi possível verificar a permissão de notificações.');
    } finally {
      _permissionRefreshing = false;
    }
  }

  Future<void> _changeLanguage(String? language) async {
    if (language == null || _languageChanging) return;
    setState(() => _languageChanging = true);
    try {
      await AppLocaleController.instance.setLanguage(language);
      _message('O idioma foi salvo neste aparelho.');
      // The device choice works offline; synchronize notification language when connected.
      try {
        await widget.repository.notificationPreference(language: language);
      } catch (_) {}
    } catch (_) {
      _message('Não foi possível salvar o idioma. Tente novamente.');
    } finally {
      if (mounted) setState(() => _languageChanging = false);
    }
  }

  Future<void> _openSettings() async {
    if (!await _permissions.openSettings())
      _message('Não foi possível abrir as configurações do aparelho.');
  }

  String get _permissionLabel => switch (_permission) {
        'granted' || 'provisional' => 'Permitidas',
        'not_determined' => 'Permissão não solicitada',
        'denied' => 'Permissão negada',
        'blocked' => 'Bloqueadas no aparelho',
        'unavailable' => 'Permissão indisponível',
        _ => 'Verificando permissão...',
      };

  Future<void> _toggleNotifications(bool enabled) async {
    if (_notificationsChanging || (enabled && !widget.bootstrap.features.push))
      return;
    setState(() => _notificationsChanging = true);
    try {
      var permission = await _permissions.status();
      if (enabled && !NotificationPermissionService.allowed(permission)) {
        if (permission == 'not_determined' || permission == 'denied')
          permission = await _permissions.request();
        if (mounted) setState(() => _permission = permission);
        if (!NotificationPermissionService.allowed(permission)) {
          await widget.repository.notificationPreference(
              permission: permission,
              language: AppLocaleController.instance.value.languageCode);
          _message(permission == 'unavailable'
              ? 'Permissão indisponível'
              : 'Permita as notificações nas configurações do aparelho.');
          return;
        }
      }
      final saved = await widget.repository.notificationPreference(
          enabled: enabled,
          permission: permission,
          language: AppLocaleController.instance.value.languageCode);
      if (mounted)
        setState(() {
          _notifications = saved['enabled'] == true;
          _permission = permission;
        });
      _message(enabled
          ? 'Notificações permitidas neste aparelho.'
          : 'Notificações desativadas neste aparelho.');
    } on ApiException catch (e) {
      _message(e.message);
    } catch (_) {
      _message('Não foi possível alterar as notificações. Tente novamente.');
    } finally {
      if (mounted) setState(() => _notificationsChanging = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const LText('Configurações Locais e Segurança')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<String>(
                    value: AppLocaleController.instance.value.languageCode,
                    decoration: const LDecoration(
                        labelText: 'Idioma', prefixIcon: Icon(Icons.language)),
                    items: const [
                      DropdownMenuItem(
                          value: 'pt',
                          child: LText('Português (Brasil)', translate: false)),
                      DropdownMenuItem(
                          value: 'en',
                          child: LText('English', translate: false)),
                      DropdownMenuItem(
                          value: 'es',
                          child: LText('Español', translate: false)),
                    ],
                    onChanged: _languageChanging ? null : _changeLanguage,
                  ))),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Card(
                child: ListTile(
                    title: LText(_error!),
                    trailing: IconButton(
                        onPressed: _load, icon: const Icon(Icons.refresh)))),
          Card(
              child: SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const LText('Entrar com biometria'),
            subtitle: LText(!widget.bootstrap.security.biometrics
                ? 'Biometria desativada pela loja.'
                : _available
                    ? 'Use sua digital ou reconhecimento facial neste aparelho.'
                    : 'Cadastre uma biometria em ${PlatformInfo.biometricSettingsLabel}.'),
            value: _biometricEnabled,
            onChanged: _loading ||
                    _biometricChanging ||
                    !widget.bootstrap.security.biometrics
                ? null
                : _toggleBiometric,
          )),
          Card(
              child: SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const LText('Notificações'),
            subtitle: LText(!widget.bootstrap.features.push
                ? 'Notificações desativadas pela loja.'
                : 'Ative para permitir avisos da loja sobre seus pedidos.'),
            value: _notifications &&
                NotificationPermissionService.allowed(_permission),
            onChanged: _loading ||
                    _notificationsChanging ||
                    (!widget.bootstrap.features.push && !_notifications)
                ? null
                : _toggleNotifications,
          )),
          ListTile(
              leading: const Icon(Icons.smartphone),
              title: const LText('Permissão do aparelho'),
              subtitle: LText(_permissionLabel)),
          if (_permission == 'blocked' || _permission == 'denied')
            TextButton.icon(
                onPressed: _openSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const LText('Abrir configurações do aparelho')),
          if (_notifications &&
              !NotificationPermissionService.allowed(_permission))
            TextButton(
                onPressed: _notificationsChanging
                    ? null
                    : () => _toggleNotifications(false),
                child: const LText('Desativar notificações')),
          if (widget.bootstrap.customerCareEnabled) ...[
            Card(
                child: ListTile(
                    leading: const Icon(Icons.policy_outlined),
                    title: const LText('Política de Privacidade'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => LegalDocumentsPage(
                            repository: widget.repository,
                            readOnly: true,
                            documentType: 'POLITICA_PRIVACIDADE'))))),
            Card(
                child: ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const LText('Privacidade e meus dados'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            PrivacyPage(repository: widget.repository))))),
          ],
        ]),
      );
}
