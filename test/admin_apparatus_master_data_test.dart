import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_apparatus_settings_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

  test('apparatus master options expose canonical picker values', () async {
    await TestModeController.instance.setEnabled(true);

    final options = await MobileApi.instance.adminApparatusMasterOptions();

    expect(options.families, contains('pechat'));
    expect(options.kindsForFamily('pechat'), contains('color_pechat'));
    expect(options.capabilities, contains('print'));
    expect(options.colorStationsMin, 1);
    expect(options.colorStationsMax, 32);
  });

  testWidgets('apparatus settings shows canonical derived groups', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await tester.pumpWidget(
      const MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminApparatusSettingsScreen(
          initialTab: AdminApparatusSettingsTab.groups,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final printGroup = find.byKey(
      const ValueKey('canonical-apparatus-group-print'),
    );
    await tester.scrollUntilVisible(
      printGroup,
      240,
      scrollable: find.descendant(
        of: find.byKey(
          const ValueKey('canonical-apparatus-groups-list'),
        ),
        matching: find.byType(Scrollable),
      ),
    );
    expect(printGroup, findsOneWidget);
    expect(find.text('Bosma aparat'), findsOneWidget);

    await tester.ensureVisible(printGroup);
    await tester.tap(printGroup);
    await tester.pumpAndSettle();

    expect(find.text('Flexo pechat'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey(
          'canonical-apparatus-group-item-apparatus:default:asset-005',
        ),
      ),
      findsOneWidget,
    );
  });

  test('custom apparatus collections CRUD does not mutate canonical apparatus',
      () async {
    await TestModeController.instance.setEnabled(true);
    final before = await MobileApi.instance.adminApparatus(limit: 500);

    final created = await MobileApi.instance.adminCreateApparatusCollection(
      name: ' Bosma A liniyasi ',
      apparatusIds: const [
        'apparatus:default:bosma_8',
        'apparatus:default:bosma_7',
        'apparatus:default:bosma_8',
      ],
    );

    expect(created.name, 'Bosma A liniyasi');
    expect(created.revision, 1);
    expect(created.apparatusIds, const [
      'apparatus:default:bosma_7',
      'apparatus:default:bosma_8',
    ]);
    expect(await MobileApi.instance.adminApparatusCollections(), [created]);

    final updated = await MobileApi.instance.adminUpdateApparatusCollection(
      collection: created,
      name: 'Aralash liniya',
      apparatusIds: const ['apparatus:default:bosma_7'],
    );
    expect(updated.revision, 2);
    expect(updated.name, 'Aralash liniya');

    await expectLater(
      MobileApi.instance.adminDeleteApparatusCollection(created),
      throwsA(
        isA<MobileApiException>()
            .having((error) => error.statusCode, 'statusCode', 409),
      ),
    );

    await MobileApi.instance.adminDeleteApparatusCollection(updated);
    expect(await MobileApi.instance.adminApparatusCollections(), isEmpty);
    expect(
      (await MobileApi.instance.adminApparatus(limit: 500))
          .map((item) => item.toJson())
          .toList(growable: false),
      before.map((item) => item.toJson()).toList(growable: false),
    );
  });

  testWidgets('apparatus groups tab shows custom collection controls', (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    final collection = await MobileApi.instance.adminCreateApparatusCollection(
      name: 'Bosma A liniyasi',
      apparatusIds: const ['apparatus:default:bosma_7'],
    );

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('uz'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminApparatusSettingsScreen(
          initialTab: AdminApparatusSettingsTab.groups,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('add-custom-apparatus-collection')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('custom-apparatus-collection-${collection.id}')),
      findsOneWidget,
    );
    expect(find.text('Bosma A liniyasi'), findsOneWidget);
  });

  testWidgets('admin can create a custom apparatus collection from groups tab',
      (
    tester,
  ) async {
    await TestModeController.instance.setEnabled(true);
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('uz'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminApparatusSettingsScreen(
          initialTab: AdminApparatusSettingsTab.groups,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('add-custom-apparatus-collection')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('apparatus-collection-name')),
      'Bosma navbatchilar',
    );
    final member = find.byKey(
      const ValueKey(
        'apparatus-collection-member-apparatus:default:bosma_7',
      ),
    );
    await tester.ensureVisible(member);
    await tester.tap(member);
    await tester.tap(find.text('Guruhni saqlash'));
    await tester.pumpAndSettle();

    expect(find.text('Bosma navbatchilar'), findsOneWidget);
    final saved = (await MobileApi.instance.adminApparatusCollections()).single;
    expect(saved.apparatusIds, const ['apparatus:default:bosma_7']);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
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

  test('factory map object binding is saved and can be cleared', () async {
    await TestModeController.instance.setEnabled(true);
    final defaults = await MobileApi.instance.adminApparatus(limit: 500);
    final apparatus = defaults.firstWhere(
      (item) => item.id == 'apparatus:default:bosma_7',
    );

    final mapped = await MobileApi.instance.adminCreateApparatus(
      apparatus.name,
      id: apparatus.id,
      family: apparatus.family,
      kind: apparatus.kind,
      capabilities: apparatus.capabilities,
      capabilityProfiles: apparatus.capabilityProfiles,
      colorStations: apparatus.colorStations,
      factoryMapObjectId: 'node:73',
    );

    expect(mapped.isDefault, isTrue);
    expect(mapped.factoryMapObjectId, 'node:73');
    expect(
      (await MobileApi.instance.adminApparatus(limit: 500))
          .firstWhere((item) => item.id == apparatus.id)
          .factoryMapObjectId,
      'node:73',
    );

    final cleared = await MobileApi.instance.adminCreateApparatus(
      mapped.name,
      id: mapped.id,
      family: mapped.family,
      kind: mapped.kind,
      capabilities: mapped.capabilities,
      capabilityProfiles: mapped.capabilityProfiles,
      colorStations: mapped.colorStations,
      factoryMapObjectId: '',
    );
    expect(cleared.factoryMapObjectId, isEmpty);
  });

  test('apparatus JSON round-trips factory map object id', () {
    const apparatus = AdminApparatus(
      id: 'apparatus:test:roundtrip',
      name: 'Test aparat',
      factoryMapObjectId: 'node:18',
      sourceRevision: 1,
      sourceAasxSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      operation: 'package',
      technology: 'bag_making',
    );

    final decoded = AdminApparatus.fromJson(apparatus.toJson());

    expect(decoded.factoryMapObjectId, 'node:18');
  });

  test('apparatus training mode can be enabled and disabled', () async {
    await TestModeController.instance.setEnabled(true);
    final apparatus = (await MobileApi.instance.adminApparatus(limit: 500))
        .firstWhere((item) => item.id == 'apparatus:default:bosma_7');

    final enabled = await MobileApi.instance.adminCreateApparatus(
      apparatus.name,
      id: apparatus.id,
      family: apparatus.family,
      kind: apparatus.kind,
      capabilities: apparatus.capabilities,
      capabilityProfiles: apparatus.capabilityProfiles,
      colorStations: apparatus.colorStations,
      trainingEnabled: true,
    );
    expect(enabled.trainingEnabled, isTrue);
    expect(
      (await MobileApi.instance.adminApparatus(limit: 500))
          .firstWhere((item) => item.id == apparatus.id)
          .trainingEnabled,
      isTrue,
    );

    final disabled = await MobileApi.instance.adminCreateApparatus(
      enabled.name,
      id: enabled.id,
      family: enabled.family,
      kind: enabled.kind,
      capabilities: enabled.capabilities,
      capabilityProfiles: enabled.capabilityProfiles,
      colorStations: enabled.colorStations,
      trainingEnabled: false,
    );
    expect(disabled.trainingEnabled, isFalse);
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
        AdminApparatusCapabilityProfile(code: 'print', level: 3),
      ],
    );
    for (final orderId in const ['zakaz-capacity-1', 'zakaz-capacity-2']) {
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
              title: apparatus.name,
              apparatusId: apparatus.id,
            ),
          ],
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
              apparatusId: primary.id,
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
      ProductionMapDefinition(
        id: orderId,
        productCode: orderId,
        title: orderId,
        orderNumber: orderId,
        nodes: [
          ProductionMapNode(
            id: 'apparatus',
            kind: 'apparatus',
            title: source,
            apparatusId: sourceApparatus.id,
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
      apparatus: sourceApparatus.id,
      orderIds: const [orderId],
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: targetApparatus.id,
      orderIds: const [],
    );
    final reservation = await MobileApi.instance.adminScheduleApparatusOrder(
      orderId: orderId,
      apparatusId: sourceApparatus.id,
      apparatus: sourceApparatus.id,
      earliestStartUnix: 1700000040,
      durationMinutes: 20,
      idempotencyKey: 'capacity-mobile-lifecycle',
    );
    expect(reservation.status, 'planned');

    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: sourceApparatus.id,
      orderId: orderId,
      action: 'start',
    );
    var snapshot = await MobileApi.instance.adminApparatusCapacitySnapshot();
    expect(snapshot.reservations.single.status, 'active');

    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: sourceApparatus.id,
      orderId: orderId,
      action: 'pause',
      producedQty: 1,
    );
    snapshot = await MobileApi.instance.adminApparatusCapacitySnapshot();
    expect(snapshot.reservations.single.status, 'paused');

    await MobileApi.instance.adminTransferProductionMapOrder(
      orderId: orderId,
      fromApparatus: sourceApparatus.id,
      toApparatus: targetApparatus.id,
      reason: 'source apparatus breakdown',
      idempotencyKey: 'capacity-mobile-transfer',
    );
    snapshot = await MobileApi.instance.adminApparatusCapacitySnapshot();
    expect(snapshot.reservations.single.status, 'paused');
    expect(snapshot.reservations.single.apparatus, target);
    expect(snapshot.reservations.single.apparatusId, targetApparatus.id);

    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: targetApparatus.id,
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
      ProductionMapDefinition(
        id: orderId,
        productCode: orderId,
        title: orderId,
        orderNumber: orderId,
        nodes: [
          ProductionMapNode(
            id: 'apparatus',
            kind: 'apparatus',
            title: apparatusName,
            apparatusId: apparatus.id,
          ),
        ],
        edges: [],
      ),
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: apparatus.id,
      orderIds: const [orderId],
    );
    await MobileApi.instance.adminSaveApparatusCapacityProfile(
      AdminApparatusCapacityProfile(
        apparatusId: apparatus.id,
        apparatus: apparatus.id,
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
        apparatus: apparatus.id,
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
