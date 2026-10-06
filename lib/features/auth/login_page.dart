import '../../core/config/platform_info.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/generated_app_config.dart';
import '../../core/models/bootstrap_config.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_session_store.dart';
import '../../widgets/brand_logo.dart';
import 'auth_repository.dart';
import 'biometric_service.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.api,
    required this.auth,
    required this.store,
    required this.biometrics,
    required this.bootstrap,
    required this.onLoggedIn,
    this.autoTryBiometric = false,
  });

  final ApiClient api;
  final AuthRepository auth;
  final SecureSessionStore store;
  final BiometricService biometrics;
  final AppBootstrap bootstrap;
  final VoidCallback onLoggedIn;
  final bool autoTryBiometric;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();

  bool _remember = true;
  bool _loading = false;
  bool _obscure = true;
  bool _canBiometric = false;
  bool _autoBiometricAttempted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLocalOptions();
  }

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadLocalOptions() async {
    final remembered = await widget.store.rememberMe;
    final biometricEnabled = await widget.store.biometricEnabled;
    final refresh = await widget.store.refreshToken;
    final rememberedIdentifier = await widget.store.rememberedIdentifier;
    final biometricAvailable = await widget.biometrics.isAvailable();

    if (!mounted) return;
    if (_identifier.text.trim().isEmpty &&
        rememberedIdentifier != null &&
        rememberedIdentifier.trim().isNotEmpty) {
      _identifier.text = rememberedIdentifier.trim();
    }

    setState(() {
      _remember = widget.bootstrap.security.rememberMe
          ? (remembered || refresh == null || refresh.isEmpty)
          : false;
      _canBiometric =
          widget.bootstrap.security.biometrics &&
          biometricEnabled &&
          refresh != null &&
          refresh.isNotEmpty &&
          biometricAvailable;
    });

    if (widget.autoTryBiometric && _canBiometric && !_autoBiometricAttempted) {
      _autoBiometricAttempted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_loading) _loginBiometric();
      });
    }
  }

  Future<void> _login() async {
    if (_identifier.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Informe o e-mail/CPF e a senha.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final effectiveRemember =
          widget.bootstrap.security.rememberMe && _remember;
      await widget.auth.login(
        identifier: _identifier.text.trim(),
        password: _password.text,
        rememberMe: effectiveRemember,
      );
      await widget.auth.event('login_password');

      if (effectiveRemember &&
          widget.bootstrap.security.biometrics &&
          await widget.biometrics.isAvailable() &&
          mounted) {
        final enable = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Ativar login por biometria?'),
            content: const Text(
              'A senha nao sera armazenada. A biometria deste aparelho apenas '
              'libera a sessao segura salva no dispositivo.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Agora nao'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.fingerprint),
                label: const Text('Ativar'),
              ),
            ],
          ),
        );

        if (enable == true) {
          final confirmed = await widget.biometrics.authenticate(
            reason: 'Confirme sua biometria para ativar o login rapido',
          );
          if (confirmed) {
            try {
              await widget.auth.setBiometric(true);
            } catch (_) {
              // Login continua valido mesmo se a ativacao biometrica falhar.
            }
          }
        }
      }

      widget.onLoggedIn();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Nao foi possivel entrar. $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openRegister() async {
    if (!widget.bootstrap.security.registrationEnabled) {
      setState(
        () => _error = 'Novos cadastros pelo aplicativo estão desabilitados.',
      );
      return;
    }
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            RegisterPage(auth: widget.auth, bootstrap: widget.bootstrap),
      ),
    );
    if (ok == true && mounted) {
      widget.onLoggedIn();
    }
  }

  Future<void> _loginGoogle() async {
    final cfg = widget.bootstrap.security;
    if (!cfg.googleLoginEnabled ||
        GeneratedAppConfig.googleWebClientId.trim().isEmpty) {
      setState(
        () => _error =
            'Login com Google ainda não foi configurado no módulo Mobile.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final google = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: GeneratedAppConfig.googleWebClientId,
      );
      final account = await google.signIn();
      if (account == null) return;
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const ApiException(
          'O Google não retornou um token de identidade.',
          code: 'INVALID_GOOGLE_TOKEN',
        );
      }
      try {
        final rememberGoogle = widget.bootstrap.security.rememberMe
            ? _remember
            : true;
        await widget.auth.googleLogin(
          idToken: idToken,
          rememberMe: rememberGoogle,
        );
        await widget.store.setRememberedIdentifier(
          rememberGoogle ? account.email : null,
        );
        await widget.auth.event('login_google');
        if (mounted) widget.onLoggedIn();
      } on ApiException catch (e) {
        if (e.code != 'GOOGLE_REGISTRATION_REQUIRED') rethrow;
        if (!mounted) return;
        final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => RegisterPage(
              auth: widget.auth,
              bootstrap: widget.bootstrap,
              googleIdToken: idToken,
              prefillName: account.displayName,
              prefillEmail: account.email,
            ),
          ),
        );
        if (ok == true && mounted) widget.onLoggedIn();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted)
        setState(() => _error = 'Não foi possível entrar com o Google. $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final raw = widget.bootstrap.security.passwordRecoveryUrl?.trim() ?? '';
    if (raw.isEmpty) {
      if (mounted)
        setState(
          () => _error = 'Recuperação de senha não está disponível nesta loja.',
        );
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null) {
      if (mounted)
        setState(() => _error = 'Endereço de recuperação de senha inválido.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      setState(() => _error = 'Não foi possível abrir a recuperação de senha.');
    }
  }

  Future<void> _loginBiometric() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final confirmed = await widget.biometrics.authenticate();
      if (!confirmed) {
        if (mounted) setState(() => _error = 'Biometria não confirmada.');
        return;
      }

      final refreshed = await widget.auth.refresh();
      if (!refreshed) {
        await widget.store.clearSession();
        if (mounted) {
          setState(() {
            _error = 'Sua sessão expirou. Entre com sua senha novamente.';
            _canBiometric = false;
          });
        }
        return;
      }

      await widget.auth.event('login_biometric');
      widget.onLoggedIn();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logo = GeneratedAppConfig.logoUrl.trim().isEmpty
        ? null
        : GeneratedAppConfig.logoUrl.trim();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: BrandLogo(logoUrl: logo)),
                      const SizedBox(height: 14),
                      Text(
                        GeneratedAppConfig.appName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Confirme sua identidade para entrar',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 26),
                      TextField(
                        controller: _identifier,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        decoration: const InputDecoration(
                          labelText: 'E-mail ou CPF/CNPJ',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) {
                          if (!_loading) _login();
                        },
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _loading ? null : _forgotPassword,
                          child: const Text('Esqueci minha senha'),
                        ),
                      ),
                      if (widget.bootstrap.security.rememberMe)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _remember,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('Manter conectado'),
                          onChanged: _loading
                              ? null
                              : (value) =>
                                    setState(() => _remember = value ?? false),
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.errorContainer.withOpacity(.55),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      FilledButton(
                        onPressed: _loading ? null : _login,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('ENTRAR'),
                        ),
                      ),
                      if (_canBiometric) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _loginBiometric,
                          icon: const Icon(Icons.fingerprint),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Entrar com biometria'),
                          ),
                        ),
                      ],
                      if (widget.bootstrap.security.googleLoginEnabled) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _loginGoogle,
                          icon: const Icon(Icons.g_mobiledata, size: 28),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Continuar com Google'),
                          ),
                        ),
                      ],
                      if (widget.bootstrap.security.registrationEnabled) ...[
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: _loading ? null : _openRegister,
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Text('Criar uma conta'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Text(
                        '${PlatformInfo.label} • ${widget.api.device.appVersion}+'
                        '${widget.api.device.appBuild}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
