import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/core/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('light and dark themes use Google Sans across Material and Cupertino',
      () {
    final themes = [
      AppTheme.light(),
      AppTheme.dark(),
    ];

    for (final theme in themes) {
      expect(theme.textTheme.bodyMedium?.fontFamily, AppTheme.fontFamily);
      expect(theme.textTheme.titleLarge?.fontFamily, AppTheme.fontFamily);
      expect(theme.inputDecorationTheme.labelStyle?.fontFamily,
          AppTheme.fontFamily);
      expect(theme.inputDecorationTheme.hintStyle?.fontFamily,
          AppTheme.fontFamily);
      final cupertinoTextTheme = theme.cupertinoOverrideTheme!.textTheme!;
      expect(cupertinoTextTheme.textStyle.fontFamily, AppTheme.fontFamily);
      expect(
          cupertinoTextTheme.actionTextStyle.fontFamily, AppTheme.fontFamily);
      expect(cupertinoTextTheme.actionSmallTextStyle.fontFamily,
          AppTheme.fontFamily);
      expect(
          cupertinoTextTheme.tabLabelTextStyle.fontFamily, AppTheme.fontFamily);
      expect(
          cupertinoTextTheme.navTitleTextStyle.fontFamily, AppTheme.fontFamily);
      expect(cupertinoTextTheme.navLargeTitleTextStyle.fontFamily,
          AppTheme.fontFamily);
      expect(cupertinoTextTheme.navActionTextStyle.fontFamily,
          AppTheme.fontFamily);
      expect(
          cupertinoTextTheme.pickerTextStyle.fontFamily, AppTheme.fontFamily);
      expect(cupertinoTextTheme.dateTimePickerTextStyle.fontFamily,
          AppTheme.fontFamily);
    }
  });

  test('Google Sans weights are included as local font assets', () async {
    const fontAssets = [
      'assets/fonts/google_sans/GoogleSans-Regular.ttf',
      'assets/fonts/google_sans/GoogleSans-Medium.ttf',
      'assets/fonts/google_sans/GoogleSans-Bold.ttf',
      'assets/fonts/google_sans/GoogleSans-Italic.ttf',
      'assets/fonts/google_sans/GoogleSans-MediumItalic.ttf',
      'assets/fonts/google_sans/GoogleSans-BoldItalic.ttf',
    ];

    for (final fontAsset in fontAssets) {
      final data = await rootBundle.load(fontAsset);
      expect(data.lengthInBytes, greaterThan(300000), reason: fontAsset);
    }

    final fontLoader = FontLoader(AppTheme.fontFamily);
    for (final fontAsset in fontAssets) {
      fontLoader.addFont(rootBundle.load(fontAsset));
    }
    await fontLoader.load();

    final license =
        await rootBundle.loadString('assets/fonts/google_sans/OFL.txt');
    expect(license, contains('SIL OPEN FONT LICENSE Version 1.1'));
  });

  testWidgets('Google Sans renders operational copy in a narrow scaled view',
      (tester) async {
    const operationalCopy =
        'Oʻzbekiston · Ўзбек тили · Русский · 125 kg · 3.5 m · №42';
    final theme = AppTheme.light();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 720),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: Text(
                  operationalCopy,
                  key: const ValueKey('operational-copy'),
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final paragraph = tester.renderObject<RenderParagraph>(
      find.byKey(const ValueKey('operational-copy')),
    );
    expect(paragraph.text.style?.fontFamily, AppTheme.fontFamily);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });

  test('kalmar theme follows the app icon palette', () {
    final scheme = AppTheme.light(AppThemeVariant.kalmar).colorScheme;

    expect(scheme.primary, const Color(0xFF7A4A2E));
    expect(scheme.secondaryContainer, const Color(0xFFE8DED3));
    expect(scheme.surface, const Color(0xFFFFF8F3));
    expect(AppTheme.light(AppThemeVariant.kalmar).scaffoldBackgroundColor,
        const Color(0xFFF8EFE8));
  });

  test('white theme uses a near-white shell with readable dark chrome', () {
    final theme = AppTheme.light(AppThemeVariant.white);
    final scheme = theme.colorScheme;

    expect(theme.brightness, Brightness.light);
    expect(scheme.surface, const Color(0xFFFFFFFF));
    expect(scheme.onSurface, const Color(0xFF1B1F23));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF5F5F5));
    expect(theme.cardColor, const Color(0xFFFFFFFF));
    expect(scheme.surfaceContainer, const Color(0xFFF0F0F0));
    expect(scheme.surfaceContainerHighest, const Color(0xFFFFFFFF));
    expect(theme.appBarTheme.backgroundColor, const Color(0xFFE6E6E6));
    expect(theme.navigationBarTheme.backgroundColor, const Color(0xFFE6E6E6));
    expect(scheme.outlineVariant, const Color(0xFFD0D0D0));
  });
}
