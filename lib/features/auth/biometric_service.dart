import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({
    String reason = 'Confirme sua biometria para entrar no aplicativo',
    Locale locale = const Locale('pt', 'BR'),
  }) async {
    try {
      final messages = biometricMessages(locale.languageCode);
      return await _auth.authenticate(
        localizedReason:
            locale.languageCode == 'pt' ? reason : messages['reason']!,
        authMessages: [
          AndroidAuthMessages(
            signInTitle: messages['title'],
            cancelButton: messages['cancel'],
            biometricHint: messages['hint'],
            biometricNotRecognized: messages['retry'],
            biometricSuccess: messages['success'],
            biometricRequiredTitle: messages['required'],
            deviceCredentialsRequiredTitle: messages['credentials'],
            deviceCredentialsSetupDescription: messages['credentialsSetup'],
            goToSettingsButton: messages['settings'],
            goToSettingsDescription: messages['setup'],
          ),
          IOSAuthMessages(
            cancelButton: messages['cancel'],
            goToSettingsButton: messages['settings'],
            goToSettingsDescription: messages['setup'],
            lockOut: messages['locked'],
            localizedFallbackTitle: '',
          ),
        ],
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}

// Mensagens do plugin acompanham o idioma escolhido no app. Diálogos exclusivos do sistema usam o idioma do aparelho.
Map<String, String> biometricMessages(String language) => switch (language) {
      'en' => {
          'reason': 'Confirm your identity to sign in',
          'title': 'Sign in with biometrics',
          'cancel': 'Cancel',
          'hint': 'Confirm your identity',
          'retry': 'Not recognized. Try again.',
          'success': 'Identity confirmed',
          'required': 'Set up biometrics',
          'credentials': 'Set up device security',
          'credentialsSetup': 'Set up screen lock in device settings.',
          'settings': 'Settings',
          'setup': 'Set up fingerprint or face recognition in device settings.',
          'locked':
              'Biometrics are temporarily unavailable. Lock and unlock your device, then try again.',
        },
      'es' => {
          'reason': 'Confirma tu identidad para entrar',
          'title': 'Entrar con biometría',
          'cancel': 'Cancelar',
          'hint': 'Confirma tu identidad',
          'retry': 'No reconocido. Inténtalo de nuevo.',
          'success': 'Identidad confirmada',
          'required': 'Configurar biometría',
          'credentials': 'Configurar seguridad del dispositivo',
          'credentialsSetup':
              'Configura el bloqueo de pantalla en los ajustes.',
          'settings': 'Ajustes',
          'setup':
              'Configura la huella o el reconocimiento facial en los ajustes.',
          'locked':
              'La biometría no está disponible. Bloquea y desbloquea el dispositivo e inténtalo de nuevo.',
        },
      _ => {
          'reason': 'Confirme sua identidade para entrar',
          'title': 'Entrar com biometria',
          'cancel': 'Cancelar',
          'hint': 'Confirme sua identidade',
          'retry': 'Não reconhecido. Tente novamente.',
          'success': 'Identidade confirmada',
          'required': 'Configure a biometria',
          'credentials': 'Configure a segurança do aparelho',
          'credentialsSetup':
              'Configure o bloqueio de tela nas configurações do aparelho.',
          'settings': 'Configurações',
          'setup':
              'Cadastre uma digital ou reconhecimento facial nas configurações do aparelho.',
          'locked':
              'A biometria está temporariamente bloqueada. Bloqueie e desbloqueie a tela e tente novamente.',
        },
    };
