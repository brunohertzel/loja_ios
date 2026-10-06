import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeModeController extends ValueNotifier<ThemeMode> {
  AppThemeModeController._() : super(ThemeMode.system);
  static final instance = AppThemeModeController._();
  static const _key = 'soft_theme_mode';

  Future<void> load({String localDefault = 'SYSTEM'}) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    value = _decode(saved ?? localDefault);
  }

  Future<void> setMode(ThemeMode mode) async {
    value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key,
        switch (mode) {
          ThemeMode.light => 'LIGHT',
          ThemeMode.dark => 'DARK',
          _ => 'SYSTEM',
        });
  }

  ThemeMode _decode(String value) => switch (value.toUpperCase()) {
        'LIGHT' => ThemeMode.light,
        'DARK' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
