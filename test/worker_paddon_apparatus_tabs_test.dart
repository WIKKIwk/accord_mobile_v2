import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/cache/production_snapshot_store.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/widgets/active_rezka_paddon_action.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'production_snapshot_test_backend.dart';

const cut = 'apparatus:default:asset-010';
const cut2 = 'apparatus:default:asset-011';
const cut3 = 'apparatus:default:asset-012';
const laminate = 'apparatus:default:asset-007';
const activePath = '/v1/mobile/admin/production-maps/paddons/active';

Map<String, dynamic> pallet(String code, String apparatus) => {
      'id': code,
      'code': code,
      'apparatus_id': apparatus,
      'created_by_ref': 'multi-worker',
      'item_count': 0,
    };

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ProductionSnapshotStore.debugOverride =
        ProductionSnapshotStore(backend: MemoryProductionSnapshotBackend());
    resetMobileApiTestModeData();
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.token = 'multi-worker';
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    ProductionSnapshotStore.debugOverride = null;
  });

  for (final multiple in [false, true]) {
    testWidgets(
        '${multiple ? "multiple" : "single"} cut apparatus toolbar follows tabs and keeps separate pallet selections',
        (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppSession.instance.profile = SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Worker',
        legalName: '',
        ref: 'multi-worker',
        phone: '',
        avatarUrl: '',
        capabilities: const ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [cut, laminate, if (multiple) cut2],
      );
      final catalog = await MobileApi.instance.adminApparatus(limit: 200);
      final events = StreamController<Object>.broadcast();
      addTearDown(events.close);
      final active = <String, String?>{cut: '0011', cut2: '4234'};
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path == activePath) {
          final body = request.method == 'PUT'
              ? jsonDecode(request.body) as Map<String, dynamic>
              : request.url.queryParameters;
          final apparatus = body['apparatus'] as String;
          if (request.method == 'PUT') {
            active[apparatus] =
                body['code'] == '' ? null : body['code'] as String;
          }
          return http.Response(
              jsonEncode({
                'ok': true,
                'apparatus': apparatus,
                'code': active[apparatus],
              }),
              200);
        }
        if (request.url.path.endsWith('/paddons')) {
          // A stale or overbroad response must never leak another machine's list.
          return http.Response(
              jsonEncode({
                'ok': true,
                'paddons': [
                  pallet('0011', cut),
                  pallet('0002', cut),
                  pallet('0334', cut2),
                  pallet('4234', cut2),
                ],
              }),
              200);
        }
        return http.Response('{}', 404);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          locale: const Locale('uz'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: AdminProductionMapOrdersScreen(
            workerMode: true,
            readOnly: true,
            apparatusLoader: () async => catalog
                .where((a) => [cut, laminate, cut2, cut3].contains(a.id))
                .toList(),
            queueSnapshotLoader: () async =>
                const AdminProductionMapLiveSnapshot(
              maps: [],
              epoch: 'test',
              revision: 1,
              scope: 'multi',
              workerShowAllApparatusTabs: true,
              sequences: {},
              visibleOrderIds: {},
              queueStates: {},
              queuePolicies: {},
              orderControls: {},
              completedOrders: [],
              completionRequests: [],
              completionRequestDecisions: [],
            ),
            liveEventsLoader: () => events.stream,
          ),
        ));
        await tester.pumpAndSettle();

        Future<void> tab(String label) async {
          final finder = find.widgetWithText(Tab, label);
          await tester.ensureVisible(finder);
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        Future<void> picker(
            String apparatus, String visible, String hidden) async {
          expect(
              tester
                  .widget<ActiveRezkaPaddonAction>(
                      find.byType(ActiveRezkaPaddonAction))
                  .apparatusId,
              apparatus);
          await tester.tap(find.byKey(const ValueKey('rezka-active-paddon')));
          await tester.pumpAndSettle();
          expect(find.byKey(ValueKey('rezka-paddon-$visible')), findsOneWidget);
          expect(find.byKey(ValueKey('rezka-paddon-$hidden')), findsNothing);
          expect(
              requests
                  .lastWhere((r) => r.url.path.endsWith('/paddons'))
                  .url
                  .queryParameters['apparatus'],
              apparatus);
          await tester.tap(find.byKey(ValueKey('rezka-paddon-$visible')));
          await tester.pumpAndSettle();
        }

        await tab('Rezka');
        await picker(cut, '0011', '4234');
        expect(find.byTooltip('Faol paddon: 0011'), findsOneWidget);
        if (multiple) {
          await tab('Rezka 2');
          await picker(cut2, '4234', '0011');
          expect(find.byTooltip('Faol paddon: 4234'), findsOneWidget);
        }
        await tab('Laminatsiya 1');
        expect(find.byType(ActiveRezkaPaddonAction), findsNothing);
        await tab('Tugallangan');
        expect(find.byType(ActiveRezkaPaddonAction), findsNothing);
        await tab('Rezka 3'); // Visible, but not assigned to this worker.
        expect(find.byType(ActiveRezkaPaddonAction), findsNothing);
        if (!multiple) {
          await tab('Rezka 2');
          expect(find.byType(ActiveRezkaPaddonAction), findsNothing);
        }
        await tab('Rezka');
        expect(find.byTooltip('Faol paddon: 0011'), findsOneWidget);
        // Swiping from the first machine into the completed tab also hides it.
        await tester.drag(find.byType(TabBarView), const Offset(-430, 0));
        await tester.pumpAndSettle();
        expect(find.byType(ActiveRezkaPaddonAction), findsNothing);
        if (multiple) {
          await tab('Rezka 2');
          expect(find.byTooltip('Faol paddon: 4234'), findsOneWidget);
        }
        expect(active[cut], '0011');
        expect(active[cut2], '4234');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }, () => client);
    });
  }
}
