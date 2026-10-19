import 'dart:async';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const apparatus = 'apparatus:default:asset-007';

ProductionMapSaved order(int index) => ProductionMapSaved.fromJson({
      'map': {
        'id': 'zakaz-$index',
        'code': 'C$index',
        'title': 'Order $index',
        'product_code': 'P$index',
        'nodes': [
          {'id': 'start', 'kind': 'start', 'title': 'Start'},
          {
            'id': 'work',
            'kind': 'apparatus',
            'apparatus_id': apparatus,
            'title': 'Work'
          },
          {'id': 'end', 'kind': 'end', 'title': 'End'},
        ],
        'edges': [
          {'from': 'start', 'to': 'work'},
          {'from': 'work', 'to': 'end'}
        ],
      },
      'program': <String, dynamic>{},
    });

AdminProductionMapLiveSnapshot snapshot(List<int> indices, String scope,
    {bool withHistory = false}) {
  final maps = indices.map(order).toList();
  final ids = maps.map((saved) => saved.map.id).toList();
  return AdminProductionMapLiveSnapshot(
    maps: maps,
    epoch: 'server',
    revision: 7,
    scope: scope,
    sequences: {apparatus: ids},
    visibleOrderIds: {apparatus: ids},
    queueStates: {
      apparatus: {for (final id in ids) id: 'pending'}
    },
    queuePolicies: const {},
    orderControls: const {},
    completedOrders: [
      if (withHistory)
        for (final index in indices)
          AdminCompletedQueueOrder(
            apparatus: apparatus,
            orderId: 'zakaz-$index',
            completedAtUnix: index,
          ),
    ],
    completionRequests: const [],
    completionRequestDecisions: const [],
  );
}

void main() {
  testWidgets('all shows more than 50 orders and can switch back to a limit',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.token = 'window-worker';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Worker',
      legalName: '',
      ref: 'window-worker',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
      assignedApparatus: [apparatus],
    );
    addTearDown(() {
      AppSession.instance.token = null;
      AppSession.instance.profile = null;
    });
    final catalog = await MobileApi.instance.adminApparatus(limit: 200);
    final events = StreamController<AdminProductionMapLiveSnapshot>.broadcast();
    addTearDown(events.close);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      home: AdminProductionMapOrdersScreen(
        workerMode: true,
        readOnly: true,
        apparatusLoader: () async =>
            catalog.where((item) => item.id == apparatus).toList(),
        queueSnapshotLoader: () async =>
            snapshot(List.generate(65, (i) => i), 'window', withHistory: true),
        liveEventsLoader: () => events.stream,
      ),
    ));
    await tester.pumpAndSettle();
    int rowCount() => tester
        .widget<SliverList>(find.byType(SliverList).first)
        .delegate
        .estimatedChildCount!;
    expect(rowCount(), 10);

    Future<void> select(String label) async {
      await tester.tap(find.byKey(const ValueKey('worker-queue-limit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('worker-queue-limit-$label')));
      await tester.pumpAndSettle();
    }

    await select('50 ta');
    expect(rowCount(), 50);
    await select('Barchasi');
    expect(find.text('Ko‘rsatish: Barchasi'), findsOneWidget);
    expect(rowCount(), 65);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('worker-order-zakaz-64')),
      400,
      scrollable: find.descendant(
        of: find.byKey(const PageStorageKey('worker-sequence-$apparatus')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.byKey(const ValueKey('worker-order-zakaz-64')), findsOneWidget);
    await tester.tap(find.text('Tugallangan'));
    await tester.pumpAndSettle();
    expect(
        find.byKey(
            const ValueKey(('worker-completed-order', 'zakaz-64', apparatus))),
        findsOneWidget);
    await tester.tap(find.text('Laminatsiya 1'));
    await tester.pumpAndSettle();
    await select('5 ta');
    expect(rowCount(), 5);
    expect(find.text('Ko‘rsatish: 5 ta'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
      'limit changes reject an old initial read when search changes again',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.token = 'window-worker';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Worker',
      legalName: '',
      ref: 'window-worker',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
      assignedApparatus: [apparatus],
    );
    addTearDown(() {
      AppSession.instance.token = null;
      AppSession.instance.profile = null;
    });
    final catalog = await MobileApi.instance.adminApparatus(limit: 200);
    final staleFive = Completer<AdminApparatusQueueSnapshot>();
    final events = StreamController<AdminProductionMapLiveSnapshot>.broadcast();
    addTearDown(events.close);
    var reads = 0;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      home: AdminProductionMapOrdersScreen(
        workerMode: true,
        readOnly: true,
        apparatusLoader: () async =>
            catalog.where((item) => item.id == apparatus).toList(),
        queueSnapshotLoader: () {
          reads++;
          if (reads == 2) return staleFive.future;
          return Future.value(reads == 1
              ? snapshot(List.generate(20, (i) => i), 'window-10')
              : snapshot([19], 'window-5-search'));
        },
        liveEventsLoader: () => events.stream,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ko‘rsatish: 10 ta'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('worker-queue-limit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('worker-queue-limit-5 ta')));
    await tester.pump();
    expect(reads, 2);
    await tester.enterText(find.byType(EditableText).first, 'Order 19');
    await tester.pump(const Duration(milliseconds: 400));
    staleFive.complete(snapshot([0, 1, 2, 3, 4], 'window-5'));
    await tester.pumpAndSettle();
    expect(reads, 3);
    expect(find.text('Ko‘rsatish: 5 ta'), findsOneWidget);
    expect(find.byKey(const ValueKey('worker-order-zakaz-19')), findsOneWidget);
    expect(find.byKey(const ValueKey('worker-order-zakaz-0')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
