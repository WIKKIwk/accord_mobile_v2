import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
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

const _apparatus = 'apparatus:default:asset-007';
const _historyPath = '/v1/mobile/admin/production-maps/layer-remainders';
const _savedRoll = {
  'operation_id': 'saved-remainder',
  'request_id': 'report-1',
  'item_name': 'Printed PET',
  'source_kind': 'progress_batch',
  'source_id': 'printed-roll',
  'qr_payload': 'remaining-qr',
  'remaining_net_kg': 20,
  'remaining_meter': 600,
  'producer_name': 'Original owner',
  'recorded_by': {'display_name': 'Lamination operator'},
};
final _l10n = AppLocalizations(const Locale('uz'));

Widget _sheet({
  Key? key,
  AdminLaminationAstatkaResult? initialResult,
  bool printFailed = false,
}) =>
    MaterialApp(
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
          apparatus: _apparatus,
          orderId: 'order-1',
          initialResult: initialResult,
          printFailed: printFailed,
          progressDriverUrlPicker: (_) async => 'http://printer.test:8080',
        ),
      ),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'worker-token';
  });
  tearDown(() => AppSession.instance.token = null);

  testWidgets('history shows saved net weight, estimated length and both actors',
      (tester) async {
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(_sheet());
      await tester.pumpAndSettle();
      expect(find.text('Printed PET'), findsOneWidget);
      expect(find.textContaining('20 kg · ≈ 600 m'), findsOneWidget);
      expect(find.textContaining('Original owner'), findsOneWidget);
      expect(find.textContaining('Lamination operator'), findsOneWidget);
      expect(find.textContaining('remaining-qr'), findsOneWidget);
      expect(find.text('Unreported film'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, _historyPath);
      expect(requests.single.url.queryParameters,
          {'apparatus': _apparatus, 'order_id': 'order-1'});
    }, () => MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode({
            'sources': [
              {'source_id': 'unreported', 'item_name': 'Unreported film'}
            ],
            'remainders': [_savedRoll],
          }), 200);
        }));
  });

  testWidgets('a print failure retries the same saved remainder only',
      (tester) async {
    final writes = <http.Request>[];
    final printFailed = _l10n.productionText('worker.layer_remainder.print_failed');
    await http.runWithClient(() async {
      await tester.pumpWidget(_sheet());
      await tester.pumpAndSettle();
      final roll = find.widgetWithText(ListTile, 'Printed PET');
      await tester.tap(roll);
      await tester.pumpAndSettle();
      expect(find.text(printFailed), findsOneWidget);
      await tester.tap(roll);
      await tester.pumpAndSettle();
      expect(find.text(_l10n.productionText('worker.layer_remainder.printed')),
          findsOneWidget);
      expect(writes, hasLength(2));
      for (final request in writes) {
        expect(request.method, 'POST');
        expect(request.url.path, '$_historyPath/reprint');
        expect(jsonDecode(request.body), containsPair('operation_id', 'saved-remainder'));
      }
    }, () => MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(jsonEncode({'remainders': [_savedRoll]}), 200);
          }
          writes.add(request);
          return http.Response(jsonEncode({
            'ok': true,
            'remainder': _savedRoll,
            'print': {'ok': writes.length == 2},
          }), 200);
        }));
  });

  testWidgets('reopening history restores the saved QR without submitting a report',
      (tester) async {
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(_sheet());
      await tester.pumpAndSettle();
      expect(find.textContaining('remaining-qr'), findsOneWidget);
      await tester.pumpWidget(_sheet(key: const ValueKey('reopened')));
      await tester.pumpAndSettle();
      expect(find.textContaining('remaining-qr'), findsOneWidget);
      expect(requests.map((r) => r.method), ['GET', 'GET']);
      expect(requests.every((r) => r.url.path == _historyPath), isTrue);
    }, () => MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode({'remainders': [_savedRoll]}), 200);
        }));
  });

  testWidgets('a committed receipt keeps saved QR available when history fails',
      (tester) async {
    final writes = <http.Request>[];
    final saved = AdminLayerRemainder.fromJson(_savedRoll);
    await http.runWithClient(() async {
      await tester.pumpWidget(_sheet(
        initialResult: AdminLaminationAstatkaResult(remainders: [saved]),
        printFailed: true,
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('remaining-qr'), findsOneWidget);
      expect(find.textContaining('20 kg · ≈ 600 m'), findsOneWidget);
      expect(find.text(_l10n.productionText('worker.layer_remainder.print_failed')),
          findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Printed PET'));
      await tester.pumpAndSettle();
      expect(writes.single.url.path, '$_historyPath/reprint');
      expect(jsonDecode(writes.single.body), containsPair('operation_id', saved.operationId));
    }, () => MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response('{"error":"store_failed"}', 503);
          }
          writes.add(request);
          return http.Response(jsonEncode({
            'ok': true,
            'remainder': _savedRoll,
            'print': {'ok': true},
          }), 200);
        }));
  });
}
