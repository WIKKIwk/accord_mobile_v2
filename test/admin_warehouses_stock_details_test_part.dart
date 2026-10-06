part of 'admin_warehouses_screen_test.dart';

void _registerWarehouseStockDetailsTests() {
  for (final status in ['available', 'reserved', 'in_use', 'consumed']) {
    testWidgets('admin warehouse detailed stock and QR reprint: $status',
        (tester) async {
      final fixture = _WarehouseStockDetailFixture(status: status);
      await TestModeController.instance.setEnabled(false);
      final printCalls = <MethodCall>[];
      _mockWarehousePrinter(tester, printCalls);
      await fixture.run(() async {
        await _pumpWarehousesScreen(tester);
        await _selectWarehouse(tester, fixture.warehouse);
        await tester.binding.setSurfaceSize(const Size(390, 850));
        await tester.pumpAndSettle();
        if (status != 'available') {
          await tester.tap(find.text('Band qilingan (1)'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('BOPP 384/12'));
        await tester.pumpAndSettle();

        final sheet = find.byType(BottomSheet);
        Finder detail(String text) =>
            find.descendant(of: sheet, matching: find.text(text));
        expect(detail(fixture.warehouse), findsOneWidget);
        expect(detail('100 kg'), findsOneWidget);
        expect(detail('384 mm'), findsOneWidget);
        expect(detail('12'), findsOneWidget);
        expect(detail('1860 m'), findsOneWidget);
        expect(detail('GSR-30AA'), findsOneWidget);
        expect(find.byKey(const ValueKey('raw-stock-edit-30AA')), findsNothing);
        if (status != 'available') {
          expect(detail('Band qilish sababi'), findsOneWidget);
          expect(detail('“Day poroshok 3 kg” buyurtmasi uchun xomashyo'),
              findsOneWidget);
          expect(detail('Day salfetka'), findsOneWidget);
          expect(detail('8 ta rangli bosma aparat'), findsOneWidget);
          expect(detail('Ulug‘bek'), findsOneWidget);
          expect(detail(formatParsedLocalDateTimeOrRaw('2026-09-28T13:00:00Z')),
              findsOneWidget);
          expect(find.textContaining('Qabul:'), findsOneWidget);
        }

        final qrButton = find.byKey(const ValueKey('raw-stock-qr-30AA'));
        await tester.ensureVisible(qrButton);
        await tester.tap(qrButton);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('raw-stock-qr-preview-30AA')),
            findsOneWidget);
        final reprint = find.byKey(const ValueKey('raw-stock-qr-reprint'));
        await tester.ensureVisible(reprint);
        await tester.tap(reprint);
        await tester.pumpAndSettle();
        expect(fixture.prepares.single, {
          'barcode': '30AA',
          if (status != 'available') 'order_id': fixture.orderId,
        });
        expect(fixture.confirms.single,
            {'barcode': '30AA', 'reprint_id': 'reprint-stock-test'});
        expect(printCalls.map((call) => call.method),
            ['detectPrinter', 'printRaw']);
        expect(find.text('Mavjud QR qayta chop etildi'), findsOneWidget);
        expect(fixture.stock['qty'], 100);
        expect(fixture.stock['status'], status);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    });
  }

  testWidgets(
      'admin reserved stock fallback resolves order and retries details',
      (tester) async {
    final fixture = _WarehouseStockDetailFixture(
        status: 'reserved', includeAssignment: false, orderReadFailures: 1);
    await TestModeController.instance.setEnabled(false);
    await fixture.run(() async {
      await _pumpWarehousesScreen(tester);
      await _selectWarehouse(tester, fixture.warehouse);
      await tester.tap(find.text('Band qilingan (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BOPP 384/12'));
      await tester.pumpAndSettle();
      expect(find.text(fixture.orderId), findsOneWidget);
      final retry = find.text('Buyurtma ma’lumoti yuklanmadi. Qayta urinish');
      expect(retry, findsOneWidget);
      expect(find.byKey(const ValueKey('raw-stock-qr-30AA')), findsOneWidget);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text('“Day poroshok 3 kg” buyurtmasi uchun xomashyo'),
          findsOneWidget);
      expect(fixture.orderReads, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });

  for (final failure in ['printer', 'identity']) {
    testWidgets('admin stock QR $failure failure does not confirm reprint',
        (tester) async {
      final fixture = _WarehouseStockDetailFixture(
          status: 'reserved', mismatchedIdentity: failure == 'identity');
      await TestModeController.instance.setEnabled(false);
      final printCalls = <MethodCall>[];
      _mockWarehousePrinter(tester, printCalls, fails: failure == 'printer');
      await fixture.run(() async {
        await _pumpWarehousesScreen(tester);
        await _selectWarehouse(tester, fixture.warehouse);
        await tester.tap(find.text('Band qilingan (1)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('BOPP 384/12'));
        await tester.pumpAndSettle();
        final qrButton = find.byKey(const ValueKey('raw-stock-qr-30AA'));
        await tester.ensureVisible(qrButton);
        await tester.tap(qrButton);
        await tester.pumpAndSettle();
        final reprint = find.byKey(const ValueKey('raw-stock-qr-reprint'));
        await tester.ensureVisible(reprint);
        await tester.tap(reprint);
        await tester.pumpAndSettle();
        expect(fixture.confirms, isEmpty);
        expect(find.text('Mavjud QR qayta chop etildi'), findsNothing);
        if (failure == 'identity') {
          expect(printCalls, isEmpty);
          expect(find.text('Serverdagi QR identifikatori mos kelmadi'),
              findsOneWidget);
        } else {
          expect(printCalls.last.method, 'printRaw');
          expect(
              find.text('QR kodini qayta chop etib bo‘lmadi'), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    });
  }
}

void _mockWarehousePrinter(WidgetTester tester, List<MethodCall> calls,
    {bool fails = false}) {
  const channel = MethodChannel('accord/usb_printer');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
      (call) async {
    calls.add(call);
    if (call.method == 'detectPrinter') return {'printer': 'godex'};
    if (fails) throw PlatformException(code: 'printer_unavailable');
    return {'ok': true};
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));
}

class _WarehouseStockDetailFixture {
  _WarehouseStockDetailFixture(
      {required this.status,
      this.includeAssignment = true,
      this.orderReadFailures = 0,
      this.mismatchedIdentity = false});

  final String status;
  final bool includeAssignment;
  final bool mismatchedIdentity;
  int orderReadFailures;
  int orderReads = 0;
  final warehouse = 'Ulug‘bek ombori';
  final orderId = 'zakaz-0024';
  final prepares = <Map<String, dynamic>>[];
  final confirms = <Map<String, dynamic>>[];

  Future<void> run(Future<void> Function() body) => HttpOverrides.runZoned(
        () => http.runWithClient(body, client),
        createHttpClient: (_) => _WarehouseNoLiveHttpClient(),
      );

  Map<String, dynamic> get stock => {
        'id': 'raw:30aa',
        'warehouse': warehouse,
        'item_code': 'BOPP',
        'item_name': 'BOPP 384/12',
        'barcode': '30AA',
        'qty': 100,
        'width_mm': 384,
        'micron': 12,
        'length_m': 1860,
        'uom': 'kg',
        'status': status,
        'reserved_order_id': status == 'available' ? '' : orderId,
        'source_receipt_id': 'GSR-30AA',
      };

  MockClient client() => MockClient((request) async {
        Object payload;
        switch (request.url.path) {
          case '/v1/mobile/admin/warehouses/summary':
            payload = [
              {
                'warehouse': warehouse,
                'product_count': 1,
                'reserved_count': status == 'available' ? 0 : 1
              }
            ];
          case '/v1/mobile/admin/warehouses/assignments':
          case '/v1/mobile/admin/warehouses/items':
            payload = [];
          case '/v1/mobile/admin/raw-material-stock':
            payload = [stock];
          case '/v1/mobile/admin/raw-material-assignments':
            payload = status == 'available' || !includeAssignment
                ? []
                : [
                    {
                      'order_id': orderId,
                      'apparatus': 'apparatus:catalog:bosma8',
                      'barcode': '30AA',
                      'item_code': 'BOPP',
                      'item_name': 'BOPP 384/12',
                      'item_group': 'Rulon',
                      'assigned_by_display_name': 'Ulug‘bek',
                      'assigned_at': '2026-09-28T13:00:00Z',
                      'stock_status': status,
                      'stock_qty': 100,
                      'stock_uom': 'kg',
                      'stock_warehouse': warehouse,
                      'received_qty': status == 'reserved' ? 0 : 100,
                      'consumed_qty': status == 'consumed' ? 100 : 0,
                      'remaining_qty': status == 'in_use' ? 100 : 0,
                    }
                  ];
          case '/v1/mobile/admin/apparatus':
            payload = [
              {
                'apparatus_id': 'apparatus:catalog:bosma8',
                'display': {'display_name': '8 ta rangli bosma aparat'},
                'source_revision': 1,
                'source_aasx_sha256': 'a'.padRight(64, 'a'),
                'execution_profile': {
                  'operation': 'print',
                  'technology': 'gravure'
                },
                'capabilities': {'print': 1}
              }
            ];
          case '/v1/mobile/admin/inventory/locations':
            payload = [
              {
                'id': 'inventory_location:warehouse:ulugbek',
                'kind': 'warehouse',
                'name': warehouse,
                'warehouse_id': 'warehouse:ulugbek'
              }
            ];
          case '/v1/mobile/admin/inventory/assets':
            payload = [
              {
                'kind': 'raw_material',
                'asset_ref': 'raw:30aa',
                'custody_warehouse_id': 'warehouse:ulugbek',
                'identifier': '30AA',
                'physical_location': {
                  'id': 'inventory_location:warehouse:ulugbek',
                  'kind': 'warehouse',
                  'name': warehouse
                }
              }
            ];
          case '/v1/mobile/admin/production-maps':
            expect(request.url.queryParameters['id'], orderId);
            orderReads++;
            if (orderReadFailures-- > 0) {
              return http.Response(
                  '{"error":"production_map_load_failed"}', 500);
            }
            payload = {
              'map': {
                'id': orderId,
                'product_code': 'DAY',
                'title': 'Day poroshok 3 kg',
                'customer_name': 'Day salfetka',
                'nodes': [],
                'edges': []
              },
              'program': {}
            };
          case '/v1/mobile/admin/raw-material-stock/reprint/prepare':
            prepares.add(jsonDecode(request.body) as Map<String, dynamic>);
            payload = {
              'reprint_id': 'reprint-stock-test',
              'stock': stock,
              'print': {
                'epc': mismatchedIdentity ? 'OTHER-QR' : '30AA',
                'item_code': 'BOPP',
                'item_name': 'BOPP 384/12',
                'warehouse': warehouse,
                'gross_qty': 100,
                'unit': 'kg',
                'label_kind': 'material_product',
                'printer': 'godex'
              }
            };
          case '/v1/mobile/admin/raw-material-stock/reprint/confirm':
            confirms.add(jsonDecode(request.body) as Map<String, dynamic>);
            payload = {'ok': true};
          default:
            fail('Unexpected warehouse request: ${request.url}');
        }
        return http.Response(jsonEncode(payload), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
}

// The HTTP fixtures cover stock reads and writes; no external live socket is
// required for these widget tests.
class _WarehouseNoLiveHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) => Future.error(
      const SocketException('Live socket disabled in widget test'));

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => getUrl(url);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
