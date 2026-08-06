import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/aparatchi_daily_work_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AdminProgressBatch _batch({
  required String batchId,
  required String orderId,
  String apparatus = 'Laminatsiya 1',
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
      assignedApparatus: ['Rezka 1'],
    );
    final day = DateTime(2026, 8, 1);
    final batches = [
      _batch(
        batchId: 'order-group-wip-1',
        orderId: 'order-group',
        apparatus: 'Rezka 1',
        startedAt: day.add(const Duration(hours: 8)),
      ),
      _batch(
        batchId: 'order-group-wip-2',
        orderId: 'order-group',
        apparatus: 'Rezka 1',
        startedAt: day.add(const Duration(hours: 10)),
      ),
      _batch(
        batchId: 'other-order-wip-1',
        orderId: 'other-order',
        apparatus: 'Rezka 1',
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
          apparatus: '7 ta rangli pechat',
          startedAt: day.add(const Duration(hours: 9)),
        ),
        _batch(
          batchId: 'lamination-wip',
          orderId: 'order-lamination',
          apparatus: 'Laminatsiya 1',
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
          apparatus: 'Rezka 1',
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
      assignedApparatus: ['7 ta rangli pechat'],
    );
    final day = DateTime(2026, 8, 1);
    final batch = AdminProgressBatch.fromJson({
      'batch_id': 'gesture-wip',
      'order_id': 'gesture-order',
      'apparatus': '7 ta rangli pechat',
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
}
