import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_progress_qr_scan_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart'
    show AdminWorkerWipQrScanArgs;
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _apparatus = 'apparatus:default:asset-010';
const _manualTitle = 'Enter QR code manually';
const _workerProfile = SessionProfile(
  role: UserRole.aparatchi,
  displayName: 'Scanner test worker',
  legalName: '',
  ref: 'scanner-worker',
  phone: '',
  avatarUrl: '',
  capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
  assignedApparatus: [_apparatus],
);

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

Widget _app({
  bool scanOnly = false,
  ValueChanged<String?>? onResult,
  RouteFactory? onGenerateRoute,
}) {
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
    onGenerateRoute: onGenerateRoute,
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
      role: UserRole.admin,
      displayName: 'Scanner test worker',
      legalName: '',
      ref: 'scanner-worker',
      phone: '',
      avatarUrl: '',
      capabilities: ['admin.access'],
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

  for (final scenario in [
    ('forbidden', 403, 'worker.qr.forbidden'),
    ('unauthorized', 401, 'worker.qr.session_expired'),
    ('store_failed', 503, 'worker.qr.server'),
    ('order_frozen', 400, 'worker.freeze.named'),
    ('order_freeze_requested', 400, 'worker.qr.freeze_requested'),
    (
      'wip_route_destination_unresolved',
      400,
      'worker.error.wip_route_destination'
    ),
    ('progress_batch_in_use', 400, 'worker.error.wip_in_use'),
    ('progress_batch_already_used', 400, 'worker.error.wip_used'),
    ('progress_qr_invalid_response', 400, 'worker.qr.invalid_response'),
    ('not_a_known_code', 400, 'worker.qr.lookup_failed'),
  ]) {
    testWidgets('normal scanner explains ${scenario.$1} and permits retry',
        (tester) async {
      final l10n = AppLocalizations(const Locale('en'));
      final paths = <String>[];
      await http.runWithClient(() async {
        await tester.pumpWidget(_app());
        await _openScanner(tester);
        await _enterManual(tester, 'blocked-production-qr');
        expect(
          find.text(l10n.productionText(scenario.$3,
              values: scenario.$1 == 'order_frozen'
                  ? {'order': 'Paused product'}
                  : const {})),
          findsOneWidget,
        );
        expect(find.text(_manualTitle), findsOneWidget);
        expect(paths.where((path) => path.endsWith('/progress-qr/report')),
            hasLength(1));
        expect(paths.any((path) => path.contains('/queue/')), isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
          () => MockClient((request) async {
                paths.add(request.url.path);
                if (request.url.path == '/v1/mobile/admin/apparatus') {
                  return _catalogResponse();
                }
                expect(request.url.path, endsWith('/progress-qr/report'));
                return http.Response(
                    jsonEncode({
                      'error': scenario.$1,
                      if (scenario.$1 == 'order_frozen')
                        'order_title': 'Paused product',
                    }),
                    scenario.$2);
              }));
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  }

  testWidgets('live scanner retains lookup guidance after restarting camera',
      (tester) async {
    final previousPlatform = MobileScannerPlatform.instance;
    final scannerPlatform = _ReportScannerPlatform();
    MobileScannerPlatform.instance = scannerPlatform;
    try {
      await http.runWithClient(() async {
        await tester.pumpWidget(_app());
        await _openScanner(tester);
        final startsBeforeLookup = scannerPlatform.starts;
        await _enterManual(tester, 'forbidden-production-qr');
        final message = AppLocalizations(const Locale('en'))
            .productionText('worker.qr.forbidden');
        expect(find.text(message), findsOneWidget);
        expect(scannerPlatform.starts, greaterThan(startsBeforeLookup));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
          () => MockClient((request) async {
                if (request.url.path == '/v1/mobile/admin/apparatus') {
                  return _catalogResponse();
                }
                return http.Response('{"error":"forbidden"}', 403);
              }));
    } finally {
      MobileScannerPlatform.instance = previousPlatform;
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final networkFailure in ['timeout', 'connection', 'invalid-json']) {
    testWidgets('normal scanner explains $networkFailure', (tester) async {
      final l10n = AppLocalizations(const Locale('en'));
      final key = switch (networkFailure) {
        'timeout' => 'worker.error.network_timeout',
        'connection' => 'worker.qr.connection',
        _ => 'worker.qr.invalid_response',
      };
      await http.runWithClient(() async {
        await tester.pumpWidget(_app());
        await _openScanner(tester);
        await _enterManual(tester, 'network-production-qr');
        expect(find.text(l10n.productionText(key)), findsOneWidget);
        expect(find.text(_manualTitle), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
          () => MockClient((request) async {
                if (request.url.path == '/v1/mobile/admin/apparatus') {
                  return _catalogResponse();
                }
                expect(request.url.path, endsWith('/progress-qr/report'));
                if (networkFailure == 'timeout') {
                  throw TimeoutException('lookup timed out');
                }
                if (networkFailure == 'connection') {
                  throw http.ClientException('connection interrupted');
                }
                return http.Response('invalid-json', 200);
              }));
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  }

  for (final (source, failure, key) in [
    ('paddon', 'forbidden', 'worker.qr.forbidden'),
    ('paddon', 'invalid-json', 'worker.qr.invalid_response'),
    ('opening-wip', 'timeout', 'worker.error.network_timeout'),
    ('opening-wip', 'invalid-json', 'worker.qr.invalid_response'),
    ('raw-material', 'unauthorized', 'worker.qr.session_expired'),
    ('raw-material', 'connection', 'worker.qr.connection'),
    ('raw-material', 'server', 'worker.qr.server'),
  ]) {
    testWidgets('normal scanner retains $source fallback $failure',
        (tester) async {
      final paths = <String>[];
      final suffix = switch (source) {
        'paddon' => '/paddons/qr/report',
        'opening-wip' => '/opening-wip/qr/report',
        _ => '/raw-material-assignments/lookup',
      };
      await http.runWithClient(() async {
        await tester.pumpWidget(_app());
        await _openScanner(tester);
        await _enterManual(
            tester, source == 'paddon' ? '12345' : 'fallback-qr');
        expect(
          find.text(AppLocalizations(const Locale('en')).productionText(key)),
          findsOneWidget,
        );
        expect(find.text(_manualTitle), findsOneWidget);
        expect(paths.where((path) => path.endsWith(suffix)), hasLength(1));
        expect(paths.last, endsWith('/raw-material-assignments/lookup'));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
          () => MockClient((request) async {
                final path = request.url.path;
                paths.add(path);
                if (path == '/v1/mobile/admin/apparatus') {
                  return _catalogResponse();
                }
                if (path.endsWith(suffix)) {
                  return switch (failure) {
                    'timeout' => throw TimeoutException('fallback timed out'),
                    'connection' =>
                      throw http.ClientException('fallback connection failed'),
                    'invalid-json' => http.Response('invalid-json', 200),
                    'forbidden' => http.Response('{"error":"forbidden"}', 403),
                    'unauthorized' =>
                      http.Response('{"error":"unauthorized"}', 401),
                    _ => http.Response('{"error":"store_failed"}', 503),
                  };
                }
                return http.Response(
                    '{"error":"progress_batch_not_found"}', 404);
              }));
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  }

  testWidgets('worker production QR hands off to the apparatus queue',
      (tester) async {
    AppSession.instance.profile = _workerProfile;
    RouteSettings? queueSettings;
    final paths = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(_app(onGenerateRoute: (settings) {
        expect(settings.name, AppRoutes.apparatusQueue);
        queueSettings = settings;
        return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('Worker queue')));
      }));
      await _openScanner(tester);
      await _enterManual(tester, 'worker-production-qr');
      expect(find.text('Worker queue'), findsOneWidget);
      expect(find.byType(AdminProgressQrScanScreen), findsNothing);
      expect((queueSettings!.arguments as AdminWorkerWipQrScanArgs).qrPayload,
          'worker-production-qr');
      expect(paths, [
        '/v1/mobile/admin/apparatus',
        '/v1/mobile/admin/production-maps/progress-qr/report',
      ]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              paths.add(request.url.path);
              if (request.url.path == '/v1/mobile/admin/apparatus') {
                return _catalogResponse();
              }
              expect(request.url.path, endsWith('/progress-qr/report'));
              return _reportResponse('worker-production-qr');
            }));
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  for (final (source, worker) in [
    ('paddon', true),
    ('opening-wip', true),
    ('raw-material', true),
    ('opening-wip', false),
  ]) {
    final handsOffToQueue = source == 'opening-wip' && worker;
    final expectedFlow = handsOffToQueue
        ? 'hands off to the apparatus queue'
        : 'retains its report fallback';
    testWidgets('${worker ? 'worker' : 'admin'} $source QR $expectedFlow',
        (tester) async {
      if (worker) {
        AppSession.instance.profile = _workerProfile;
      }
      RouteSettings? queueSettings;
      final qr = source == 'paddon' ? '12345' : '$source-stock-qr';
      await http.runWithClient(() async {
        await tester.pumpWidget(_app(onGenerateRoute: (settings) {
          expect(settings.name, AppRoutes.apparatusQueue);
          queueSettings = settings;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('Worker queue')),
          );
        }));
        await _openScanner(tester);
        await _enterManual(tester, qr);
        if (handsOffToQueue) {
          expect(find.text('Worker queue'), findsOneWidget);
          expect(find.byType(AdminProgressQrScanScreen), findsNothing);
          expect(
              (queueSettings!.arguments as AdminWorkerWipQrScanArgs).qrPayload,
              qr);
        } else {
          expect(queueSettings, isNull);
          expect(find.byType(AdminProgressQrScanScreen), findsOneWidget);
          expect(find.text(_manualTitle), findsNothing);
          expect(find.text(source == 'paddon' ? qr : '$source product'),
              findsWidgets);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
          () => MockClient((request) async {
                final path = request.url.path;
                if (path == '/v1/mobile/admin/apparatus') {
                  return _catalogResponse();
                }
                if (source == 'paddon' && path.endsWith('/paddons/qr/report')) {
                  return http.Response(
                      jsonEncode({
                        'paddon': {'code': qr},
                        'items': []
                      }),
                      200);
                }
                if (source == 'opening-wip' &&
                    path.endsWith('/opening-wip/qr/report')) {
                  return http.Response(
                      jsonEncode({
                        'record': {
                          'intake': {'status': 'confirmed'},
                          'batches': [
                            {
                              'batch_id': 'opening-test-batch',
                              'qr_payload': qr,
                              'label_item_name': '$source product',
                              'wip_status': 'waiting',
                            },
                          ],
                        },
                      }),
                      200);
                }
                if (source == 'raw-material' &&
                    path.endsWith('/opening-wip/qr/report')) {
                  return http.Response('{"error":"forbidden"}', 403);
                }
                if (source == 'raw-material' &&
                    path.endsWith('/raw-material-assignments/lookup')) {
                  return http.Response(
                      jsonEncode({
                        'barcode': qr,
                        'item_name': '$source product',
                        'status': 'available',
                        'qty': 12,
                        'uom': 'kg',
                      }),
                      200);
                }
                expect(path, isNot(AppRoutes.apparatusQueue));
                return http.Response(
                    '{"error":"progress_batch_not_found"}', 404);
              }));
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  }

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

class _ReportScannerPlatform extends MobileScannerPlatform {
  var starts = 0;

  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();
  @override
  Stream<TorchState> get torchStateStream =>
      Stream.value(TorchState.unavailable);
  @override
  Stream<double> get zoomScaleStateStream => Stream.value(1);
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    starts++;
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.unavailable,
      size: Size(200, 200),
      numberOfCameras: 1,
    );
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> updateScanWindow(Rect? window) async {}
  @override
  Future<void> dispose() async {}
  @override
  Widget buildCameraView() => const SizedBox.square(dimension: 100);
}
