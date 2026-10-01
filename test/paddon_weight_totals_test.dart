import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/widgets/paddon_weight_totals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nullable server totals preserve zero and full precision', () {
    final p = AdminPaddon.fromJson(
        {'total_gross_kg': 12.345678, 'total_net_kg': '11.123456'});
    expect(p.totalGrossKg, 12.345678);
    expect(p.totalNetKg, 11.123456);
    expect(AdminPaddon.fromJson({'total_gross_kg': 0}).totalGrossKg, 0);
    for (final invalid in [null, -1, double.nan, double.infinity, 'bad']) {
      expect(AdminPaddon.fromJson({'total_gross_kg': invalid}).totalGrossKg,
          isNull);
    }
    expect(AdminPaddon.fromJson({'item_count': 0}).totalGrossKg, isNull);
  });
  test('snapshot never infers totals from meters or available WIP', () {
    final p = AdminPaddonSnapshot.fromJson({
      'paddon': {'total_gross_kg': 5},
      'items': [
        {
          'batch_id': 'a',
          'apparatus': 'apparatus:default:asset-010',
          'produced_qty': 2000,
          'uom': 'm'
        }
      ],
      'available_items': [
        {
          'batch_id': 'b',
          'apparatus': 'apparatus:default:asset-010',
          'finished_goods_kg': 100
        }
      ]
    });
    expect(p.paddon.totalGrossKg, 5);
    expect(p.paddon.totalNetKg, isNull);
  });
  for (final locale in ['uz', 'ru', 'en']) {
    testWidgets('localized totals wrap in narrow $locale layout',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(240, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          locale: Locale(locale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate
          ],
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.8)),
              child: child!),
          home: Scaffold(
              body: PaddonWeightTotals(
                  paddon: AdminPaddon.fromJson(
                      {'total_gross_kg': 1234.567891, 'total_net_kg': 0})))));
      await tester.pumpAndSettle();
      final gross = tester
          .widget<Text>(find.byKey(const ValueKey('paddon-total-gross')))
          .data!;
      final net = tester
          .widget<Text>(find.byKey(const ValueKey('paddon-total-net')))
          .data!;
      expect(gross, contains('1234.567891 kg'));
      expect(net, contains('0 kg'));
      expect(
          gross,
          startsWith({
            'uz': 'Jami brutto',
            'ru': 'Всего брутто',
            'en': 'Total gross'
          }[locale]!));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('unknown differs from zero', (tester) async {
    await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: Scaffold(
            body: PaddonWeightTotals(
                paddon: AdminPaddon.fromJson({'total_net_kg': 0})))));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('paddon-total-gross')))
            .data,
        endsWith('—'));
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('paddon-total-net')))
            .data,
        endsWith('0 kg'));
  });
}
