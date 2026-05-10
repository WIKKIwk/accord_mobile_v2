import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeVariant {
  classic,
  earthy,
  blush,
  moss,
  lavender,
  slate,
  ocean,
  bingsu,
  bliss,
  dollar,
  fleuriste,
  paleNimbus,
  blackEdition,
}

class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();
  static const String prefsKey = 'app_theme_mode';
  static const String variantPrefsKey = 'app_theme_variant';

  ThemeMode _themeMode = ThemeMode.dark;
  AppThemeVariant _variant = AppThemeVariant.earthy;

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
        prefsKey, nextMode == ThemeMode.light ? 'light' : 'dark');
  }

  Future<void> setVariant(AppThemeVariant nextVariant) async {
    if (_variant == nextVariant) {
      return;
    }
    _variant = nextVariant;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      variantPrefsKey,
      _variantToPrefs(nextVariant),
    );
  }

  static AppThemeVariant _variantFromPrefs(String? value) {
    return switch (value) {
      'classic' => AppThemeVariant.classic,
      'blush' => AppThemeVariant.blush,
      'moss' => AppThemeVariant.moss,
      'lavender' => AppThemeVariant.lavender,
      'slate' => AppThemeVariant.slate,
      'ocean' => AppThemeVariant.ocean,
      'bingsu' => AppThemeVariant.bingsu,
      'bliss' => AppThemeVariant.bliss,
      'dollar' => AppThemeVariant.dollar,
      'fleuriste' => AppThemeVariant.fleuriste,
      'pale_nimbus' => AppThemeVariant.paleNimbus,
      'black_edition' => AppThemeVariant.blackEdition,
      _ => AppThemeVariant.earthy,
    };
  }

  static String _variantToPrefs(AppThemeVariant variant) {
    return switch (variant) {
      AppThemeVariant.classic => 'classic',
      AppThemeVariant.earthy => 'earthy',
      AppThemeVariant.blush => 'blush',
      AppThemeVariant.moss => 'moss',
      AppThemeVariant.lavender => 'lavender',
      AppThemeVariant.slate => 'slate',
      AppThemeVariant.ocean => 'ocean',
      AppThemeVariant.bingsu => 'bingsu',
      AppThemeVariant.bliss => 'bliss',
      AppThemeVariant.dollar => 'dollar',
      AppThemeVariant.fleuriste => 'fleuriste',
      AppThemeVariant.paleNimbus => 'pale_nimbus',
      AppThemeVariant.blackEdition => 'black_edition',
    };
  }
}
