import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_progress_qr_scan_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _apparatus = 'apparatus:default:asset-010';
const _manualTitle = 'Enter QR code manually';

// Deterministic canonical JSON fixture, not a production catalog measurement.
final _catalogBody = jsonEncode([
  for (var index = 10; index < 42; index++)
    {
      'apparatus_id': 'apparatus:default:asset-$index',
      'source_revision': 1,
      'source_aasx_sha256': List.filled(64, 'a').join(),
      'display': {'display_name': 'Rezka test $index'},
      'execution_profile': {'operation': 'cut', 'technology': 'cutting'},
    },
  {
    'apparatus_id': _apparatus,
    'source_revision': 1,
    'source_aasx_sha256': List.filled(64, 'a').join(),
    'display': {'display_name': 'Canonical test station'},
    'execution_profile': {'operation': 'cut', 'technology': 'cutting'},
  },
]);

http.Response _catalogResponse() => http.Response(
      _catalogBody,
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Response _reportResponse(String qr) => http.Response(
      jsonEncode({
        'scanned_batch': {
          'batch_id': 'test-batch',
          'qr_payload': qr,
          'apparatus': _apparatus,
          'current_apparatus': _apparatus,
          'produced_qty': 12,
          'uom': 'kg',
        },
      }),
      200,
    );

Widget _app({bool scanOnly = false, ValueChanged<String?>? onResult}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async {
            final result = await Navigator.of(context).push<String>(
              MaterialPageRoute<String>(
                builder: (_) => AdminProgressQrScanScreen(scanOnly: scanOnly),
              ),
            );
            onResult?.call(result);
          },
          child: const Text('Open scanner'),
        ),
      ),
    ),
  );
}

Future<void> _openScanner(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open scanner'));
  await tester.pumpAndSettle();
  expect(find.byType(AdminProgressQrScanScreen), findsOneWidget);
}

Future<void> _enterManual(WidgetTester tester, String value) async {
  await tester.tap(find.text(_manualTitle));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), value);
  await tester.tap(find.widgetWithText(FilledButton, 'Verify'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'scanner-test-token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Scanner test worker',
      legalName: '',
      ref: 'scanner-worker',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read'],
      assignedApparatus: [_apparatus],
    );
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('scan-only opening sends no catalog GET or JSON bytes', (
    tester,
  ) async {
    var catalogReads = 0;
    var responseBytes = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(_app(scanOnly: true));
      await _openScanner(tester);
      // The old unconditional init GET consumes this exact fixture response.
      debugPrint('scan-only fixture: catalog_reads=$catalogReads '
          'json_body_bytes=$responseBytes '
          'catalog_fixture_bytes=${utf8.encode(_catalogBody).length}');
      expect(catalogReads, 0);
      expect(responseBytes, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              expect(request.method, 'GET');
              expect(request.url.path, '/v1/mobile/admin/apparatus');
              expect(request.url.queryParameters, {'limit': '10000'});
              catalogReads++;
              final response = _catalogResponse();
              responseBytes += response.bodyBytes.length;
              return response;
            }));
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets(
      'scan-only cancel, empty input and repeated routes preserve result', (
    tester,
  ) async {
    final results = <String?>[];
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(_app(scanOnly: true, onResult: results.add));
      await _openScanner(tester);
      await tester.tap(find.text(_manualTitle));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'must-not-return');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(results, isEmpty);
      expect(find.byType(AdminProgressQrScanScreen), findsOneWidget);
      await _enterManual(tester, '   ');
      expect(results, isEmpty);
      expect(find.byType(AdminProgressQrScanScreen), findsOneWidget);
      // Reauth changes the token/revision but the raw scanner owns no data.
      await AppSession.instance.setSession(
        token: 'scanner-refreshed-token',
        profile: AppSession.instance.profile!,
      );
      await _enterManual(
          tester, 'https://example.test/scan/ignored?qr_payload=00001');
      expect(results, ['00001']);
      expect(find.byType(AdminProgressQrScanScreen), findsNothing);
      await _openScanner(tester);
      await _enterManual(tester, '  40011234567890ABCDEF  ');
      expect(results, ['00001', '40011234567890ABCDEF']);
      await _openScanner(tester);
      Navigator.of(tester.element(find.byType(AdminProgressQrScanScreen)))
          .pop();
      await tester.pumpAndSettle();
      expect(results, ['00001', '40011234567890ABCDEF', null]);
      expect(find.text('Open scanner'), findsOneWidget);
      expect(requests, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              requests.add(request);
              return _catalogResponse();
            }));
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('normal scanner keeps catalog names and repeated report lookup', (
    tester,
  ) async {
    var catalogReads = 0;
    final qrRequests = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await _openScanner(tester);
      expect(catalogReads, 1);
      await _enterManual(tester, 'report-1');
      expect(qrRequests, ['report-1']);
      expect(find.textContaining('Canonical test station'), findsWidgets);
      final scanAgain = find.text(
        AppLocalizations(const Locale('en'))
            .productionText('worker.scanner.scan_again'),
      );
      await tester.scrollUntilVisible(scanAgain, 400);
      await tester.tap(scanAgain);
      await tester.pumpAndSettle();
      await _enterManual(tester, 'report-2');
      expect(qrRequests, ['report-1', 'report-2']);
      expect(catalogReads, 1);
      expect(find.textContaining('Canonical test station'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              if (request.url.path == '/v1/mobile/admin/apparatus') {
                expect(request.method, 'GET');
                expect(request.url.queryParameters, {'limit': '10000'});
                catalogReads++;
                return _catalogResponse();
              }
              expect(request.method, 'POST');
              expect(request.url.path, endsWith('/progress-qr/report'));
              final qr = jsonDecode(request.body)['qr_payload'] as String;
              qrRequests.add(qr);
              return _reportResponse(qr);
            }));
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('normal scanner survives catalog and lookup errors, then retries',
      (
    tester,
  ) async {
    var catalogReads = 0;
    var reportReads = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await _openScanner(tester);
      expect(catalogReads, 1);
      await _enterManual(tester, 'bad-report');
      expect(reportReads, 1);
      expect(find.byType(AdminProgressQrScanScreen), findsOneWidget);
      expect(find.text(_manualTitle), findsOneWidget);
      await _enterManual(tester, 'good-report');
      expect(reportReads, 2);
      expect(find.text(_manualTitle), findsNothing);
      expect(find.textContaining('good-report'), findsWidgets);
      expect(catalogReads, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              if (request.url.path == '/v1/mobile/admin/apparatus') {
                catalogReads++;
                return http.Response('{"error":"store_failed"}', 503);
              }
              expect(request.url.path, endsWith('/progress-qr/report'));
              reportReads++;
              return reportReads == 1
                  ? http.Response('{"error":"store_failed"}', 503)
                  : _reportResponse('good-report');
            }));
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('normal scanner ignores catalog completion after route closes', (
    tester,
  ) async {
    final catalog = Completer<http.Response>();
    var catalogReads = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await _openScanner(tester);
      expect(catalogReads, 1);
      Navigator.of(tester.element(find.byType(AdminProgressQrScanScreen)))
          .pop();
      await tester.pumpAndSettle();
      catalog.complete(_catalogResponse());
      await tester.pumpAndSettle();
      expect(find.text('Open scanner'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) {
              expect(request.method, 'GET');
              expect(request.url.path, '/v1/mobile/admin/apparatus');
              catalogReads++;
              return catalog.future;
            }));
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
