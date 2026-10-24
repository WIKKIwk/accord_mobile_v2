import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_cache.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_disk_store_stub.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/state/admin_sequence_apparatus_store.dart';
import 'package:accord_mobile_v2/src/features/gscale/presentation/gscale_mode_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _apparatusId = 'apparatus:default:bosma_7';
const _otherApparatusId = 'apparatus:default:bosma_9';
const _epoch = 'supply-widget-server';

String _version(int revision) => revision.toRadixString(16).padLeft(64, '0');

Map<String, dynamic> _taskRow(int number,
        {String kind = 'qolip', String prefix = 'Product'}) =>
    {
      'id': 'zakaz-$number',
      'code': '$number'.padLeft(4, '0'),
      'order_number': '$number'.padLeft(4, '0'),
      'title': '$prefix $number',
      'product_code': 'ITEM-$number',
      'customer_name': 'Task customer',
      'image_id': 'image-$number',
      'position': number - 1,
      'apparatus_count': 8,
      'task_state': kind == 'material' && number == 3 ? 'partial' : 'missing',
    };

class _SupplyHarness {
  _SupplyHarness(this.kind) {
    events = StreamController<SupplyTaskMessage>.broadcast(onListen: () {
      final baseline = opened.last;
      scheduleMicrotask(() {
        if (!events.isClosed && events.hasListener) {
          events.add(SupplyTaskMessage.fromJson({
            'ok': true,
            'type': 'tasks_ready',
            'epoch': baseline.epoch,
            'scope': baseline.scope,
            'rev': baseline.revision,
            'version': baseline.version,
            'resync': false,
          }));
        }
      });
    });
  }

  final String kind;
  late final StreamController<SupplyTaskMessage> events;
  final reads = <({String kind, String apparatus, int limit, String search})>[];
  final opened = <SupplyTaskWindow>[];
  final requests = <http.Request>[];
  final detailReads = <String>[];
  final productReads = <List<String>>[];
  Set<int> missing = {3, 6};
  int revision = 7;
  String prefix = 'Product';
  Completer<SupplyTaskWindow>? pendingWindow;
  Completer<ProductionMapSaved>? pendingDetail;
  GScaleModeArgs? receipt;

  Map<String, dynamic> windowWire(
      {String apparatus = '', int limit = 10, String search = ''}) {
    final selected = apparatus.isEmpty ? _apparatusId : apparatus;
    final checked = [for (var n = 1; n <= 6 && n <= limit; n++) n];
    final taskIds = checked.where(missing.contains).toList();
    return {
      'ok': true,
      'projection': 'supply_tasks_v1',
      'kind': kind,
      'scope': '$kind|$selected|$limit|$search',
      'epoch': _epoch,
      'rev': revision,
      'version': _version(revision),
      'apparatus_id': selected,
      'limit': limit,
      'search': search,
      'checked_count': checked.length,
      'missing_count': taskIds.length,
      'rows': [
        for (final n in taskIds)
          if (search.isEmpty ||
              '$prefix $n ITEM-$n Task customer'
                  .toLowerCase()
                  .contains(search.toLowerCase()))
            _taskRow(n, kind: kind, prefix: prefix),
      ],
      'apparatus': [
        for (final id in [_apparatusId, _otherApparatusId])
          {
            'apparatus_id': id,
            'source_revision': 1,
            'source_aasx_sha256': '1' * 64,
            'display': {
              'display_name':
                  id == _apparatusId ? 'Task machine 7' : 'Task machine 9',
            },
            'execution_profile': {
              'operation': 'print',
              'technology': 'flexographic',
            },
          },
      ],
    };
  }

  SupplyTaskWindow window(
          {String apparatus = '', int limit = 10, String search = ''}) =>
      SupplyTaskWindow.fromJson(
          windowWire(apparatus: apparatus, limit: limit, search: search));

  Future<SupplyTaskWindow> load(
      {required String kind,
      required String apparatus,
      required int limit,
      required String search}) async {
    reads.add((kind: kind, apparatus: apparatus, limit: limit, search: search));
    return pendingWindow?.future ??
        Future.value(
            window(apparatus: apparatus, limit: limit, search: search));
  }

  Stream<SupplyTaskMessage> live(SupplyTaskWindow baseline) {
    opened.add(baseline);
    return events.stream;
  }

  ProductionMapSaved full(String id) => ProductionMapSaved.fromJson({
        'map': {
          'id': id,
          'code': id.split('-').last.padLeft(4, '0'),
          'title': 'Authoritative Product ${id.split('-').last}',
          'product_code': 'ITEM-${id.split('-').last}',
          'customer_name': 'Task customer',
          'width_mm': 384,
          'image_id': 'image-${id.split('-').last}',
          'nodes': [
            {'id': 'start', 'kind': 'start', 'title': 'Start'},
            {
              'id': 'print',
              'kind': 'apparatus',
              'apparatus_id': _apparatusId,
              'title': 'Print',
            },
            {'id': 'end', 'kind': 'end', 'title': 'Finished product'},
          ],
          'edges': [
            {'from': 'start', 'to': 'print'},
            {'from': 'print', 'to': 'end'},
          ],
        },
        'program': <String, dynamic>{},
      });

  Future<ProductionMapSaved> detail(String id) async {
    detailReads.add(id);
    return pendingDetail?.future ?? Future.value(full(id));
  }

  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
    if (request.url.path.endsWith('/qolip/order-products')) {
      final ids =
          (jsonDecode(request.body)['order_ids'] as List).cast<String>();
      productReads.add(ids);
      return http.Response(
          jsonEncode({
            'orders': [
              for (final id in ids)
                {
                  'order_id': id,
                  'product': {
                    'code': 'ITEM-${id.split('-').last}',
                    'name': 'Authoritative Product ${id.split('-').last}',
                    'item_group': 'Finished product',
                    'has_qolip_spec':
                        !missing.contains(int.parse(id.split('-').last)),
                  },
                },
            ],
          }),
          200);
    }
    if (request.url.path.endsWith('/qolip/blocks')) {
      return http.Response('{"warehouses":["Qolip ombori"],"blocks":[]}', 200);
    }
    if (request.url.path.endsWith('/raw-material-assignments')) {
      return http.Response('[]', 200);
    }
    if (request.url.path.contains('order-image')) {
      return http.Response('', 404);
    }
    return http.Response('{}', 200);
  }

  Future<void> mount(WidgetTester tester, {bool settle = true}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      onGenerateRoute: (settings) {
        receipt = settings.arguments as GScaleModeArgs;
        return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Task receipt')));
      },
      home: AdminProductionMapOrdersScreen(
        readOnly: true,
        supplyViewerMode: true,
        qolipTasksMode: kind == 'qolip',
        materialTasksMode: kind == 'material',
        supplyTaskWindowLoader: load,
        supplyTaskEventsLoader: live,
        supplyOrderDetailLoader: detail,
      ),
    ));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Finder row(int number) => find.byKey(ValueKey('$kind-task-zakaz-$number'));

  Iterable<http.Request> get forbiddenReads => requests.where((request) {
        final path = request.url.path;
        return path.endsWith('/sequence') ||
            (path.endsWith('/production-maps') &&
                (request.url.queryParameters['id'] ?? '').isEmpty) ||
            path.endsWith('/completed-orders') ||
            path.endsWith('/completion-requests') ||
            path.endsWith('/completion-request-decisions') ||
            path.endsWith('/gscale/material-tasks');
      });

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await events.close();
    await tester.pump(const Duration(seconds: 35));
    expect(tester.takeException(), isNull);
  }
}

Finder _detailSheet({bool? pending}) => find.byWidgetPredicate((widget) =>
    widget.runtimeType.toString() == '_ReadOnlyOrderDetailSheet' &&
    (pending == null || (widget as dynamic).detailPending == pending));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var serial = 0;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AdminSequenceApparatusStore.instance.clearCache();
    OrderImageCache.debugOverride =
        OrderImageCache(disk: createOrderImageDiskStore());
    AppSession.instance.token = 'supply-widget-token';
    AppSession.instance.profile = SessionProfile(
      role: UserRole.qolipchi,
      ref: 'supply-widget-${++serial}',
      displayName: 'Supply worker',
      legalName: '',
      phone: '',
      avatarUrl: '',
      capabilities: ['qolip.manage'],
    );
  });
  tearDown(() async {
    await OrderImageCache.instance.clear();
    OrderImageCache.debugOverride = null;
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  for (final kind in ['qolip', 'material']) {
    testWidgets('compact $kind tasks bootstrap only its bounded task window',
        (tester) async {
      if (kind == 'material') {
        AppSession.instance.profile = AppSession.instance.profile!.copyWith(
            role: UserRole.materialTaminotchi,
            capabilities: ['raw_material.assign']);
      }
      final harness = _SupplyHarness(kind)
        ..pendingWindow = Completer<SupplyTaskWindow>();
      await http.runWithClient(() async {
        await harness.mount(tester, settle: false);
        expect(harness.reads, hasLength(1));
        expect(harness.reads.single.kind, kind);
        expect(harness.reads.single.limit, 10);
        expect(harness.requests, isEmpty,
            reason:
                'No hidden images or legacy bootstrap requests while loading');
        harness.pendingWindow!.complete(harness.window());
        harness.pendingWindow = null;
        await tester.pumpAndSettle();
        expect(harness.row(3), findsOneWidget);
        expect(harness.row(6), findsOneWidget);
        expect(harness.row(1), findsNothing);
        expect(find.descendant(of: harness.row(3), matching: find.text('3')),
            findsOneWidget);
        expect(harness.productReads, isEmpty);
        expect(harness.detailReads, isEmpty);
        expect(harness.forbiddenReads, isEmpty);
        final images = harness.requests
            .where((request) => request.url.path.contains('order-image'));
        expect(
            images.every((request) => const {'zakaz-3', 'zakaz-6'}
                .contains(request.url.queryParameters['order_id'])),
            isTrue,
            reason: 'Only visible task thumbnails may load');
        final reads = harness.reads.length;
        await tester.pump(const Duration(seconds: 30));
        await tester.pumpAndSettle();
        expect(harness.reads, hasLength(reads), reason: 'No task polling');
        await harness.close(tester);
      }, () => MockClient(harness.respond));
    });
  }

  testWidgets(
      'compact tasks preserve first N before missing and search filters',
      (tester) async {
    final harness = _SupplyHarness('qolip');
    await http.runWithClient(() async {
      await harness.mount(tester);
      await tester.tap(find.byKey(const ValueKey('qolip-tasks-limit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('qolip-tasks-limit-5 ta')));
      await tester.pumpAndSettle();
      expect(harness.reads.last.limit, 5);
      expect(harness.row(3), findsOneWidget);
      expect(harness.row(6), findsNothing);
      expect(find.descendant(of: harness.row(3), matching: find.text('3')),
          findsOneWidget);
      await tester.enterText(find.byType(EditableText).first, 'Product 6');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(harness.reads.last.search, 'product 6');
      expect(harness.reads.last.limit, 5);
      expect(harness.row(6), findsNothing,
          reason: 'Search cannot pull a task beyond the checked queue prefix');
      expect(harness.forbiddenReads, isEmpty);
      expect(harness.productReads, isEmpty);
      await harness.close(tester);
    }, () => MockClient(harness.respond));
  });

  testWidgets(
      'compact Qolip tap rechecks exactly one product before locked form',
      (tester) async {
    final harness = _SupplyHarness('qolip');
    await http.runWithClient(() async {
      await harness.mount(tester);
      expect(harness.productReads, isEmpty);
      await tester.tap(harness.row(3));
      await tester.pumpAndSettle();
      expect(harness.productReads, [
        ['zakaz-3']
      ]);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(find.text('Authoritative Product 3'), findsOneWidget);
      expect(harness.detailReads, isEmpty);
      harness.missing.remove(3);
      Navigator.of(tester.element(find.byIcon(Icons.lock_outline_rounded)))
          .pop();
      await tester.pumpAndSettle();
      expect(harness.row(3), findsOneWidget);
      final baseline = harness.opened.last;
      harness.events.add(SupplyTaskDelta(
        epoch: baseline.epoch,
        scope: baseline.scope,
        baseRevision: baseline.revision,
        revision: baseline.revision + 1,
        version: _version(8),
        checkedCount: 6,
        missingCount: 1,
        orderIds: const ['zakaz-6'],
        upsert: const [],
        remove: const ['zakaz-3'],
      ));
      await tester.pumpAndSettle();
      expect(harness.row(3), findsNothing);
      expect(harness.row(6), findsOneWidget);
      expect(harness.reads, hasLength(1));
      expect(
          harness.productReads,
          [
            ['zakaz-3']
          ],
          reason:
              'Spec readiness arrives by delta without batch product reads');
      expect(harness.forbiddenReads, isEmpty);
      await harness.close(tester);
    }, () => MockClient(harness.respond));
  });

  testWidgets(
      'compact material tap opens preview before one authoritative full order',
      (tester) async {
    AppSession.instance.profile = AppSession.instance.profile!.copyWith(
        role: UserRole.materialTaminotchi,
        capabilities: ['raw_material.assign']);
    final harness = _SupplyHarness('material')
      ..pendingDetail = Completer<ProductionMapSaved>();
    await http.runWithClient(() async {
      await harness.mount(tester);
      expect(harness.detailReads, isEmpty);
      await tester.tap(harness.row(3));
      await tester.pump(const Duration(milliseconds: 16));
      expect(_detailSheet(pending: true), findsOneWidget);
      expect(harness.detailReads, ['zakaz-3']);
      final original = tester.state(_detailSheet(pending: true));
      harness.pendingDetail!.complete(harness.full('zakaz-3'));
      harness.pendingDetail = null;
      await tester.pumpAndSettle();
      expect(_detailSheet(pending: false), findsOneWidget);
      expect(identical(tester.state(_detailSheet(pending: false)), original),
          isTrue);
      final dynamic sheet = tester.widget(_detailSheet(pending: false));
      expect((sheet.order as ProductionMapSaved).map.widthMm, 384);
      expect((sheet.order as ProductionMapSaved).map.nodes, hasLength(3));
      expect(harness.detailReads, ['zakaz-3']);
      expect(harness.forbiddenReads, isEmpty);
      await harness.close(tester);
    }, () => MockClient(harness.respond));
  });

  testWidgets(
      'compact task deltas upsert remove and retain original queue rank',
      (tester) async {
    final harness = _SupplyHarness('qolip');
    await http.runWithClient(() async {
      await harness.mount(tester);
      final baseline = harness.opened.last;
      harness.missing = {2, 6};
      harness.revision = 8;
      harness.events.add(SupplyTaskMessage.fromJson({
        'ok': true,
        'type': 'tasks_delta',
        'epoch': baseline.epoch,
        'scope': baseline.scope,
        'base_rev': baseline.revision,
        'rev': 8,
        'version': _version(8),
        'checked_count': 6,
        'missing_count': 2,
        'order_ids': ['zakaz-2', 'zakaz-6'],
        'upsert': [_taskRow(2)],
        'remove': ['zakaz-3'],
      }));
      await tester.pumpAndSettle();
      expect(harness.row(3), findsNothing);
      expect(harness.row(2), findsOneWidget);
      expect(harness.row(6), findsOneWidget);
      expect(find.descendant(of: harness.row(2), matching: find.text('2')),
          findsOneWidget);
      expect(harness.reads, hasLength(1),
          reason: 'A complete delta does not refetch the task window');
      expect(harness.productReads, isEmpty);
      expect(harness.forbiddenReads, isEmpty);
      await harness.close(tester);
    }, () => MockClient(harness.respond));
  });

  testWidgets('compact task stale delta cannot replace newer task rows',
      (tester) async {
    final harness = _SupplyHarness('qolip');
    await http.runWithClient(() async {
      await harness.mount(tester);
      final baseline = harness.opened.last;
      harness.events.add(SupplyTaskMessage.fromJson({
        'ok': true,
        'type': 'tasks_delta',
        'epoch': baseline.epoch,
        'scope': baseline.scope,
        'base_rev': baseline.revision - 2,
        'rev': baseline.revision - 1,
        'version': _version(6),
        'checked_count': 6,
        'missing_count': 1,
        'order_ids': ['zakaz-2'],
        'upsert': [_taskRow(2, prefix: 'Stale secret')],
        'remove': ['zakaz-3', 'zakaz-6'],
      }));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Stale secret'), findsNothing);
      expect(harness.row(2), findsNothing);
      expect(harness.row(3), findsOneWidget);
      expect(harness.forbiddenReads, isEmpty);
      await harness.close(tester);
    }, () => MockClient(harness.respond));
  });

  testWidgets('compact task delta from another scope cannot publish rows',
      (tester) async {
    final harness = _SupplyHarness('qolip');
    await http.runWithClient(() async {
      await harness.mount(tester);
      final baseline = harness.opened.last;
      harness.events.add(SupplyTaskDelta(
        epoch: baseline.epoch,
        scope: 'another-actor-window',
        baseRevision: baseline.revision,
        revision: baseline.revision + 1,
        version: _version(8),
        checkedCount: 6,
        missingCount: 1,
        orderIds: const ['zakaz-2'],
        upsert: [SupplyTaskRow.fromJson(_taskRow(2, prefix: 'Foreign secret'))],
        remove: const ['zakaz-3', 'zakaz-6'],
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Foreign secret'), findsNothing);
      expect(harness.row(2), findsNothing);
      expect(harness.row(3), findsOneWidget);
      expect(harness.reads, hasLength(2),
          reason: 'An invalid live cursor repairs one bounded task window');
      final reads = harness.reads.length;
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(harness.reads, hasLength(reads));
      expect(harness.forbiddenReads, isEmpty);
      await harness.close(tester);
    }, () => MockClient(harness.respond));
  });

  testWidgets('compact tasks discard a late first window after account change',
      (tester) async {
    final harness = _SupplyHarness('qolip')
      ..pendingWindow = Completer<SupplyTaskWindow>();
    await http.runWithClient(() async {
      await harness.mount(tester, settle: false);
      expect(harness.reads, hasLength(1));
      final oldResult = harness.window();
      AppSession.instance.profile =
          AppSession.instance.profile!.copyWith(ref: 'another-supply-actor');
      AppSession.instance.revision.value++;
      harness.pendingWindow!.complete(oldResult);
      harness.pendingWindow = null;
      await tester.pumpAndSettle();
      expect(harness.row(3), findsNothing);
      expect(harness.row(6), findsNothing);
      expect(harness.opened, isEmpty);
      expect(harness.requests, isEmpty);
      await harness.close(tester);
    }, () => MockClient(harness.respond));
  });

  testWidgets(
      'compact material receipt hydrates width only after explicit action',
      (tester) async {
    AppSession.instance.profile = AppSession.instance.profile!.copyWith(
        role: UserRole.materialTaminotchi,
        capabilities: ['raw_material.assign']);
    final harness = _SupplyHarness('material')
      ..pendingDetail = Completer<ProductionMapSaved>();
    await http.runWithClient(() async {
      await harness.mount(tester);
      expect(harness.detailReads, isEmpty);
      await tester.longPress(harness.row(3));
      await tester.pumpAndSettle();
      expect(harness.detailReads, isEmpty);
      await tester.tap(find.byKey(const ValueKey('material-task-receive')));
      await tester.pumpAndSettle();
      expect(harness.detailReads, ['zakaz-3']);
      expect(harness.receipt, isNull);
      harness.pendingDetail!.complete(harness.full('zakaz-3'));
      harness.pendingDetail = null;
      await tester.pumpAndSettle();
      expect(find.text('Task receipt'), findsOneWidget);
      expect(harness.receipt!.order!.id, 'zakaz-3');
      expect(harness.receipt!.order!.widthMm, 384);
      expect(harness.receipt!.order!.title, 'Authoritative Product 3');
      expect(harness.detailReads, ['zakaz-3']);
      expect(harness.forbiddenReads, isEmpty);
      await harness.close(tester);
    }, () => MockClient(harness.respond));
  });

  testWidgets(
      'compact tasks adopt authoritative apparatus snapshot without HTTP',
      (tester) async {
    final harness = _SupplyHarness('qolip');
    await http.runWithClient(() async {
      await harness.mount(tester);
      harness.prefix = 'Assigned product';
      harness.events.add(
          SupplyTaskSnapshot(harness.window(apparatus: _otherApparatusId)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Task machine 9'), findsOneWidget);
      expect(find.textContaining('Assigned product 3'), findsOneWidget);
      expect(find.textContaining('Product 3'), findsNothing);
      expect(harness.row(3), findsOneWidget);
      expect(harness.reads, hasLength(1));
      expect(harness.productReads, isEmpty);
      expect(harness.forbiddenReads, isEmpty);
      await harness.close(tester);
    }, () => MockClient(harness.respond));
  });

  testWidgets('compact tasks clear rows after live permission rejection',
      (tester) async {
    final harness = _SupplyHarness('qolip');
    await http.runWithClient(() async {
      await harness.mount(tester);
      expect(harness.row(3), findsOneWidget);
      harness.events.addError(const MobileApiException(
          code: 'forbidden', statusCode: 403, message: 'Task access denied'));
      await tester.pumpAndSettle();
      expect(harness.row(3), findsNothing);
      expect(harness.row(6), findsNothing);
      final reads = harness.reads.length;
      final connections = harness.opened.length;
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(harness.reads, hasLength(reads));
      expect(harness.opened, hasLength(connections));
      await harness.close(tester);
    }, () => MockClient(harness.respond));
  });

  testWidgets('compact task reconnects its socket without polling HTTP',
      (tester) async {
    final harness = _SupplyHarness('qolip');
    await http.runWithClient(() async {
      await harness.mount(tester);
      harness.events.addError(http.ClientException('Task socket disconnected'));
      for (var frame = 0; frame < 10 && harness.opened.length < 2; frame++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await tester.pumpAndSettle();
      expect(harness.reads, hasLength(1));
      expect(harness.opened.length, greaterThanOrEqualTo(2));
      final reads = harness.reads.length;
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(harness.reads, hasLength(reads));
      expect(harness.forbiddenReads, isEmpty);
      expect(harness.productReads, isEmpty);
      await harness.close(tester);
    }, () => MockClient(harness.respond));
  });
}
