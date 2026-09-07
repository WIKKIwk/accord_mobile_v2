import 'dart:async';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/features/werka/presentation/werka_paddon_receive_screen.dart';
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
        Map<String, dynamic>? received}) =>
    WerkaPaddonPreview.fromJson({
      'paddon': {
        'id': 'p1',
        'code': '00001',
        'location': 'Rezka',
        'item_count': 2
      },
      'items': [
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
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.runAsync(() async {
    await GlobalMaterialLocalizations.delegate.load(const Locale('uz'));
    await GlobalCupertinoLocalizations.delegate.load(const Locale('uz'));
  });
  await tester.binding.setSurfaceSize(const Size(430, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('uz'),
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
        receive: receive),
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
  testWidgets('shared QR scanner opens the pallet preview', (tester) async {
    var scans = 0;
    await showScreen(tester, initialCode: null, load: (code) async {
      scans++;
      expect(code, '00001');
      return preview();
    });
    final scanner = tester.widget<ProductionQuickScannerPanel>(
        find.byType(ProductionQuickScannerPanel));
    await scanner.onCodeDetected('not-a-pallet');
    await tester.pump();
    expect(scans, 0);
    expect(find.byKey(const ValueKey('werka-paddon-error')), findsOneWidget);
    await scanner.onCodeDetected('00001');
    await tester.pumpAndSettle();
    expect(scans, 1);
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
        find.byKey(const ValueKey('werka-paddon-roll-roll-0')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('werka-paddon-roll-roll-1')), findsOneWidget);
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
}
