import 'dart:io' show Platform;
import '../localization/locale_controller.dart';

class PlatformInfo {
  static bool get isIOS => Platform.isIOS;
  static bool get isAndroid => Platform.isAndroid;
  static String get apiPlatform => isIOS ? 'IOS' : 'ANDROID';
  static String get label => isIOS ? 'iOS' : 'Android';
  static String get biometricSettingsLabel =>
      tr(isIOS ? 'Ajustes do iPhone' : 'configurações do Android');
}
