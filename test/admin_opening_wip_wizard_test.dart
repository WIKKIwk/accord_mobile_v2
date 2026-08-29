import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _laminationId = 'apparatus:default:asset-007';
const _lamination2Id = 'apparatus:default:asset-008';
const _rezkaId = 'apparatus:default:asset-010';
const _printingId = 'apparatus:default:bosma_7';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    resetMobileApiTestModeData();
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.token = 'opening-wip-admin-token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Opening WIP admin',
      legalName: 'Opening WIP admin',
      ref: 'ADMIN-OPENING-WIP',
      phone: '',
      avatarUrl: '',
      capabilities: ['admin.access', 'production_map.manage'],
    );
  });

  tearDown(() async {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    resetMobileApiTestModeData();
    await TestModeController.instance.setEnabled(false);
  });

  testWidgets('admin creates distinct measured batches from selectable fields',
      (tester) async {
    await MobileApi.instance.adminSaveProductionMap(_openingOrder());
    var printerPickerCalls = 0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminOpeningWipScreen(
          progressDriverUrlPicker: (_) async {
            printerPickerCalls += 1;
            return 'http://printer.test';
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Bu fake ishlab chiqarish tarixi emas'),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('opening-wip-order')), findsOneWidget);
    expect(find.text('Izoh (ixtiyoriy)'), findsNothing);
    final orderDecoration = tester
        .widget<DropdownButtonFormField<ProductionMapSaved>>(
          find.byKey(const ValueKey('opening-wip-order')),
        )
        .decoration;
    expect(orderDecoration.border, isA<OutlineInputBorder>());
    expect(
      (orderDecoration.border! as OutlineInputBorder).borderRadius,
      BorderRadius.circular(8),
    );
    expect(
      find.byKey(const ValueKey('opening-wip-source-operation')),
      findsNothing,
    );

    final sourcePicker = find.byKey(
      const ValueKey('opening-wip-source-apparatus'),
    );
    final sourceField = find.descendant(
      of: sourcePicker,
      matching: find.byType(DropdownButtonFormField<String>),
    );
    expect(
      tester.widget(sourceField),
      isA<DropdownButtonFormField<String>>(),
    );

    for (final key in const [
      ValueKey('opening-wip-roll-meter-0'),
      ValueKey('opening-wip-roll-kg-0'),
      ValueKey('opening-wip-roll-bobina-0'),
    ]) {
      final editable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(EditableText),
        ),
      );
      expect(
        editable.keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );
    }
    final meterField = find.byKey(
      const ValueKey('opening-wip-roll-meter-0'),
    );
    final meterDecoration = tester
        .widget<TextField>(
          find.descendant(of: meterField, matching: find.byType(TextField)),
        )
        .decoration!;
    expect(meterDecoration.border, isA<OutlineInputBorder>());
    expect(
      (meterDecoration.border! as OutlineInputBorder).borderRadius,
      BorderRadius.circular(8),
    );
    await tester.enterText(meterField, 'df12,5m');
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: meterField,
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      '12,5',
    );
    await tester.tap(sourcePicker);
    await tester.pumpAndSettle();
    expect(find.text('Laminatsiya 1'), findsWidgets);
    expect(find.text('Rezka'), findsNothing);
    await tester.tap(find.text('Laminatsiya 1').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('opening-wip-roll-count')),
      '2',
    );
    await tester.enterText(
      find.byKey(const ValueKey('opening-wip-roll-meter-0')),
      '125',
    );
    await tester.enterText(
      find.byKey(const ValueKey('opening-wip-roll-kg-0')),
      '12.5',
    );
    await tester.enterText(
      find.byKey(const ValueKey('opening-wip-roll-bobina-0')),
      '1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('opening-wip-roll-meter-1')),
      '140',
    );
    await tester.enterText(
      find.byKey(const ValueKey('opening-wip-roll-kg-1')),
      '14',
    );
    await tester.enterText(
      find.byKey(const ValueKey('opening-wip-roll-bobina-1')),
      '1.1',
    );
    expect(
      find.byKey(const ValueKey('opening-wip-roll-diameter-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('opening-wip-pick-printer')),
      findsNothing,
    );
    final submit = find.byKey(const ValueKey('opening-wip-submit'));
    expect(find.text('QRsini chiqarish'), findsOneWidget);
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(printerPickerCalls, 1);

    final records = await MobileApi.instance.adminOpeningWipRecords(
      orderId: 'zakaz-opening-wip-1',
    );
    expect(records, hasLength(1));
    expect(records.single.intake.sourceApparatus, _laminationId);
    expect(records.single.intake.sourceStageNodeId, 'lamination');
    expect(records.single.intake.currentLocation, isEmpty);
    expect(records.single.intake.resumeApparatus, isEmpty);
    expect(records.single.batches, hasLength(2));
    expect(
      records.single.batches.map((batch) => batch.finishedGoodsMeter).toList(),
      [125, 140],
    );
    expect(
      records.single.batches.map((batch) => batch.finishedGoodsKg).toList(),
      [12.5, 14],
    );
    expect(
      records.single.batches.map((batch) => batch.bobinaKg).toList(),
      [1, 1.1],
    );
    expect(
      records.single.batches.map((batch) => batch.qrPayload).toSet(),
      hasLength(2),
    );
    expect(
      records.single.intake.historyStatus,
      'unavailable_before_cutover',
    );
  });

  testWidgets('QR action opens the shared three-device printer sheet',
      (tester) async {
    await MobileApi.instance.adminSaveProductionMap(_openingOrder());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminOpeningWipScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('opening-wip-roll-meter-0')),
      '125',
    );
    await tester.enterText(
      find.byKey(const ValueKey('opening-wip-roll-kg-0')),
      '12.5',
    );
    await tester.enterText(
      find.byKey(const ValueKey('opening-wip-roll-bobina-0')),
      '1',
    );

    expect(
      find.byKey(const ValueKey('opening-wip-pick-printer')),
      findsNothing,
    );
    expect(find.text('QRsini chiqarish'), findsOneWidget);
    final submit = find.byKey(const ValueKey('opening-wip-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Qurilma tanlash'), findsOneWidget);
    expect(find.text('USB'), findsOneWidget);
    expect(find.text('Bluetooth'), findsOneWidget);
    expect(find.text('Wi-Fi'), findsOneWidget);
    expect(
      await MobileApi.instance.adminOpeningWipRecords(
        orderId: 'zakaz-opening-wip-1',
      ),
      isEmpty,
    );
  });

  testWidgets('successful print stays on the Opening WIP tab', (tester) async {
    await MobileApi.instance.adminSaveProductionMap(
      _openingOrder(id: 'zakaz-opening-wip-stay-page'),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        initialRoute: '/opening-wip',
        routes: {
          '/': (_) => const Scaffold(body: Text('HOME_MARKER')),
          '/opening-wip': (_) => AdminOpeningWipScreen(
                progressDriverUrlPicker: (_) async => 'http://printer.test',
              ),
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('opening-wip-roll-meter-0')),
      '125',
    );
    await tester.enterText(
      find.byKey(const ValueKey('opening-wip-roll-kg-0')),
      '12.5',
    );
    await tester.enterText(
      find.byKey(const ValueKey('opening-wip-roll-bobina-0')),
      '1',
    );
    final submit = find.byKey(const ValueKey('opening-wip-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('HOME_MARKER'), findsNothing);
    expect(find.byType(AdminOpeningWipScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('opening-wip-fields')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('opening-wip-apparatus-filter-chip')),
      findsNothing,
    );
  });

  testWidgets(
      'switching order resets the source apparatus to the first eligible stage',
      (tester) async {
    await MobileApi.instance.adminSaveProductionMap(
      _printingOpeningOrder(
        id: 'zakaz-opening-wip-switch-a',
        orderNumber: 'OWIP-SWITCH-A',
      ),
    );
    await MobileApi.instance.adminSaveProductionMap(
      _printingOpeningOrder(
        id: 'zakaz-opening-wip-switch-b',
        orderNumber: 'OWIP-SWITCH-B',
      ),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminOpeningWipScreen(),
      ),
    );
    await tester.pumpAndSettle();

    Finder sourceField() => find.descendant(
          of: find.byKey(const ValueKey('opening-wip-source-apparatus')),
          matching: find.byType(DropdownButtonFormField<String>),
        );
    String selectedSourceNode() =>
        tester.state<FormFieldState<String>>(sourceField()).value ?? '';

    expect(selectedSourceNode(), 'print');
    await tester
        .tap(find.byKey(const ValueKey('opening-wip-source-apparatus')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Laminatsiya 1').last);
    await tester.pumpAndSettle();
    expect(selectedSourceNode(), 'lamination');

    final orderField = find.byKey(const ValueKey('opening-wip-order'));
    final selectedOrder =
        tester.state<FormFieldState<ProductionMapSaved>>(orderField).value!;
    final nextOrderLabel = selectedOrder.map.orderNumber == 'OWIP-SWITCH-A'
        ? 'OWIP-SWITCH-B • Opening WIP switch'
        : 'OWIP-SWITCH-A • Opening WIP switch';
    await tester.tap(orderField);
    await tester.pumpAndSettle();
    await tester.tap(find.text(nextOrderLabel).last);
    await tester.pumpAndSettle();

    expect(selectedSourceNode(), 'print');
    expect(find.text('7 ta rangli bosma aparat'), findsWidgets);
  });

  testWidgets(
      'source selector keeps map alternatives and excludes the final stage',
      (tester) async {
    await MobileApi.instance.adminSaveProductionMap(_openingAlternativeOrder());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminOpeningWipScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(const ValueKey('opening-wip-source-apparatus')));
    await tester.pumpAndSettle();

    expect(find.text('Laminatsiya 1'), findsWidgets);
    expect(find.text('Laminatsiya 2'), findsOneWidget);
    expect(find.text('Rezka'), findsNothing);
  });

  testWidgets('rezka Opening WIP requires diameter per roll', (tester) async {
    await MobileApi.instance.adminSaveProductionMap(_rezkaSourceOrder());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminOpeningWipScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('opening-wip-roll-diameter-0')),
      findsOneWidget,
    );
  });

  testWidgets(
      'completed target hides its prior source and keeps the next source',
      (tester) async {
    const orderId = 'zakaz-opening-wip-stage-advance';
    await MobileApi.instance.adminSaveProductionMap(
      _printingOpeningOrder(
        id: orderId,
        orderNumber: 'OWIP-STAGE-ADVANCE',
      ),
    );
    setMobileApiTestModeProductionMapStageStates(
      orderId: orderId,
      states: const {
        'print': 'completed',
        'lamination': 'completed',
        'rezka': 'pending',
      },
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminOpeningWipScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final sourceField = find.descendant(
      of: find.byKey(const ValueKey('opening-wip-source-apparatus')),
      matching: find.byType(DropdownButtonFormField<String>),
    );
    expect(
      tester.state<FormFieldState<String>>(sourceField).value,
      'lamination',
    );
    expect(find.text('Laminatsiya 1'), findsOneWidget);
    await tester
        .tap(find.byKey(const ValueKey('opening-wip-source-apparatus')));
    await tester.pumpAndSettle();
    expect(find.text('7 ta rangli bosma aparat'), findsNothing);
    expect(find.text('Rezka'), findsNothing);
  });

  testWidgets('work map does not render the Opening WIP intake',
      (tester) async {
    await MobileApi.instance.adminSaveProductionMap(_openingOrder());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('opening-wip-order')), findsNothing);
    expect(find.text('Opening WIP'), findsNothing);
  });

  testWidgets('Opening WIP list filters by its linked source apparatus',
      (tester) async {
    await MobileApi.instance.adminSaveProductionMap(
      _openingOrder(
        id: 'zakaz-opening-wip-filter-lamination',
      ),
    );
    await MobileApi.instance.adminSaveProductionMap(
      _printingOpeningOrder(
        id: 'zakaz-opening-wip-filter-print',
        orderNumber: 'OWIP-FILTER-PRINT',
      ),
    );
    await MobileApi.instance.adminCreateOpeningWip(
      const AdminOpeningWipCreateInput(
        idempotencyKey: 'opening-wip-filter-lamination',
        orderId: 'zakaz-opening-wip-filter-lamination',
        sourceApparatus: _laminationId,
        sourceStageNodeId: 'lamination',
        batches: [
          AdminOpeningWipBatchInput(
            quantityBasis: AdminOpeningWipQuantityBasis.measured,
            finishedGoodsMeter: 120,
            finishedGoodsKg: 12,
            bobinaKg: 1,
          ),
        ],
      ),
    );
    await MobileApi.instance.adminCreateOpeningWip(
      const AdminOpeningWipCreateInput(
        idempotencyKey: 'opening-wip-filter-print',
        orderId: 'zakaz-opening-wip-filter-print',
        sourceApparatus: _printingId,
        sourceStageNodeId: 'print',
        batches: [
          AdminOpeningWipBatchInput(
            quantityBasis: AdminOpeningWipQuantityBasis.estimated,
            finishedGoodsMeter: 220,
            finishedGoodsKg: 22,
            bobinaKg: 2,
          ),
        ],
      ),
    );

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminOpeningWipScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('WIP list'));
    await tester.pumpAndSettle();

    final filter = find.byKey(
      const ValueKey('opening-wip-apparatus-filter-chip'),
    );
    expect(filter, findsOneWidget);
    await tester.tap(filter);
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey(
          'opening-wip-apparatus-option-chip-apparatus:default:asset-007',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey(
          'opening-wip-apparatus-option-chip-apparatus:default:bosma_7',
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(
        const ValueKey(
          'opening-wip-apparatus-option-chip-apparatus:default:asset-007',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Laminatsiya 1'), findsWidgets);
    expect(find.text('7 ta rangli bosma aparat'), findsNothing);
  });

  testWidgets('tapping Opening WIP opens details and reprints its QR',
      (tester) async {
    await MobileApi.instance.adminSaveProductionMap(
      _openingOrder(id: 'zakaz-opening-wip-details-ui'),
    );
    final record = await MobileApi.instance.adminCreateOpeningWip(
      const AdminOpeningWipCreateInput(
        idempotencyKey: 'opening-wip-details-ui',
        orderId: 'zakaz-opening-wip-details-ui',
        sourceApparatus: _laminationId,
        sourceStageNodeId: 'lamination',
        note: 'Opening WIP test izohi',
        batches: [
          AdminOpeningWipBatchInput(
            quantityBasis: AdminOpeningWipQuantityBasis.measured,
            finishedGoodsMeter: 120,
            finishedGoodsKg: 12,
            bobinaKg: 1,
          ),
        ],
      ),
    );
    final batch = record.batches.single;
    var printerPickerCalls = 0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminOpeningWipScreen(
          progressDriverUrlPicker: (_) async {
            printerPickerCalls += 1;
            return 'http://printer.test';
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('WIP list'));
    await tester.pumpAndSettle();

    final card = find.byKey(ValueKey('opening-wip-batch-${batch.batchId}'));
    expect(card, findsOneWidget);
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.text('Opening WIP ma’lumoti'), findsOneWidget);
    expect(find.text('WIP ID'), findsOneWidget);
    expect(find.text(batch.batchId), findsOneWidget);
    expect(
      find.byKey(ValueKey('opening-wip-preview-${batch.batchId}')),
      findsOneWidget,
    );
    final reprint = find.byKey(
      ValueKey('opening-wip-reprint-${batch.batchId}'),
    );
    expect(reprint, findsOneWidget);
    await tester.ensureVisible(reprint);
    await tester.tap(reprint);
    await tester.pumpAndSettle();

    expect(printerPickerCalls, 1);
    expect(find.text('Opening WIP QR qayta chop etildi'), findsOneWidget);
  });

  testWidgets('long press cancel keeps WIP and confirm deletes unused WIP',
      (tester) async {
    await MobileApi.instance.adminSaveProductionMap(
      _openingOrder(id: 'zakaz-opening-wip-delete-ui'),
    );
    final record = await MobileApi.instance.adminCreateOpeningWip(
      const AdminOpeningWipCreateInput(
        idempotencyKey: 'opening-wip-delete-ui',
        orderId: 'zakaz-opening-wip-delete-ui',
        sourceApparatus: _laminationId,
        sourceStageNodeId: 'lamination',
        batches: [
          AdminOpeningWipBatchInput(
            quantityBasis: AdminOpeningWipQuantityBasis.measured,
            finishedGoodsMeter: 120,
            finishedGoodsKg: 12,
            bobinaKg: 1,
          ),
        ],
      ),
    );
    final batchId = record.batches.single.batchId;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminOpeningWipScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('WIP list'));
    await tester.pumpAndSettle();

    final card = find.byKey(ValueKey('opening-wip-batch-$batchId'));
    expect(card, findsOneWidget);
    await tester.longPress(card);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('opening-wip-delete-cancel')),
    );
    await tester.pumpAndSettle();
    expect(card, findsOneWidget);
    expect(
      await MobileApi.instance.adminOpeningWipRecords(
        orderId: 'zakaz-opening-wip-delete-ui',
      ),
      hasLength(1),
    );

    await tester.longPress(card);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('opening-wip-delete-confirm')),
    );
    await tester.pumpAndSettle();
    expect(card, findsNothing);
    expect(
      await MobileApi.instance.adminOpeningWipRecords(
        orderId: 'zakaz-opening-wip-delete-ui',
      ),
      isEmpty,
    );
  });
}

ProductionMapDefinition _openingOrder({
  String id = 'zakaz-opening-wip-1',
  String apparatusId = _laminationId,
  bool includeRezkaStage = true,
}) {
  return ProductionMapDefinition(
    id: id,
    productCode: 'ITEM-OPENING-WIP',
    title: 'Opening WIP mahsulot',
    orderNumber: 'OWIP-0001',
    nodes: [
      const ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
      ProductionMapNode(
        id: 'lamination',
        kind: 'apparatus',
        title: apparatusId == _rezkaId ? 'Rezka' : 'Laminatsiya 1',
        apparatusId: apparatusId,
      ),
      if (includeRezkaStage)
        const ProductionMapNode(
          id: 'rezka',
          kind: 'apparatus',
          title: 'Rezka',
          apparatusId: _rezkaId,
        ),
      const ProductionMapNode(id: 'end', kind: 'end', title: 'End'),
    ],
    edges: [
      const ProductionMapEdge(from: 'start', to: 'lamination'),
      if (includeRezkaStage) ...const [
        ProductionMapEdge(from: 'lamination', to: 'rezka'),
        ProductionMapEdge(from: 'rezka', to: 'end'),
      ] else
        const ProductionMapEdge(from: 'lamination', to: 'end'),
    ],
  );
}

ProductionMapDefinition _openingAlternativeOrder() {
  return const ProductionMapDefinition(
    id: 'zakaz-opening-wip-alternative',
    productCode: 'ITEM-OPENING-WIP-ALT',
    title: 'Opening WIP alternative',
    orderNumber: 'OWIP-ALT',
    nodes: [
      ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
      ProductionMapNode(
        id: 'print',
        kind: 'apparatus',
        title: '7 ta rangli bosma aparat',
        apparatusId: _printingId,
      ),
      ProductionMapNode(
        id: 'lamination-1',
        kind: 'apparatus',
        title: 'Laminatsiya 1',
        apparatusId: _laminationId,
        alternativeGroupId: 'alt-laminatsiya',
        alternativeGroupLabel: 'Laminatsiya',
      ),
      ProductionMapNode(
        id: 'rezka',
        kind: 'apparatus',
        title: 'Rezka',
        apparatusId: _rezkaId,
      ),
      ProductionMapNode(
        id: 'lamination-2',
        kind: 'apparatus',
        title: 'Laminatsiya 2',
        apparatusId: _lamination2Id,
        alternativeGroupId: 'alt-laminatsiya',
        alternativeGroupLabel: 'Laminatsiya',
      ),
      ProductionMapNode(id: 'end', kind: 'end', title: 'End'),
    ],
    edges: [
      ProductionMapEdge(from: 'start', to: 'print'),
      ProductionMapEdge(from: 'print', to: 'lamination-1'),
      ProductionMapEdge(from: 'print', to: 'lamination-2'),
      ProductionMapEdge(from: 'lamination-1', to: 'rezka'),
      ProductionMapEdge(from: 'lamination-2', to: 'rezka'),
      ProductionMapEdge(from: 'rezka', to: 'end'),
    ],
  );
}

ProductionMapDefinition _printingOpeningOrder({
  required String id,
  required String orderNumber,
}) {
  return ProductionMapDefinition(
    id: id,
    productCode: 'ITEM-OPENING-WIP-SWITCH',
    title: 'Opening WIP switch',
    orderNumber: orderNumber,
    nodes: const [
      ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
      ProductionMapNode(
        id: 'print',
        kind: 'apparatus',
        title: '7 ta rangli bosma aparat',
        apparatusId: _printingId,
      ),
      ProductionMapNode(
        id: 'lamination',
        kind: 'apparatus',
        title: 'Laminatsiya 1',
        apparatusId: _laminationId,
      ),
      ProductionMapNode(
        id: 'rezka',
        kind: 'apparatus',
        title: 'Rezka',
        apparatusId: _rezkaId,
      ),
      ProductionMapNode(id: 'end', kind: 'end', title: 'End'),
    ],
    edges: const [
      ProductionMapEdge(from: 'start', to: 'print'),
      ProductionMapEdge(from: 'print', to: 'lamination'),
      ProductionMapEdge(from: 'lamination', to: 'rezka'),
      ProductionMapEdge(from: 'rezka', to: 'end'),
    ],
  );
}

ProductionMapDefinition _rezkaSourceOrder() {
  return const ProductionMapDefinition(
    id: 'zakaz-opening-wip-rezka',
    productCode: 'ITEM-OPENING-WIP-REZKA',
    title: 'Rezka Opening WIP',
    orderNumber: 'OWIP-REZKA',
    nodes: [
      ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
      ProductionMapNode(
        id: 'rezka',
        kind: 'apparatus',
        title: 'Rezka',
        apparatusId: _rezkaId,
      ),
      ProductionMapNode(
        id: 'lamination',
        kind: 'apparatus',
        title: 'Laminatsiya 1',
        apparatusId: _laminationId,
      ),
      ProductionMapNode(id: 'end', kind: 'end', title: 'End'),
    ],
    edges: [
      ProductionMapEdge(from: 'start', to: 'rezka'),
      ProductionMapEdge(from: 'rezka', to: 'lamination'),
      ProductionMapEdge(from: 'lamination', to: 'end'),
    ],
  );
}
