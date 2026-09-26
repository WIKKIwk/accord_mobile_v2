import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:accord_mobile_v2/src/core/cache/order_image_cache.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_disk_store_base.dart';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/state/admin_sequence_apparatus_store.dart';
import 'package:accord_mobile_v2/src/features/qolip/state/qolip_data_revision.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const machine = AdminApparatus(
    id: 'apparatus:test:bosma',
    name: 'Bosma',
    operation: 'print',
    capabilities: ['print', 'tooling']);
final orders = [
  for (var i = 1; i <= 6; i++)
    ProductionMapSaved.fromJson({
      'map': {
        'id': 'zakaz-$i',
        'product_code': 'ITEM-$i',
        'title': 'Product $i',
        'nodes': [
          {'id': 'stage-$i', 'kind': 'apparatus', 'apparatus_id': machine.id}
        ],
        'edges': []
      },
      'program': <String, dynamic>{},
    })
];

Widget screen() => MaterialApp(
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdminProductionMapOrdersScreen(
        readOnly: true,
        supplyViewerMode: true,
        qolipTasksMode: true,
        apparatusLoader: () async => [machine],
        liveEventsLoader: () => const Stream.empty(),
        queueSnapshotLoader: () async => AdminApparatusQueueSnapshot(
          maps: orders,
          revision: 1,
          epoch: 'tasks-test',
          sequences: {
            machine.id: [for (final order in orders) order.map.id]
          },
          visibleOrderIds: {
            machine.id: [for (final order in orders) order.map.id]
          },
          queueStates: {
            machine.id: {for (final order in orders) order.map.id: 'pending'}
          },
          queuePolicies: const {},
          orderControls: const {},
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    OrderImageCache.debugOverride = OrderImageCache(disk: _NoImageDisk());
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AdminSequenceApparatusStore.instance.clearCache();
    AppSession.instance.token = 'tasks-token';
    AppSession.instance.profile = const SessionProfile(
        role: UserRole.qolipchi,
        displayName: 'Qolipchi',
        legalName: '',
        ref: 'qolipchi',
        phone: '',
        avatarUrl: '',
        capabilities: ['qolip.manage']);
  });
  tearDown(() {
    OrderImageCache.debugOverride = null;
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets(
      'window is taken before QR/search filters, preserves rank and refreshes after assignment',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final missing = {'zakaz-3', 'zakaz-6'};
    final requests = <List<String>>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('qolip-task-zakaz-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('qolip-task-zakaz-6')), findsOneWidget);
      expect(find.text('Profil'), findsNothing);
      expect(find.text('Vazifalar'), findsWidgets);
      expect(AppRouter.canOpenRoute(AppRoutes.qolipTasks), isTrue);
      await tester.tap(find.byKey(const ValueKey('qolip-tasks-limit')));
      await tester.pumpAndSettle();
      for (final count in [5, 10, 20, 50]) {
        expect(find.text('$count ta'), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('qolip-tasks-limit-5 ta')));
      await tester.pumpAndSettle();
      expect(requests.last,
          ['zakaz-1', 'zakaz-2', 'zakaz-3', 'zakaz-4', 'zakaz-5']);
      final third = find.byKey(const ValueKey('qolip-task-zakaz-3'));
      expect(third, findsOneWidget);
      expect(
          find.descendant(of: third, matching: find.text('3')), findsOneWidget);
      expect(find.byKey(const ValueKey('qolip-task-zakaz-6')), findsNothing);
      await tester.enterText(find.byType(EditableText).first, 'Product 6');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('qolip-task-zakaz-6')), findsNothing);
      await tester.enterText(find.byType(EditableText).first, '');
      await tester.pumpAndSettle();
      await tester.tap(third);
      await tester.pumpAndSettle();
      expect(requests.last, ['zakaz-3']);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(find.textContaining('ITEM-3'), findsWidgets);
      // Simulate a colleague registering the exact product while its form is open.
      missing.remove('zakaz-3');
      Navigator.of(tester.element(find.byIcon(Icons.lock_outline_rounded)))
          .pop();
      await tester.pumpAndSettle();
      expect(third, findsNothing);
      expect(
          find.text(
              'Tanlangan orderlarning barchasiga qolip QR’i biriktirilgan.'),
          findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/qolip/order-products')) {
                final ids = (jsonDecode(request.body)['order_ids'] as List)
                    .cast<String>();
                requests.add(ids);
                return http.Response(
                    jsonEncode({
                      'orders': [
                        for (final id in ids)
                          {
                            'order_id': id,
                            'product': {
                              'code': 'ITEM-${id.split('-').last}',
                              'name': 'Product ${id.split('-').last}',
                              'item_group': 'Tayyor mahsulot',
                              'has_qolip_spec': !missing.contains(id)
                            },
                          }
                      ]
                    }),
                    200);
              }
              if (request.url.path.endsWith('/qolip/blocks')) {
                return http.Response(
                    '{"warehouses":["Qolip ombori"],"blocks":[]}', 200);
              }
              if (request.url.path.contains('order-image')) {
                return http.Response('', 404);
              }
              return http.Response('{}', 200);
            }));
  });

  testWidgets('read failure is retryable and never reported as all ready',
      (tester) async {
    var failing = true;
    await http.runWithClient(() async {
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Qolip QR holatini tekshirib bo‘lmadi. Qayta urinib ko‘ring.'),
          findsOneWidget);
      expect(find.textContaining('barchasiga qolip QR'), findsNothing);
      failing = false;
      QolipDataRevision.notifyLocationsChanged();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('qolip-task-zakaz-1')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/qolip/order-products')) {
                if (failing) {
                  return http.Response('{"error":"store_failed"}', 500);
                }
                final ids = jsonDecode(request.body)['order_ids'] as List;
                return http.Response(
                    jsonEncode({
                      'orders': [
                        for (final id in ids) {'order_id': id, 'product': null}
                      ]
                    }),
                    200);
              }
              if (request.url.path.contains('order-image')) {
                return http.Response('', 404);
              }
              return http.Response('{}', 200);
            }));
  });

  test('partial readiness responses fail instead of hiding tasks', () async {
    await http.runWithClient(() async {
      await expectLater(MobileApi.instance.qolipOrderProducts(['zakaz-1']),
          throwsFormatException);
    }, () => MockClient((_) async => http.Response('{"orders":[]}', 200)));
  });
}

class _NoImageDisk implements OrderImageDiskStore {
  @override
  Future<Uint8List?> read(String key) async => null;
  @override
  Future<void> write(String key, Uint8List bytes) async {}
  @override
  Future<void> remove(String key) async {}
  @override
  Future<void> clear() async {}
}
