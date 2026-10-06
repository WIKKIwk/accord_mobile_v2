import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/scanner/reliable_mobile_scanner.dart';
import 'package:accord_mobile_v2/src/features/werka/presentation/werka_qr_preview_screen.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/werka/presentation/werka_archive_batch_qr_lookup_screen.dart';
import 'package:accord_mobile_v2/src/features/werka/presentation/werka_paddon_receive_screen.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/aparatchi_paddon_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/werka/presentation/werka_stock_entry_lookup_screen.dart';
import 'package:accord_mobile_v2/src/features/werka/presentation/werka_stock_entry_qr_scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _previewPath = '/v1/mobile/werka/qr/preview';
Map<String, dynamic> _preview() => {
      'kind': 'paddon',
      'paddon': {
        'id': 'p2',
        'code': '00002',
        'location': 'Rezka',
        'item_count': 2
      },
      'items': [
        for (var i = 0; i < 2; i++)
          {
            'batch_id': 'roll-$i',
            'apparatus': 'apparatus:default:asset-010',
            'order_id': 'order-1',
            'qr_payload': 'QR-$i',
            'label_item_name': 'Rulon $i',
            'finished_goods_kg': 10.0 + i,
          }
      ],
      'warehouses': ['WH-1'],
      'snapshot_token': 'snapshot-2',
      'can_receive': true,
    };

Future<void> _openScanner(
    WidgetTester tester, List<RouteSettings> routes) async {
  await tester.runAsync(() async {
    await GlobalMaterialLocalizations.delegate.load(const Locale('uz'));
    await GlobalCupertinoLocalizations.delegate.load(const Locale('uz'));
  });
  await tester.binding.setSurfaceSize(const Size(430, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    navigatorObservers: [reliableScannerRouteObserver],
    locale: const Locale('uz'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate
    ],
    onGenerateRoute: (settings) {
      routes.add(settings);
      // Exercise the real app router and existing receipt screen for pallets.
      if (settings.name == AppRoutes.werkaQrPreview) {
        return AppRouter.onGenerateRoute(settings);
      }
      return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(body: Text(settings.name!)));
    },
    home: const WerkaStockEntryQrScanScreen(),
  ));
  await tester.pumpAndSettle();
}

void _detect(WidgetTester tester, String code) {
  tester.widget<MobileScanner>(find.byType(MobileScanner)).onDetect!(
    BarcodeCapture(barcodes: [Barcode(rawValue: code)]),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalPlatform = MobileScannerPlatform.instance;
  setUpAll(() => MobileScannerPlatform.instance = _ScannerPlatform());
  tearDownAll(() => MobileScannerPlatform.instance = originalPlatform);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSession.instance.setSession(
        token: 'token',
        profile: const SessionProfile(
            role: UserRole.werka,
            ref: 'keeper',
            displayName: 'Werka',
            legalName: '',
            phone: '',
            avatarUrl: '',
            capabilities: ['werka.access']));
  });
  tearDown(() => AppSession.instance.clear());

  testWidgets(
      '00002 in ordinary scanner opens all pallet rolls and receives once',
      (tester) async {
    final routes = <RouteSettings>[];
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      await _openScanner(tester, routes);
      _detect(tester, ' 00002 ');
      _detect(
          tester, '00002'); // Duplicate camera frames must not navigate twice.
      await tester.pumpAndSettle();
      expectSync(routes.map((r) => r.name), [AppRoutes.werkaQrPreview]);
      expectSync((routes.single.arguments as WerkaQrPreview).code, '00002');
      expectSync(find.byType(WerkaPaddonReceiveScreen), findsOneWidget);
      for (var i = 0; i < 2; i++) {
        expectSync(
            find.byKey(ValueKey('paddon-wip-card-roll-$i')), findsOneWidget);
      }
      expectSync(
          requests
              .every((r) => r.url.path == _previewPath && r.method == 'GET'),
          isTrue);
      expectSync(requests.length,
          1); // A single read-only server identity and preview.
      final accept = find.byKey(const ValueKey('werka-paddon-receive'));
      await tester.ensureVisible(accept);
      await tester.tap(accept);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('werka-paddon-confirm')));
      await tester.pumpAndSettle();
      expectSync(
          find.byKey(const ValueKey('werka-paddon-received')), findsOneWidget);
      expectSync(requests.where((r) => r.method == 'POST').length, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
        () => MockClient((request) async {
              requests.add(request);
              expectSync(request.headers['Authorization'], 'Bearer token');
              if (request.method == 'GET') {
                expectSync(request.url.path, _previewPath);
                expectSync(request.url.queryParameters['qr_payload'], '00002');
                return http.Response(jsonEncode(_preview()), 200);
              }
              expectSync(request.url.path, '/v1/mobile/werka/paddons/receive');
              expectSync(jsonDecode(request.body), {
                'code': '00002',
                'warehouse': 'WH-1',
                'expected_batch_ids': ['roll-0', 'roll-1'],
                'snapshot_token': 'snapshot-2'
              });
              return http.Response(
                  jsonEncode({
                    'ok': true,
                    'receipt': {
                      'warehouse': 'WH-1',
                      'accepted_by_display_name': 'Werka',
                    }
                  }),
                  200);
            }));
  });

  testWidgets('missing five-digit pallet preserves legacy numeric stock QR',
      (tester) async {
    final routes = <RouteSettings>[];
    await http.runWithClient(() async {
      await _openScanner(tester, routes);
      _detect(tester, '54321');
      await tester.pumpAndSettle();
      expectSync(routes.single.name, AppRoutes.werkaStockEntryLookup);
      expectSync(
          (routes.single.arguments as WerkaStockEntryLookupArgs).scannedBarcode,
          '54321');
    },
        () => MockClient((request) async {
              expectSync(request.url.path, _previewPath);
              return http.Response(jsonEncode({'error': 'qr_not_found'}), 404);
            }));
  });

  for (final raw in [
    'STOCK-ABC',
    'https://scan.wspace.sbs/L/ACCORD/item/00002'
  ]) {
    testWidgets('explicit stock QR keeps legacy route: $raw', (tester) async {
      final routes = <RouteSettings>[];
      await http.runWithClient(() async {
        await _openScanner(tester, routes);
        _detect(tester, raw);
        await tester.pumpAndSettle();
        expectSync(routes.single.name, AppRoutes.werkaStockEntryLookup);
        final args = routes.single.arguments as WerkaStockEntryLookupArgs;
        expectSync(args.rawValue, raw);
        expectSync(args.scannedBarcode, raw.split('/').last);
      },
          () => MockClient((request) async {
                expectSync(request.method, 'GET');
                expectSync(request.url.path, _previewPath);
                expectSync(request.url.queryParameters['qr_payload'], raw);
                return http.Response('{"error":"qr_not_found"}', 404);
              }));
    });
  }

  testWidgets('archive QR still takes its existing route', (tester) async {
    final routes = <RouteSettings>[];
    final encoded = base64Url
        .encode(utf8.encode('ARCHIVE\nsess-1\nProduct\n3.6\n08 Sep 2026'))
        .replaceAll('=', '');
    await http.runWithClient(() async {
      await _openScanner(tester, routes);
      _detect(tester, 'https://scan.wspace.sbs/A/$encoded');
      await tester.pumpAndSettle();
      expectSync(routes.single.name, AppRoutes.werkaArchiveBatchQrLookup);
      expectSync(
          (routes.single.arguments as WerkaArchiveBatchQrLookupArgs)
              .payload
              .sessionID,
          'sess-1');
    },
        () => MockClient((_) async =>
            throw StateError('Archive QR must not call pallet API')));
  });

  for (final response in [
    http.Response('{"error":"forbidden"}', 403),
    http.Response(
        '', 404), // Old backend missing the endpoint is NOT a missing pallet.
    http.Response('', 503),
  ]) {
    testWidgets(
        'pallet HTTP ${response.statusCode} does not fall through to stock lookup',
        (tester) async {
      final routes = <RouteSettings>[];
      final requests = <http.Request>[];
      await http.runWithClient(() async {
        await _openScanner(tester, routes);
        _detect(tester, '00002');
        await tester.pumpAndSettle();
        expectSync(routes, isEmpty);
        expectSync(find.byType(WerkaStockEntryQrScanScreen), findsOneWidget);
        expectSync(find.byType(SnackBar), findsOneWidget);
        expectSync(requests.map((r) => r.url.path), [_previewPath]);
        expectSync(
            find.text(response.statusCode == 403
                ? 'QR ma’lumotini ko‘rishga ruxsat yo‘q. Sizga ombor biriktirilganini tekshiring.'
                : 'QR ma’lumotini olib bo‘lmadi. Qayta urinib ko‘ring.'),
            findsOneWidget);
      },
          () => MockClient((request) async {
                requests.add(request);
                return response;
              }));
    });
  }

  testWidgets('network failure keeps scanner available for a successful retry',
      (tester) async {
    var calls = 0;
    final routes = <RouteSettings>[];
    await http.runWithClient(() async {
      await _openScanner(tester, routes);
      _detect(tester, '00002');
      await tester.pumpAndSettle();
      expectSync(routes, isEmpty);
      _detect(tester, '00002');
      await tester.pumpAndSettle();
      expectSync(routes.single.name, AppRoutes.werkaQrPreview);
      expectSync(find.byType(WerkaPaddonReceiveScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
        () => MockClient((request) async {
              expectSync(request.url.path, _previewPath);
              if (++calls == 1) throw http.ClientException('offline');
              return http.Response(jsonEncode(_preview()), 200);
            }));
  });
  testWidgets('single WIP scan is read-only and explicit confirm receives once',
      (tester) async {
    final routes = <RouteSettings>[];
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      await _openScanner(tester, routes);
      _detect(tester, 'WIP-actual-code');
      _detect(tester, 'WIP-actual-code');
      await tester.pumpAndSettle();
      expectSync(routes.single.name, AppRoutes.werkaQrPreview);
      expectSync(find.byType(WerkaWipPreviewScreen), findsOneWidget);
      expectSync(find.text('Rulon single'), findsOneWidget);
      expectSync(requests.length, 1);
      expectSync(requests.single.method, 'GET');
      final button = find.byKey(const ValueKey('werka-wip-receive'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expectSync(requests.length, 1);
      await tester.tap(find.byKey(const ValueKey('werka-wip-confirm')));
      await tester.pumpAndSettle();
      expectSync(requests.where((r) => r.method == 'POST').length, 1);
      expectSync(
          find.byKey(const ValueKey('werka-wip-received')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
        () => MockClient((request) async {
              requests.add(request);
              expectSync(request.headers['Authorization'], 'Bearer token');
              if (request.method == 'GET') {
                expectSync(request.url.path, _previewPath);
                expectSync(request.url.queryParameters['qr_payload'],
                    'WIP-actual-code');
                return http.Response(
                    jsonEncode({
                      'kind': 'wip',
                      'batch': {
                        'batch_id': 'single',
                        'apparatus': 'apparatus:default:asset-010',
                        'order_id': 'order-1',
                        'qr_payload': 'WIP-actual-code',
                        'label_item_name': 'Rulon single',
                        'wip_status': 'waiting',
                        'finished_goods_kg': 12.5,
                      },
                      'warehouses': ['WH-1'],
                      'can_receive': true,
                      'snapshot_token': 'wip-token',
                    }),
                    200);
              }
              expectSync(request.url.path, '/v1/mobile/werka/wip/receive');
              expectSync(jsonDecode(request.body), {
                'progress_batch_id': 'single',
                'qr_payload': 'WIP-actual-code',
                'warehouse': 'WH-1',
                'snapshot_token': 'wip-token',
              });
              return http.Response(
                  jsonEncode({
                    'receipt': {
                      'warehouse': 'WH-1',
                      'accepted_by_display_name': 'Werka',
                    }
                  }),
                  200);
            }));
  });

  testWidgets(
      'server can identify nonnumeric pallet codes without client length rules',
      (tester) async {
    final routes = <RouteSettings>[];
    await http.runWithClient(() async {
      await _openScanner(tester, routes);
      _detect(tester, 'PALLET-A-2026');
      await tester.pumpAndSettle();
      expectSync(routes.single.name, AppRoutes.werkaQrPreview);
      expectSync(tester.widget<AparatchiPaddonDetailScreen>(
        find.byType(AparatchiPaddonDetailScreen),
      ).code, 'PALLET-A-2026');
      await tester.ensureVisible(find.text('Qayta tekshirish'));
      await tester.tap(find.text('Qayta tekshirish'));
      await tester.pumpAndSettle();
      expectSync(
          find.byKey(const ValueKey('werka-paddon-error')), findsNothing);
    },
        () => MockClient((request) async {
              expectSync(request.method, 'GET');
              expectSync(
                  request.url.queryParameters['qr_payload'], 'PALLET-A-2026');
              final data = _preview();
              (data['paddon'] as Map)['code'] = 'PALLET-A-2026';
              return http.Response(jsonEncode(data), 200);
            }));
  });

  testWidgets(
      'manual cancel performs no read and camera frames wait for dialog',
      (tester) async {
    final routes = <RouteSettings>[];
    await http.runWithClient(() async {
      await _openScanner(tester, routes);
      await tester.tap(find.byKey(const ValueKey('werka-qr-manual-entry')));
      await tester.pumpAndSettle();
      expectSync(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('werka-qr-manual-submit')))
              .onPressed,
          isNull);
      _detect(tester, '00002');
      await tester.pumpAndSettle();
      expectSync(
          find.byKey(const ValueKey('werka-qr-manual-code')), findsOneWidget);
      await tester.tap(find.text('Bekor qilish'));
      await tester.pumpAndSettle();
      expectSync(routes, isEmpty);
      expectSync(
          find.byKey(const ValueKey('werka-qr-manual-code')), findsNothing);
      expectSync(tester.takeException(), isNull);
    },
        () => MockClient(
            (_) async => throw StateError('Cancel must not read or receive')));
  });

  testWidgets('invalid manual archive QR resumes camera for next valid scan',
      (tester) async {
    var reads = 0;
    final routes = <RouteSettings>[];
    await http.runWithClient(() async {
      await _openScanner(tester, routes);
      await tester.tap(find.byKey(const ValueKey('werka-qr-manual-entry')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('werka-qr-manual-code')),
          'https://scan.wspace.sbs/A/not-valid-base64');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('werka-qr-manual-submit')));
      await tester.pumpAndSettle();
      expectSync(reads, 0);
      expectSync(routes, isEmpty);
      expectSync(
          tester
              .widget<MobileScanner>(find.byType(MobileScanner))
              .controller!
              .value
              .isRunning,
          isTrue);
      _detect(tester, '00002');
      await tester.pumpAndSettle();
      expectSync(reads, 1);
      expectSync(routes.single.name, AppRoutes.werkaQrPreview);
      expectSync(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
        () => MockClient((request) async {
              reads++;
              expectSync(request.method, 'GET');
              return http.Response(jsonEncode(_preview()), 200);
            }));
  });

  for (final desktop in [false, true]) {
    testWidgets(
        'manual QR submits once through read-only resolver, desktop=$desktop',
        (tester) async {
      if (desktop) debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      var reads = 0;
      final routes = <RouteSettings>[];
      try {
        await http.runWithClient(() async {
          await _openScanner(tester, routes);
          if (desktop) expectSync(find.byType(MobileScanner), findsNothing);
          await tester.tap(find.byKey(const ValueKey('werka-qr-manual-entry')));
          await tester.pumpAndSettle();
          await tester.enterText(
              find.byKey(const ValueKey('werka-qr-manual-code')), ' 00002 ');
          await tester.pump();
          final submit = tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('werka-qr-manual-submit')))
              .onPressed!;
          submit();
          submit();
          await tester.pumpAndSettle();
          expectSync(reads, 1);
          expectSync(routes.single.name, AppRoutes.werkaQrPreview);
          expectSync(find.byType(WerkaPaddonReceiveScreen), findsOneWidget);
          expectSync(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
            () => MockClient((request) async {
                  reads++;
                  expectSync(request.method, 'GET');
                  expectSync(request.url.path, _previewPath);
                  expectSync(
                      request.url.queryParameters['qr_payload'], '00002');
                  return http.Response(jsonEncode(_preview()), 200);
                }));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('invalid WIP remains on scanner and does not become stock',
      (tester) async {
    final routes = <RouteSettings>[];
    await http.runWithClient(() async {
      await _openScanner(tester, routes);
      _detect(tester, 'WIP-invalid');
      await tester.pumpAndSettle();
      expectSync(routes, isEmpty);
      expectSync(find.byType(SnackBar), findsOneWidget);
    },
        () => MockClient((request) async {
              expectSync(request.method, 'GET');
              return http.Response('{"error":"progress_batch_not_found"}', 404);
            }));
  });

  testWidgets('disposing scanner during pending resolution never navigates',
      (tester) async {
    final routes = <RouteSettings>[];
    final response = Completer<http.Response>();
    var reads = 0;
    await http.runWithClient(() async {
      await _openScanner(tester, routes);
      _detect(tester, '00002');
      _detect(tester, '00002');
      await tester.pump();
      expectSync(reads, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      response.complete(http.Response(jsonEncode(_preview()), 200));
      await tester.pumpAndSettle();
      expectSync(routes, isEmpty);
    },
        () => MockClient((request) {
              reads++;
              expectSync(request.method, 'GET');
              return response.future;
            }));
  });
}

class _ScannerPlatform extends MobileScannerPlatform {
  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();
  @override
  Stream<TorchState> get torchStateStream =>
      Stream.value(TorchState.unavailable);
  @override
  Stream<double> get zoomScaleStateStream => Stream.value(1);
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async =>
      const MobileScannerViewAttributes(
          cameraDirection: CameraFacing.back,
          currentTorchMode: TorchState.unavailable,
          size: Size(200, 200),
          numberOfCameras: 1);
  @override
  Future<void> stop() async {}
  @override
  Future<void> updateScanWindow(Rect? window) async {}
  @override
  Future<void> dispose() async {}
  @override
  Widget buildCameraView() => const SizedBox.square(dimension: 100);
}
