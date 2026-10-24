import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const product = QolipProduct(
    code: 'DEMO-HOTLUNCH',
    name: 'Hotlunch',
    itemGroup: 'Demo tayyor mahsulotlar',
    warehouse: 'Qolip ombori');

Map<String, dynamic> wireEntry(String id, String code, {String? returnedAt}) =>
    {
      'id': id,
      'qolip_code': code,
      'qolip_set_id': '950100000001',
      'warehouse': 'Qolip ombori',
      'item_code': product.code,
      'item_name': product.name,
      'color': 'Panton 1',
      'size': 40,
      'sent_at': '2026-10-24T10:00:00Z',
      'returned_at': returnedAt,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    resetMobileApiTestModeData();
    await TestModeController.instance.setEnabled(false);
    await ServerEndpointStore.instance.clearOverride();
    AppSession.instance.token = 'rework-token';
    AppSession.instance.profile = const SessionProfile(
        role: UserRole.qolipchi,
        displayName: 'Qolipchi',
        legalName: '',
        ref: 'rework-clerk',
        phone: '',
        avatarUrl: '',
        capabilities: ['qolip.manage']);
    AppSession.instance.revision.value++;
  });
  tearDown(() async {
    await ServerEndpointStore.instance.clearOverride();
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    resetMobileApiTestModeData();
    await TestModeController.instance.setEnabled(false);
  });

  test('wire API deduplicates shared codes and returns only selected entry IDs',
      () async {
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      final sent = await MobileApi.instance.qolipSendToRework(
          requestId: 'stable-send', qolipCodes: [' Q-1 ', 'q-1', 'Q-2']);
      expect(sent.map((row) => row.qolipCode), ['Q-1', 'Q-2']);
      final open = await MobileApi.instance.qolipReworks();
      expect(open, hasLength(2));
      final returned = await MobileApi.instance
          .qolipReturnFromRework(requestId: 'stable-return', reworkIds: ['r1']);
      expect(returned.single.qolipCode, 'Q-1');
      expect(returned.single.isOpen, isFalse);
    },
        () => MockClient((request) async {
              requests.add(request);
              expect(request.headers['Authorization'], 'Bearer rework-token');
              if (request.url.path.endsWith('/send')) {
                expect(jsonDecode(request.body), {
                  'request_id': 'stable-send',
                  'qolip_codes': ['q-1', 'q-2']
                });
                return http.Response(
                    jsonEncode({
                      'reworks': [
                        wireEntry('r1', 'Q-1'),
                        wireEntry('r2', 'Q-2')
                      ]
                    }),
                    200);
              }
              if (request.url.path.endsWith('/return')) {
                expect(jsonDecode(request.body), {
                  'request_id': 'stable-return',
                  'rework_ids': ['r1']
                });
                return http.Response(
                    jsonEncode({
                      'reworks': [
                        wireEntry('r1', 'Q-1',
                            returnedAt: '2026-10-24T11:00:00Z')
                      ]
                    }),
                    200);
              }
              expect(request.url.queryParameters, {'status': 'open'});
              return http.Response(
                  jsonEncode({
                    'reworks': [wireEntry('r1', 'Q-1'), wireEntry('r2', 'Q-2')]
                  }),
                  200);
            }));
    expect(requests, hasLength(3));
  });

  test('partial success response is rejected', () async {
    await http.runWithClient(() async {
      await expectLater(
          MobileApi.instance.qolipSendToRework(
              requestId: 'all-or-none', qolipCodes: ['Q-1', 'Q-2']),
          throwsFormatException);
    },
        () => MockClient((_) async => http.Response(
            jsonEncode({
              'reworks': [wireEntry('r1', 'Q-1')],
            }),
            200)));
  });

  test('server conflict codes and messages are retained', () async {
    await http.runWithClient(() async {
      await expectLater(
          MobileApi.instance
              .qolipSendToRework(requestId: 'conflict', qolipCodes: ['Q-1']),
          throwsA(isA<MobileApiException>()
              .having((error) => error.code, 'code', 'qolip_in_rework')
              .having((error) => error.statusCode, 'status', 409)));
    },
        () => MockClient(
            (_) async => http.Response('{"error":"qolip_in_rework"}', 409)));
    final uz = AppLocalizations(const Locale('uz'));
    expect(
        uz.qolipErrorText('qolip_history_locked'), contains('probeg tarixi'));
    expect(uz.productionErrorMessage('qolip_in_rework'),
        contains('Buyurtma qoliplari peredelkada'));
    expect(
        AppLocalizations(const Locale('en'))
            .productionErrorMessage('qolip_in_rework'),
        contains('molds in rework'));
  });

  test('mileage wire data keeps unknown baseline and old cycles', () async {
    await http.runWithClient(() async {
      final before = await MobileApi.instance.qolipMileage('Q-1');
      expect(before.trackingEnabled, isFalse);
      expect(before.currentMeter, isNull);
      final after = await MobileApi.instance.qolipMileage('Q-2');
      expect(after.currentMeter, 800);
      expect(after.cycles.map((cycle) => cycle.meter), [1200, 800]);
      expect(after.cycles.first.endedAt, isNotNull);
    },
        () => MockClient((request) async {
              final code = request.url.queryParameters['qolip_code'];
              return http.Response(
                  jsonEncode({
                    'mileage': {
                      'qolip_code': code,
                      'tracking_enabled': code == 'Q-2',
                      'current_meter': code == 'Q-2' ? 800 : null,
                      'cycles': code == 'Q-2'
                          ? [
                              {
                                'id': 'c1',
                                'started_at': '2026-10-20T10:00:00Z',
                                'ended_at': '2026-10-24T10:00:00Z',
                                'meter': 1200,
                                'rework_id': 'old'
                              },
                              {
                                'id': 'c2',
                                'started_at': '2026-10-24T10:00:00Z',
                                'ended_at': null,
                                'meter': 800,
                                'rework_id': 'new'
                              },
                            ]
                          : [],
                    }
                  }),
                  200);
            }));
  });

  for (final action in ['list', 'mileage', 'send', 'return']) {
    test('$action discards a pending result after account or server changes',
        () async {
      final started = Completer<void>();
      final response = Completer<http.Response>();
      await http.runWithClient(() async {
        final Future<Object> pending = switch (action) {
          'list' => MobileApi.instance.qolipReworks(),
          'mileage' => MobileApi.instance.qolipMileage('Q-1'),
          'send' => MobileApi.instance.qolipSendToRework(
              requestId: 'pending-send', qolipCodes: ['Q-1']),
          _ => MobileApi.instance.qolipReturnFromRework(
              requestId: 'pending-return', reworkIds: ['r1']),
        };
        final assertion = expectLater(
            pending,
            throwsA(isA<MobileApiException>().having(
                (error) => error.code, 'code', 'session_scope_changed')));
        await started.future;
        if (action == 'return' || action == 'mileage') {
          await ServerEndpointStore.instance
              .setBaseUrl('https://different-rework.example');
        } else {
          AppSession.instance.profile = const SessionProfile(
              role: UserRole.qolipchi,
              displayName: 'Other',
              legalName: '',
              ref: 'other-clerk',
              phone: '',
              avatarUrl: '',
              capabilities: ['qolip.manage']);
          AppSession.instance.revision.value++;
        }
        final nextWindow = QolipCatalogStore.instance.window('new-account');
        nextWindow.loaded = true;
        response.complete(http.Response(
            jsonEncode(action == 'mileage'
                ? {
                    'mileage': {
                      'qolip_code': 'Q-1',
                      'tracking_enabled': false,
                      'current_meter': null,
                      'cycles': []
                    }
                  }
                : {
                    'reworks': [
                      wireEntry('r1', 'Q-1',
                          returnedAt: action == 'return'
                              ? '2026-10-24T11:00:00Z'
                              : null)
                    ]
                  }),
            200));
        await assertion;
        expect(QolipCatalogStore.instance.window('new-account').loaded, isTrue,
            reason:
                'An old mutation must not invalidate the new account catalog');
      },
          () => MockClient((_) {
                started.complete();
                return response.future;
              }));
    });
  }

  test('same-account token refresh does not invalidate pending rework reads',
      () async {
    final started = Completer<void>();
    final response = Completer<http.Response>();
    await http.runWithClient(() async {
      final pending = MobileApi.instance.qolipReworks();
      await started.future;
      AppSession.instance.token = 'refreshed-token';
      AppSession.instance.revision.value++;
      response.complete(http.Response('{"reworks":[]}', 200));
      expect(await pending, isEmpty);
    },
        () => MockClient((_) {
              started.complete();
              return response.future;
            }));
  });

  group('test mode lifecycle', () {
    setUp(() async {
      await TestModeController.instance.setEnabled(true);
      await MobileApi.instance.qolipSaveProductSpecsBatch(
          product: product,
          warehouse: product.warehouse,
          specs: const [
            QolipProductSpecBatchItem(qolipCode: 'RW-A1', size: 40),
            QolipProductSpecBatchItem(qolipCode: 'RW-A2', size: 40),
          ]);
    });

    test(
        'send does not activate mileage; subset return resets only returned codes',
        () async {
      final sent = await MobileApi.instance.qolipSendToRework(
          requestId: 'send', qolipCodes: ['RW-A1', 'rw-a1', 'RW-A2']);
      expect(sent, hasLength(2));
      expect((await MobileApi.instance.qolipMileage('RW-A1')).trackingEnabled,
          isFalse);
      final first = sent.firstWhere((row) => row.qolipCode == 'RW-A1');
      await MobileApi.instance
          .qolipReturnFromRework(requestId: 'return', reworkIds: [first.id]);
      expect(
          (await MobileApi.instance.qolipReworks()).single.qolipCode, 'RW-A2');
      final mileage = await MobileApi.instance.qolipMileage('RW-A1');
      expect(mileage.trackingEnabled, isTrue);
      expect(mileage.currentMeter, 0);
      expect(mileage.cycles, hasLength(1));
      expect((await MobileApi.instance.qolipMileage('RW-A2')).trackingEnabled,
          isFalse);
      await MobileApi.instance
          .qolipReturnFromRework(requestId: 'return', reworkIds: [first.id]);
      expect((await MobileApi.instance.qolipMileage('RW-A1')).cycles,
          hasLength(1));
      final again = await MobileApi.instance
          .qolipSendToRework(requestId: 'send-again', qolipCodes: ['RW-A1']);
      expect((await MobileApi.instance.qolipMileage('RW-A1')).cycles,
          hasLength(1));
      await expectLater(
          MobileApi.instance.qolipReturnFromRework(
              requestId: 'stale-return', reworkIds: [first.id]),
          throwsA(isA<MobileApiException>()));
      await MobileApi.instance.qolipReturnFromRework(
          requestId: 'return-again', reworkIds: [again.single.id]);
      final history = await MobileApi.instance.qolipMileage('RW-A1');
      expect(history.cycles, hasLength(2));
      expect(history.cycles.first.endedAt, isNotNull);
      expect(history.cycles.last.endedAt, isNull);
    });

    test(
        'every order using an away code is blocked even with a complete alternative',
        () async {
      await MobileApi.instance.qolipSaveProductSpecsBatch(
          product: product,
          warehouse: product.warehouse,
          specs: const [
            QolipProductSpecBatchItem(qolipCode: 'RW-B1', size: 40),
            QolipProductSpecBatchItem(qolipCode: 'RW-B2', size: 40),
          ]);
      const second = QolipProduct(
          code: 'DEMO-SALAD',
          name: 'Salat set',
          itemGroup: 'Demo tayyor mahsulotlar',
          warehouse: 'Qolip ombori');
      final shared = await MobileApi.instance.qolipResolveSet('RW-A1');
      await MobileApi.instance.qolipReuseSet(set: shared!, product: second);
      final orderIds = <String>[];
      for (var index = 0; index < 3; index++) {
        final source = index == 2 ? second : product;
        final saved = await MobileApi.instance
            .adminSaveProductionMap(ProductionMapDefinition(
          id: 'zakaz-peredelka-$index',
          productCode: source.code,
          title: 'Peredelka $index',
          orderNumber: 'PED-$index',
          nodes: const [],
          edges: const [],
        ));
        orderIds.add(saved.map.id);
      }
      await MobileApi.instance
          .qolipSendToRework(requestId: 'block-shared', qolipCodes: ['RW-A1']);
      for (final id in orderIds) {
        for (final action in ['start', 'resume']) {
          await expectLater(
              MobileApi.instance.adminApparatusQueueActionResult(
                  apparatus: 'apparatus:default:asset-001',
                  orderId: id,
                  action: action,
                  qolipCodes: const ['RW-B1', 'RW-B2']),
              throwsA(isA<MobileApiException>()
                  .having((error) => error.code, 'code', 'qolip_in_rework')));
        }
      }
    });

    test('invalid batch is atomic and request replay cannot change its codes',
        () async {
      await expectLater(
          MobileApi.instance.qolipSendToRework(
              requestId: 'bad', qolipCodes: ['RW-A1', 'MISSING']),
          throwsA(isA<MobileApiException>()));
      expect(await MobileApi.instance.qolipReworks(), isEmpty);
      final first = await MobileApi.instance
          .qolipSendToRework(requestId: 'same', qolipCodes: ['RW-A1']);
      expect(
          (await MobileApi.instance
                  .qolipSendToRework(requestId: 'same', qolipCodes: ['rw-a1']))
              .single
              .id,
          first.single.id);
      await expectLater(
          MobileApi.instance
              .qolipSendToRework(requestId: 'same', qolipCodes: ['RW-A2']),
          throwsA(isA<MobileApiException>()));
      expect(await MobileApi.instance.qolipReworks(), hasLength(1));
    });
  });
}
