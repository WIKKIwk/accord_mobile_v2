import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/widgets/feedback/rps_qr_reprint_sheet.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/worker_wip_details.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _workerRef = 'workerispdaduio0242304203480239';
const _apparatusId = 'apparatus:default:asset-010';
const _epc = '400000000000000000000001';

AdminProgressBatch _batch({
  Map<String, dynamic> payload = const {'gross_qty': 211.675},
  double? finishedGoodsKg = 200,
  double? bobinaKg = 1.125,
  String workerName = 'Akmal Rahimov',
}) =>
    AdminProgressBatch(
      batchId: 'internal-wip-id',
      sessionId: 'internal-session-id',
      apparatus: _apparatusId,
      orderId: 'internal-order-id',
      action: 'complete',
      status: 'completed',
      producedQty: 8787,
      uom: 'm',
      qrPayload: _epc,
      labelItemCode: '0021',
      labelItemName: 'Guruch alanga arzon 1 kg',
      executorName: _workerRef,
      workerRef: _workerRef,
      workerDisplayName: workerName,
      finishedGoodsKg: finishedGoodsKg,
      bobinaKg: bobinaKg,
      payloadJson: payload,
    );

Future<void> _showDetails(
  WidgetTester tester,
  AdminProgressBatch batch, {
  SessionProfile? viewer,
  double width = 400,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(useMaterial3: true),
    locale: const Locale('uz'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: Scaffold(
      body: Builder(builder: (context) {
        return TextButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (_) => RpsQrReprintSheet(
              title: 'WIP tafsilotlari',
              payload: _epc,
              showPayload: false,
              itemName: '0021 • Guruch alanga arzon 1 kg',
              details: const [],
              detailsContent: WorkerWipDetails(
                batch: batch,
                apparatusCatalog: const [
                  AdminApparatus(id: _apparatusId, name: 'Rezka'),
                ],
                statusLabel: 'Keyingi bosqichda ishlatilgan',
                viewer: viewer,
              ),
              onReprint: () async => null,
              errorMessage: (error) => error.toString(),
            ),
          ),
          child: const Text('Tafsilotlar'),
        );
      }),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tafsilotlar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('WIP shows measured gross, net, core, readable producer and EPC',
      (tester) async {
    await _showDetails(tester, _batch());
    for (final value in [
      'Brutto',
      '211.675 kg',
      'Netto',
      '210.55 kg',
      'Bobina og‘irligi',
      '1.125 kg',
      '8 787 m',
      'Chiqargan xodim',
      'Akmal Rahimov',
      'Rezka',
      'EPC kodi',
    ]) {
      expect(find.text(value), findsOneWidget);
    }
    expect(find.text('200 kg'), findsNothing);
    expect(find.textContaining(_workerRef), findsNothing);
    expect(find.textContaining('internal-'), findsNothing);
    expect(find.textContaining('apparatus:'), findsNothing);
    for (final detail in <(String, String)>[
      ('Brutto', '211.675 kg'),
      ('Netto', '210.55 kg'),
      ('Chiqargan xodim', 'Akmal Rahimov'),
      ('EPC kodi', '4000 0000 0000 0000 0000 0001'),
    ]) {
      final row = find
          .ancestor(of: find.text(detail.$1), matching: find.byType(Row))
          .first;
      expect(find.descendant(of: row, matching: find.text(detail.$2)),
          findsOneWidget);
    }
    await tester.ensureVisible(find.byType(SelectableText));
    expect(find.text('4000 0000 0000 0000 0000 0001'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('rps-qr-reprint')));
    await tester.tap(find.byKey(const ValueKey('rps-qr-reprint')));
    await tester.pumpAndSettle();
    expect(find.text('Mavjud QR qayta chop etildi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing weights stay unknown and raw worker IDs are not shown',
      (tester) async {
    await _showDetails(
      tester,
      _batch(
          payload: const {},
          finishedGoodsKg: null,
          bobinaKg: null,
          workerName: _workerRef),
    );
    expect(find.text('Kiritilmagan'), findsNWidgets(3));
    expect(find.text('Bajargan xodim ko‘rsatilmagan'), findsOneWidget);
    expect(find.text('8 787 kg'), findsNothing);
    expect(find.textContaining(_workerRef), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('own saved profile resolves a legacy creator ID', (tester) async {
    await _showDetails(tester, _batch(workerName: _workerRef),
        viewer: const SessionProfile(
          role: UserRole.aparatchi,
          displayName: 'Sardor Karimov',
          legalName: '',
          ref: _workerRef,
          phone: '',
          avatarUrl: '',
        ));
    expect(find.text('Sardor Karimov'), findsOneWidget);
    expect(find.textContaining(_workerRef), findsNothing);
  });

  for (final core in <double?>[null, 250, 0]) {
    testWidgets('net respects missing, invalid and zero core weight: $core',
        (tester) async {
      await _showDetails(tester, _batch(payload: const {}, bobinaKg: core));
      expect(find.text('200 kg'), findsNWidgets(core == 0 ? 2 : 1));
      expect(
          find.text('Kiritilmagan'),
          findsNWidgets(core == null
              ? 2
              : core == 0
                  ? 0
                  : 1));
      expect(find.text('-50 kg'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('details remain readable on a narrow phone with large text',
      (tester) async {
    await _showDetails(tester, _batch(), width: 320, textScale: 1.6);
    await tester.ensureVisible(find.byType(SelectableText));
    expect(find.text('4000 0000 0000 0000 0000 0001'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('rps-qr-reprint')));
    expect(tester.takeException(), isNull);
  });
}
