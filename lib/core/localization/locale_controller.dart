import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'message_catalog.dart';

class AppLocaleController extends ValueNotifier<Locale> {
  AppLocaleController._() : super(const Locale('pt', 'BR'));
  static final instance = AppLocaleController._();
  static const supported = [Locale('pt', 'BR'), Locale('en'), Locale('es')];
  static const _key = 'soft_language';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _apply(prefs.getString(_key) ?? 'pt');
  }

  void _apply(String language) {
    value = supported.firstWhere((l) => l.languageCode == language,
        orElse: () => supported.first);
  }

  Future<void> setLanguage(String language) async {
    if (!supported.any((l) => l.languageCode == language)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, language);
    _apply(language);
  }
}

String tr(String text) => MessageCatalog.translate(
    text, AppLocaleController.instance.value.languageCode);
