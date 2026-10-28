import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/native_usb_printer.dart';
import 'package:accord_mobile_v2/src/core/print_transport.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/gscale/gscale_mobile_app.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _recipe = {
  'variant_id': 'variant-lg',
  'variant_name': 'LG',
  'material_id': 'pe-pr',
  'material_name': 'PE PR',
  'captured_at': '2026-10-28T05:00:00Z',
  'formulas': [
    {
      'name': 'A',
      'share_percent': '30.000000',
      'lines': [
        {'item_code': 'S1', 'name': 'Seriya 1', 'percent': '88.000000'},
        {'item_code': 'S2', 'name': 'Seriya 2', 'percent': '12.000000'},
      ],
    },
    {
      'name': 'B',
      'share_percent': '70.000000',
      'lines': [
        {'item_code': 'S1', 'name': 'Seriya 1', 'percent': '100.000000'},
      ],
    },
  ],
};

void main() {
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('formula receipt sends its recipe identity with the batch start', () {
    final request = buildGScaleRpsBatchStartRequest(
      orderId: 'zakaz-0317',
      preparationFormulaMaterialId: 'pe-pr',
      preparationFormulaVariantId: 'variant-lg',
      driverUrl: 'usb://local',
      item: const MobileItem(itemCode: 'PE PR', itemName: 'PE PR'),
      warehouse: 'Own W',
      printer: 'godex',
      printMode: 'label',
      quantitySource: 'scale',
      manualQtyKg: 0,
      tareEnabled: false,
      tareKg: 0,
      lengthM: 125,
    );
    expect(request.toJson()['preparation_formula'], {
      'material_id': 'pe-pr',
      'variant_id': 'variant-lg',
    });
    expect(request.toJson()['order_id'], 'zakaz-0317');
  });

  testWidgets('print history displays the recipe frozen for the printed roll',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.tayyorlovMasteri,
      displayName: 'Master',
      legalName: '',
      ref: 'prep-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['preparation.access', 'rps.batch.manage'],
    );
    final batch = GScaleRpsBatchSession.fromJson({
      'id': 'batch-lg',
      'active': false,
      'order_assignment': {
        'order_id': 'zakaz-0317',
        'preparation_formula': _recipe,
      },
      'item_code': 'PE PR',
      'item_name': 'PE PR',
      'warehouse': 'Own W',
      'printer': 'godex',
      'prints': [
        {'epc': '303132333435363738394142', 'qty': 23, 'unit': 'kg'},
      ],
    });
    expect(batch.preparationFormulaVariantId, 'variant-lg');
    expect(
        MobileArchiveSession.fromRpsBatch(batch).preparationFormula, _recipe);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: OperatorDashboardPage(
          server: null,
          printTransport: PrintTransport.offline,
          offlinePrinter: const UsbPrinterProfile(
            kind: UsbPrinterKind.godex,
            deviceName: 'usb:test',
            vendorId: 1,
            productId: 2,
            manufacturerName: 'GoDEX',
            productName: 'G500',
          ),
          controlOnly: true,
          onExitMode: () async {},
          onChangeServer: () async {},
          rpsBatchStateLoader: () async =>
              GScaleRpsBatchResponse(ok: true, batch: batch),
          rpsBatchHistoryLoader: () async => [batch],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Print tarixi'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('batch-history-batch-lg')));
    await tester.pumpAndSettle();
    expect(find.text('Shnek formulasi'), findsOneWidget);
    expect(find.text('LG'), findsOneWidget);
    expect(find.text('Shnek A (30.000000%)'), findsOneWidget);
    expect(find.text('Seriya 1: 88.000000%\nSeriya 2: 12.000000%'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
