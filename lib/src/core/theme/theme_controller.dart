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
    _variant = savedVariant == 'classic'
        ? AppThemeVariant.classic
        : savedVariant == 'blush'
            ? AppThemeVariant.blush
            : savedVariant == 'moss'
                ? AppThemeVariant.moss
                : savedVariant == 'lavender'
                    ? AppThemeVariant.lavender
                    : savedVariant == 'slate'
                        ? AppThemeVariant.slate
                        : savedVariant == 'ocean'
                            ? AppThemeVariant.ocean
                            : savedVariant == 'bingsu'
                                ? AppThemeVariant.bingsu
                                : savedVariant == 'bliss'
                                    ? AppThemeVariant.bliss
                                    : savedVariant == 'dollar'
                                        ? AppThemeVariant.dollar
                                        : savedVariant == 'fleuriste'
                                            ? AppThemeVariant.fleuriste
                                            : savedVariant == 'pale_nimbus'
                                                ? AppThemeVariant.paleNimbus
                                                : AppThemeVariant.earthy;
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
      nextVariant == AppThemeVariant.classic
          ? 'classic'
          : nextVariant == AppThemeVariant.blush
              ? 'blush'
              : nextVariant == AppThemeVariant.moss
                  ? 'moss'
                  : nextVariant == AppThemeVariant.lavender
                      ? 'lavender'
                      : nextVariant == AppThemeVariant.slate
                          ? 'slate'
                          : nextVariant == AppThemeVariant.ocean
                              ? 'ocean'
                              : nextVariant == AppThemeVariant.bingsu
                                  ? 'bingsu'
                                  : nextVariant == AppThemeVariant.bliss
                                      ? 'bliss'
                                      : nextVariant == AppThemeVariant.dollar
                                          ? 'dollar'
                                          : nextVariant ==
                                                  AppThemeVariant.fleuriste
                                              ? 'fleuriste'
                                              : nextVariant ==
                                                      AppThemeVariant.paleNimbus
                                                  ? 'pale_nimbus'
                                                  : 'earthy',
    );
  }
}
