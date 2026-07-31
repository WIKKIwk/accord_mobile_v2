import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    resetMobileApiTestModeData();
  });

  tearDown(() async {
    resetMobileApiTestModeData();
    await TestModeController.instance.setEnabled(false);
  });

  test('custom apparatus keeps its stable id while being renamed', () async {
    await TestModeController.instance.setEnabled(true);

    final created = await MobileApi.instance.adminCreateApparatus(
      'Flexo liniya 1',
      family: 'pechat',
      kind: 'flexo',
      capabilities: const ['print', 'pechat', 'flexo'],
    );
    final renamed = await MobileApi.instance.adminCreateApparatus(
      'Flexo liniya 2',
      id: created.id,
      family: 'pechat',
      kind: 'flexo',
      capabilities: const ['print', 'pechat', 'flexo'],
    );

    expect(renamed.id, created.id);
    expect(renamed.name, 'Flexo liniya 2');
    expect(renamed.isPechat, isTrue);
    expect(renamed.isFlexo, isTrue);
    expect(
      (await MobileApi.instance.adminApparatus(query: 'Flexo liniya 2'))
          .single
          .id,
      created.id,
    );
  });

  test('capacity API schedules Flexo orders with finite capacity and cancel',
      () async {
    await TestModeController.instance.setEnabled(true);
    final apparatus = await MobileApi.instance.adminCreateApparatus(
      'Flexo test',
      family: 'pechat',
      kind: 'flexo',
      capabilities: const ['print', 'pechat', 'flexo'],
      capabilityProfiles: const [
        AdminApparatusCapabilityProfile(code: 'flexo', level: 3),
      ],
    );
    for (final orderId in const ['zakaz-capacity-1', 'zakaz-capacity-2']) {
      await MobileApi.instance.adminSaveProductionMap(
        ProductionMapDefinition(
          id: orderId,
          productCode: orderId,
          title: orderId,
          orderNumber: orderId,
          nodes: const [],
          edges: const [],
        ),
      );
    }
    await MobileApi.instance.adminSaveApparatusCapacityProfile(
      AdminApparatusCapacityProfile(
        apparatusId: apparatus.id,
        apparatus: apparatus.name,
        capacitySlots: 1,
        setupMinutes: 5,
        cleanupMinutes: 5,
        capabilities: const ['flexo'],
        capabilityLevels: const {'flexo': 3},
        workingWindows: const [
          AdminApparatusWorkingWindow(
            weekday: 1,
            startMinute: 480,
            endMinute: 1020,
          ),
          AdminApparatusWorkingWindow(
            weekday: 1,
            startMinute: 1080,
            endMinute: 1200,
          ),
        ],
      ),
    );

    const start = 1700000040;
    final first = await MobileApi.instance.adminScheduleApparatusOrder(
      orderId: 'zakaz-capacity-1',
      apparatusId: apparatus.id,
      apparatus: apparatus.name,
      earliestStartUnix: start,
      durationMinutes: 10,
      idempotencyKey: 'capacity-mobile-1',
      capabilityRequirements: const [
        AdminApparatusCapabilityRequirement(code: 'flexo', minLevel: 2),
      ],
    );
    expect(first.reservedDurationMinutes, 20);
    expect(apparatus.capabilityProfiles.single.level, 3);

    final second = await MobileApi.instance.adminScheduleApparatusOrder(
      orderId: 'zakaz-capacity-2',
      apparatusId: apparatus.id,
      apparatus: apparatus.name,
      earliestStartUnix: start,
      durationMinutes: 10,
      idempotencyKey: 'capacity-mobile-2',
    );
    expect(second.startsAtUnix, first.endsAtUnix);

    final cancelled =
        await MobileApi.instance.adminCancelApparatusScheduleReservation(
      reservationId: first.reservationId,
      reason: 'test',
    );
    expect(cancelled.status, 'cancelled');
    final snapshot = await MobileApi.instance.adminApparatusCapacitySnapshot();
    expect(snapshot.profiles.single.apparatusId, apparatus.id);
    expect(snapshot.profiles.single.finiteCapacity, isTrue);
    expect(snapshot.profiles.single.workingWindows, hasLength(2));
    expect(snapshot.reservations, hasLength(2));
  });

  test('capacity API selects a compatible alternative when the primary is full',
      () async {
    await TestModeController.instance.setEnabled(true);
    final primary = await MobileApi.instance.adminCreateApparatus(
      'Flexo primary',
      family: 'pechat',
      kind: 'flexo',
      capabilities: const ['print', 'pechat', 'flexo'],
      capabilityProfiles: const [
        AdminApparatusCapabilityProfile(code: 'flexo', level: 3),
      ],
    );
    final alternative = await MobileApi.instance.adminCreateApparatus(
      'Flexo alternative',
      family: 'pechat',
      kind: 'flexo',
      capabilities: const ['print', 'pechat', 'flexo'],
      capabilityProfiles: const [
        AdminApparatusCapabilityProfile(code: 'flexo', level: 3),
      ],
    );
    for (final orderId in const [
      'zakaz-capacity-primary',
      'zakaz-capacity-alternative',
    ]) {
      await MobileApi.instance.adminSaveProductionMap(
        ProductionMapDefinition(
          id: orderId,
          productCode: orderId,
          title: orderId,
          orderNumber: orderId,
          nodes: [
            ProductionMapNode(
              id: 'apparatus',
              kind: 'apparatus',
              title: primary.name,
            ),
          ],
          edges: const [],
        ),
      );
    }
    for (final apparatus in [primary, alternative]) {
      await MobileApi.instance.adminSaveApparatusCapacityProfile(
        AdminApparatusCapacityProfile(
          apparatusId: apparatus.id,
          apparatus: apparatus.name,
          capacitySlots: 1,
          capabilities: const ['flexo'],
          capabilityLevels: const {'flexo': 3},
        ),
      );
    }

    const start = 1700000040;
    final first = await MobileApi.instance.adminScheduleApparatusOrder(
      orderId: 'zakaz-capacity-primary',
      apparatusId: primary.id,
      apparatus: primary.name,
      earliestStartUnix: start,
      durationMinutes: 30,
      idempotencyKey: 'capacity-mobile-primary',
    );
    final second = await MobileApi.instance.adminScheduleApparatusOrder(
      orderId: 'zakaz-capacity-alternative',
      apparatusId: primary.id,
      apparatus: primary.name,
      earliestStartUnix: start,
      durationMinutes: 30,
      idempotencyKey: 'capacity-mobile-alternative',
      candidateApparatuses: [
        AdminApparatusScheduleCandidate(
          apparatusId: alternative.id,
          apparatus: alternative.name,
        ),
      ],
      capabilityRequirements: const [
        AdminApparatusCapabilityRequirement(code: 'flexo', minLevel: 2),
      ],
    );

    expect(first.apparatusId, primary.id);
    expect(second.apparatusId, alternative.id);
    expect(second.startsAtUnix, first.startsAtUnix);
  });

  test('capacity reservation follows queue execution and emergency transfer',
      () async {
    await TestModeController.instance.setEnabled(true);
    const orderId = 'zakaz-capacity-lifecycle-mobile';
    const source = 'Flexo lifecycle source';
    const target = 'Flexo lifecycle target';
    final sourceApparatus = await MobileApi.instance.adminCreateApparatus(
      source,
      family: 'pechat',
      kind: 'flexo',
      capabilities: const ['print', 'pechat', 'flexo'],
    );
    final targetApparatus = await MobileApi.instance.adminCreateApparatus(
      target,
      family: 'pechat',
      kind: 'flexo',
      capabilities: const ['print', 'pechat', 'flexo'],
    );
    await MobileApi.instance.adminSaveProductionMap(
      const ProductionMapDefinition(
        id: orderId,
        productCode: orderId,
        title: orderId,
        orderNumber: orderId,
        nodes: [
          ProductionMapNode(
            id: 'apparatus',
            kind: 'apparatus',
            title: source,
          ),
        ],
        edges: [],
      ),
    );
    await MobileApi.instance.adminSaveApparatusCapacityProfile(
      AdminApparatusCapacityProfile(
        apparatusId: sourceApparatus.id,
        apparatus: source,
        capabilities: const ['flexo'],
        capabilityLevels: const {'flexo': 3},
      ),
    );
    await MobileApi.instance.adminSaveApparatusCapacityProfile(
      AdminApparatusCapacityProfile(
        apparatusId: targetApparatus.id,
        apparatus: target,
        capabilities: const ['flexo'],
        capabilityLevels: const {'flexo': 3},
      ),
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: source,
      orderIds: const [orderId],
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: target,
      orderIds: const [],
    );
    final reservation = await MobileApi.instance.adminScheduleApparatusOrder(
      orderId: orderId,
      apparatusId: sourceApparatus.id,
      apparatus: source,
      earliestStartUnix: 1700000040,
      durationMinutes: 20,
      idempotencyKey: 'capacity-mobile-lifecycle',
    );
    expect(reservation.status, 'planned');

    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: source,
      orderId: orderId,
      action: 'start',
    );
    var snapshot = await MobileApi.instance.adminApparatusCapacitySnapshot();
    expect(snapshot.reservations.single.status, 'active');

    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: source,
      orderId: orderId,
      action: 'pause',
      producedQty: 1,
    );
    snapshot = await MobileApi.instance.adminApparatusCapacitySnapshot();
    expect(snapshot.reservations.single.status, 'paused');

    await MobileApi.instance.adminTransferProductionMapOrder(
      orderId: orderId,
      fromApparatus: source,
      toApparatus: target,
      reason: 'source apparatus breakdown',
      idempotencyKey: 'capacity-mobile-transfer',
    );
    snapshot = await MobileApi.instance.adminApparatusCapacitySnapshot();
    expect(snapshot.reservations.single.status, 'paused');
    expect(snapshot.reservations.single.apparatus, target);
    expect(snapshot.reservations.single.apparatusId, targetApparatus.id);

    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: target,
      orderId: orderId,
      action: 'resume',
    );
    snapshot = await MobileApi.instance.adminApparatusCapacitySnapshot();
    expect(snapshot.reservations.single.status, 'active');
  });

  test('queue start rejects an apparatus during active downtime', () async {
    await TestModeController.instance.setEnabled(true);
    const orderId = 'zakaz-capacity-downtime-mobile';
    const apparatusName = 'Flexo downtime mobile';
    final apparatus = await MobileApi.instance.adminCreateApparatus(
      apparatusName,
      family: 'pechat',
      kind: 'flexo',
      capabilities: const ['print', 'pechat', 'flexo'],
    );
    await MobileApi.instance.adminSaveProductionMap(
      const ProductionMapDefinition(
        id: orderId,
        productCode: orderId,
        title: orderId,
        orderNumber: orderId,
        nodes: [],
        edges: [],
      ),
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: apparatusName,
      orderIds: const [orderId],
    );
    await MobileApi.instance.adminSaveApparatusCapacityProfile(
      AdminApparatusCapacityProfile(
        apparatusId: apparatus.id,
        apparatus: apparatusName,
        capabilities: const ['flexo'],
        capabilityLevels: const {'flexo': 3},
      ),
    );
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await MobileApi.instance.adminSaveApparatusDowntime(
      AdminApparatusDowntime(
        id: 'downtime-mobile-active',
        apparatusId: apparatus.id,
        apparatus: apparatusName,
        startsAtUnix: now - 60,
        endsAtUnix: now + 3600,
        reason: 'planned maintenance',
      ),
    );

    await expectLater(
      MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: apparatusName,
        orderId: orderId,
        action: 'start',
      ),
      throwsA(
        isA<MobileApiException>().having(
          (error) => error.code,
          'code',
          'capacity_unavailable',
        ),
      ),
    );
  });

  test('workflow audit API exposes a clean report in test mode', () async {
    await TestModeController.instance.setEnabled(true);
    await MobileApi.instance.adminSaveProductionMap(
      const ProductionMapDefinition(
        id: 'zakaz-audit-mobile',
        productCode: 'audit-mobile',
        title: 'Audit mobile',
        orderNumber: 'audit-mobile',
        nodes: [],
        edges: [],
      ),
    );

    final report = await MobileApi.instance.adminProductionMapAudit();

    expect(report.ok, isTrue);
    expect(report.checkedOrderCount, 1);
    expect(report.checkedBatchCount, 0);
    expect(report.checkedSessionCount, 0);
    expect(report.violations, isEmpty);
  });

  test('workflow audit violation preserves backend fields', () {
    final report = AdminProductionWorkflowAuditReport.fromJson(const {
      'ok': false,
      'checked_order_count': 2,
      'checked_batch_count': 3,
      'checked_session_count': 1,
      'violations': [
        {
          'code': 'duplicate_qr_payload',
          'order_id': 'zakaz-1',
          'subject': 'QR-1',
          'detail': 'duplicate progress QR',
        },
      ],
    });

    expect(report.ok, isFalse);
    expect(report.violations.single.code, 'duplicate_qr_payload');
    expect(report.violations.single.orderId, 'zakaz-1');
    expect(report.violations.single.subject, 'QR-1');
    expect(report.violations.single.detail, 'duplicate progress QR');
  });
}
