import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/native_bluetooth_printer.dart';
import 'package:accord_mobile_v2/src/core/native_usb_printer.dart';
import 'package:accord_mobile_v2/src/core/print_service.dart';
import 'package:accord_mobile_v2/src/core/print_transport.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/gscale/gscale_mobile_app.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('material receipt print response reads RS result', () {
    final response = GScaleMaterialReceiptPrintResponse.fromJson({
      'ok': true,
      'status': 'submitted',
      'draft_name': 'MAT-STE-001',
      'epc': '000000000000000000000001',
      'item_code': 'ITEM-1',
      'item_name': 'Green Tea',
      'warehouse': 'Stores - A',
      'qty': 1.72,
      'net_qty': 1.72,
      'gross_qty': 2.5,
      'width_mm': 615,
      'micron': 13,
      'unit': 'kg',
      'printer': 'zebra',
      'print_mode': 'rfid',
      'printer_status': 'OK',
      'print_count': 5,
    });

    expect(response.ok, isTrue);
    expect(response.status, 'submitted');
    expect(response.draftName, 'MAT-STE-001');
    expect(response.netQty, 1.72);
    expect(response.grossQty, 2.5);
    expect(response.widthMm, 615);
    expect(response.micron, 13);
    expect(response.printer, 'zebra');
    expect(response.printCount, 5);
  });

  test('material receipt USB request opts into the large QR product label', () {
    const response = GScaleMaterialReceiptPrintResponse(
      ok: true,
      status: 'prepared',
      draftName: '',
      epc: '303132333435363738394142',
      itemCode: 'CPP 1030/25',
      itemName: 'CPP 1030/25',
      warehouse: 'Kalidor',
      qty: 23,
      netQty: 23,
      grossQty: 23,
      unit: 'kg',
      printer: 'godex',
      printMode: 'label',
      printerStatus: 'client_usb_pending',
      printCount: 1,
    );

    final request = response.toUsbPrintRequest(
      labelKind: 'material_product',
    );

    expect(request.epc, response.epc);
    expect(request.labelKind, 'material_product');
    expect(request.materialProductLabelTitle, 'CPP 1030/25  23 kg');
    expect(
      request.largeQrLabelFooter(request.epc),
      'EPC: 303132333435363738394142',
    );
  });

  test('receipt reprint preserves the existing EPC and prints one label', () {
    const stock = AdminRawMaterialStockEntry(
      id: 'stock-1',
      warehouse: 'Kalidor',
      itemCode: 'CPP 1030/25',
      itemName: 'CPP 1030/25',
      barcode: '303132333435363738394142',
      qty: 23,
      uom: 'kg',
      status: 'available',
      reservedOrderId: '',
      sourceReceiptId: 'MAT-STE-001',
    );
    const prepared = AdminRawMaterialStockReprintPreparation(
      reprintId: 'raw_label_123',
      stock: stock,
      printRequest: UsbRpsPrintRequest(
        epc: '303132333435363738394142',
        itemCode: 'CPP 1030/25',
        itemName: 'CPP 1030/25',
        warehouse: 'Kalidor',
        printer: 'godex',
        printMode: 'label',
        grossQty: 23,
      ),
    );
    const history = MobileArchivePrintEntry(
      itemCode: 'CPP 1030/25',
      itemName: 'CPP 1030/25',
      qty: 23,
      grossQty: 25,
      netQty: 23,
      unit: 'kg',
      printedAt: '2026-07-20T05:00:00Z',
      draftName: 'MAT-STE-001',
      epc: '303132333435363738394142',
      printMode: 'rfid',
    );

    final request = buildMaterialReceiptReprintRequest(
      prepared: prepared,
      historyEntry: history,
      printer: 'zebra',
    );

    expect(request.epc, stock.barcode);
    expect(request.printCount, 1);
    expect(request.labelKind, 'material_product');
    expect(request.grossQty, 25);
    expect(request.netQty, 23);
    expect(request.printMode, 'rfid');
  });

  test('USB print refuses repeated material labels with the same EPC',
      () async {
    const request = UsbRpsPrintRequest(
      epc: '303132333435363738394142',
      itemCode: 'CPP 1030/25',
      itemName: 'CPP 1030/25',
      warehouse: 'Kalidor',
      printer: 'godex',
      printMode: 'label',
      grossQty: 23,
      printCount: 2,
      labelKind: 'material_product',
    );

    await expectLater(PrintService.printRps(request), throwsStateError);
  });

  test('print success message distinguishes fast printed status', () {
    const response = GScaleMaterialReceiptPrintResponse(
      ok: true,
      status: 'printed',
      draftName: '',
      epc: 'EPC-1',
      itemCode: 'ITEM-1',
      itemName: 'Green Tea',
      warehouse: 'Stores - A',
      qty: 2.5,
      netQty: 2.5,
      grossQty: 2.5,
      unit: 'kg',
      printer: 'godex',
      printMode: 'label',
      printerStatus: 'sent',
      printCount: 1,
    );

    expect(
      buildPrintSuccessMessage(response),
      'Printerga yuborildi • netto 2.5 kg',
    );
    expect(
      buildPrintSuccessMessage(
        response,
        serverLabel: 'rp-scale-godex-2 @ 41257',
      ),
      'Printerga yuborildi • rp-scale-godex-2 @ 41257 • netto 2.5 kg',
    );
  });

  test('print success message includes duplicate count', () {
    const response = GScaleMaterialReceiptPrintResponse(
      ok: true,
      status: 'printed',
      draftName: '',
      epc: 'EPC-1',
      itemCode: 'ITEM-1',
      itemName: 'Green Tea',
      warehouse: 'Stores - A',
      qty: 2.5,
      netQty: 2.5,
      grossQty: 2.5,
      unit: 'kg',
      printer: 'godex',
      printMode: 'label',
      printerStatus: 'sent',
      printCount: 5,
    );

    expect(
      buildPrintSuccessMessage(response),
      'Printerga yuborildi • 5 ta • netto 2.5 kg',
    );
  });

  test('rps batch start request matches RS contract', () {
    const request = GScaleRpsBatchStartRequest(
      clientBatchId: ' batch-1 ',
      driverUrl: ' http://127.0.0.1:39117/ ',
      itemCode: ' ITEM-1 ',
      itemName: ' Green Tea ',
      warehouse: ' Stores - A ',
      printer: 'zebra',
      printMode: 'rfid',
      quantitySource: 'manual',
      manualQtyKg: 2.5,
      tareEnabled: true,
      tareKg: 0.78,
      widthMm: 615,
      micron: 13,
    );

    expect(request.toJson(), {
      'client_batch_id': 'batch-1',
      'driver_url': 'http://127.0.0.1:39117',
      'item_code': 'ITEM-1',
      'item_name': 'Green Tea',
      'warehouse': 'Stores - A',
      'printer': 'zebra',
      'print_mode': 'rfid',
      'quantity_source': 'manual',
      'manual_qty_kg': 2.5,
      'tare_enabled': true,
      'tare_kg': 0.78,
      'width_mm': 615.0,
      'micron': 13.0,
    });
  });

  test('rps batch response reads active RS session', () {
    final response = GScaleRpsBatchResponse.fromJson({
      'ok': true,
      'batch': {
        'id': 'batch-1',
        'revision': 7,
        'active': true,
        'owner_key': 'werka:+998901234567',
        'driver_url': 'http://127.0.0.1:39117',
        'item_code': 'ITEM-1',
        'item_name': 'Green Tea',
        'warehouse': 'Stores - A',
        'printer': 'zebra',
        'print_mode': 'rfid',
        'quantity_source': 'manual',
        'manual_qty_kg': 2.5,
        'tare_enabled': true,
        'tare_kg': 0.78,
        'width_mm': 615,
        'micron': 13,
        'last_error': 'submit failed',
        'last_error_at': '2026-05-19T05:00:00Z',
        'prints': [
          {
            'epc': '303132333435363738394142',
            'draft_name': 'MAT-STE-0001',
            'status': 'printed',
            'qty': 1.72,
            'net_qty': 1.72,
            'gross_qty': 2.5,
            'unit': 'kg',
            'printer': 'zebra',
            'print_mode': 'rfid',
            'print_count': 2,
            'printed_at': '2026-05-19T05:01:00Z',
          },
        ],
      },
    });

    expect(response.ok, isTrue);
    expect(response.batch.active, isTrue);
    expect(response.batch.revision, 7);
    expect(response.batch.itemCode, 'ITEM-1');
    expect(response.batch.displayItemName, 'Green Tea');
    expect(response.batch.driverUrl, 'http://127.0.0.1:39117');
    expect(response.batch.quantitySource, 'manual');
    expect(response.batch.tareEnabled, isTrue);
    expect(response.batch.widthMm, 615);
    expect(response.batch.micron, 13);
    expect(response.batch.lastError, 'submit failed');
    expect(response.batch.lastErrorAt, '2026-05-19T05:00:00Z');
    expect(response.batch.prints, hasLength(1));
    expect(response.batch.prints.single.epc, '303132333435363738394142');
    expect(response.batch.prints.single.grossQty, 2.5);
    expect(response.batch.prints.single.printCount, 2);
  });

  test('completed RS batch maps to device-independent print history', () {
    final batch = GScaleRpsBatchSession.fromJson({
      'id': 'batch-history-1',
      'batch_code': '421234567890ABCDEF123456',
      'active': false,
      'item_code': 'ITEM-1',
      'item_name': 'Green Tea',
      'warehouse': 'Stores - A',
      'printer': 'zebra',
      'print_mode': 'rfid',
      'quantity_source': 'manual',
      'manual_qty_kg': 2.5,
      'tare_enabled': true,
      'tare_kg': 0.5,
      'created_at': '2026-07-20T05:00:00Z',
      'updated_at': '2026-07-20T05:05:00Z',
      'prints': [
        {
          'epc': '303132333435363738394142',
          'draft_name': 'MAT-STE-0001',
          'status': 'submitted',
          'qty': 2.0,
          'net_qty': 2.0,
          'gross_qty': 2.5,
          'unit': 'kg',
          'printer': 'zebra',
          'print_mode': 'rfid',
          'print_count': 1,
          'printed_at': '2026-07-20T05:02:00Z',
        },
      ],
    });

    final history = MobileArchiveSession.fromRpsBatch(batch);

    expect(history.sessionId, 'batch-history-1');
    expect(history.batchCode, '421234567890ABCDEF123456');
    expect(history.startedAt, '2026-07-20T05:00:00Z');
    expect(history.endedAt, '2026-07-20T05:05:00Z');
    expect(history.printCount, 1);
    expect(history.grossQty, 2.5);
    expect(history.netQty, 2.0);
    expect(history.prints.single.epc, '303132333435363738394142');
    expect(history.prints.single.status, 'submitted');
  });

  test('material batch reprint uses aggregate weight and a batch QR', () {
    const prints = [
      MobileArchivePrintEntry(
        itemCode: 'CPP 1030/25',
        itemName: 'CPP 1030/25',
        qty: 23,
        grossQty: 23,
        netQty: 23,
        unit: 'kg',
        printedAt: '',
        draftName: 'MAT-STE-1',
        epc: '400100000000000000000001',
      ),
      MobileArchivePrintEntry(
        itemCode: 'CPP 1030/25',
        itemName: 'CPP 1030/25',
        qty: 23,
        grossQty: 23,
        netQty: 23,
        unit: 'kg',
        printedAt: '',
        draftName: 'MAT-STE-2',
        epc: '400100000000000000000002',
      ),
      MobileArchivePrintEntry(
        itemCode: 'CPP 1030/25',
        itemName: 'CPP 1030/25',
        qty: 23,
        grossQty: 23,
        netQty: 23,
        unit: 'kg',
        printedAt: '',
        draftName: 'MAT-STE-3',
        epc: '400100000000000000000003',
      ),
      MobileArchivePrintEntry(
        itemCode: 'CPP 1030/25',
        itemName: 'CPP 1030/25',
        qty: 23,
        grossQty: 23,
        netQty: 23,
        unit: 'kg',
        printedAt: '',
        draftName: 'MAT-STE-4',
        epc: '400100000000000000000004',
      ),
    ];
    const session = MobileArchiveSession(
      sessionId: 'batch-history-92',
      batchCode: '42A1234567890ABCDEF12345',
      active: false,
      itemCode: 'CPP 1030/25',
      itemName: 'CPP 1030/25',
      warehouse: 'Kalidor',
      startedAt: '',
      endedAt: '',
      totalQty: 92,
      grossQty: 92,
      netQty: 92,
      unit: 'kg',
      tareEnabled: false,
      tareKg: 0,
      printCount: 4,
      prints: prints,
    );

    final plan = buildMaterialBatchPrintPlan(session);
    final request = plan.toDriverRequest(printer: 'zebra');

    expect(plan.grossQty, 92);
    expect(plan.netQty, 92);
    expect(plan.qrPayload, 'RPS-BATCH:42A1234567890ABCDEF12345');
    expect(
      plan.toUsbRequest(printer: 'godex').largeQrLabelFooter(plan.qrPayload),
      'BATCH ID: 42A1234567890ABCDEF12345',
    );
    expect(prints.map((entry) => entry.epc), isNot(contains(plan.qrPayload)));
    expect(request['gross_qty'], 92);
    expect(request['print_mode'], 'label');
    expect(request['label_kind'], 'qolip_code');
    expect(request['print_count'], 1);
  });

  test('material batch QR keeps legacy fallback and rejects a corrupt code',
      () {
    const legacy = MobileArchiveSession(
      sessionId: 'legacy-batch-1',
      active: false,
      itemCode: 'ITEM-1',
      itemName: 'Green Tea',
      warehouse: 'Stores - A',
      startedAt: '',
      endedAt: '',
      totalQty: 1,
      grossQty: 1,
      netQty: 1,
      unit: 'kg',
      tareEnabled: false,
      tareKg: 0,
      printCount: 1,
      prints: [],
    );
    expect(
      buildMaterialBatchPrintPlan(legacy).qrPayload,
      'RPS-BATCH:LEGACY-BATCH-1',
    );

    const corrupt = MobileArchiveSession(
      sessionId: 'batch-2',
      batchCode: 'NOT-A-BATCH-CODE',
      active: false,
      itemCode: 'ITEM-1',
      itemName: 'Green Tea',
      warehouse: 'Stores - A',
      startedAt: '',
      endedAt: '',
      totalQty: 1,
      grossQty: 1,
      netQty: 1,
      unit: 'kg',
      tareEnabled: false,
      tareKg: 0,
      printCount: 1,
      prints: [],
    );
    expect(
      () => buildMaterialBatchPrintPlan(corrupt),
      throwsA(isA<StateError>()),
    );
  });

  testWidgets(
    'material control restores active manual batch without selected device',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await saveOperatorControlDraft(
        const OperatorControlDraft(
          itemCode: 'STALE-ITEM',
          itemName: 'Stale product',
          warehouse: 'Wrong warehouse',
          printMode: 'rfid',
          printer: 'zebra',
          quantitySource: 'manual',
          manualQtyText: '',
          manualDuplicateText: '',
          babinaEnabled: false,
          babinaText: '',
          warehouseMode: 'manual',
          defaultWarehouse: '',
        ),
      );
      AppSession.instance.token = 'token';
      AppSession.instance.profile = const SessionProfile(
        role: UserRole.materialTaminotchi,
        displayName: 'Materialchi',
        legalName: '',
        ref: 'MAT-RECOVERY',
        phone: '+998900000001',
        avatarUrl: '',
        capabilities: ['rps.batch.manage', 'gscale.print'],
        assignedItemGroups: ['Rulon'],
      );
      var stateLoadCount = 0;
      const activeBatch = GScaleRpsBatchSession(
        id: 'batch-active-1',
        revision: 1,
        active: true,
        driverUrl: 'usb://local',
        itemCode: 'ITEM-1',
        itemName: 'Green Tea',
        warehouse: 'Kalidor',
        printer: 'godex',
        printMode: 'label',
        quantitySource: 'manual',
        manualQtyKg: 23,
        tareEnabled: false,
        tareKg: 0,
      );
      const offlinePrinter = UsbPrinterProfile(
        kind: UsbPrinterKind.godex,
        deviceName: 'usb:test',
        vendorId: 1,
        productId: 2,
        manufacturerName: 'GoDEX',
        productName: 'G500',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OperatorDashboardPage(
              server: null,
              printTransport: PrintTransport.offline,
              offlinePrinter: offlinePrinter,
              controlOnly: true,
              onExitMode: () async {},
              onChangeServer: () async {},
              rpsBatchStateLoader: () async {
                stateLoadCount++;
                return const GScaleRpsBatchResponse(
                  ok: true,
                  batch: activeBatch,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(stateLoadCount, 1);
      expect(find.text('Green Tea • Kalidor'), findsOneWidget);
      expect(find.text('ITEM-1'), findsOneWidget);
      expect(find.text('STALE-ITEM'), findsNothing);
      expect(find.text('Wrong warehouse'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Batch stop'),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        find.widgetWithText(FilledButton, 'Batch start'),
        findsNothing,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Qo‘lda brutto kg'),
        '23',
      );
      await tester.pump();

      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Chop etish'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'admin bluetooth selection resolves batch state and enables batch start',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await saveOperatorControlDraft(
        const OperatorControlDraft(
          itemCode: 'OPP-445-20',
          itemName: 'opp 445/20',
          warehouse: 'b blok',
          printMode: 'label',
          printer: 'xp-p323b',
          quantitySource: 'manual',
          manualQtyText: '10',
          manualDuplicateText: '',
          babinaEnabled: false,
          babinaText: '',
          warehouseMode: 'manual',
          defaultWarehouse: '',
        ),
      );
      AppSession.instance.token = 'token';
      AppSession.instance.profile = const SessionProfile(
        role: UserRole.admin,
        displayName: 'Admin',
        legalName: '',
        ref: 'admin',
        phone: '+998880000000',
        avatarUrl: '',
        capabilities: ['rps.batch.manage', 'gscale.print'],
      );
      var stateLoadCount = 0;
      const bluetoothPrinter = BluetoothPrinterProfile(
        name: 'XP-P323B-3972',
        address: '00:11:22:33:44:55',
      );

      Widget dashboard({
        required PrintTransport transport,
        BluetoothPrinterProfile? printer,
      }) {
        return MaterialApp(
          home: Scaffold(
            body: OperatorDashboardPage(
              server: null,
              printTransport: transport,
              bluetoothPrinter: printer,
              onExitMode: () async {},
              onChangeServer: () async {},
              rpsBatchStateLoader: () async {
                stateLoadCount++;
                return const GScaleRpsBatchResponse(
                  ok: true,
                  batch: GScaleRpsBatchSession(
                    id: '',
                    active: false,
                    driverUrl: '',
                    itemCode: '',
                    itemName: '',
                    warehouse: '',
                    printer: '',
                    printMode: 'label',
                    quantitySource: 'manual',
                    manualQtyKg: 0,
                    tareEnabled: false,
                    tareKg: 0,
                  ),
                );
              },
            ),
          ),
        );
      }

      await tester.pumpWidget(dashboard(transport: PrintTransport.wifi));
      await tester.pumpAndSettle();
      expect(stateLoadCount, 0);

      await tester.pumpWidget(
        dashboard(
          transport: PrintTransport.bluetooth,
          printer: bluetoothPrinter,
        ),
      );
      await tester.pumpAndSettle();

      expect(stateLoadCount, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Batch start'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'receipt long press opens its EPC instead of the batch QR action',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      AppSession.instance.token = 'token';
      AppSession.instance.profile = const SessionProfile(
        role: UserRole.materialTaminotchi,
        displayName: 'Materialchi',
        legalName: '',
        ref: 'MAT-HISTORY',
        phone: '+998900000002',
        avatarUrl: '',
        capabilities: ['rps.batch.manage', 'gscale.print'],
        assignedItemGroups: ['Rulon'],
      );
      const receiptEpc = '303132333435363738394142';
      const historyBatch = GScaleRpsBatchSession(
        id: 'batch-history-receipt-1',
        batchCode: '421234567890ABCDEF123456',
        active: false,
        driverUrl: 'usb://local',
        itemCode: 'CPP 1030/25',
        itemName: 'CPP 1030/25',
        warehouse: 'Kalidor',
        printer: 'godex',
        printMode: 'label',
        quantitySource: 'manual',
        manualQtyKg: 23,
        tareEnabled: false,
        tareKg: 0,
        createdAt: '2026-07-20T07:00:00Z',
        updatedAt: '2026-07-20T07:01:00Z',
        prints: [
          GScaleRpsBatchPrintEntry(
            epc: receiptEpc,
            draftName: 'MAT-STE-001',
            status: 'submitted',
            qty: 23,
            netQty: 23,
            grossQty: 23,
            unit: 'kg',
            printer: 'godex',
            printMode: 'label',
            printCount: 1,
            printedAt: '2026-07-20T07:00:30Z',
          ),
        ],
      );
      const offlinePrinter = UsbPrinterProfile(
        kind: UsbPrinterKind.godex,
        deviceName: 'usb:test',
        vendorId: 1,
        productId: 2,
        manufacturerName: 'GoDEX',
        productName: 'G500',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OperatorDashboardPage(
              server: null,
              printTransport: PrintTransport.offline,
              offlinePrinter: offlinePrinter,
              controlOnly: true,
              onExitMode: () async {},
              onChangeServer: () async {},
              rpsBatchStateLoader: () async => const GScaleRpsBatchResponse(
                ok: true,
                batch: historyBatch,
              ),
              rpsBatchHistoryLoader: () async => const [historyBatch],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(Tab, 'Print tarixi'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('batch-qr-print-batch-history-receipt-1')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey('batch-history-batch-history-receipt-1'),
        ),
      );
      await tester.pumpAndSettle();
      final receipt = find.byKey(
        const ValueKey('batch-receipt-303132333435363738394142'),
      );
      expect(receipt, findsOneWidget);

      await tester.longPress(receipt);
      await tester.pumpAndSettle();

      expect(find.text('Chop etilgan QR'), findsOneWidget);
      expect(find.text(receiptEpc), findsOneWidget);
      expect(find.text('Partiya QR chop etish'), findsNothing);
    },
  );

  test('batch already active API error is recognized for state recovery', () {
    const error = MobileApiException(
      code: 'batch_already_active',
      message: 'batch already active',
      statusCode: 409,
    );

    expect(isRpsBatchAlreadyActiveError(error), isTrue);
    expect(
      rpsBatchActionErrorMessage(
        const MobileApiException(
          code: 'batch_context_conflict',
          message: 'batch context conflict',
        ),
      ),
      contains('Eski mahsulot chop etilmadi'),
    );
    expect(
      rpsBatchActionErrorMessage(
        const MobileApiException(
          code: 'batch_store_failed',
          message: 'store failed',
        ),
      ),
      contains('Amal bekor qilindi'),
    );
    expect(
      isRpsBatchAlreadyActiveError(
        const MobileApiException(
          code: 'batch_store_failed',
          message: 'store failed',
        ),
      ),
      isFalse,
    );
  });

  test('mobile batch state accepts RS batch session shape', () {
    final batch = MobileBatchState.fromJson({
      'active': true,
      'batch_code': '421234567890ABCDEF123456',
      'item_code': 'ITEM-1',
      'item_name': 'Green Tea',
      'warehouse': 'Stores - A',
      'printer': 'zebra',
      'print_mode': 'rfid',
      'quantity_source': 'scale',
      'manual_qty_kg': 0,
      'tare_enabled': true,
      'tare_kg': 0.78,
    });

    expect(batch.active, isTrue);
    expect(batch.batchCode, '421234567890ABCDEF123456');
    expect(batch.displayItemName, 'Green Tea');
    expect(batch.tareEnabled, isTrue);
    expect(batch.tareKg, 0.78);
  });

  test('mobile batch state can be built from RS API model', () {
    const rsBatch = GScaleRpsBatchSession(
      id: 'batch-1',
      batchCode: '421234567890ABCDEF123456',
      active: true,
      driverUrl: 'http://127.0.0.1:39117',
      itemCode: 'ITEM-1',
      itemName: 'Green Tea',
      warehouse: 'Stores - A',
      printer: 'zebra',
      printMode: 'rfid',
      quantitySource: 'scale',
      manualQtyKg: 0,
      tareEnabled: true,
      tareKg: 0.78,
      lastError: 'submit failed',
      lastErrorAt: '2026-05-19T05:00:00Z',
    );

    final snapshot = MonitorSnapshot.empty().copyWithBatch(
      MobileBatchState.fromRpsBatch(rsBatch),
    );

    expect(snapshot.batchActive, isTrue);
    expect(snapshot.batchItemCode, 'ITEM-1');
    expect(snapshot.batchItemName, 'Green Tea');
    expect(snapshot.batchWarehouse, 'Stores - A');
    expect(snapshot.batchTareEnabled, isTrue);
    expect(snapshot.batchLastError, 'submit failed');
  });

  test('late ERP batch error message and auto-stop decision are clear', () {
    const batch = GScaleRpsBatchSession(
      id: 'batch-1',
      active: true,
      driverUrl: 'http://127.0.0.1:39117',
      itemCode: 'ITEM-1',
      itemName: 'Green Tea',
      warehouse: 'Stores - A',
      printer: 'godex',
      printMode: 'label',
      quantitySource: 'scale',
      manualQtyKg: 0,
      tareEnabled: false,
      tareKg: 0,
      lastError: 'submit failed: NegativeStockError',
      lastErrorAt: '2026-05-19T05:00:00Z',
    );

    expect(
      buildRsBatchErpErrorMessage(batch.lastError),
      'ERPNext tasdiqlashda xatolik yuz berdi: submit failed: NegativeStockError',
    );
    expect(
      shouldStopRsBatchAfterLateError(batch: batch, seenErrorKey: ''),
      isTrue,
    );
    expect(
      shouldStopRsBatchAfterLateError(
        batch: batch,
        seenErrorKey: rsBatchLateErrorKey(batch),
      ),
      isFalse,
    );
  });

  test('monitor snapshot reads connected GoDEX printer state', () {
    final snapshot = MonitorSnapshot.fromJson({
      'ok': true,
      'state': {
        'scale': {
          'source': 'serial',
          'port': '/dev/pts/0',
          'weight': 2.5,
          'unit': 'kg',
          'stable': true,
          'error': '',
        },
        'zebra': {'verify': 'idle', 'action': 'printer state'},
        'printer': {
          'ok': true,
          'connected': true,
          'kind': 'godex',
          'label': 'ulangan',
          'device_paths': ['/dev/usb/lp2'],
          'error': '',
        },
        'batch': {
          'active': false,
          'printer': 'godex',
          'print_mode': 'label',
          'quantity_source': 'scale',
        },
        'print_request': {'status': 'idle'},
      },
    });

    expect(snapshot.scaleValue, '2.5 kg');
    expect(snapshot.scaleStable, isTrue);
    expect(snapshot.scaleConnectionLabel, 'Scale: ulangan');
    expect(snapshot.printerLabel, 'ulangan');
    expect(snapshot.printerKind, 'godex');
    expect(snapshot.livePrinterChoice, 'godex');
    expect(snapshot.batchPrinter, 'godex');
    expect(snapshot.batchPrintMode, 'label');
  });

  test('live monitor keeps active RS batch session state', () {
    const rsBatch = GScaleRpsBatchSession(
      id: 'batch-1',
      active: true,
      driverUrl: 'http://127.0.0.1:39117',
      itemCode: 'ITEM-1',
      itemName: 'Green Tea',
      warehouse: 'Stores - A',
      printer: 'godex',
      printMode: 'label',
      quantitySource: 'scale',
      manualQtyKg: 0,
      tareEnabled: true,
      tareKg: 0.78,
    );
    final previous = MonitorSnapshot.empty().copyWithBatch(
      MobileBatchState.fromRpsBatch(rsBatch),
    );
    final live = MonitorSnapshot.fromJson({
      'ok': true,
      'state': {
        'scale': {
          'source': 'serial',
          'port': '/dev/pts/0',
          'weight': 2.75,
          'unit': 'kg',
          'stable': true,
          'error': '',
        },
        'zebra': {'verify': 'idle', 'action': 'printer state'},
        'printer': {
          'ok': true,
          'connected': true,
          'kind': 'godex',
          'label': 'ulangan',
        },
        'batch': {
          'active': false,
          'printer': 'godex',
          'print_mode': 'label',
          'quantity_source': 'scale',
        },
        'print_request': {'status': 'idle'},
      },
    });

    final merged = mergeLiveMonitorWithRsBatch(live, previous);

    expect(merged.scaleValue, '2.75 kg');
    expect(merged.scaleStable, isTrue);
    expect(merged.printerKind, 'godex');
    expect(merged.batchActive, isTrue);
    expect(merged.batchItemCode, 'ITEM-1');
    expect(merged.batchItemName, 'Green Tea');
    expect(merged.batchWarehouse, 'Stores - A');
    expect(merged.batchPrinter, 'godex');
    expect(merged.batchPrintMode, 'label');
  });

  test('live monitor does not resurrect stopped RS batch session', () {
    final previous = MonitorSnapshot.empty().copyWithBatch(
      const MobileBatchState(
        active: false,
        itemCode: 'ITEM-1',
        itemName: 'Green Tea',
        warehouse: 'Stores - A',
        printer: 'godex',
        printMode: 'label',
        quantitySource: 'scale',
        manualQtyKg: 0,
        tareEnabled: false,
        tareKg: 0,
      ),
    );
    final live = MonitorSnapshot.fromJson({
      'ok': true,
      'state': {
        'scale': {'weight': 2.75, 'unit': 'kg', 'stable': true},
        'printer': {'connected': true, 'kind': 'godex', 'label': 'ulangan'},
        'batch': {'active': false, 'printer': 'godex'},
        'print_request': {'status': 'idle'},
      },
    });

    final merged = mergeLiveMonitorWithRsBatch(live, previous);

    expect(merged.batchActive, isFalse);
    expect(merged.batchItemCode, '');
  });

  test('rps batch start helper carries current print controls', () {
    final request = buildGScaleRpsBatchStartRequest(
      driverUrl: 'http://127.0.0.1:39117',
      item: const MobileItem(itemCode: 'ITEM-1', itemName: 'Green Tea'),
      warehouse: 'Stores - A',
      printer: 'zebra',
      printMode: 'rfid',
      quantitySource: 'scale',
      manualQtyKg: 0,
      tareEnabled: true,
      tareKg: 0.78,
      widthMm: 615,
      micron: 13,
    );

    expect(request.toJson(), {
      'client_batch_id': '',
      'driver_url': 'http://127.0.0.1:39117',
      'item_code': 'ITEM-1',
      'item_name': 'Green Tea',
      'warehouse': 'Stores - A',
      'printer': 'zebra',
      'print_mode': 'rfid',
      'quantity_source': 'scale',
      'manual_qty_kg': 0,
      'tare_enabled': true,
      'tare_kg': 0.78,
      'width_mm': 615.0,
      'micron': 13.0,
    });
  });

  test('rps batch print helper sends gross qty and driver url', () {
    const batch = GScaleRpsBatchSession(
      id: 'batch-1',
      revision: 7,
      active: true,
      driverUrl: 'usb://local',
      itemCode: 'ITEM-1',
      itemName: 'Green Tea',
      warehouse: 'Stores - A',
      printer: 'godex',
      printMode: 'label',
      quantitySource: 'manual',
      manualQtyKg: 0,
      tareEnabled: false,
      tareKg: 0,
    );
    final request = buildGScaleRpsBatchPrintRequest(
      batch: batch,
      grossQtyKg: 2.5,
      driverUrl: ' http://127.0.0.1:39117/ ',
      printCount: 5,
    );

    expect(request.toJson(), {
      'batch_id': 'batch-1',
      'expected_revision': 7,
      'expected_item_code': 'ITEM-1',
      'expected_warehouse': 'Stores - A',
      'gross_qty': 2.5,
      'unit': 'kg',
      'driver_url': 'http://127.0.0.1:39117',
      'print_count': 5,
    });
    expect(GScaleRpsBatchStopRequest.fromBatch(batch).toJson(), {
      'batch_id': 'batch-1',
      'expected_revision': 7,
    });
    expect(hasExactRpsBatchContext(batch), isTrue);
    expect(
      hasExactRpsBatchContext(
        const GScaleRpsBatchSession(
          id: 'batch-without-revision',
          active: true,
          driverUrl: 'usb://local',
          itemCode: 'ITEM-1',
          itemName: 'Green Tea',
          warehouse: 'Stores - A',
          printer: 'godex',
          printMode: 'label',
          quantitySource: 'manual',
          manualQtyKg: 0,
          tareEnabled: false,
          tareKg: 0,
        ),
      ),
      isFalse,
    );
  });

  test(
    'manual duplicate count parser defaults to one and rejects invalid input',
    () {
      expect(parseManualDuplicateCount(''), 1);
      expect(parseManualDuplicateCount(' 5 '), 5);
      expect(parseManualDuplicateCount('0'), isNull);
      expect(parseManualDuplicateCount('1.5'), isNull);
      expect(parseManualDuplicateCount('101'), isNull);
    },
  );

  test('auto batch print triggers once per stable scale reading', () {
    final key = autoBatchPrintKey(
      grossKg: 2.75,
      scaleStable: true,
      babinaEnabled: false,
      babinaText: '',
    );

    expect(key, '2.750');
    expect(
      shouldTriggerAutoBatchPrint(
        batchActive: true,
        loading: false,
        stablePrintKey: key,
        lastPrintedKey: '',
      ),
      isTrue,
    );
    expect(
      shouldTriggerAutoBatchPrint(
        batchActive: true,
        loading: false,
        stablePrintKey: key,
        lastPrintedKey: key,
      ),
      isFalse,
    );
    expect(
      autoBatchPrintKey(
        grossKg: 2.75,
        scaleStable: false,
        babinaEnabled: false,
        babinaText: '',
      ),
      '',
    );
    expect(
      autoBatchPrintKey(
        grossKg: 0.05,
        scaleStable: true,
        babinaEnabled: false,
        babinaText: '',
      ),
      '',
    );
  });

  test('scale batch action becomes stop while batch is active', () {
    expect(
      canPressScaleBatchAction(
        hasPrintSelection: true,
        batchActive: false,
        manualPrintLoading: false,
        batchActionLoading: false,
      ),
      isTrue,
    );
    expect(
      scaleBatchActionLabel(loading: false, batchActive: false),
      'Batch start',
    );
    expect(
      canPressScaleBatchAction(
        hasPrintSelection: false,
        batchActive: true,
        manualPrintLoading: false,
        batchActionLoading: false,
      ),
      isTrue,
    );
    expect(
      scaleBatchActionLabel(loading: false, batchActive: true),
      'Batch stop',
    );
    expect(
      canPressScaleBatchAction(
        hasPrintSelection: true,
        batchActive: true,
        manualPrintLoading: false,
        batchActionLoading: true,
      ),
      isFalse,
    );
  });

  test('scale display kg parser accepts monitor label', () {
    expect(parseScaleDisplayKg('2.500 kg'), 2.5);
    expect(parseScaleDisplayKg('2,500 kg'), 2.5);
    expect(parseScaleDisplayKg('--'), isNull);
  });
}
