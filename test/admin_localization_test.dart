import 'package:accord_mobile_v2/src/core/localization/admin_localization.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin copy has complete Uzbek, English, and Russian coverage', () {
    final localizations = <AppLocalizations>[
      AppLocalizations(const Locale('uz')),
      AppLocalizations(const Locale('en')),
      AppLocalizations(const Locale('ru')),
    ];

    for (final entry in adminTranslations.entries) {
      final key = entry.key.substring('admin.'.length);
      for (final languageCode in const ['uz', 'en', 'ru']) {
        expect(
          entry.value[languageCode]?.trim(),
          isNotEmpty,
          reason: '${entry.key} is missing $languageCode copy',
        );
      }
      for (final l10n in localizations) {
        expect(
          l10n.adminText(key, values: const {'count': 2}),
          isNot(startsWith('admin.')),
          reason: '${entry.key} did not resolve for ${l10n.locale}',
        );
      }
    }

    final english = localizations[1];
    expect(
      english.adminText('home.raw_material_microns'),
      'Raw material microns',
    );
    expect(
      english.adminText(
        'production.move.success',
        values: const {'count': 3},
      ),
      '3 order(s) moved',
    );
    expect(
      english.adminText('capacity.schedule_title'),
      'Schedule an order',
    );
  });
}
