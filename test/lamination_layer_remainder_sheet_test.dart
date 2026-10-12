import 'dart:convert';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const apparatus = 'apparatus:default:asset-007';
Map<String, dynamic> sourcePayload({String kind = 'progress_batch'}) => {
      'source_kind': kind,
      'source_id': kind == 'raw_material' ? 'film-roll' : 'printed-roll',
      'session_id': 'completed-lamination',
      'revision': 3,
      'qr_payload': kind == 'raw_material' ? 'film-qr' : 'printed-qr',
      'item_code': 'PET',
      'item_name': kind == 'raw_material' ? 'Film PET' : 'Printed PET',
      'source_net_kg': 50,
      'source_meter': 1500,
      'tare_kg': 2,
      'producer_name': 'Original owner',
    };

Map<String, dynamic> remainderPayload(String requestId) => {
      'operation_id': 'saved-remainder',
      'request_id': requestId,
      'source_kind': 'progress_batch',
      'source_id': 'printed-roll',
      'qr_payload': 'remaining-qr',
      'remaining_net_kg': 20,
      'remaining_meter': 600,
      'producer_name': 'Original owner',
      'recorded_by': {'display_name': 'Lamination operator'},
    };

Widget sheet({Key? key}) => MaterialApp(
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: LaminationLayerRemainderSheet(
          key: key,
          apparatus: apparatus,
          orderId: 'order-1',
          progressDriverUrlPicker: (_) async => 'http://printer.local:8080',
        ),
      ),
    );

Future<void> scrollTo(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(ValueKey(key)),
    160,
    scrollable: find
        .byWidgetPredicate((widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down)
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'worker-token';
  });
  tearDown(() {
    AppSession.instance.token = null;
  });

  testWidgets('lists scanned layers and previews meter from net kg',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(sheet());
      await tester.pumpAndSettle();
      expect(find.text('Printed PET'), findsOneWidget);
      expect(find.text('Film PET'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey(
          'layer-remainder-source-progress_batch-printed-roll')));
      await tester.pumpAndSettle();
      await scrollTo(tester, 'layer-remainder-net-kg');
      await tester.enterText(
          find.byKey(const ValueKey('layer-remainder-net-kg')), '20');
      await tester.pump();
      expect(find.text('Taxminiy metraj: ≈ 600 m'), findsOneWidget);
      final save = tester.widget<FilledButton>(
          find.byKey(const ValueKey('layer-remainder-save')));
      expect(save.onPressed, isNotNull);
      await tester.enterText(
          find.byKey(const ValueKey('layer-remainder-net-kg')), '51');
      await tester.pump();
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('layer-remainder-save')))
              .onPressed,
          isNull);
    },
        () => MockClient((request) async {
              expect(request.method, 'GET');
              return http.Response(
                  jsonEncode({
                    'sources': [
                      sourcePayload(),
                      sourcePayload(kind: 'raw_material')
                    ],
                    'remainders': [],
                  }),
                  200);
            }));
  });

  testWidgets('saved print failure offers reprint without another return',
      (tester) async {
    final creates = <http.Request>[];
    final reprints = <http.Request>[];
    Map<String, dynamic>? saved;
    await http.runWithClient(() async {
      await tester.pumpWidget(sheet());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey(
          'layer-remainder-source-progress_batch-printed-roll')));
      await tester.pumpAndSettle();
      await scrollTo(tester, 'layer-remainder-net-kg');
      await tester.enterText(
          find.byKey(const ValueKey('layer-remainder-net-kg')), '20');
      await tester.pump();
      await scrollTo(tester, 'layer-remainder-save');
      await tester.tap(find.byKey(const ValueKey('layer-remainder-save')));
      await tester.pumpAndSettle();
      expect(creates, hasLength(1));
      expect(find.textContaining('Qoldiq saqlangan. QR chop etilmadi'),
          findsOneWidget);
      await scrollTo(tester, 'layer-remainder-reprint');
      await tester.tap(find.byKey(const ValueKey('layer-remainder-reprint')));
      await tester.pumpAndSettle();
      expect(creates, hasLength(1));
      expect(reprints, hasLength(1));
      expect(
          jsonDecode(reprints.single.body)['operation_id'], 'saved-remainder');
    },
        () => MockClient((request) async {
              if (request.method == 'GET') {
                return http.Response(
                    jsonEncode({
                      'sources': saved == null ? [sourcePayload()] : [],
                      'remainders': saved == null ? [] : [saved],
                    }),
                    200);
              }
              if (request.url.path.endsWith('/reprint')) {
                reprints.add(request);
              } else {
                creates.add(request);
                saved = remainderPayload(
                    jsonDecode(request.body)['request_id'] as String);
              }
              return http.Response(
                  jsonEncode({
                    'ok': true,
                    'remainder': saved,
                    'print': {'ok': false, 'status': 'printer_unavailable'},
                  }),
                  200);
            }));
  });

  testWidgets('unknown save retry survives sheet reopen with same request ID',
      (tester) async {
    final requests = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(sheet());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey(
          'layer-remainder-source-progress_batch-printed-roll')));
      await tester.pumpAndSettle();
      await scrollTo(tester, 'layer-remainder-net-kg');
      await tester.enterText(
          find.byKey(const ValueKey('layer-remainder-net-kg')), '20');
      await tester.pump();
      await scrollTo(tester, 'layer-remainder-save');
      await tester.tap(find.byKey(const ValueKey('layer-remainder-save')));
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      await tester.pumpWidget(sheet(key: const ValueKey('reopened')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Oldingi so‘rovning javobi kelmagan'),
          findsOneWidget);
      await scrollTo(tester, 'layer-remainder-save');
      await tester.tap(find.byKey(const ValueKey('layer-remainder-save')));
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      expect(requests[0]['request_id'], requests[1]['request_id']);
      expect(requests[1]['remaining_net_kg'], 20);
      expect(requests[1]['expected_revision'], 3);
    },
        () => MockClient((request) async {
              if (request.method == 'GET') {
                return http.Response(
                    jsonEncode({
                      'sources': [sourcePayload()],
                      'remainders': []
                    }),
                    200);
              }
              requests.add(
                  (jsonDecode(request.body) as Map).cast<String, dynamic>());
              throw http.ClientException('Connection lost after save');
            }));
  });

  testWidgets('reopening reconciles committed save whose response was lost',
      (tester) async {
    Map<String, dynamic>? saved;
    var creates = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(sheet());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey(
          'layer-remainder-source-progress_batch-printed-roll')));
      await tester.pumpAndSettle();
      await scrollTo(tester, 'layer-remainder-net-kg');
      await tester.enterText(
          find.byKey(const ValueKey('layer-remainder-net-kg')), '20');
      await tester.pump();
      await scrollTo(tester, 'layer-remainder-save');
      await tester.tap(find.byKey(const ValueKey('layer-remainder-save')));
      await tester.pumpAndSettle();
      expect(creates, 1);
      await tester.pumpWidget(sheet(key: const ValueKey('recovered')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Oldingi so‘rovning javobi kelmagan'),
          findsNothing);
      await scrollTo(tester, 'layer-remainder-reprint');
      expect(find.byKey(const ValueKey('layer-remainder-reprint')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('layer-remainder-save')), findsNothing);
      expect(creates, 1);
    },
        () => MockClient((request) async {
              if (request.method == 'GET') {
                return http.Response(
                    jsonEncode({
                      'sources': saved == null ? [sourcePayload()] : [],
                      'remainders': saved == null ? [] : [saved],
                    }),
                    200);
              }
              creates++;
              saved = remainderPayload(jsonDecode(request.body)['request_id']);
              throw http.ClientException('Response lost after commit');
            }));
  });
}
