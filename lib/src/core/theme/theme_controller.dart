import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeVariant {
  classic,
  kalmar,
  moss,
  lavender,
  bliss,
  white,
}

class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();
  static const String prefsKey = 'app_theme_mode';
  static const String variantPrefsKey = 'app_theme_variant';

  ThemeMode _themeMode = ThemeMode.dark;
  AppThemeVariant _variant = AppThemeVariant.kalmar;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;
  AppThemeVariant get variant => _variant;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(prefsKey);
    final savedVariant = prefs.getString(variantPrefsKey);
    _themeMode = saved == 'light' ? ThemeMode.light : ThemeMode.dark;
    _variant = _variantFromPrefs(savedVariant);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode nextMode) async {
    if (_themeMode == nextMode) {
      return;
    }
    _themeMode = nextMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefsKey,
      nextMode == ThemeMode.light ? 'light' : 'dark',
    );
  }

  Future<void> setVariant(AppThemeVariant nextVariant) async {
    if (_variant == nextVariant) {
      return;
    }
    _variant = nextVariant;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(variantPrefsKey, _variantToPrefs(nextVariant));
  }

  static AppThemeVariant _variantFromPrefs(String? value) {
    return switch (value) {
      'classic' => AppThemeVariant.classic,
      'kalmar' => AppThemeVariant.kalmar,
      'moss' => AppThemeVariant.moss,
      'lavender' => AppThemeVariant.lavender,
      'bliss' => AppThemeVariant.bliss,
      'white' => AppThemeVariant.white,
      _ => AppThemeVariant.kalmar,
    };
  }

  static String _variantToPrefs(AppThemeVariant variant) {
    return switch (variant) {
      AppThemeVariant.classic => 'classic',
      AppThemeVariant.kalmar => 'kalmar',
      AppThemeVariant.moss => 'moss',
      AppThemeVariant.lavender => 'lavender',
      AppThemeVariant.bliss => 'bliss',
      AppThemeVariant.white => 'white',
    };
  }
}
