import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_loading_indicator.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _snapshot() => http.Response(
    jsonEncode({
      'ok': true,
      'rev': 1,
      'epoch': 'network-test',
      'maps': [],
      'sequences': {},
      'visible_order_ids': {},
      'queue_states': {},
      'stage_states': {},
      'queue_policies': [],
      'queue_action_controls': {},
      'order_controls': {},
      'order_statuses': {},
      'frozen_orders_by_apparatus': {},
    }),
    200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({'test_mode_enabled': false});
    AppSession.instance.token = 'local-test-token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Worker',
      legalName: '',
      ref: 'worker-test',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
      assignedApparatus: [],
    );
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test(
      'concurrent snapshot consumers share one read; completed results are not cached',
      () async {
    final response = Completer<http.Response>();
    final entered = Completer<void>();
    var reads = 0;
    var clients = 0;
    await http.runWithClient(() async {
      final pending = List.generate(
          12, (_) => MobileApi.instance.adminProductionMapQueueSnapshot());
      await entered.future;
      expect(reads, 1);
      response.complete(_snapshot());
      final values = await Future.wait(pending);
      expect(values.every((v) => identical(v, values.first)), isTrue);
      expect(values.first.epoch, 'network-test');
      await MobileApi.instance.adminProductionMapQueueSnapshot();
      expect(reads, 2);
      expect(clients, 1, reason: 'keep-alive client is reused');
    }, () {
      clients++;
      return MockClient((request) {
        reads++;
        if (!entered.isCompleted) entered.complete();
        return response.future;
      });
    });
  });

  test(
      'scoped controls request carries canonical IDs and auth scopes do not share reads',
      () async {
    final requests = <http.Request>[];
    final response = Completer<http.Response>();
    await http.runWithClient(() async {
      final first = MobileApi.instance.adminProductionMapQueueSnapshot(
          apparatus: 'apparatus:test:one', orderId: 'zakaz-one');
      AppSession.instance.token = 'another-test-account';
      final second = MobileApi.instance.adminProductionMapQueueSnapshot(
          apparatus: 'apparatus:test:one', orderId: 'zakaz-one');
      response.complete(_snapshot());
      await Future.wait([first, second]);
      expect(requests, hasLength(2));
      expect(requests.first.url.queryParameters, {
        'apparatus': 'apparatus:test:one',
        'order_id': 'zakaz-one',
      });
    },
        () => MockClient((request) {
              requests.add(request);
              return response.future;
            }));
  });

  test('failed shared snapshot is evicted and can be retried', () async {
    var reads = 0;
    await http.runWithClient(() async {
      await expectLater(MobileApi.instance.adminProductionMapQueueSnapshot(),
          throwsA(isA<MobileApiException>()));
      expect(
          (await MobileApi.instance.adminProductionMapQueueSnapshot()).revision,
          1);
      expect(reads, 2);
    },
        () => MockClient((request) async => ++reads == 1
            ? http.Response('{"error":"store_failed"}', 503)
            : _snapshot()));
  });

  test('an admin mutation prevents sharing a pre-mutation snapshot', () async {
    final oldRead = Completer<http.Response>();
    final entered = Completer<void>();
    var reads = 0;
    await http.runWithClient(() async {
      final before = MobileApi.instance.adminProductionMapQueueSnapshot();
      await entered.future;
      await MobileApi.instance.adminProductionMapOrderControl(
          orderId: 'zakaz-one', action: AdminOrderControlAction.freeze);
      final after = await MobileApi.instance.adminProductionMapQueueSnapshot();
      expect(reads, 2);
      expect(after.epoch, 'network-test');
      oldRead.complete(_snapshot());
      await before;
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                return http.Response(
                    '{"ok":true,"control":{"state":"frozen"}}', 200);
              }
              if (++reads == 1) {
                entered.complete();
                return oldRead.future;
              }
              return _snapshot();
            }));
  });

  for (final timeout in [false, true]) {
    testWidgets(
        'worker cold-load ${timeout ? 'timeout' : '503'} exits loading and exposes retry',
        (tester) async {
      final pending = Completer<http.Response>();
      final requests = <String>[];
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(useMaterial3: true),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminProductionMapOrdersScreen(
              readOnly: true, workerMode: true),
        ));
        await tester.pump();
        expect(requests, contains('/v1/mobile/admin/apparatus'));
        expect(requests, contains('/v1/mobile/admin/production-maps/sequence'));
        // Isolate cold-load HTTP failure from the subsequent live connection.
        // Both real MobileApi requests have already entered the mock transport.
        await TestModeController.instance.setEnabled(true);
        if (!timeout) {
          pending.complete(http.Response('{"error":"store_failed"}', 503));
        }
        await tester.pump(const Duration(seconds: 11));
        await tester.pump();
        expect(find.byType(AppLoadingIndicator), findsNothing);
        expect(find.text('Reja menu yuklanmadi'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (!pending.isCompleted) pending.complete(http.Response('{}', 503));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
          () => MockClient((request) {
                requests.add(request.url.path);
                return pending.future;
              }));
    });
  }
}
