import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/inventory/inventory_view_store.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_summary_card.dart';
import 'package:accord_mobile_v2/src/features/inventory/presentation/inventory_movements_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    InventoryViewStore.instance.reset();
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'inventory-lazy-loading-token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.materialTaminotchi,
      displayName: 'Materialchi',
      legalName: '',
      ref: 'material-lazy-loading',
      phone: '',
      avatarUrl: '',
      capabilities: ['raw_material.assign', 'inventory.movement.manage'],
      assignedWarehouses: ['Material ombor'],
      assignedItemGroups: ['Rulon'],
      assignedApparatus: ['apparatus:default:asset-005'],
    );
  });

  tearDown(() {
    InventoryViewStore.instance.reset();
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('inventory bootstrap uses compact metadata and defers details',
      (tester) async {
    final fixture = _InventoryLazyFixture();
    await fixture.run(() async {
      await _pumpInventory(tester);

      expect(fixture.requests.map((uri) => uri.path).toSet(), {
        '${_InventoryLazyFixture.prefix}/inventory/locations',
        '${_InventoryLazyFixture.prefix}/inventory/assets',
      });
      final assetReads = fixture.requests.where(
        (uri) => uri.path.endsWith('/inventory/assets'),
      );
      expect(assetReads, isNotEmpty);
      expect(
        assetReads.every(
          (uri) => uri.queryParameters['include_order_assignment'] == 'true',
        ),
        isTrue,
      );
      expect(find.text('0042 · Frozen job'), findsOneWidget);
      expect(find.text('0043 · Active job'), findsOneWidget);
      expect(find.text('Plain polymer'), findsOneWidget);
      expect(fixture.detailReads, 0);
      expect(fixture.candidateReads, 0);

      final frozenFinder =
          find.byKey(const ValueKey('inventory-asset-card-raw:frozen'));
      final frozenCard = tester.widget<AdminSummaryCard>(frozenFinder);
      final scheme = Theme.of(tester.element(frozenFinder)).colorScheme;
      expect(
        frozenCard.backgroundColor,
        Color.alphaBlend(
          const Color(0xFF0288D1).withValues(alpha: 0.12),
          scheme.surfaceContainerLowest,
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('inventory-asset-card-raw:plain')),
      );
      await _pumpBounded(tester);
      expect(fixture.detailReads, 1);
      expect(fixture.candidateReads, 1);
      expect(
          find.text('Bu homashyoga mos faol zakaz topilmadi'), findsOneWidget);
      expect(
        fixture.requests.any((uri) =>
            uri.path.endsWith('/production-maps/sequence') ||
            uri.path.endsWith('/raw-material-assignments/orders') ||
            uri.path ==
                '${_InventoryLazyFixture.prefix}/raw-material-assignments'),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  testWidgets('transfer reads start on their tab and do not block products',
      (tester) async {
    final fixture = _InventoryLazyFixture(delayTransfers: true);
    await fixture.run(() async {
      try {
        await _pumpInventory(tester);
        expect(find.text('Plain polymer'), findsOneWidget);
        expect(fixture.transferDirections, isEmpty);

        await tester.tap(find.text('Kiruvchi'));
        await _pumpBounded(tester);
        expect(fixture.transferDirections, contains('incoming'));
        expect(fixture.pendingTransferReads, isNotEmpty);

        await tester.tap(find.text('Mahsulotlar'));
        await _pumpBounded(tester);
        expect(find.text('Plain polymer'), findsOneWidget);

        fixture.completeTransfers();
        await _pumpBounded(tester);
        await tester.tap(find.text('Chiquvchi'));
        await _pumpBounded(tester);
        expect(fixture.transferDirections, contains('outgoing'));
      } finally {
        fixture.completeTransfers();
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }
    });
  });

  testWidgets('older transfer read cannot overwrite a committed transfer',
      (tester) async {
    final fixture = _InventoryLazyFixture(delayTransfers: true);
    await fixture.run(() async {
      try {
        await _pumpInventory(tester);
        await tester.tap(find.text('Chiquvchi'));
        await _pumpBounded(tester);
        expect(fixture.transferDirections, ['outgoing']);
        expect(fixture.pendingTransferReads, hasLength(1));

        await tester.tap(find.text('Mahsulotlar'));
        await _pumpBounded(tester);
        await tester.tap(
          find.byKey(const ValueKey('inventory-asset-card-raw:plain')),
        );
        await _pumpBounded(tester);
        await tester.ensureVisible(find.text('Transfer'));
        await tester.tap(find.text('Transfer'));
        await _pumpBounded(tester);
        await tester.tap(find.byKey(const ValueKey(
          'inventory-location-inventory_location:warehouse:b',
        )));
        await _pumpBounded(tester);
        await tester.tap(find.text('So‘rov yuborish'));
        await _pumpBounded(tester);
        expect(fixture.createdTransfers, hasLength(1));

        // The pending GET contains the pre-write empty list. The committed
        // receipt must survive it, and a fresh GET must reconcile the tab.
        fixture.completeTransfers();
        await _pumpBounded(tester);
        await tester.tap(find.text('Chiquvchi'));
        await _pumpBounded(tester);
        expect(
          fixture.transferDirections.where((value) => value == 'outgoing'),
          hasLength(2),
        );
        expect(
          find.byKey(const ValueKey('inventory-transfer-transfer:new')),
          findsOneWidget,
        );
      } finally {
        fixture.completeTransfers();
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }
    });
  });
}

Future<void> _pumpInventory(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const InventoryMovementsScreen(),
    ),
  );
  await _pumpBounded(tester);
}

Future<void> _pumpBounded(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _InventoryLazyFixture {
  _InventoryLazyFixture({this.delayTransfers = false});

  static const prefix = '/v1/mobile/admin';
  final bool delayTransfers;
  final requests = <Uri>[];
  final transferDirections = <String>[];
  final pendingTransferReads = <Completer<http.Response>>[];
  final _pendingTransferPayloads =
      <Completer<http.Response>, List<Map<String, dynamic>>>{};
  final createdTransfers = <Map<String, dynamic>>[];
  int detailReads = 0;
  int candidateReads = 0;
  bool _transfersReleased = false;

  Future<void> run(Future<void> Function() body) => HttpOverrides.runZoned(
        () => http.runWithClient(() async {
          try {
            await body();
          } finally {
            InventoryViewStore.instance.reset();
          }
        }, () => MockClient(_handle)),
        createHttpClient: (_) => _NoInventoryLiveHttpClient(),
      );

  void completeTransfers() {
    _transfersReleased = true;
    for (final pending in pendingTransferReads) {
      if (!pending.isCompleted) {
        pending.complete(_jsonResponse(_pendingTransferPayloads[pending]!));
      }
    }
  }

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request.url);
    expect(request.headers['authorization'],
        'Bearer inventory-lazy-loading-token');
    if (request.method == 'POST' &&
        request.url.path == '$prefix/inventory/transfers') {
      final input = jsonDecode(request.body) as Map<String, dynamic>;
      expect(input['source_warehouse_id'], 'warehouse:a');
      expect(input['destination_warehouse_id'], 'warehouse:b');
      final transfer = {
        'id': 'transfer:new',
        'source_warehouse_id': 'warehouse:a',
        'source_warehouse': 'Material ombor',
        'destination_warehouse_id': 'warehouse:b',
        'destination_warehouse': 'Qolip ombor',
        'status': 'requested',
        'requested_by_name': 'Materialchi',
        'created_at_unix': 100,
        'lines': [
          {
            'asset_kind': 'raw_material',
            'asset_ref': 'raw:plain',
            'item_code': 'PE-plain',
            'item_name': 'Plain polymer',
            'identifier': 'QR-plain',
            'qty': 10,
            'uom': 'kg',
            'source_physical_location_id': 'inventory_location:warehouse:a',
          },
        ],
      };
      createdTransfers.add(transfer);
      return _jsonResponse(transfer);
    }
    expect(request.method, 'GET');
    switch (request.url.path) {
      case '$prefix/inventory/locations':
        return _jsonResponse([
          {
            'id': 'inventory_location:warehouse:a',
            'kind': 'warehouse',
            'name': 'Material ombor',
            'warehouse_id': 'warehouse:a',
            'active': true,
          },
          {
            'id': 'inventory_location:warehouse:b',
            'kind': 'warehouse',
            'name': 'Qolip ombor',
            'warehouse_id': 'warehouse:b',
            'active': true,
          },
        ]);
      case '$prefix/inventory/assets':
        if (request.url.queryParameters['current_user_states_only'] == 'true') {
          return _jsonResponse([]);
        }
        return _jsonResponse([
          _asset('frozen', 'Frozen polymer', {
            'order_id': 'zakaz-0042',
            'order_label': '0042 · Frozen job',
            'order_control': 'frozen',
          }),
          _asset('active', 'Active polymer', {
            'order_id': 'zakaz-0043',
            'order_label': '0043 · Active job',
            'order_control': 'active',
          }),
          _asset('plain', 'Plain polymer', null),
        ]);
      case '$prefix/inventory/transfers':
        transferDirections.add(request.url.queryParameters['direction'] ?? '');
        if (delayTransfers && !_transfersReleased) {
          final pending = Completer<http.Response>();
          pendingTransferReads.add(pending);
          _pendingTransferPayloads[pending] = List.of(createdTransfers);
          return pending.future;
        }
        return _jsonResponse(createdTransfers);
      case '$prefix/raw-material-assignments/lookup':
        detailReads++;
        expect(request.url.queryParameters['barcode'], 'QR-plain');
        return _jsonResponse({
          'barcode': 'QR-plain',
          'warehouse': 'Material ombor',
          'item_code': 'PE-plain',
          'item_name': 'Plain polymer',
          'item_group': 'Rulon',
          'qty': 10,
          'uom': 'kg',
          'status': 'available',
          'assignment': null,
        });
      case '$prefix/apparatus':
        return _jsonResponse([]);
      case '$prefix/raw-material-assignments/candidate-orders':
        candidateReads++;
        expect(request.url.queryParameters['barcode'], 'QR-plain');
        return _jsonResponse([]);
      default:
        fail('Unexpected inventory request: ${request.url}');
    }
  }

  Map<String, dynamic> _asset(
      String id, String name, Map<String, dynamic>? assignment) {
    return {
      'kind': 'raw_material',
      'asset_ref': 'raw:$id',
      'custody_warehouse_id': 'warehouse:a',
      'custody_warehouse': 'Material ombor',
      'item_code': 'PE-$id',
      'item_name': name,
      'identifier': 'QR-$id',
      'qty': 10,
      'uom': 'kg',
      'status': 'available',
      'physical_location': {
        'id': 'inventory_location:warehouse:a',
        'kind': 'warehouse',
        'name': 'Material ombor',
      },
      'placement_version': 1,
      'order_assignment': assignment,
    };
  }
}

http.Response _jsonResponse(Object payload) => http.Response(
      jsonEncode(payload),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

class _NoInventoryLiveHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) => Future.error(
        const SocketException(
            'Live sockets disabled for inventory widget test'),
      );

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => getUrl(url);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
