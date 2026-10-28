import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:accord_mobile_v2/src/core/cache/order_image_cache.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_disk_store_stub.dart';
import 'package:accord_mobile_v2/src/core/cache/production_snapshot_store.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/production/preparation_orders_warm_store.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_retry_state.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/state/admin_sequence_apparatus_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _apparatus = 'apparatus:default:bosma_7';
const _ordersPath = '/v1/mobile/preparation/orders';

http.Response _response(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

class _OrdersApi {
  final requests = <http.Request>[];
  final listQueries = <Map<String, String>>[];
  final detailReads = <String>[];
  final imageReads = <String>[];
  int liveListens = 0;
  late final events =
      StreamController<Object>.broadcast(onListen: () => liveListens++);
  Completer<http.Response>? pendingList;
  Completer<http.Response>? pendingDetail;
  Future<http.Response> Function(http.Request)? listResponse;
  void Function()? onImageRead;
  int failLists = 0;
  int rowCount = 2;
  int revision = 7;
  String titlePrefix = 'Master product';
  Map<String, dynamic>? detailCombo;
  List<Map<String, dynamic>>? detailProducts;

  Map<String, dynamic> row(int number) => {
        'id': 'zakaz-$number',
        'code': '0$number',
        'order_number': 'ORDER-$number',
        'title': '$titlePrefix $number',
        'customer_name': 'Master customer $number',
        'image_id': 'master-image-$number',
        'position': 10 + number,
      };

  Map<String, dynamic> window({String search = ''}) => {
        'ok': true,
        'projection': 'preparation_order_list_v1',
        'scope': 'master|$_apparatus|$search',
        'epoch': 'preparation-orders-test',
        'rev': revision,
        'version': revision.toRadixString(16).padLeft(64, '0'),
        'apparatus_id': _apparatus,
        'apparatus': [
          {'id': _apparatus, 'name': 'Master machine'}
        ],
        'limit': 30,
        'search': search,
        'total': search.isEmpty ? rowCount : 1,
        'next_cursor': null,
        'rows': [
          for (var i = 1; i <= rowCount; i++)
            if (search.isEmpty || 'master product $i'.contains(search)) row(i),
        ],
      };

  Map<String, dynamic> detail(String id) => {
        'ok': true,
        'epoch': 'preparation-orders-test',
        'rev': 7,
        'scope': 'master-detail|$id',
        'maps': [
          {
            'map': {
              'id': id,
              'code': '01',
              'order_number': 'ORDER-1',
              'title': 'Full master product 1',
              'product_code': 'MASTER-ITEM',
              'customer_name': 'Master customer 1',
              'image_id': 'master-image-1',
              'width_mm': 384,
              'base_length': 900,
              'order_kg': 120,
              if (detailCombo != null) 'combo': detailCombo,
              if (detailProducts != null) 'products': detailProducts,
              'nodes': [
                {'id': 'start', 'kind': 'start', 'title': 'Start'},
                {
                  'id': 'print',
                  'kind': 'apparatus',
                  'apparatus_id': _apparatus,
                  'title': 'Master machine',
                },
                {'id': 'end', 'kind': 'end', 'title': 'Finished product'},
              ],
              'edges': [
                {'from': 'start', 'to': 'print'},
                {'from': 'print', 'to': 'end'},
              ],
            },
            'program': <String, dynamic>{},
          }
        ],
        'sequences': {
          _apparatus: [id]
        },
        'visible_order_ids': {
          _apparatus: [id]
        },
        'queue_states': {
          _apparatus: {id: 'pending'}
        },
        'queue_policies': [],
        'queue_action_controls': {},
        'stage_states': {id: <String, dynamic>{}},
        'order_controls': {},
        'order_statuses': {},
        'order_customers': {id: 'Master customer 1'},
        'frozen_orders_by_apparatus': {},
      };

  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path == _ordersPath) {
      listQueries.add(request.url.queryParameters);
      if (failLists > 0) {
        failLists--;
        return _response({'code': 'store_failed', 'message': 'Offline'}, 503);
      }
      final custom = listResponse;
      if (custom != null) return custom(request);
      return pendingList?.future ??
          _response(
              window(search: request.url.queryParameters['search'] ?? ''));
    }
    if (path.startsWith('$_ordersPath/')) {
      final id = Uri.decodeComponent(path.substring(_ordersPath.length + 1));
      detailReads.add(id);
      return pendingDetail?.future ?? _response(detail(id));
    }
    if (path.contains('order-image')) {
      imageReads.add(request.url.queryParameters['order_id'] ?? '');
      onImageRead?.call();
      return _response({}, 404);
    }
    if (path.endsWith('/raw-material-assignments')) return _response([]);
    if (path.endsWith('/qolip/shared-sets')) return _response({'products': []});
    if (path.endsWith('/admin/apparatus')) {
      return _response([
        {
          'apparatus_id': _apparatus,
          'source_revision': 1,
          'source_aasx_sha256': '1' * 64,
          'display': {'display_name': 'Master machine'},
          'execution_profile': {
            'operation': 'print',
            'technology': 'flexographic',
          },
        },
      ]);
    }
    return _response({});
  }

  Future<void> mount(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AdminProductionMapOrdersScreen(
        readOnly: true,
        supplyViewerMode: true,
        liveEventsLoader: () => events.stream,
      ),
    ));
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await events.close();
    await tester.pump(const Duration(seconds: 35));
    expect(tester.takeException(), isNull);
  }
}

class _ListSnapshotBackend implements ProductionSnapshotBackend {
  final values = <String, Uint8List>{};
  final dates = <String, int>{};

  @override
  Future<Uint8List?> read(String id, {required int maxBytes}) async =>
      values[id];

  @override
  Future<void> write(String id, Uint8List bytes,
      {required int savedAtMs}) async {
    values[id] = bytes;
    dates[id] = savedAtMs;
  }

  @override
  Future<List<ProductionSnapshotStoredEntry>> entries() async => [
        for (final entry in values.entries)
          ProductionSnapshotStoredEntry(
              id: entry.key,
              bytes: entry.value.length,
              savedAtMs: dates[entry.key]!),
      ];

  @override
  Future<void> remove(String id) async {
    values.remove(id);
    dates.remove(id);
  }

  @override
  Future<void> clear() async {
    values.clear();
    dates.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var serial = 0;
  late ProductionSnapshotStore snapshots;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AdminSequenceApparatusStore.instance.clearCache();
    OrderImageCache.debugOverride =
        OrderImageCache(disk: createOrderImageDiskStore());
    AppSession.instance.token = 'master-list-token';
    AppSession.instance.profile = SessionProfile(
      role: UserRole.tayyorlovMasteri,
      ref: 'master-orders-${++serial}',
      displayName: 'Master',
      legalName: '',
      phone: '',
      avatarUrl: '',
      capabilities: const ['preparation.access'],
    );
    snapshots = ProductionSnapshotStore(backend: _ListSnapshotBackend());
    PreparationOrdersWarmStore.debugOverride =
        PreparationOrdersWarmStore(snapshots: snapshots);
  });

  tearDown(() async {
    PreparationOrdersWarmStore.instance.reset();
    PreparationOrdersWarmStore.debugOverride = null;
    await OrderImageCache.instance.clear();
    OrderImageCache.debugOverride = null;
    AdminSequenceApparatusStore.instance.clearCache();
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('cached master labels paint while HTTP validation is pending',
      (tester) async {
    final api = _OrdersApi()..pendingList = Completer<http.Response>();
    PreparationOrdersWarmStore.instance
        .remember(PreparationOrderListWindow.fromJson(api.window()));
    await http.runWithClient(() async {
      await api.mount(tester);
      await tester.pump();
      expect(api.listQueries, hasLength(1));
      expect(find.text('Master product 1'), findsOneWidget);
      expect(find.text('Master customer 1'), findsOneWidget);
      expect(api.detailReads, isEmpty);
      expect(api.listQueries.single['if_version'], api.window()['version']);
      api.pendingList!.complete(_response(api.window()));
      api.pendingList = null;
      await tester.pumpAndSettle();
      await api.close(tester);
    }, () => MockClient(api.respond));
  });

  testWidgets('304 preserves an entire restored multi-page master prefix',
      (tester) async {
    final api = _OrdersApi()..rowCount = 3;
    PreparationOrdersWarmStore.instance
        .remember(PreparationOrderListWindow.fromJson(api.window()));
    api.listResponse = (_) async => http.Response('', 304, headers: {
          'x-production-epoch': 'preparation-orders-test',
          'x-production-revision': '8',
          'x-preparation-scope': 'master|$_apparatus|',
          'x-preparation-version': api.window()['version'] as String,
        });
    await http.runWithClient(() async {
      await api.mount(tester);
      await tester.pumpAndSettle();
      expect(api.listQueries, hasLength(1));
      for (final id in [1, 2, 3]) {
        expect(find.text('Master product $id'), findsOneWidget);
        expect(find.text('${10 + id}'), findsOneWidget);
      }
      expect(PreparationOrdersWarmStore.instance.peek()?.revision, 8);
      expect(api.detailReads, isEmpty);
      await api.close(tester);
    }, () => MockClient(api.respond));
  });

  testWidgets('master restores disk labels without waiting for HTTP',
      (tester) async {
    final api = _OrdersApi()..pendingList = Completer<http.Response>();
    await tester.runAsync(() async {
      PreparationOrdersWarmStore.instance
          .remember(PreparationOrderListWindow.fromJson(api.window()));
      await snapshots.flush();
    });
    PreparationOrdersWarmStore.instance.reset();
    expect(PreparationOrdersWarmStore.instance.peek(), isNull);
    await http.runWithClient(() async {
      await api.mount(tester);
      // The disk fixture was seeded in the real async zone. Let its completed
      // storage queue hand the new read back to the widget's fake clock.
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      expect(api.listQueries, hasLength(1));
      expect(find.text('Master product 1'), findsOneWidget);
      expect(api.detailReads, isEmpty);
      api.titlePrefix = 'Fresh master product';
      api.revision = 8;
      api.pendingList!.complete(_response(api.window()));
      api.pendingList = null;
      await tester.pumpAndSettle();
      expect(find.text('Fresh master product 1'), findsOneWidget);
      expect(find.text('Master product 1'), findsNothing);
      await api.close(tester);
    }, () => MockClient(api.respond));
  });

  testWidgets('master checkpoint retains rows, thumbnails and socket',
      (tester) async {
    final api = _OrdersApi();
    await http.runWithClient(() async {
      await api.mount(tester);
      await tester.pumpAndSettle();
      final images = List.of(api.imageReads);
      final listeners = api.liveListens;
      api.events.add({...api.window(), 'type': 'checkpoint', 'rev': 8});
      await tester.pumpAndSettle();
      expect(api.listQueries, hasLength(1));
      expect(api.imageReads, images);
      expect(api.liveListens, listeners);
      expect(find.text('Master product 1'), findsOneWidget);
      expect(api.detailReads, isEmpty);
      await api.close(tester);
    }, () => MockClient(api.respond));
  });

  testWidgets(
      'master delta adds, removes and reorders without another HTTP read',
      (tester) async {
    final api = _OrdersApi();
    await http.runWithClient(() async {
      await api.mount(tester);
      await tester.pumpAndSettle();
      final listeners = api.liveListens;
      final delta = {
        ...api.window(),
        'type': 'list_delta',
        'rev': 8,
        'version': 'f' * 64,
        'base_version': api.window()['version'],
        'order_ids': ['zakaz-3', 'zakaz-1'],
        'removed_ids': ['zakaz-2'],
        'upserts': [
          api.row(3),
          {...api.row(1), 'title': 'Renamed master product', 'position': 42},
        ],
      }..remove('rows');
      api.events.add(delta);
      await tester.pumpAndSettle();
      expect(api.listQueries, hasLength(1));
      expect(api.liveListens, listeners);
      expect(find.text('Master product 2'), findsNothing);
      expect(find.text('Master product 3'), findsOneWidget);
      expect(find.text('Renamed master product'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Master product 3')).dy,
          lessThan(tester.getTopLeft(find.text('Renamed master product')).dy));
      expect(api.detailReads, isEmpty);
      await api.close(tester);
    }, () => MockClient(api.respond));
  });

  testWidgets('missing master delta baseline starts only one HTTP repair',
      (tester) async {
    final api = _OrdersApi();
    await http.runWithClient(() async {
      await api.mount(tester);
      await tester.pumpAndSettle();
      api.pendingList = Completer<http.Response>();
      final delta = {
        ...api.window(),
        'type': 'list_delta',
        'base_version': 'missing',
        'rev': 8,
        'version': 'f' * 64,
        'order_ids': ['zakaz-1', 'zakaz-2'],
        'upserts': [],
        'removed_ids': [],
      }..remove('rows');
      api.events
        ..add(delta)
        ..add(delta);
      await tester.pump();
      expect(api.listQueries, hasLength(2));
      expect(api.events.hasListener, isFalse);
      api.pendingList!.complete(_response(api.window()));
      api.pendingList = null;
      await tester.pumpAndSettle();
      expect(api.listQueries, hasLength(2));
      expect(find.text('Master product 1'), findsOneWidget);
      await api.close(tester);
    }, () => MockClient(api.respond));
  });

  testWidgets('master loads only list data before deferring visible thumbnails',
      (tester) async {
    final api = _OrdersApi()
      ..pendingList = Completer<http.Response>()
      ..rowCount = 30;
    var imagesStartedAfterRows = true;
    api.onImageRead = () {
      imagesStartedAfterRows &=
          find.text('Master product 1').evaluate().isNotEmpty;
    };
    await http.runWithClient(() async {
      await api.mount(tester);
      expect(api.listQueries, hasLength(1));
      expect(api.requests.map((request) => request.url.path), [_ordersPath]);
      expect(api.imageReads, isEmpty);
      expect(api.detailReads, isEmpty);
      api.pendingList!.complete(_response(api.window()));
      api.pendingList = null;
      await tester.pumpAndSettle();
      expect(find.text('Master product 1'), findsOneWidget);
      expect(find.text('Master customer 1'), findsOneWidget);
      expect(find.text('11'), findsOneWidget,
          reason: 'The canonical position must not become the visible index');
      expect(api.imageReads, isNotEmpty);
      expect(imagesStartedAfterRows, isTrue);
      expect(api.imageReads, isNot(contains('zakaz-30')),
          reason: 'Offscreen rows must not start image downloads');
      expect(api.detailReads, isEmpty);
      expect(
          api.requests.every((request) =>
              request.url.path == _ordersPath ||
              request.url.path.contains('order-image')),
          isTrue,
          reason: 'No full queue, preparation, inventory or mold bootstrap');
      await api.close(tester);
    }, () => MockClient(api.respond));
  });

  testWidgets('master opens sheet before fetching only the tapped order detail',
      (tester) async {
    final api = _OrdersApi()..pendingDetail = Completer<http.Response>();
    await http.runWithClient(() async {
      await api.mount(tester);
      await tester.pumpAndSettle();
      expect(api.detailReads, isEmpty);
      await tester.tap(find.text('Master product 1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(api.detailReads, ['zakaz-1']);
      expect(find.textContaining('Full master product 1'), findsNothing);
      api.pendingDetail!.complete(_response(api.detail('zakaz-1')));
      api.pendingDetail = null;
      await tester.pumpAndSettle();
      expect(find.textContaining('Full master product 1'), findsOneWidget);
      expect(find.text('120 kg'), findsOneWidget);
      expect(api.detailReads, ['zakaz-1']);
      expect(
          api.requests.where((request) =>
              request.url.path.endsWith('/sequence') ||
              request.url.path.endsWith('/preparation/snapshot') ||
              request.url.path.endsWith('/admin/apparatus') ||
              request.url.path.contains('/qolip/') ||
              request.url.path.contains('/raw-material-') ||
              request.url.path.contains('/progress-batches')),
          isEmpty);
      await api.close(tester);
    }, () => MockClient(api.respond));
  });

  testWidgets('master does not see the combo details card', (tester) async {
    final api = _OrdersApi()
      ..detailCombo = {
        'id': 'combo-1',
        'item_code': 'COMBO-1',
        'name': 'Master combo',
        'revision': 1,
      }
      ..detailProducts = [
        {
          'id': 'p1',
          'item_code': 'SKU-A',
          'product': 'Yashil',
          'frame_product_size_mm': 120,
          'frame_count': 2,
        },
      ];
    await http.runWithClient(() async {
      await api.mount(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Master product 1'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Full master product 1'), findsOneWidget);
      expect(find.text('120 kg'), findsOneWidget);
      expect(find.byKey(const ValueKey('production-order-combo:zakaz-1')),
          findsNothing);
      expect(find.byKey(const ValueKey('production-order-combo-toggle')),
          findsNothing);
      expect(find.text('Kombo ma’lumotlari'), findsNothing);
      expect(find.text('Kombo tarkibi'), findsNothing);
      expect(find.text('Master combo'), findsNothing);
      expect(find.textContaining('SKU-A'), findsNothing);
      expect(api.requests.where((r) => r.url.path.endsWith('/admin/combos')),
          isEmpty);
      expect(tester.takeException(), isNull);
      await api.close(tester);
    }, () => MockClient(api.respond));
  });

  testWidgets('master search stays on the server and keeps canonical numbering',
      (tester) async {
    final api = _OrdersApi();
    await http.runWithClient(() async {
      await api.mount(tester);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(EditableText).first, 'master product 2');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(api.listQueries.last['search'], 'master product 2');
      expect(find.text('Master product 2'), findsOneWidget);
      expect(find.text('Master product 1'), findsNothing);
      expect(find.text('12'), findsOneWidget);
      expect(api.detailReads, isEmpty);
      await api.close(tester);
    }, () => MockClient(api.respond));
  });

  testWidgets('master list failure retries without loading unrelated data',
      (tester) async {
    final api = _OrdersApi()..failLists = 1;
    await http.runWithClient(() async {
      await api.mount(tester);
      await tester.pumpAndSettle();
      expect(find.byType(AppRetryState), findsOneWidget);
      expect(api.detailReads, isEmpty);
      expect(api.imageReads, isEmpty);
      await tester.tap(find.descendant(
          of: find.byType(AppRetryState), matching: find.byType(TextButton)));
      await tester.pumpAndSettle();
      expect(api.listQueries, hasLength(2));
      expect(find.text('Master product 1'), findsOneWidget);
      expect(api.detailReads, isEmpty);
      await api.close(tester);
    }, () => MockClient(api.respond));
  });

  testWidgets('master pagination and live refresh retain original positions',
      (tester) async {
    final api = _OrdersApi();
    api.listResponse = (request) async {
      final cursor = request.url.queryParameters['cursor'];
      expect(cursor, anyOf(isNull, 'master-page-2'));
      return _response({
        ...api.window(),
        'total': 3,
        'rows': [
          for (final id in cursor == null ? [1, 2] : [3]) api.row(id)
        ],
        'next_cursor': cursor == null ? 'master-page-2' : null,
      });
    };
    await http.runWithClient(() async {
      await api.mount(tester);
      await tester.pumpAndSettle();
      expect(api.listQueries, hasLength(1));
      expect(find.text('Master product 3'), findsNothing);
      await tester.tap(find.text('Yana yuklash'));
      await tester.pumpAndSettle();
      expect(api.listQueries, hasLength(2));
      expect(api.listQueries.last['cursor'], 'master-page-2');
      for (final id in [1, 2, 3]) {
        expect(find.text('Master product $id'), findsOneWidget);
        expect(find.text('${10 + id}'), findsOneWidget);
      }
      expect(find.text('Yana yuklash'), findsNothing);
      expect(api.detailReads, isEmpty);
      api.revision = 8;
      api.titlePrefix = 'Updated master product';
      api.events.add({'type': 'invalidate'});
      await tester.pumpAndSettle();
      expect(api.listQueries.map((query) => query['cursor']),
          [null, 'master-page-2', null, 'master-page-2']);
      for (final id in [1, 2, 3]) {
        expect(find.text('Updated master product $id'), findsOneWidget);
        expect(find.text('${10 + id}'), findsOneWidget);
      }
      expect(find.text('Master product 3'), findsNothing);
      expect(api.detailReads, isEmpty);
      await api.close(tester);
    }, () => MockClient(api.respond));
  });

  testWidgets('master stale pagination cursor resets to a fresh first page',
      (tester) async {
    final api = _OrdersApi();
    var changed = false;
    api.listResponse = (request) async {
      if (request.url.queryParameters['cursor'] != null) {
        changed = true;
        api.revision = 8;
        api.titlePrefix = 'Updated master product';
        return _response({'code': 'order_page_changed'}, 409);
      }
      return _response({
        ...api.window(),
        'total': changed ? 1 : 3,
        'rows': [
          for (final id in changed ? [3] : [1, 2]) api.row(id)
        ],
        'next_cursor': changed ? null : 'stale-master-cursor',
      });
    };
    await http.runWithClient(() async {
      await api.mount(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yana yuklash'));
      await tester.pumpAndSettle();
      expect(api.listQueries.map((query) => query['cursor']),
          [null, 'stale-master-cursor', null]);
      expect(find.text('Updated master product 3'), findsOneWidget);
      expect(find.text('Master product 1'), findsNothing);
      expect(find.text('Master product 2'), findsNothing);
      expect(find.text('13'), findsOneWidget);
      expect(find.byType(AppRetryState), findsNothing);
      expect(api.detailReads, isEmpty);
      await api.close(tester);
    }, () => MockClient(api.respond));
  });

  testWidgets('master lightweight live invalidation reloads only list labels',
      (tester) async {
    final api = _OrdersApi();
    await http.runWithClient(() async {
      await api.mount(tester);
      await tester.pumpAndSettle();
      expect(api.events.hasListener, isTrue);
      api.revision = 8;
      api.titlePrefix = 'Updated master product';
      api.events.add({'type': 'invalidate'});
      await tester.pumpAndSettle();
      expect(api.listQueries, hasLength(2));
      expect(find.text('Updated master product 1'), findsOneWidget);
      expect(find.text('Master product 1'), findsNothing);
      expect(api.detailReads, isEmpty);
      expect(
          api.requests.every((request) =>
              request.url.path == _ordersPath ||
              request.url.path.contains('order-image')),
          isTrue);
      await api.close(tester);
    }, () => MockClient(api.respond));
  });

  testWidgets('master permission rejection withdraws previously visible rows',
      (tester) async {
    final api = _OrdersApi();
    await http.runWithClient(() async {
      await api.mount(tester);
      await tester.pumpAndSettle();
      expect(find.text('Master product 1'), findsOneWidget);
      api.listResponse = (_) async => _response(
          {'code': 'forbidden', 'message': 'Master access revoked'}, 403);
      api.events.add({'type': 'invalidate'});
      await tester.pumpAndSettle();
      expect(api.listQueries, hasLength(2));
      expect(find.text('Master product 1'), findsNothing);
      expect(find.text('Master product 2'), findsNothing);
      expect(find.byType(AppRetryState), findsOneWidget);
      expect(api.events.hasListener, isFalse);
      expect(api.detailReads, isEmpty);
      await api.close(tester);
    }, () => MockClient(api.respond));
  });
}
