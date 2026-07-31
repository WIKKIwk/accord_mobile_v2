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
