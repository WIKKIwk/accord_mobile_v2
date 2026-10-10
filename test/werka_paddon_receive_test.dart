import 'dart:async';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/features/werka/presentation/werka_paddon_receive_screen.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/aparatchi_paddon_detail_screen.dart';
import 'package:accord_mobile_v2/src/core/formatters/date_time_formatters.dart';
import 'package:accord_mobile_v2/src/core/widgets/feedback/rps_qr_reprint_sheet.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/raw_material_scan_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const receipt = <String, dynamic>{
  'warehouse': 'WH-1',
  'accepted_by_display_name': 'Omborchi',
  'accepted_at_unix': 1700000000
};
WerkaPaddonPreview preview(
        {List<String> warehouses = const ['WH-1'],
        bool ready = true,
        Map<String, dynamic>? received,
        String location = 'Rezka',
        List<Map<String, dynamic>>? items}) =>
    WerkaPaddonPreview.fromJson({
      'paddon': {
        'id': 'p1',
        'code': '00001',
        'location': location,
        'created_by_ref': 'worker-1',
        'created_by_display_name': 'Qobil',
        'total_gross_kg': 21,
        'total_net_kg': 19.875,
        'item_count': 2
      },
      'items': items ?? [
        for (var i = 0; i < 2; i++)
          {
            'batch_id': 'roll-$i',
            'apparatus': 'apparatus:default:asset-010',
            'order_id': 'order-1',
            'qr_payload': 'QR-$i',
            'finished_goods_kg': 10.0 + i,
            'label_item_name': 'Rulon $i',
            'processed_by_apparatus': received == null ? '' : 'warehouse:WH-1'
          }
      ],
      'warehouses': warehouses,
      'can_receive': ready,
      'snapshot_token': 'token',
      'receipt': received,
    });

Future<void> showScreen(
  WidgetTester tester, {
  String? initialCode = '00001',
  Future<WerkaPaddonPreview> Function(String)? load,
  Future<Map<String, dynamic>> Function(WerkaPaddonPreview, String)? receive,
  Future<Map<String, String>> Function()? loadApparatusNames,
  Locale locale = const Locale('uz'),
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.runAsync(() async {
    await GlobalMaterialLocalizations.delegate.load(locale);
    await GlobalCupertinoLocalizations.delegate.load(locale);
  });
  await tester.binding.setSurfaceSize(const Size(430, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate
    ],
    home: WerkaPaddonReceiveScreen(
        initialCode: initialCode,
        loadPreview: load ?? (_) async => preview(),
        receive: receive,
        loadApparatusNames: loadApparatusNames ?? () async => {}),
  ));
  await tester.pumpAndSettle();
}

Finder get accept => find.byKey(const ValueKey('werka-paddon-receive'));
Future<void> confirm(WidgetTester tester) async {
  await tester.ensureVisible(accept);
  await tester.tap(accept);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('werka-paddon-confirm')));
  await tester.pumpAndSettle();
}

void main() {
  const apparatusId = 'apparatus:default:asset-010';
  const removedLabel =
      'Avella 120 sht tayyor mahsulot, apparat: $apparatusId, rulon yechildi';
  const finishedLabel =
      'Avella 120 sht tayyor mahsulot, apparat: $apparatusId, ish tugatildi';
  final legacyRolls = [
    for (final (index, label) in [removedLabel, finishedLabel].indexed)
      <String, dynamic>{
        'batch_id': 'roll-$index',
        'apparatus': apparatusId,
        'order_id': 'order-1',
        'qr_payload': 'QR-$index',
        'finished_goods_kg': 10.0 + index,
        'finished_goods_meter': 100.0 + index,
        'label_item_name': label,
      },
  ];

  testWidgets('shared details retain apparatus labels and receipt behavior',
      (tester) async {
    var calls = 0;
    await showScreen(tester,
        load: (_) async => preview(items: legacyRolls, location: apparatusId),
        loadApparatusNames: () async => {apparatusId: 'Rezka 1'},
        receive: (p, warehouse) async {
          calls++;
          expect(warehouse, 'WH-1');
          expect(p.snapshot.items.first.labelItemName, removedLabel);
          expect(p.snapshot.items.last.labelItemName, finishedLabel);
          expect(p.snapshot.items.first.apparatus, apparatusId);
          expect(p.snapshotToken, 'token');
          return receipt;
        });
    expect(find.byType(AparatchiPaddonDetailScreen), findsOneWidget);
    final creator = find.byKey(const ValueKey('paddon-created-by'));
    expect(find.descendant(of: creator, matching: find.text('Paddonni ochgan')),
        findsOneWidget);
    expect(find.descendant(of: creator, matching: find.text('Qobil')),
        findsOneWidget);
    expect(find.text('Rezka 1'), findsOneWidget);
    expect(find.text('Buyurtma: — - Avella 120 sht'), findsNWidgets(2));
    expect(find.textContaining('apparatus:'), findsNothing);
    expect(find.text('Jami brutto: 21 kg'), findsOneWidget);
    expect(find.text('Jami netto: 19.875 kg'), findsOneWidget);
    expect(find.text('EPC: QR-0 • 100 m'), findsOneWidget);
    await confirm(tester);
    expect(calls, 1);
    expect(find.byKey(const ValueKey('werka-paddon-received')), findsOneWidget);
    expect(find.text('Ombor: WH-1'), findsOneWidget);
    expect(find.descendant(of: creator, matching: find.text('Qobil')),
        findsOneWidget);
    expect(accept, findsNothing);
  });

  for (final language in ['uz', 'en', 'ru']) {
    testWidgets('unavailable apparatus names have a $language fallback',
        (tester) async {
      await showScreen(tester,
          locale: Locale(language),
          load: (_) async => preview(items: legacyRolls, location: apparatusId),
          loadApparatusNames: () async {
            if (language == 'uz') {
              throw const MobileApiException(code: 'forbidden', message: '');
            }
            return {apparatusId: language == 'en' ? '  ' : apparatusId};
          });
      final unspecified = tester
          .element(find.byType(AparatchiPaddonDetailScreen))
          .l10n.adminText('wip.unspecified');
      final locationRow = find.byWidgetPredicate((widget) =>
          widget is Row && widget.children.any((child) =>
              child is Icon && child.icon == Icons.place_outlined));
      expect(find.descendant(of: locationRow, matching: find.text(unspecified)),
          findsOneWidget);
      expect(find.textContaining('apparatus:'), findsNothing);
      expect(find.byKey(const ValueKey('werka-paddon-error')), findsNothing);
      expect(tester.widget<FilledButton>(accept).onPressed, isNotNull);
    });
  }

  testWidgets('pending name lookup leaves receipt actions usable',
      (tester) async {
    final names = Completer<Map<String, String>>();
    await showScreen(tester,
        load: (_) async => preview(items: legacyRolls, location: apparatusId),
        loadApparatusNames: () => names.future,
        receive: (_, warehouse) async => receipt);
    expect(find.textContaining('apparatus:'), findsNothing);
    final unspecified = tester
        .element(find.byType(AparatchiPaddonDetailScreen))
        .l10n.adminText('wip.unspecified');
    expect(find.text(unspecified), findsOneWidget);
    await confirm(tester);
    expect(find.byKey(const ValueKey('werka-paddon-received')), findsOneWidget);
    names.complete({apparatusId: 'Rezka 1'});
    await tester.pumpAndSettle();
    expect(find.text(unspecified), findsNothing);
    expect(find.text('Rezka 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('werka-paddon-received')), findsOneWidget);
    expect(accept, findsNothing);
  });


  testWidgets('warehouse reuses bobbin filtering and WIP provenance sheet',
      (tester) async {
    const producedAt = 1700000000;
    var writes = 0;
    await showScreen(
      tester,
      load: (_) async => preview(items: [
        for (var i = 0; i < 3; i++)
          {
            'batch_id': 'roll-$i',
            'apparatus': 'apparatus:default:asset-010',
            'order_id': 'order-1',
            'qr_payload': 'QR-$i',
            'bobina_kg': i == 1 ? 4 : 2,
            'completed_at_unix': producedAt,
            'worker_display_name': 'Anis',
            'executor_name': 'Old label name',
          },
      ]),
      receive: (paddon, warehouse) async {
        writes++;
        return receipt;
      },
    );
    expect(find.byType(AparatchiPaddonDetailScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('app-primary-navigation-button')),
        findsNothing);
    final group = find.byKey(const ValueKey('paddon-bobina-group-2000000'));
    expect(find.descendant(of: group, matching: find.text('2 ta')),
        findsOneWidget);
    await tester.tap(group);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paddon-wip-card-roll-1')), findsNothing);
    expect(find.byKey(const ValueKey('paddon-wip-card-roll-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('paddon-wip-card-roll-2')), findsOneWidget);
    await tester.longPress(
        find.byKey(const ValueKey('paddon-wip-card-roll-0')));
    await tester.pumpAndSettle();
    final sheet = tester.widget<RpsQrReprintSheet>(find.byType(RpsQrReprintSheet));
    expect(sheet.details.any((detail) =>
        detail.label == 'Chiqarilgan vaqt' &&
        detail.value == formatUnixSecondsLocalDateTime(producedAt)), isTrue);
    expect(sheet.details.any((detail) =>
        detail.label == 'Chiqargan' && detail.value == 'Anis'), isTrue);
    expect(sheet.onReprint, isNotNull);
    final reprint = tester.widget<FilledButton>(
        find.byKey(const ValueKey('paddon-wip-reprint-roll-0')));
    expect(reprint.onPressed, isNotNull);
    expect(writes, 0);
  });

  testWidgets('shared QR scanner opens the pallet preview', (tester) async {
    var scans = 0;
    await showScreen(tester, initialCode: null, load: (code) async {
      scans++;
      if (code == 'not-a-pallet') {
        throw const MobileApiException(code: 'paddon_not_found', message: '');
      }
      expect(code, '00001');
      return preview();
    });
    final scanner = tester.widget<ProductionQuickScannerPanel>(
        find.byType(ProductionQuickScannerPanel));
    await scanner.onCodeDetected('not-a-pallet');
    await tester.pump();
    expect(scans, 1);
    expect(find.byKey(const ValueKey('werka-paddon-error')), findsOneWidget);
    await scanner.onCodeDetected('00001');
    await tester.pumpAndSettle();
    expect(scans, 2);
    expect(find.descendant(
        of: find.byKey(const ValueKey('paddon-created-by')),
        matching: find.text('Qobil')), findsOneWidget);
    expect(find.text('Jami brutto: 21 kg'), findsOneWidget);
    expect(find.text('Jami netto: 19.875 kg'), findsOneWidget);
    expect(accept, findsOneWidget);
  });
  testWidgets('preview shows all rolls; confirm receives whole pallet once',
      (tester) async {
    var calls = 0;
    await showScreen(tester, receive: (p, warehouse) async {
      calls++;
      expect(warehouse, 'WH-1');
      expect(p.snapshot.items.length, 2);
      expect(p.snapshotToken, 'token');
      return receipt;
    });
    expect(
        find.byKey(const ValueKey('paddon-wip-card-roll-0')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('paddon-wip-card-roll-1')), findsOneWidget);
    await confirm(tester);
    expect(calls, 1);
    expect(find.byKey(const ValueKey('werka-paddon-received')), findsOneWidget);
    expect(accept, findsNothing);
  });

  testWidgets('cancel performs no receipt write', (tester) async {
    var calls = 0;
    await showScreen(tester, receive: (_, warehouse) async {
      calls++;
      return receipt;
    });
    await tester.ensureVisible(accept);
    await tester.tap(accept);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bekor qilish'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(tester.widget<FilledButton>(accept).onPressed, isNotNull);
  });

  testWidgets('multiple assigned warehouses require explicit selection',
      (tester) async {
    await showScreen(tester,
        load: (_) async => preview(warehouses: ['WH-1', 'WH-2']));
    expect(tester.widget<FilledButton>(accept).onPressed, isNull);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WH-2').last);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(accept).onPressed, isNotNull);
  });

  testWidgets('ineligible pallet cannot be submitted', (tester) async {
    await showScreen(tester, load: (_) async => preview(ready: false));
    expect(tester.widget<FilledButton>(accept).onPressed, isNull);
  });

  testWidgets('previously received pallet shows receipt without submit',
      (tester) async {
    await showScreen(tester,
        load: (_) async => preview(ready: false, received: receipt));
    expect(find.byKey(const ValueKey('werka-paddon-received')), findsOneWidget);
    expect(accept, findsNothing);
  });

  testWidgets('uncertain write forces reload and does not repeat receipt',
      (tester) async {
    var calls = 0;
    var loads = 0;
    await showScreen(tester,
        load: (_) async =>
            ++loads == 1 ? preview() : preview(ready: false, received: receipt),
        receive: (_, warehouse) async {
          calls++;
          throw TimeoutException('response lost');
        });
    await confirm(tester);
    expect(calls, 1);
    expect(tester.widget<FilledButton>(accept).onPressed, isNull);
    await tester.ensureVisible(find.text('Qayta tekshirish'));
    await tester.tap(find.text('Qayta tekshirish'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(loads, 2);
    expect(find.byKey(const ValueKey('werka-paddon-received')), findsOneWidget);
    expect(accept, findsNothing);
  });
  testWidgets('warehouse reload refreshes unknown totals', (tester) async {
    var loads = 0;
    await showScreen(tester, load: (_) async {
      loads++; final initial = preview();
      return WerkaPaddonPreview(snapshot: AdminPaddonSnapshot(
        paddon: AdminPaddon.fromJson({'code':'00001', 'item_count':2,
          'total_gross_kg':loads == 1 ? null : 22.125,
          'total_net_kg':loads == 1 ? null : 20.875}), items:initial.snapshot.items),
        warehouses:initial.warehouses, canReceive:initial.canReceive, snapshotToken:initial.snapshotToken);
    });
    expect(find.text('Jami brutto: —'), findsOneWidget);
    await tester.ensureVisible(find.text('Qayta tekshirish'));
    await tester.tap(find.text('Qayta tekshirish')); await tester.pumpAndSettle();
    expect(loads,2);
    await tester.ensureVisible(find.byKey(const ValueKey('paddon-detail-weights')));
    await tester.pumpAndSettle();
    expect(find.text('Jami brutto: 22.125 kg'),findsOneWidget);
    expect(find.text('Jami netto: 20.875 kg'),findsOneWidget);
  });

}
