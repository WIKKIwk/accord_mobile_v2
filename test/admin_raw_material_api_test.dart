import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/inventory_movement_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    resetMobileApiTestModeData();
  });

  tearDown(() async {
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('queue action sends material barcode when provided', () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Aparatchi',
      legalName: '',
      ref: 'ap-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.manage'],
    );

    await HttpOverrides.runZoned(() async {
      final states = await MobileApi.instance.adminApparatusQueueAction(
        apparatus: 'Pechat',
        orderId: 'zakaz-1',
        action: 'start',
        materialBarcode: 'RM-001',
      );

      expect(states, {'zakaz-1': 'in_progress'});
      expect(
        seenRequests,
        contains(
          'BODY POST /v1/mobile/admin/production-maps/queue-action '
          '{"apparatus":"Pechat","order_id":"zakaz-1","action":"start",'
          '"material_barcode":"RM-001"}',
        ),
      );
    }, createHttpClient: (_) => _RawMaterialApiHttpClient(seenRequests));
  });

  test('qolip is confirmed only after backend order validation', () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';

    await HttpOverrides.runZoned(() async {
      final validatedCode =
          await MobileApi.instance.adminValidateProductionMapQolip(
        apparatus: '7 ta rangli bosma aparat',
        orderId: 'zakaz-1212',
        qolipCode: 'QOLIP-1212',
      );

      expect(validatedCode, 'QOLIP-1212');
      expect(
        seenRequests,
        contains(
          'BODY POST /v1/mobile/admin/production-maps/qolip-validate '
          '{"apparatus":"7 ta rangli bosma aparat",'
          '"order_id":"zakaz-1212","qolip_code":"QOLIP-1212"}',
        ),
      );
    }, createHttpClient: (_) => _RawMaterialApiHttpClient(seenRequests));
  });

  test('qolip requirements expose the complete mold code and color set',
      () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';

    await HttpOverrides.runZoned(() async {
      final validation =
          await MobileApi.instance.adminProductionMapQolipRequirements(
        apparatus: '7 ta rangli bosma aparat',
        orderId: 'zakaz-1212',
      );

      expect(validation.qolipCode, isEmpty);
      expect(
        validation.requiredQolipCodes,
        ['QOLIP-1212', 'QOLIP-1213', 'QOLIP-1214', 'QOLIP-1215'],
      );
      expect(validation.requiredQolips, hasLength(4));
      expect(validation.requiredQolips.first.color, '#E53935');
      expect(
        seenRequests,
        contains(
          'BODY POST /v1/mobile/admin/production-maps/qolip-validate '
          '{"apparatus":"7 ta rangli bosma aparat",'
          '"order_id":"zakaz-1212","qolip_code":""}',
        ),
      );
    },
        createHttpClient: (_) => _RawMaterialApiHttpClient(
              seenRequests,
              qolipValidationQolipCode: '',
            ));
  });

  test('qolip metadata is never invented from count or code-only fields', () {
    final validation = AdminProductionMapQolipValidation.fromJson(const {
      'qolip_code': '',
      'required_qolip_codes': ['QOLIP-ONLY-CODE'],
      'required_qolip_count': 1,
    });

    expect(validation.requiredQolips, isEmpty);
    expect(validation.requiredQolipCodes, isEmpty);
  });

  test('queue action sends unique scanned qolip codes together', () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';

    await HttpOverrides.runZoned(() async {
      final states = await MobileApi.instance.adminApparatusQueueAction(
        apparatus: '7 ta rangli bosma aparat',
        orderId: 'zakaz-1212',
        action: 'start',
        qolipCodes: const ['QOLIP-1', 'QOLIP-2', 'qolip-2'],
      );

      expect(states, {'zakaz-1': 'in_progress'});
      expect(
        seenRequests,
        contains(
          'BODY POST /v1/mobile/admin/production-maps/queue-action '
          '{"apparatus":"7 ta rangli bosma aparat",'
          '"order_id":"zakaz-1212","action":"start",'
          '"qolip_codes":["QOLIP-1","QOLIP-2"]}',
        ),
      );
    }, createHttpClient: (_) => _RawMaterialApiHttpClient(seenRequests));
  });

  test('qolip validation exposes backend rejection', () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';

    await HttpOverrides.runZoned(() async {
      await expectLater(
        MobileApi.instance.adminValidateProductionMapQolip(
          apparatus: '7 ta rangli bosma aparat',
          orderId: 'zakaz-1212',
          qolipCode: 'UNKNOWN',
        ),
        throwsA(
          isA<MobileApiException>()
              .having((error) => error.code, 'code', 'qolip_code_not_found'),
        ),
      );
    },
        createHttpClient: (_) => _RawMaterialApiHttpClient(
              seenRequests,
              qolipValidationErrorCode: 'qolip_code_not_found',
            ));
  });

  test('queue action explains incompatible raw material scan', () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Aparatchi',
      legalName: '',
      ref: 'ap-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.manage'],
    );

    await HttpOverrides.runZoned(() async {
      await expectLater(
        MobileApi.instance.adminApparatusQueueAction(
          apparatus: 'Pechat',
          orderId: 'zakaz-1',
          action: 'start',
          materialBarcode: 'OTHER-RM',
        ),
        throwsA(
          isA<MobileApiException>().having(
            (error) => error.message,
            'message',
            'Bu homashyo ish boshlash uchun mos emas',
          ),
        ),
      );
    },
        createHttpClient: (_) => _RawMaterialApiHttpClient(
              seenRequests,
              queueActionErrorCode: 'raw_material_group_not_allowed',
            ));
  });

  test('queue action translates production map backend errors', () async {
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Aparatchi',
      legalName: '',
      ref: 'ap-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.manage'],
    );
    const expectedMessages = {
      'laminatsiya_completion_metrics_required':
          'Laminatsiyani tugatish uchun barcha majburiy qiymatlarni kiriting',
      'laminatsiya_rubber_too_large':
          'Rezina razmeri 1050 mm dan katta bo‘lsa laminatsiya mumkin emas',
      'raw_material_stock_unavailable':
          'Bu homashyo omborda mavjud emas yoki boshqa zakaz uchun band',
      'insufficient_stock': 'Bu qolip omborda qolmagan',
      'qolip_scan_incomplete':
          'Mahsulotga biriktirilgan barcha qoliplarni scan qiling',
      'returned_paint_astatka_exceeds_rasxot':
          'Astatka Rasxotdan katta bo‘lishi mumkin emas',
      'astatka cannot exceed rasxot':
          'Astatka Rasxotdan katta bo‘lishi mumkin emas',
    };

    for (final entry in expectedMessages.entries) {
      await HttpOverrides.runZoned(() async {
        await expectLater(
          MobileApi.instance.adminApparatusQueueAction(
            apparatus: 'Laminatsiya 1',
            orderId: 'zakaz-1',
            action: 'complete',
          ),
          throwsA(
            isA<MobileApiException>()
                .having((error) => error.code, 'code', entry.key)
                .having((error) => error.message, 'message', entry.value),
          ),
        );
      },
          createHttpClient: (_) => _RawMaterialApiHttpClient(
                <String>[],
                queueActionErrorCode: entry.key,
              ));
    }
  });

  test('queue progress action sends qty and reads progress batch', () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Aparatchi',
      legalName: '',
      ref: 'ap-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.manage'],
    );

    await HttpOverrides.runZoned(() async {
      final result = await MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: 'Pechat',
        orderId: 'zakaz-1',
        action: 'pause',
        producedQty: 12.5,
        grossQty: 17,
        uom: 'm',
        driverUrl: ' http://127.0.0.1:39117/ ',
      );
      final batch = await MobileApi.instance.adminProgressQrLookup(
        'GSP:PROGRESS-1',
      );

      expect(result.states, {'zakaz-1': 'paused'});
      expect(result.progressBatch?.qrPayload, 'GSP:PROGRESS-1');
      expect(batch.status, 'paused');
      expect(
        seenRequests,
        contains(
          'BODY POST /v1/mobile/admin/production-maps/queue-action '
          '{"apparatus":"Pechat","order_id":"zakaz-1","action":"pause",'
          '"produced_qty":12.5,"gross_qty":17.0,"uom":"m",'
          '"driver_url":"http://127.0.0.1:39117"}',
        ),
      );
      expect(
        seenRequests,
        contains(
          'BODY POST /v1/mobile/admin/production-maps/progress-qr/lookup '
          '{"qr_payload":"GSP:PROGRESS-1"}',
        ),
      );
    },
        createHttpClient: (_) => _RawMaterialApiHttpClient(
              seenRequests,
              queueActionProgress: true,
            ));
  });

  test('progress qr report reads server aggregated order flow', () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['admin.access'],
    );

    await HttpOverrides.runZoned(() async {
      final report = await MobileApi.instance.adminProgressQrReport(
        'GSP:PROGRESS-OLD',
      );

      expect(report.scannedBatch.qrPayload, 'GSP:PROGRESS-OLD');
      expect(report.currentBatch?.qrPayload, 'GSP:PROGRESS-NEW');
      expect(report.currentBatch?.statusDetail.workStatus, 'completed');
      expect(
        report.currentBatch?.statusDetail.flowStatus,
        'free_wip',
      );
      expect(report.currentBatch?.statusDetail.stockStatus, isEmpty);
      expect(report.orderStatus.orderStatus, 'completed');
      expect(report.orderStatus.flowStatus, 'free_wip');
      expect(report.orderStatus.stockStatus, isEmpty);
      expect(report.orderStatus.freeWipCount, 1);
      expect(report.orderStatus.completedQueueCount, 1);
      expect(report.orderStatus.completedWithIssueCount, 0);
      expect(report.isStale, isTrue);
      expect(report.staleReason, 'processed_by_next_stage');
      expect(report.order?.id, 'zakaz-1');
      expect(report.queueStates['Qadoqlash stol']?['zakaz-1'], 'completed');
      expect(report.logs.single.actorDisplayName, 'Aparatchi');
      expect(report.runSessions.map((session) => session.status), [
        'completed',
        'completed',
      ]);
      expect(report.openedBy?.actorRef, 'worker-1');
      expect(
        seenRequests,
        contains(
          'BODY POST /v1/mobile/admin/production-maps/progress-qr/report '
          '{"qr_payload":"GSP:PROGRESS-OLD"}',
        ),
      );
    }, createHttpClient: (_) => _RawMaterialApiHttpClient(seenRequests));
  });

  test('bosma complete action sends completion metrics and parses them',
      () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Bosma aparatchi',
      legalName: '',
      ref: 'ap-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.manage'],
    );

    await HttpOverrides.runZoned(() async {
      final result = await MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: '7 ta rangli bosma',
        orderId: 'zakaz-1',
        action: 'complete',
        returnInkKg: 1.25,
        totalWaste: 2.5,
        finishedGoodsKg: 18.75,
        finishedGoodsMeter: 125.5,
        driverUrl: 'http://127.0.0.1:39117',
      );

      expect(result.states, {'zakaz-1': 'completed'});
      expect(result.progressBatch?.returnInkKg, 1.25);
      expect(result.progressBatch?.totalWaste, 2.5);
      expect(result.progressBatch?.finishedGoodsKg, 18.75);
      expect(result.progressBatch?.finishedGoodsMeter, 125.5);
      expect(
        seenRequests,
        contains(
          'BODY POST /v1/mobile/admin/production-maps/queue-action '
          '{"apparatus":"7 ta rangli bosma","order_id":"zakaz-1",'
          '"action":"complete","return_ink_kg":1.25,"total_waste":2.5,'
          '"finished_goods_kg":18.75,"finished_goods_meter":125.5,'
          '"driver_url":"http://127.0.0.1:39117"}',
        ),
      );
    },
        createHttpClient: (_) => _RawMaterialApiHttpClient(
              seenRequests,
              queueActionProgress: true,
              queueActionCompleteMetrics: true,
            ));
  });

  test('laminatsiya complete action sends completion metrics and parses them',
      () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Laminatsiya operatori',
      legalName: '',
      ref: 'lam-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.manage'],
    );

    await HttpOverrides.runZoned(() async {
      final result = await MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: 'Laminatsiya 1',
        orderId: 'zakaz-1',
        action: 'complete',
        laminationPrintLeftoverRolls: 1.5,
        laminationFilmLeftoverRolls: 2.5,
        totalWaste: 3.5,
        finishedGoodsKg: 20.75,
        finishedGoodsMeter: 140.25,
        driverUrl: 'http://127.0.0.1:39117',
      );

      expect(result.states, {'zakaz-1': 'completed'});
      expect(result.progressBatch?.laminationPrintLeftoverRolls, 1.5);
      expect(result.progressBatch?.laminationFilmLeftoverRolls, 2.5);
      expect(result.progressBatch?.totalWaste, 3.5);
      expect(result.progressBatch?.finishedGoodsKg, 20.75);
      expect(result.progressBatch?.finishedGoodsMeter, 140.25);
      expect(
        seenRequests,
        contains(
          'BODY POST /v1/mobile/admin/production-maps/queue-action '
          '{"apparatus":"Laminatsiya 1","order_id":"zakaz-1",'
          '"action":"complete","lamination_print_leftover_rolls":1.5,'
          '"lamination_film_leftover_rolls":2.5,"total_waste":3.5,'
          '"finished_goods_kg":20.75,"finished_goods_meter":140.25,'
          '"driver_url":"http://127.0.0.1:39117"}',
        ),
      );
    },
        createHttpClient: (_) => _RawMaterialApiHttpClient(
              seenRequests,
              queueActionLaminatsiyaMetrics: true,
            ));
  });

  test('rezka complete action sends progress metrics and parses them',
      () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Rezka operatori',
      legalName: '',
      ref: 'rez-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.manage'],
    );

    await HttpOverrides.runZoned(() async {
      final result = await MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: 'Rezka',
        orderId: 'zakaz-1',
        action: 'complete',
        producedQty: 32,
        grossQty: 32,
        rezkaBosmaWaste: 1.25,
        rezkaLaminationWaste: 2.5,
        rezkaEdgeWaste: 0.75,
        uom: 'kg',
        driverUrl: 'http://127.0.0.1:39117',
      );

      expect(result.states, {'zakaz-1': 'completed'});
      expect(result.progressBatch?.rezkaBosmaWaste, 1.25);
      expect(result.progressBatch?.rezkaLaminationWaste, 2.5);
      expect(result.progressBatch?.rezkaEdgeWaste, 0.75);
      expect(
        seenRequests,
        contains(
          'BODY POST /v1/mobile/admin/production-maps/queue-action '
          '{"apparatus":"Rezka","order_id":"zakaz-1",'
          '"action":"complete","produced_qty":32.0,"gross_qty":32.0,'
          '"rezka_bosma_waste":1.25,"rezka_lamination_waste":2.5,'
          '"rezka_edge_waste":0.75,"uom":"kg",'
          '"driver_url":"http://127.0.0.1:39117"}',
        ),
      );
    },
        createHttpClient: (_) => _RawMaterialApiHttpClient(
              seenRequests,
              queueActionRezkaMetrics: true,
            ));
  });

  test('closed production orders endpoint parses full action logs', () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['production_map.manage'],
    );

    await HttpOverrides.runZoned(() async {
      final orders = await MobileApi.instance.adminClosedProductionMapOrders();

      expect(orders, hasLength(1));
      expect(orders.first.orderId, 'zakaz-closed-route');
      expect(orders.first.orderNumber, '9401');
      expect(orders.first.closedByRef, 'worker-closed-lamin');
      expect(orders.first.logs, hasLength(2));
      expect(orders.first.logs.first.action, 'start');
      expect(orders.first.logs.last.apparatus, 'Laminatsiya 1');
      expect(
        seenRequests,
        contains('GET /v1/mobile/admin/production-maps/closed-orders'),
      );
    }, createHttpClient: (_) => _RawMaterialApiHttpClient(seenRequests));
  });

  test('test mode resumes paused next order after previous completion',
      () async {
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Aparatchi',
      legalName: '',
      ref: 'ap-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.manage'],
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: 'Pechat resume',
      orderIds: const ['zakaz-resume-completed', 'zakaz-resume-1'],
    );

    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: 'Pechat resume',
      orderId: 'zakaz-resume-completed',
      action: 'start',
    );
    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: 'Pechat resume',
      orderId: 'zakaz-resume-completed',
      action: 'complete',
      producedQty: 1,
      grossQty: 1,
      uom: 'kg',
    );

    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: 'Pechat resume',
      orderId: 'zakaz-resume-1',
      action: 'start',
    );
    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: 'Pechat resume',
      orderId: 'zakaz-resume-1',
      action: 'pause',
      producedQty: 3,
      uom: 'kg',
    );
    final resumed = await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: 'Pechat resume',
      orderId: 'zakaz-resume-1',
      action: 'resume',
    );

    expect(resumed.states['zakaz-resume-completed'], 'completed');
    expect(resumed.states['zakaz-resume-1'], 'in_progress');
    expect(resumed.progressBatch, isNull);
  });

  test('wip batches endpoint sends filters and parses current location',
      () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['production.map.manage'],
    );

    await HttpOverrides.runZoned(() async {
      final batches = await MobileApi.instance.adminWipBatches(
        status: 'waiting',
        apparatus: 'Pechat',
        currentLocation: 'Pechat yonida',
        limit: 25,
      );

      expect(batches, hasLength(1));
      expect(batches.first.batchId, 'progress-1');
      expect(batches.first.wipStatus, 'waiting');
      expect(batches.first.currentApparatusKey, 'pechat');
      expect(batches.first.nextApparatus, 'Laminatsiya 1');
      expect(
        seenRequests,
        contains(
          'GET /v1/mobile/admin/production-maps/wip-batches?'
          'status=waiting&apparatus=Pechat&current_location=Pechat+yonida&limit=25',
        ),
      );
    }, createHttpClient: (_) => _RawMaterialApiHttpClient(seenRequests));
  });

  test('wip batches endpoint sends previous and next apparatus filters',
      () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Laminatsiya worker',
      legalName: '',
      ref: 'worker-lamin',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read'],
    );

    await HttpOverrides.runZoned(() async {
      final batches = await MobileApi.instance.adminWipBatches(
        status: 'waiting',
        apparatus: '7 ta rangli pechat',
        nextApparatus: 'Laminatsiya 1',
        orderId: 'zakaz-1111',
        limit: 250,
      );

      expect(batches, hasLength(1));
      expect(batches.first.nextApparatus, 'Laminatsiya 1');
      expect(
        seenRequests,
        contains(
          'GET /v1/mobile/admin/production-maps/wip-batches?'
          'status=waiting&apparatus=7+ta+rangli+pechat&'
          'next_apparatus=Laminatsiya+1&order_id=zakaz-1111&limit=250',
        ),
      );
    }, createHttpClient: (_) => _RawMaterialApiHttpClient(seenRequests));
  });

  test('wip batches endpoint can include already used batches', () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Laminatsiya worker',
      legalName: '',
      ref: 'worker-lamin',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read'],
    );

    await HttpOverrides.runZoned(() async {
      final batches = await MobileApi.instance.adminWipBatches(
        status: 'all',
        apparatus: '7 ta rangli pechat',
        nextApparatus: 'Laminatsiya 1',
        orderId: 'zakaz-1111',
        limit: 250,
      );

      expect(batches.map((batch) => batch.wipStatus), [
        'waiting',
        'processed',
      ]);
      expect(
        seenRequests,
        contains(
          'GET /v1/mobile/admin/production-maps/wip-batches?'
          'status=all&apparatus=7+ta+rangli+pechat&next_apparatus=Laminatsiya+1&'
          'order_id=zakaz-1111&limit=250',
        ),
      );
    }, createHttpClient: (_) => _RawMaterialApiHttpClient(seenRequests));
  });

  test('raw material rule and assignment endpoints use backend contract',
      () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['raw_material.rule.manage', 'raw_material.assign'],
    );

    await HttpOverrides.runZoned(() async {
      final rule = await MobileApi.instance.adminSaveRawMaterialRule(
        apparatus: 'Pechat',
        requiresMaterial: true,
        startPolicy: AdminRawMaterialStartPolicy.requirementGroups,
        itemGroups: const ['Kraska', 'Kley'],
        requirementGroups: const [
          AdminRawMaterialRequirementGroup(
            name: 'Yopishtiruvchi',
            itemGroups: ['Kraska', 'Kley'],
            minRequiredCount: 1,
          ),
        ],
      );
      final assignment = await MobileApi.instance.adminAssignRawMaterialToOrder(
        orderId: 'zakaz-1',
        barcode: 'RM-001',
        apparatus: 'Pechat',
      );

      expect(rule.apparatus, 'Pechat');
      expect(rule.requiresMaterial, isTrue);
      expect(
        rule.startPolicy,
        AdminRawMaterialStartPolicy.requirementGroups,
      );
      expect(rule.itemGroups, ['Kraska', 'Kley']);
      expect(rule.requirementGroups, hasLength(1));
      expect(rule.requirementGroups.first.name, 'Yopishtiruvchi');
      expect(rule.requirementGroups.first.itemGroups, ['Kraska', 'Kley']);
      expect(assignment.orderId, 'zakaz-1');
      expect(assignment.barcode, 'RM-001');
      expect(assignment.stockStatus, 'in_use');
      expect(assignment.reservedOrderId, 'zakaz-1');
      expect(assignment.stockWarehouse, 'Kalidor');
      expect(
        seenRequests,
        contains(
          'BODY PUT /v1/mobile/admin/raw-material-rules '
          '{"apparatus":"Pechat","requires_material":true,'
          '"start_policy":"requirement_groups",'
          '"item_groups":["Kraska","Kley"],'
          '"requirement_groups":[{"name":"Yopishtiruvchi",'
          '"item_groups":["Kraska","Kley"],"min_required_count":1}]}',
        ),
      );
      expect(
        seenRequests,
        contains(
          'BODY POST /v1/mobile/admin/raw-material-assignments '
          '{"order_id":"zakaz-1","barcode":"RM-001",'
          '"apparatus":"Pechat"}',
        ),
      );
    }, createHttpClient: (_) => _RawMaterialApiHttpClient(seenRequests));
  });

  test('start requirements consume backend eligibility and scan status', () {
    final requirements = AdminRawMaterialStartRequirements.fromJson(const {
      'policy': 'state_all',
      'requires_material': true,
      'assigned_barcodes': [
        'RM-01',
        'RM-02',
        'RM-03',
        'RM-04',
        'RM-05',
        'RM-06',
        'RM-07',
        'RM-08',
        'RM-09',
        'RM-10',
      ],
      'staged_barcodes': ['RM-01', 'RM-02', 'RM-03'],
      'eligible_barcodes': ['RM-01', 'RM-02', 'RM-03'],
      'requirement_groups': [],
      'required_scan_count': 3,
      'matched_scan_count': 2,
      'assignments_satisfied': true,
      'scan_satisfied': false,
      'assignments': [
        {
          'order_id': 'zakaz-1',
          'apparatus': 'Pechat',
          'barcode': 'RM-01',
          'item_code': 'RM-1',
          'item_name': 'Rulon 1',
          'item_group': 'Rulon',
        },
        {
          'order_id': 'zakaz-1',
          'apparatus': 'Pechat',
          'barcode': 'RM-02',
          'item_code': 'RM-2',
          'item_name': 'Rulon 2',
          'item_group': 'Rulon',
        },
        {
          'order_id': 'zakaz-1',
          'apparatus': 'Pechat',
          'barcode': 'RM-03',
          'item_code': 'RM-3',
          'item_name': 'Rulon 3',
          'item_group': 'Rulon',
        },
        {
          'order_id': 'zakaz-1',
          'apparatus': 'Laminatsiya',
          'barcode': 'RM-04',
          'item_code': 'RM-4',
          'item_name': 'Kley 1',
          'item_group': 'Kley',
        },
      ],
      'start_assignments': [
        {
          'order_id': 'zakaz-1',
          'apparatus': 'Pechat',
          'barcode': 'RM-01',
          'item_code': 'RM-1',
          'item_name': 'Rulon 1',
          'item_group': 'Rulon',
        },
        {
          'order_id': 'zakaz-1',
          'apparatus': 'Pechat',
          'barcode': 'RM-02',
          'item_code': 'RM-2',
          'item_name': 'Rulon 2',
          'item_group': 'Rulon',
        },
        {
          'order_id': 'zakaz-1',
          'apparatus': 'Pechat',
          'barcode': 'RM-03',
          'item_code': 'RM-3',
          'item_name': 'Rulon 3',
          'item_group': 'Rulon',
        },
      ],
    });

    expect(requirements.assignments, hasLength(4));
    expect(requirements.startAssignments, hasLength(3));
    expect(requirements.requiredScanCount, 3);
    expect(requirements.matchedScanCount, 2);
    expect(requirements.assignmentsSatisfied, isTrue);
    expect(requirements.scanSatisfied, isFalse);
  });

  test('raw material start requirements use backend state context', () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';

    await HttpOverrides.runZoned(() async {
      final requirements =
          await MobileApi.instance.adminRawMaterialStartRequirements(
        orderId: 'zakaz-1',
        apparatus: 'Pechat',
        materialBarcodes: const ['RM-01'],
      );

      expect(requirements.policy, AdminRawMaterialStartPolicy.stateAll);
      expect(requirements.assignedBarcodes, ['RM-01', 'RM-02', 'RM-03']);
      expect(requirements.stagedBarcodes, ['RM-01', 'RM-02']);
      expect(requirements.assignments, hasLength(2));
      expect(requirements.startAssignments, hasLength(2));
      expect(requirements.requiredScanCount, 2);
      expect(requirements.matchedScanCount, 1);
      expect(requirements.scanSatisfied, isFalse);
      expect(
        seenRequests,
        contains(
          'GET /v1/mobile/admin/raw-material-start-requirements?'
          'order_id=zakaz-1&apparatus=Pechat&material_barcodes=RM-01',
        ),
      );
    }, createHttpClient: (_) => _RawMaterialApiHttpClient(seenRequests));
  });

  test('raw material assignments send order scope', () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';

    await HttpOverrides.runZoned(() async {
      final assignments = await MobileApi.instance.adminRawMaterialAssignments(
        orderId: 'zakaz-1',
      );

      expect(assignments.map((item) => item.barcode), ['RM-001']);
      expect(
        seenRequests,
        contains(
          'GET /v1/mobile/admin/raw-material-assignments?'
          'order_id=zakaz-1',
        ),
      );
    }, createHttpClient: (_) => _RawMaterialApiHttpClient(seenRequests));
  });

  test('requirement group validation status comes from backend', () {
    const requirements = AdminRawMaterialStartRequirements(
      policy: AdminRawMaterialStartPolicy.requirementGroups,
      requiresMaterial: true,
      assignedBarcodes: ['RM-UNIVERSAL', 'RM-KLEY'],
      requiredScanCount: 2,
      matchedScanCount: 1,
      assignmentsSatisfied: true,
      scanSatisfied: false,
      requirementGroups: [
        AdminRawMaterialRequirementGroup(
          name: 'Bo‘yoq',
          itemGroups: ['Kraska', 'Universal'],
        ),
        AdminRawMaterialRequirementGroup(
          name: 'Yopishtiruvchi',
          itemGroups: ['Kley', 'Universal'],
        ),
      ],
    );

    expect(requirements.requiredScanCount, 2);
    expect(requirements.matchedScanCount, 1);
    expect(requirements.assignmentsSatisfied, isTrue);
    expect(requirements.scanSatisfied, isFalse);
  });

  test('raw material assignment exposes apparatus choices from backend',
      () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['raw_material.assign'],
    );

    await HttpOverrides.runZoned(() async {
      await expectLater(
        MobileApi.instance.adminAssignRawMaterialToOrder(
          orderId: 'zakaz-1',
          barcode: 'RM-001',
        ),
        throwsA(
          isA<MobileApiException>()
              .having(
            (error) => error.code,
            'code',
            'raw_material_group_ambiguous',
          )
              .having(
            (error) => error.apparatusOptions,
            'apparatusOptions',
            ['7 ta rangli pechat', 'Laminatsiya 1'],
          ).having(
            (error) => error.message,
            'message',
            'Bu homashyoni qaysi aparatga ulashni tanlang',
          ),
        ),
      );
    },
        createHttpClient: (_) => _RawMaterialApiHttpClient(
              seenRequests,
              assignmentErrorCode: 'raw_material_group_ambiguous',
              assignmentErrorApparatusOptions: const [
                '7 ta rangli pechat',
                'Laminatsiya 1',
              ],
            ));
  });

  test(
      'active order raw material intake sends worker contract and parses balance',
      () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';

    await HttpOverrides.runZoned(() async {
      final assignment =
          await MobileApi.instance.adminReceiveRawMaterialForActiveOrder(
        orderId: 'zakaz-1',
        apparatus: 'Pechat',
        barcode: 'ROLL-1000-B',
      );

      expect(assignment.orderId, 'zakaz-1');
      expect(assignment.barcode, 'ROLL-1000-B');
      expect(assignment.stockStatus, 'in_use');
      expect(assignment.stockQty, 1000);
      expect(assignment.stockUom, 'm');
      expect(assignment.receivedQty, 1000);
      expect(assignment.consumedQty, 0);
      expect(assignment.remainingQty, 1000);
      expect(
        seenRequests,
        contains(
          'BODY POST /v1/mobile/admin/raw-material-intake '
          '{"order_id":"zakaz-1","apparatus":"Pechat",'
          '"barcode":"ROLL-1000-B"}',
        ),
      );
    }, createHttpClient: (_) => _RawMaterialApiHttpClient(seenRequests));
  });

  test('raw material intake candidates use backend order and apparatus scope',
      () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';

    await HttpOverrides.runZoned(() async {
      final candidates =
          await MobileApi.instance.adminRawMaterialIntakeCandidates(
        orderId: 'zakaz-1',
        apparatus: 'Pechat',
      );

      expect(candidates.map((item) => item.barcode), ['RM-AVAILABLE']);
      expect(candidates.single.stockStatus, 'available');
      expect(
        seenRequests,
        contains(
          'GET /v1/mobile/admin/raw-material-intake-candidates?'
          'order_id=zakaz-1&apparatus=Pechat',
        ),
      );
    }, createHttpClient: (_) => _RawMaterialApiHttpClient(seenRequests));
  });

  test('test mode intake only accepts unused assigned material at apparatus',
      () async {
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Aparatchi',
      legalName: '',
      ref: 'worker-intake',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.manage'],
      assignedApparatus: ['Pechat intake'],
    );
    const location = InventoryLocation(
      id: 'state:pechat-intake',
      kind: InventoryLocationKind.state,
      name: 'Pechat oldi',
      factoryLocationId: 'factory:pechat',
      apparatus: [
        InventoryLocationApparatus(
          id: 'apparatus:pechat-intake',
          name: 'Pechat intake',
        ),
      ],
    );
    seedMobileApiInventoryMovementTestData(
      locations: const [location],
      assets: const [
        InventoryAsset(
          kind: InventoryAssetKind.rawMaterial,
          assetRef: 'raw:assigned-intake',
          custodyWarehouseId: 'warehouse:material',
          custodyWarehouse: 'Material ombor',
          itemCode: 'INK-1',
          itemName: 'Black ink',
          identifier: 'ASSIGNED-INTAKE',
          qty: 25,
          uom: 'kg',
          status: 'available',
          physicalLocation: InventoryLocationReference(
            id: 'state:pechat-intake',
            kind: InventoryLocationKind.state,
            name: 'Pechat oldi',
          ),
        ),
      ],
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: 'Pechat intake',
      orderIds: const ['zakaz-intake'],
    );
    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: 'Pechat intake',
      orderId: 'zakaz-intake',
      action: 'start',
    );
    await MobileApi.instance.adminAssignRawMaterialToOrder(
      orderId: 'zakaz-intake',
      apparatus: 'Pechat intake',
      barcode: 'ASSIGNED-INTAKE',
    );

    expect(
      await MobileApi.instance.adminRawMaterialIntakeCandidates(
        orderId: 'zakaz-intake',
        apparatus: 'Pechat intake',
      ),
      hasLength(1),
    );

    final received =
        await MobileApi.instance.adminReceiveRawMaterialForActiveOrder(
      orderId: 'zakaz-intake',
      apparatus: 'Pechat intake',
      barcode: 'ASSIGNED-INTAKE',
    );
    expect(received.stockStatus, 'in_use');
    expect(received.receivedQty, 25);
    expect(
      await MobileApi.instance.adminRawMaterialIntakeCandidates(
        orderId: 'zakaz-intake',
        apparatus: 'Pechat intake',
      ),
      isEmpty,
    );

    await expectLater(
      MobileApi.instance.adminReceiveRawMaterialForActiveOrder(
        orderId: 'zakaz-intake',
        apparatus: 'Pechat intake',
        barcode: 'ASSIGNED-INTAKE',
      ),
      throwsA(
        isA<MobileApiException>().having(
          (error) => error.code,
          'code',
          'raw_material_stock_unavailable',
        ),
      ),
    );
    await expectLater(
      MobileApi.instance.adminReceiveRawMaterialForActiveOrder(
        orderId: 'zakaz-intake',
        apparatus: 'Pechat intake',
        barcode: 'UNASSIGNED-INTAKE',
      ),
      throwsA(
        isA<MobileApiException>().having(
          (error) => error.code,
          'code',
          'raw_material_assignment_not_found',
        ),
      ),
    );
    expect(
      await MobileApi.instance.adminRawMaterialAssignments(
        orderId: 'zakaz-intake',
      ),
      hasLength(1),
    );
  });

  test('raw material lookup returns understandable scan report data', () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['admin.access'],
    );

    await HttpOverrides.runZoned(() async {
      final lookup = await MobileApi.instance.adminRawMaterialLookup(
        barcode: 'RM-001',
      );

      expect(lookup.barcode, 'RM-001');
      expect(lookup.status, 'in_use');
      expect(lookup.reservedOrderId, 'zakaz-1');
      expect(lookup.assignment?.apparatus, 'Pechat');
      expect(lookup.order?.title, 'Paynet');
      expect(lookup.logs.single.action, 'start');
      expect(
        seenRequests,
        contains(
            'GET /v1/mobile/admin/raw-material-assignments/lookup?barcode=RM-001'),
      );
    }, createHttpClient: (_) => _RawMaterialApiHttpClient(seenRequests));
  });

  test('raw material assignment explains occupied barcode', () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['raw_material.assign'],
    );

    await HttpOverrides.runZoned(() async {
      await expectLater(
        MobileApi.instance.adminAssignRawMaterialToOrder(
          orderId: 'zakaz-2',
          barcode: 'RM-001',
        ),
        throwsA(
          isA<MobileApiException>().having(
            (error) => error.message,
            'message',
            'Bu homashyo boshqa zakaz uchun band qilingan',
          ),
        ),
      );
    },
        createHttpClient: (_) => _RawMaterialApiHttpClient(
              seenRequests,
              assignmentErrorCode: 'raw_material_already_assigned',
            ));
  });

  test('raw material assignment explains barcode already linked to same order',
      () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['raw_material.assign'],
    );

    await HttpOverrides.runZoned(() async {
      await expectLater(
        MobileApi.instance.adminAssignRawMaterialToOrder(
          orderId: 'zakaz-1',
          barcode: 'RM-001',
        ),
        throwsA(
          isA<MobileApiException>().having(
            (error) => error.message,
            'message',
            'Bu homashyo allaqachon shu zakazga ulangan',
          ),
        ),
      );
    },
        createHttpClient: (_) => _RawMaterialApiHttpClient(
              seenRequests,
              assignmentErrorCode: 'raw_material_already_assigned_to_order',
            ));
  });

  test('raw material assignment unlink uses backend contract', () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['raw_material.assign'],
    );

    await HttpOverrides.runZoned(() async {
      final removed = await MobileApi.instance.adminUnlinkRawMaterialAssignment(
        orderId: 'zakaz-1',
        barcode: 'RM-001',
      );

      expect(removed.orderId, 'zakaz-1');
      expect(removed.barcode, 'RM-001');
      expect(
        seenRequests,
        contains(
          'BODY DELETE /v1/mobile/admin/raw-material-assignments '
          '{"order_id":"zakaz-1","barcode":"RM-001"}',
        ),
      );
    }, createHttpClient: (_) => _RawMaterialApiHttpClient(seenRequests));
  });

  test('raw material assignment unlink explains locked stock', () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['raw_material.assign'],
    );

    await HttpOverrides.runZoned(() async {
      await expectLater(
        MobileApi.instance.adminUnlinkRawMaterialAssignment(
          orderId: 'zakaz-1',
          barcode: 'RM-001',
        ),
        throwsA(
          isA<MobileApiException>().having(
            (error) => error.message,
            'message',
            'Bu homashyo allaqachon ishga tushgan yoki ishlatilgan, uzib bo‘lmaydi',
          ),
        ),
      );
    },
        createHttpClient: (_) => _RawMaterialApiHttpClient(
              seenRequests,
              unlinkErrorCode: 'raw_material_assignment_locked',
            ));
  });

  test('raw material assignment explains rulon size mismatch', () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['raw_material.assign'],
    );

    await HttpOverrides.runZoned(() async {
      await expectLater(
        MobileApi.instance.adminAssignRawMaterialToOrder(
          orderId: 'zakaz-1',
          barcode: 'RM-ROLL',
        ),
        throwsA(
          isA<MobileApiException>().having(
            (error) => error.message,
            'message',
            'Bu rulon bu buyurtma uchun mos emas',
          ),
        ),
      );
    },
        createHttpClient: (_) => _RawMaterialApiHttpClient(
              seenRequests,
              assignmentErrorCode: 'raw_material_roll_size_mismatch',
            ));
  });

  test('raw material assignment explains missing rulon size', () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['raw_material.assign'],
    );

    await HttpOverrides.runZoned(() async {
      await expectLater(
        MobileApi.instance.adminAssignRawMaterialToOrder(
          orderId: 'zakaz-1',
          barcode: 'RM-ROLL',
        ),
        throwsA(
          isA<MobileApiException>().having(
            (error) => error.message,
            'message',
            'Rulon razmeri topilmadi',
          ),
        ),
      );
    },
        createHttpClient: (_) => _RawMaterialApiHttpClient(
              seenRequests,
              assignmentErrorCode: 'raw_material_roll_size_missing',
            ));
  });
}

class _RawMaterialApiHttpClient implements HttpClient {
  _RawMaterialApiHttpClient(
    this.seenRequests, {
    this.queueActionErrorCode = '',
    this.qolipValidationErrorCode = '',
    this.qolipValidationQolipCode = 'QOLIP-1212',
    this.assignmentErrorCode = '',
    this.assignmentErrorApparatusOptions = const [],
    this.unlinkErrorCode = '',
    this.queueActionProgress = false,
    this.queueActionCompleteMetrics = false,
    this.queueActionLaminatsiyaMetrics = false,
    this.queueActionRezkaMetrics = false,
  });

  final List<String> seenRequests;
  final String queueActionErrorCode;
  final String qolipValidationErrorCode;
  final String qolipValidationQolipCode;
  final String assignmentErrorCode;
  final List<String> assignmentErrorApparatusOptions;
  final String unlinkErrorCode;
  final bool queueActionProgress;
  final bool queueActionCompleteMetrics;
  final bool queueActionLaminatsiyaMetrics;
  final bool queueActionRezkaMetrics;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final key =
        '$method ${url.path}${url.query.isEmpty ? '' : '?${url.query}'}';
    seenRequests.add(key);

    Object body;
    switch (key) {
      case 'POST /v1/mobile/admin/production-maps/qolip-validate':
        if (qolipValidationErrorCode.isNotEmpty) {
          body = {'error': qolipValidationErrorCode};
          return _FakeHttpClientRequest(
            response: _FakeHttpClientResponse(
              body: jsonEncode(body),
              statusCode: HttpStatus.badRequest,
              requestKey: key,
              seenRequests: seenRequests,
            ),
          );
        }
        body = {
          'ok': true,
          'qolip': {
            'qolip_code': qolipValidationQolipCode,
            'required_qolip_codes': const [
              'QOLIP-1212',
              'QOLIP-1213',
              'QOLIP-1214',
              'QOLIP-1215',
            ],
            'required_qolip_count': 4,
            'required_qolips': const [
              {
                'qolip_code': 'QOLIP-1212',
                'color': '#E53935',
              },
              {
                'qolip_code': 'QOLIP-1213',
                'color': '#FB8C00',
              },
              {
                'qolip_code': 'QOLIP-1214',
                'color': '#FDD835',
              },
              {
                'qolip_code': 'QOLIP-1215',
                'color': '#43A047',
              },
            ],
          },
        };
      case 'POST /v1/mobile/admin/production-maps/queue-action':
        if (queueActionErrorCode.isNotEmpty) {
          body = {'error': queueActionErrorCode};
          return _FakeHttpClientRequest(
            response: _FakeHttpClientResponse(
              body: jsonEncode(body),
              statusCode: HttpStatus.badRequest,
              requestKey: key,
              seenRequests: seenRequests,
            ),
          );
        }
        body = queueActionRezkaMetrics
            ? const {
                'states': {'zakaz-1': 'completed'},
                'progress_batch': {
                  'batch_id': 'progress-1',
                  'session_id': 'session-1',
                  'apparatus': 'Rezka',
                  'order_id': 'zakaz-1',
                  'action': 'complete',
                  'status': 'completed',
                  'produced_qty': 32,
                  'uom': 'kg',
                  'qr_payload': 'GSP:PROGRESS-1',
                  'label_item_code': 'zakaz-1',
                  'label_item_name': 'Zakaz tayyor',
                  'executor_name': 'Rezka operatori',
                  'rezka_bosma_waste': 1.25,
                  'rezka_lamination_waste': 2.5,
                  'rezka_edge_waste': 0.75,
                },
              }
            : queueActionLaminatsiyaMetrics
                ? const {
                    'states': {'zakaz-1': 'completed'},
                    'progress_batch': {
                      'batch_id': 'progress-1',
                      'session_id': 'session-1',
                      'apparatus': 'Laminatsiya 1',
                      'order_id': 'zakaz-1',
                      'action': 'complete',
                      'status': 'completed',
                      'produced_qty': 140.25,
                      'uom': 'm',
                      'qr_payload': 'GSP:PROGRESS-1',
                      'label_item_code': 'zakaz-1',
                      'label_item_name': 'Zakaz tayyor',
                      'executor_name': 'Laminatsiya operatori',
                      'lamination_print_leftover_rolls': 1.5,
                      'lamination_film_leftover_rolls': 2.5,
                      'total_waste': 3.5,
                      'finished_goods_kg': 20.75,
                      'finished_goods_meter': 140.25,
                    },
                  }
                : queueActionCompleteMetrics
                    ? const {
                        'states': {'zakaz-1': 'completed'},
                        'progress_batch': {
                          'batch_id': 'progress-1',
                          'session_id': 'session-1',
                          'apparatus': '7 ta rangli bosma',
                          'order_id': 'zakaz-1',
                          'action': 'complete',
                          'status': 'completed',
                          'produced_qty': 125.5,
                          'uom': 'm',
                          'qr_payload': 'GSP:PROGRESS-1',
                          'label_item_code': 'zakaz-1',
                          'label_item_name': 'Zakaz tayyor',
                          'executor_name': 'Bosma aparatchi',
                          'return_ink_kg': 1.25,
                          'total_waste': 2.5,
                          'finished_goods_kg': 18.75,
                          'finished_goods_meter': 125.5,
                        },
                      }
                    : queueActionProgress
                        ? const {
                            'states': {'zakaz-1': 'paused'},
                            'progress_batch': {
                              'batch_id': 'progress-1',
                              'session_id': 'session-1',
                              'apparatus': 'Pechat',
                              'order_id': 'zakaz-1',
                              'action': 'pause',
                              'status': 'paused',
                              'produced_qty': 12.5,
                              'uom': 'kg',
                              'qr_payload': 'GSP:PROGRESS-1',
                              'label_item_code': 'zakaz-1',
                              'label_item_name': 'Zakaz yarim tayyor',
                              'executor_name': 'Aparatchi',
                            },
                          }
                        : const {
                            'states': {'zakaz-1': 'in_progress'},
                          };
      case 'POST /v1/mobile/admin/production-maps/progress-qr/lookup':
        body = const {
          'ok': true,
          'can_resume': true,
          'batch': {
            'batch_id': 'progress-1',
            'session_id': 'session-1',
            'apparatus': 'Pechat',
            'order_id': 'zakaz-1',
            'action': 'pause',
            'status': 'paused',
            'produced_qty': 12.5,
            'uom': 'kg',
            'qr_payload': 'GSP:PROGRESS-1',
            'label_item_code': 'zakaz-1',
            'label_item_name': 'Zakaz yarim tayyor',
            'executor_name': 'Aparatchi',
          },
        };
      case 'POST /v1/mobile/admin/production-maps/progress-qr/report':
        body = const {
          'ok': true,
          'scanned_batch': {
            'batch_id': 'progress-old',
            'session_id': 'session-1',
            'apparatus': 'Pechat',
            'order_id': 'zakaz-1',
            'action': 'pause',
            'status': 'paused',
            'produced_qty': 12.5,
            'uom': 'kg',
            'qr_payload': 'GSP:PROGRESS-OLD',
            'label_item_code': 'zakaz-1',
            'label_item_name': 'Zakaz yarim tayyor',
            'executor_name': 'Aparatchi',
            'wip_status': 'processed',
          },
          'current_batch': {
            'batch_id': 'progress-new',
            'session_id': 'session-2',
            'apparatus': 'Qadoqlash stol',
            'order_id': 'zakaz-1',
            'action': 'complete',
            'status': 'completed',
            'produced_qty': 10,
            'uom': 'kg',
            'qr_payload': 'GSP:PROGRESS-NEW',
            'label_item_code': 'zakaz-1',
            'label_item_name': 'Zakaz tayyor',
            'executor_name': 'Aparatchi',
            'wip_status': 'waiting',
            'status_detail': {
              'work_status': 'completed',
              'wip_status': 'waiting',
              'flow_status': 'free_wip',
            },
          },
          'is_stale': true,
          'stale_reason': 'processed_by_next_stage',
          'order': {
            'id': 'zakaz-1',
            'product_code': 'PECHAT-1',
            'title': 'QR report order',
            'order_number': '1',
            'nodes': [],
            'edges': [],
          },
          'order_status': {
            'order_status': 'completed',
            'work_status': 'completed',
            'flow_status': 'free_wip',
            'total_wip_count': 2,
            'waiting_wip_count': 1,
            'in_use_wip_count': 0,
            'processed_wip_count': 1,
            'waiting_next_stage_count': 0,
            'consumed_by_next_stage_count': 1,
            'free_wip_count': 1,
            'accepted_wip_count': 0,
            'active_session_count': 0,
            'paused_session_count': 0,
            'completed_queue_count': 1,
            'completed_with_issue_count': 0,
          },
          'queue_states': {
            'Qadoqlash stol': {'zakaz-1': 'completed'},
          },
          'logs': [
            {
              'event_id': 'event-1',
              'apparatus': 'Pechat',
              'order_id': 'zakaz-1',
              'action': 'start',
              'from_state': 'pending',
              'to_state': 'in_progress',
              'actor_role': 'aparatchi',
              'actor_ref': 'worker-1',
              'actor_display_name': 'Aparatchi',
              'created_at_unix': 1781779900,
            },
          ],
          'progress_batches': [],
          'run_sessions': [
            {
              'session_id': 'session-1',
              'apparatus': 'Pechat',
              'order_id': 'zakaz-1',
              'status': 'completed',
              'worker_role': 'aparatchi',
              'worker_ref': 'worker-1',
              'worker_display_name': 'Aparatchi',
              'started_at_unix': 1781779800,
              'updated_at_unix': 1781779900,
            },
            {
              'session_id': 'session-2',
              'apparatus': 'Qadoqlash stol',
              'order_id': 'zakaz-1',
              'status': 'completed',
              'worker_role': 'aparatchi',
              'worker_ref': 'worker-2',
              'worker_display_name': 'Qadoqlovchi',
              'started_at_unix': 1781780000,
              'updated_at_unix': 1781780100,
            },
          ],
          'active_sessions': [],
          'opened_by': {
            'actor_role': 'aparatchi',
            'actor_ref': 'worker-1',
            'actor_display_name': 'Aparatchi',
            'opened_at_unix': 1781779900,
          },
        };
      case 'GET /v1/mobile/admin/production-maps/closed-orders':
        body = const {
          'ok': true,
          'closed_orders': [
            {
              'order_id': 'zakaz-closed-route',
              'order_number': '9401',
              'title': 'Closed route',
              'product_code': 'PECHAT-9401',
              'completed_at_unix': 1781780000,
              'closed_by_role': 'aparatchi',
              'closed_by_ref': 'worker-closed-lamin',
              'closed_by_display_name': 'Laminatsiya operatori',
              'logs': [
                {
                  'event_id': 'event-1',
                  'apparatus': '7 ta rangli pechat',
                  'order_id': 'zakaz-closed-route',
                  'action': 'start',
                  'from_state': 'pending',
                  'to_state': 'in_progress',
                  'actor_role': 'aparatchi',
                  'actor_ref': 'worker-closed-pechat',
                  'actor_display_name': 'Pechatchi',
                  'created_at_unix': 1781779900,
                },
                {
                  'event_id': 'event-2',
                  'apparatus': 'Laminatsiya 1',
                  'order_id': 'zakaz-closed-route',
                  'action': 'complete',
                  'from_state': 'in_progress',
                  'to_state': 'completed',
                  'actor_role': 'aparatchi',
                  'actor_ref': 'worker-closed-lamin',
                  'actor_display_name': 'Laminatsiya operatori',
                  'created_at_unix': 1781780000,
                },
              ],
            },
          ],
        };
      case 'GET /v1/mobile/admin/production-maps/wip-batches?status=waiting&apparatus=Pechat&current_location=Pechat+yonida&limit=25':
        body = const {
          'ok': true,
          'batches': [
            {
              'batch_id': 'progress-1',
              'session_id': 'session-1',
              'apparatus': 'Pechat',
              'order_id': 'zakaz-1',
              'action': 'pause',
              'status': 'paused',
              'produced_qty': 100,
              'uom': 'kg',
              'qr_payload': 'GSP:PROGRESS-1',
              'label_item_code': 'zakaz-1',
              'label_item_name': 'Vesta yarim tayyor',
              'executor_name': 'Pechatchi',
              'wip_status': 'waiting',
              'current_apparatus': 'Pechat',
              'current_apparatus_key': 'pechat',
              'current_location': 'Pechat yonida',
              'next_apparatus': 'Laminatsiya 1',
              'worker_role': 'aparatchi',
              'worker_ref': 'worker-1',
              'worker_display_name': 'Pechatchi',
            },
          ],
        };
      case 'GET /v1/mobile/admin/production-maps/wip-batches?status=waiting&apparatus=7+ta+rangli+pechat&next_apparatus=Laminatsiya+1&order_id=zakaz-1111&limit=250':
        body = const {
          'ok': true,
          'batches': [
            {
              'batch_id': 'progress-1111',
              'session_id': 'session-1111',
              'apparatus': '7 ta rangli pechat',
              'order_id': 'zakaz-1111',
              'action': 'pause',
              'status': 'paused',
              'produced_qty': 1,
              'uom': 'm',
              'qr_payload': 'GSP:WIP-1111',
              'label_item_code': 'zakaz-1111',
              'label_item_name': 'ABCD Family',
              'executor_name': 'Pechatchi',
              'wip_status': 'waiting',
              'current_apparatus': '7 ta rangli pechat',
              'current_apparatus_key': 'pechat:7',
              'current_location': '7 ta rangli pechat chiqim',
              'next_apparatus': 'Laminatsiya 1',
              'worker_role': 'aparatchi',
              'worker_ref': 'worker-pechat',
              'worker_display_name': 'Pechatchi',
            },
          ],
        };
      case 'GET /v1/mobile/admin/production-maps/wip-batches?status=all&apparatus=7+ta+rangli+pechat&next_apparatus=Laminatsiya+1&order_id=zakaz-1111&limit=250':
        body = const {
          'ok': true,
          'batches': [
            {
              'batch_id': 'progress-1111',
              'session_id': 'session-1111',
              'apparatus': '7 ta rangli pechat',
              'order_id': 'zakaz-1111',
              'action': 'pause',
              'status': 'paused',
              'produced_qty': 1,
              'uom': 'm',
              'qr_payload': 'GSP:WIP-1111',
              'label_item_code': 'zakaz-1111',
              'label_item_name': 'ABCD Family',
              'executor_name': 'Pechatchi',
              'wip_status': 'waiting',
              'current_apparatus': '7 ta rangli pechat',
              'current_apparatus_key': 'pechat:7',
              'current_location': '7 ta rangli pechat chiqim',
              'next_apparatus': 'Laminatsiya 1',
              'worker_role': 'aparatchi',
              'worker_ref': 'worker-pechat',
              'worker_display_name': 'Pechatchi',
            },
            {
              'batch_id': 'progress-1111-used',
              'session_id': 'session-1111',
              'apparatus': '7 ta rangli pechat',
              'order_id': 'zakaz-1111',
              'action': 'complete',
              'status': 'completed',
              'produced_qty': 1,
              'uom': 'm',
              'qr_payload': 'GSP:WIP-1111-USED',
              'label_item_code': 'zakaz-1111',
              'label_item_name': 'ABCD Family',
              'executor_name': 'Pechatchi',
              'wip_status': 'processed',
              'current_apparatus': 'Laminatsiya 1',
              'current_apparatus_key': 'laminatsiya 1',
              'current_location': 'Laminatsiya 1',
              'next_apparatus': 'Laminatsiya 1',
              'worker_role': 'aparatchi',
              'worker_ref': 'worker-pechat',
              'worker_display_name': 'Pechatchi',
            },
          ],
        };
      case 'PUT /v1/mobile/admin/raw-material-rules':
        body = const {
          'apparatus': 'Pechat',
          'requires_material': true,
          'start_policy': 'requirement_groups',
          'item_groups': ['Kraska', 'Kley'],
          'requirement_groups': [
            {
              'name': 'Yopishtiruvchi',
              'item_groups': ['Kraska', 'Kley'],
              'min_required_count': 1,
            },
          ],
        };
      case 'GET /v1/mobile/admin/raw-material-start-requirements?order_id=zakaz-1&apparatus=Pechat&material_barcodes=RM-01':
        body = const {
          'policy': 'state_all',
          'requires_material': true,
          'requirement_groups': [],
          'assigned_barcodes': ['RM-01', 'RM-02', 'RM-03'],
          'staged_barcodes': ['RM-01', 'RM-02'],
          'eligible_barcodes': ['RM-01', 'RM-02'],
          'required_scan_count': 2,
          'matched_scan_count': 1,
          'assignments_satisfied': true,
          'scan_satisfied': false,
          'assignments': [
            {
              'order_id': 'zakaz-1',
              'apparatus': 'Pechat',
              'barcode': 'RM-01',
              'item_code': 'RM-1',
              'item_name': 'Rulon 1',
              'item_group': 'Rulon',
            },
            {
              'order_id': 'zakaz-1',
              'apparatus': 'Pechat',
              'barcode': 'RM-02',
              'item_code': 'RM-2',
              'item_name': 'Rulon 2',
              'item_group': 'Rulon',
            },
          ],
          'start_assignments': [
            {
              'order_id': 'zakaz-1',
              'apparatus': 'Pechat',
              'barcode': 'RM-01',
              'item_code': 'RM-1',
              'item_name': 'Rulon 1',
              'item_group': 'Rulon',
            },
            {
              'order_id': 'zakaz-1',
              'apparatus': 'Pechat',
              'barcode': 'RM-02',
              'item_code': 'RM-2',
              'item_name': 'Rulon 2',
              'item_group': 'Rulon',
            },
          ],
        };
      case 'GET /v1/mobile/admin/raw-material-assignments?order_id=zakaz-1':
        body = const [
          {
            'order_id': 'zakaz-1',
            'apparatus': 'Pechat',
            'barcode': 'RM-001',
            'item_code': 'KR-1',
            'item_name': 'Qora kraska',
            'item_group': 'Kraska',
          },
        ];
      case 'GET /v1/mobile/admin/raw-material-intake-candidates?order_id=zakaz-1&apparatus=Pechat':
        body = const [
          {
            'order_id': 'zakaz-1',
            'apparatus': 'Pechat',
            'barcode': 'RM-AVAILABLE',
            'item_code': 'KR-2',
            'item_name': 'Oq kraska',
            'item_group': 'Kraska',
            'stock_status': 'available',
          },
        ];
      case 'POST /v1/mobile/admin/raw-material-assignments':
        if (assignmentErrorCode.isNotEmpty) {
          body = {
            'error': assignmentErrorCode,
            if (assignmentErrorApparatusOptions.isNotEmpty)
              'apparatus_options': assignmentErrorApparatusOptions,
          };
          return _FakeHttpClientRequest(
            response: _FakeHttpClientResponse(
              body: jsonEncode(body),
              statusCode: HttpStatus.badRequest,
              requestKey: key,
              seenRequests: seenRequests,
            ),
          );
        }
        body = const {
          'order_id': 'zakaz-1',
          'apparatus': 'Pechat',
          'barcode': 'RM-001',
          'item_code': 'KR-1',
          'item_name': 'Qora kraska',
          'item_group': 'Kraska',
          'assigned_by_ref': 'admin',
          'assigned_by_name': 'Admin',
          'assigned_at': '2026-06-16T10:00:00Z',
          'stock_status': 'in_use',
          'reserved_order_id': 'zakaz-1',
          'stock_warehouse': 'Kalidor',
        };
      case 'POST /v1/mobile/admin/raw-material-intake':
        body = const {
          'order_id': 'zakaz-1',
          'apparatus': 'Pechat',
          'barcode': 'ROLL-1000-B',
          'item_code': 'RULON-1000',
          'item_name': '1000 metr rulon',
          'item_group': 'Rulon',
          'assigned_by_ref': 'worker-1',
          'assigned_by_display_name': 'Pechatchi',
          'assigned_at': '2026-07-25T10:00:00Z',
          'stock_status': 'in_use',
          'reserved_order_id': 'zakaz-1',
          'stock_warehouse': 'Kalidor',
          'stock_qty': 1000,
          'stock_uom': 'm',
          'received_qty': 1000,
          'consumed_qty': 0,
          'remaining_qty': 1000,
        };
      case 'GET /v1/mobile/admin/raw-material-assignments/lookup?barcode=RM-001':
        body = const {
          'barcode': 'RM-001',
          'warehouse': 'Kalidor',
          'item_code': 'KR-1',
          'item_name': 'Qora kraska',
          'item_group': 'Kraska',
          'qty': 12,
          'uom': 'kg',
          'status': 'in_use',
          'reserved_order_id': 'zakaz-1',
          'source_receipt_id': 'GSR-RM-001',
          'assignment': {
            'order_id': 'zakaz-1',
            'apparatus': 'Pechat',
            'barcode': 'RM-001',
            'item_code': 'KR-1',
            'item_name': 'Qora kraska',
            'item_group': 'Kraska',
            'assigned_by_ref': 'admin',
            'assigned_by_display_name': 'Admin',
            'assigned_at': '2026-06-16T10:00:00Z',
            'stock_status': 'in_use',
            'reserved_order_id': 'zakaz-1',
            'stock_warehouse': 'Kalidor',
          },
          'order': {
            'id': 'zakaz-1',
            'product_code': 'Paynet',
            'title': 'Paynet',
            'order_number': '6365',
            'nodes': [],
            'edges': [],
          },
          'queue_states': {
            'Pechat': {'zakaz-1': 'in_progress'},
          },
          'logs': [
            {
              'event_id': 'event-raw-1',
              'apparatus': 'Pechat',
              'order_id': 'zakaz-1',
              'action': 'start',
              'from_state': 'pending',
              'to_state': 'in_progress',
              'actor_role': 'aparatchi',
              'actor_ref': 'worker-1',
              'actor_display_name': 'Pechatchi',
              'created_at_unix': 1781779900,
            },
          ],
        };
      case 'DELETE /v1/mobile/admin/raw-material-assignments':
        if (unlinkErrorCode.isNotEmpty) {
          body = {'error': unlinkErrorCode};
          return _FakeHttpClientRequest(
            response: _FakeHttpClientResponse(
              body: jsonEncode(body),
              statusCode: HttpStatus.badRequest,
              requestKey: key,
              seenRequests: seenRequests,
            ),
          );
        }
        body = const {
          'ok': true,
          'assignment': {
            'order_id': 'zakaz-1',
            'apparatus': 'Pechat',
            'barcode': 'RM-001',
            'item_code': 'KR-1',
            'item_name': 'Qora kraska',
            'item_group': 'Kraska',
            'assigned_by_ref': 'admin',
            'assigned_by_name': 'Admin',
            'assigned_at': '2026-06-16T10:00:00Z',
            'stock_status': 'available',
            'reserved_order_id': '',
            'stock_warehouse': 'Kalidor',
          },
        };
      default:
        body = {'error': 'Unhandled request: $key'};
        return _FakeHttpClientRequest(
          response: _FakeHttpClientResponse(
            body: jsonEncode(body),
            statusCode: HttpStatus.notFound,
            requestKey: key,
            seenRequests: seenRequests,
          ),
        );
    }

    return _FakeHttpClientRequest(
      response: _FakeHttpClientResponse(
        body: jsonEncode(body),
        statusCode: HttpStatus.ok,
        requestKey: key,
        seenRequests: seenRequests,
      ),
    );
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

  @override
  void close({bool force = false}) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest({required this.response});

  final _FakeHttpClientResponse response;
  final BytesBuilder _body = BytesBuilder();

  @override
  bool persistentConnection = true;

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  int contentLength = -1;

  @override
  bool bufferOutput = true;

  @override
  List<Cookie> get cookies => const <Cookie>[];

  @override
  void write(Object? object) {
    if (object != null) {
      _body.add(utf8.encode(object.toString()));
    }
  }

  @override
  void add(List<int> data) {
    _body.add(data);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      _body.add(data);
    }
  }

  @override
  Future<HttpClientResponse> close() async {
    final body = utf8.decode(_body.takeBytes());
    if (body.isNotEmpty) {
      response.seenRequests.add('BODY ${response.requestKey} $body');
    }
    return response;
  }

  final _headers = _FakeHttpHeaders();

  @override
  HttpHeaders get headers => _headers;

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding value) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse({
    required this.body,
    required this.statusCode,
    required this.requestKey,
    required this.seenRequests,
  });

  final String body;
  final String requestKey;
  final List<String> seenRequests;

  @override
  final int statusCode;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([utf8.encode(body)]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  int get contentLength => utf8.encode(body).length;

  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => '';

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  List<Cookie> get cookies => const <Cookie>[];

  @override
  Future<Socket> detachSocket() => throw UnsupportedError('detachSocket');

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) =>
      Future<HttpClientResponse>.value(this);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _values = {};

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _values.putIfAbsent(name, () => <String>[]).add(value.toString());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name] = [value.toString()];
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _values.forEach(action);
  }
}
