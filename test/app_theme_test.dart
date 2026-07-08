import 'dart:async';

import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/core/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('earthy light theme keeps existing shell and chrome colors', () async {
    final theme = await _buildThemeIgnoringGoogleFontLoadErrors(
      () => AppTheme.light(AppThemeVariant.earthy),
    );
    final scheme = theme.colorScheme;

    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, const Color(0xFFECE7D1));
    expect(theme.cardColor, const Color(0xFFE7DCC0));
    expect(scheme.surfaceContainerHighest, const Color(0xFFECE7D1));
    expect(theme.appBarTheme.backgroundColor, const Color(0xFFECE7D1));
    expect(theme.navigationBarTheme.backgroundColor, const Color(0xFFECE7D1));
  });

  test('earthy dark theme separates shell from chrome and nav', () async {
    final theme = await _buildThemeIgnoringGoogleFontLoadErrors(
      () => AppTheme.dark(AppThemeVariant.earthy),
    );

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF211D16));
    expect(theme.appBarTheme.backgroundColor, const Color(0xFF302A21));
    expect(theme.navigationBarTheme.backgroundColor, const Color(0xFF302A21));
    expect(
      theme.scaffoldBackgroundColor,
      isNot(theme.navigationBarTheme.backgroundColor),
    );
  });
}

Future<ThemeData> _buildThemeIgnoringGoogleFontLoadErrors(
  ThemeData Function() create,
) async {
  late ThemeData theme;
  Object? unexpectedError;
  StackTrace? unexpectedStack;

  await runZonedGuarded(
    () async {
      theme = create();
      // Font assets are not bundled for this unit test; color token assertions
      // do not depend on the async font load outcome.
      await Future<void>.delayed(const Duration(milliseconds: 20));
    },
    (error, stack) {
      if (_isGoogleFontLoadError(error)) {
        return;
      }
      unexpectedError = error;
      unexpectedStack = stack;
    },
  );

  if (unexpectedError != null) {
    Error.throwWithStackTrace(unexpectedError!, unexpectedStack!);
  }
  return theme;
}

bool _isGoogleFontLoadError(Object error) =>
    error.toString().contains('GoogleFonts.config.allowRuntimeFetching') ||
    error.toString().contains('google_fonts was unable to load font');
