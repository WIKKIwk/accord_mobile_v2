import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/aparatchi_daily_work_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dailyWorkApparatusCatalog = <AdminApparatus>[
  AdminApparatus(
    id: 'apparatus:default:asset-005',
    name: 'Flexo pechat',
    operation: 'print',
    technology: 'flexographic',
    sourceRevision: 1,
  ),
  AdminApparatus(
    id: 'apparatus:default:asset-007',
    name: 'Laminatsiya 1',
    operation: 'laminate',
    technology: 'adhesive_lamination',
    sourceRevision: 1,
  ),
  AdminApparatus(
    id: 'apparatus:default:asset-010',
    name: 'Rezka',
    operation: 'cut',
    technology: 'slitting',
    sourceRevision: 1,
  ),
  AdminApparatus(
    id: 'apparatus:default:bosma_7',
    name: '7 ta rangli bosma aparat',
    operation: 'print',
    technology: 'rotogravure',
    colorStations: 7,
    sourceRevision: 1,
  ),
];

AdminProgressBatch _batch({
  required String batchId,
  required String orderId,
  String apparatus = 'apparatus:default:asset-007',
  required DateTime startedAt,
  DateTime? completedAt,
}) {
  return AdminProgressBatch.fromJson({
    'batch_id': batchId,
    'order_id': orderId,
    'apparatus': apparatus,
    'started_at_unix': startedAt.millisecondsSinceEpoch ~/ 1000,
    'completed_at_unix': (completedAt?.millisecondsSinceEpoch ?? 0) ~/ 1000,
  });
}

void main() {
  test('daily WIP history is date sorted and counts unique orders', () {
    final day = DateTime(2026, 8, 1);
    final batches = [
      _batch(
        batchId: 'wip-1',
        orderId: 'order-1',
        startedAt: day.add(const Duration(hours: 8)),
        completedAt: day.add(const Duration(hours: 9)),
      ),
      _batch(
        batchId: 'wip-2',
        orderId: 'order-1',
        startedAt: day.add(const Duration(hours: 10)),
        completedAt: day.add(const Duration(hours: 11)),
      ),
      _batch(
        batchId: 'wip-other-day',
        orderId: 'order-2',
        startedAt: day.add(const Duration(days: 1, hours: 8)),
      ),
    ];

    final daily = adminProgressBatchesForLocalDay(batches, day);

    expect(daily.map((batch) => batch.batchId), ['wip-2', 'wip-1']);
    expect(adminProgressBatchOrderCount(daily), 1);
  });

  testWidgets('daily work groups WIPs under their order', (tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Rezka operatori',
      legalName: '',
      ref: 'rezka-group-test',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read'],
      assignedApparatus: ['apparatus:default:asset-010'],
    );
    final day = DateTime(2026, 8, 1);
    final batches = [
      _batch(
        batchId: 'order-group-wip-1',
        orderId: 'order-group',
        apparatus: 'apparatus:default:asset-010',
        startedAt: day.add(const Duration(hours: 8)),
      ),
      _batch(
        batchId: 'order-group-wip-2',
        orderId: 'order-group',
        apparatus: 'apparatus:default:asset-010',
        startedAt: day.add(const Duration(hours: 10)),
      ),
      _batch(
        batchId: 'other-order-wip-1',
        orderId: 'other-order',
        apparatus: 'apparatus:default:asset-010',
        startedAt: day.add(const Duration(hours: 11)),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AparatchiDailyWorkScreen(
          initialDate: day,
          historyLoader: () async => batches,
          apparatusLoader: () async => _dailyWorkApparatusCatalog,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('daily-work-order-group-order-group')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('daily-work-order-group-other-order')),
      findsOneWidget,
    );
    expect(find.text('order-group'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('daily-work-wip-card-order-group-wip-1')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('daily-work-wip-card-order-group-wip-2')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('daily-work-order-header-order-group')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('daily-work-wip-card-order-group-wip-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('daily-work-wip-card-order-group-wip-2')),
      findsOneWidget,
    );

    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('daily WIP history is not restricted by apparatus name', () {
    final day = DateTime(2026, 8, 1);
    final daily = adminProgressBatchesForLocalDay(
      [
        _batch(
          batchId: 'pechat-wip',
          orderId: 'order-pechat',
          apparatus: 'apparatus:default:bosma_7',
          startedAt: day.add(const Duration(hours: 9)),
        ),
        _batch(
          batchId: 'lamination-wip',
          orderId: 'order-lamination',
          apparatus: 'apparatus:default:asset-007',
          startedAt: day.add(const Duration(hours: 10)),
        ),
      ],
      day,
    );

    expect(
      daily.map((batch) => batch.batchId),
      ['lamination-wip', 'pechat-wip'],
    );
  });

  test('Rezka worker daily history keeps the worker-scoped WIP', () {
    final day = DateTime(2026, 8, 1);
    final daily = adminProgressBatchesForLocalDay(
      [
        _batch(
          batchId: 'rezka-wip',
          orderId: 'order-rezka',
          apparatus: 'apparatus:default:asset-010',
          startedAt: day.add(const Duration(hours: 9)),
        ),
      ],
      day,
    );

    expect(daily.map((batch) => batch.batchId), ['rezka-wip']);
  });

  testWidgets('WIP tap expands details and long press opens the QR sheet', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Pechatchi operatori',
      legalName: '',
      ref: 'lamination-gesture-test',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read'],
      assignedApparatus: ['apparatus:default:bosma_7'],
    );
    final day = DateTime(2026, 8, 1);
    final batch = AdminProgressBatch.fromJson({
      'batch_id': 'gesture-wip',
      'order_id': 'gesture-order',
      'apparatus': 'apparatus:default:bosma_7',
      'produced_qty': 454,
      'uom': 'm',
      'qr_payload': 'GESTURE-QR',
      'label_item_name': 'Gesture mahsulot',
      'started_at_unix':
          day.add(const Duration(hours: 8)).millisecondsSinceEpoch ~/ 1000,
      'completed_at_unix':
          day.add(const Duration(hours: 9)).millisecondsSinceEpoch ~/ 1000,
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AparatchiDailyWorkScreen(
          initialDate: day,
          historyLoader: () async => [batch],
          apparatusLoader: () async => _dailyWorkApparatusCatalog,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Pechatchi tomonidan chiqarilgan WIP va orderlar'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('daily-work-order-header-gesture-order')),
    );
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('daily-work-wip-card-gesture-wip'));
    expect(card, findsOneWidget);
    expect(find.text('WIP ID'), findsNothing);

    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('WIP ID'), findsOneWidget);
    expect(find.text('Boshlangan'), findsOneWidget);

    await tester.longPress(card);
    await tester.pumpAndSettle();
    expect(find.text('WIP QR'), findsOneWidget);
    expect(find.text('Qayta chop etish'), findsOneWidget);

    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets(
      'waiting WIP pencils open one prefilled editor and require a reason', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Rezka operatori',
      legalName: '',
      ref: 'daily-correction-worker',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read'],
      assignedApparatus: ['apparatus:default:asset-010'],
    );
    final day = DateTime(2026, 8, 1);
    final batch = AdminProgressBatch.fromJson({
      'batch_id': 'correction-wip',
      'revision': 3,
      'order_id': 'correction-order',
      'apparatus': 'apparatus:default:asset-010',
      'produced_qty': 100,
      'uom': 'm',
      'qr_payload': 'CORRECTION-QR',
      'label_item_name': 'Correction mahsulot',
      'wip_status': 'waiting',
      'worker_ref': 'daily-correction-worker',
      'finished_goods_meter': 100,
      'finished_goods_kg': 50,
      'bobina_kg': 5,
      'diameter': 200,
      'started_at_unix':
          day.add(const Duration(hours: 8)).millisecondsSinceEpoch ~/ 1000,
      'completed_at_unix':
          day.add(const Duration(hours: 9)).millisecondsSinceEpoch ~/ 1000,
    });
    AdminProgressBatchCorrectionInput? submitted;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AparatchiDailyWorkScreen(
          initialDate: day,
          historyLoader: () async => [batch],
          apparatusLoader: () async => _dailyWorkApparatusCatalog,
          correctionSaver: (input) async {
            submitted = input;
            return AdminProgressBatch.fromJson({
              'batch_id': input.batchId,
              'revision': input.expectedRevision + 1,
              'order_id': batch.orderId,
              'apparatus': batch.apparatus,
              'produced_qty': input.producedQty,
              'uom': input.uom,
              'qr_payload': batch.qrPayload,
              'label_item_name': batch.labelItemName,
              'wip_status': 'waiting',
              'worker_ref': batch.workerRef,
              'finished_goods_meter': input.finishedGoodsMeter,
              'finished_goods_kg': input.finishedGoodsKg,
              'bobina_kg': input.bobinaKg,
              'diameter': input.diameter,
              'description': input.description,
              'started_at_unix': batch.startedAtUnix,
              'completed_at_unix': batch.completedAtUnix,
            });
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('daily-work-order-header-correction-order')),
    );
    await tester.pumpAndSettle();
    final card =
        find.byKey(const ValueKey('daily-work-wip-card-correction-wip'));
    expect(card, findsOneWidget);
    expect(
      find.byKey(const ValueKey('daily-work-wip-edit-correction-wip')),
      findsNothing,
    );

    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('daily-work-wip-edit-correction-wip')),
      findsOneWidget,
    );

    await tester.longPress(card);
    await tester.pumpAndSettle();
    final sheetEdit =
        find.byKey(const ValueKey('daily-work-wip-sheet-edit-correction-wip'));
    expect(sheetEdit, findsOneWidget);
    await tester.tap(sheetEdit);
    await tester.pumpAndSettle();
    expect(find.text('WIPni o‘zgartirish'), findsOneWidget);
    expect(find.text('100'), findsWidgets);
    expect(find.text('50'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('200'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '120');
    await tester.tap(
      find.byKey(const ValueKey('daily-work-wip-edit-save')),
    );
    await tester.pumpAndSettle();
    expect(find.text('O‘zgartirish sababi'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('daily-work-wip-correction-confirm')),
    );
    await tester.pump();
    expect(find.text('Izohsiz o‘zgartirib bo‘lmaydi'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('daily-work-wip-correction-reason')),
      'Metraj noto‘g‘ri yozilgan',
    );
    await tester.tap(
      find.byKey(const ValueKey('daily-work-wip-correction-confirm')),
    );
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.expectedRevision, 3);
    expect(submitted!.producedQty, 120);
    expect(submitted!.reason, 'Metraj noto‘g‘ri yozilgan');
    expect(find.text('120 m'), findsOneWidget);

    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('in-use WIP does not show an edit pencil', (tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Laminatsiya operatori',
      legalName: '',
      ref: 'locked-wip-worker',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read'],
      assignedApparatus: ['apparatus:default:asset-007'],
    );
    final day = DateTime(2026, 8, 1);
    final batch = AdminProgressBatch.fromJson({
      'batch_id': 'locked-wip',
      'order_id': 'locked-order',
      'apparatus': 'apparatus:default:asset-007',
      'wip_status': 'in_use',
      'qr_payload': 'LOCKED-QR',
      'started_at_unix':
          day.add(const Duration(hours: 8)).millisecondsSinceEpoch ~/ 1000,
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AparatchiDailyWorkScreen(
          initialDate: day,
          historyLoader: () async => [batch],
          apparatusLoader: () async => _dailyWorkApparatusCatalog,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('daily-work-order-header-locked-order')),
    );
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('daily-work-wip-card-locked-wip'));
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('daily-work-wip-edit-locked-wip')),
      findsNothing,
    );
    await tester.longPress(card);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('daily-work-wip-sheet-edit-locked-wip')),
      findsNothing,
    );

    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });
}
