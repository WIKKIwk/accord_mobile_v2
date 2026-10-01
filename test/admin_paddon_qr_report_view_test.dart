import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_progress_qr_scan_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'admin-paddon-qr-test';
  });

  tearDown(() {
    AppSession.instance.token = null;
  });

  testWidgets('admin pallet QR report shows backend weight totals',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.binding.setSurfaceSize(const Size(430, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(() async {
        await GlobalMaterialLocalizations.delegate.load(const Locale('uz'));
        await GlobalCupertinoLocalizations.delegate.load(const Locale('uz'));
      });

      var qrReportCalls = 0;
      var palletReportCalls = 0;
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(
          locale: Locale('uz'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: AdminProgressQrScanScreen(),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        await tester.tap(find.byIcon(Icons.keyboard_alt_outlined));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.enterText(find.byType(TextField), '00001');
        await tester.tap(find.text('Tekshirish'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(qrReportCalls, 1);
        expect(palletReportCalls, 1);
        expect(find.byKey(const ValueKey('admin-paddon-qr-weights')),
            findsOneWidget);
        expect(find.text('Jami brutto: 21.25 kg'), findsOneWidget);
        expect(find.text('Jami netto: 19.875 kg'), findsOneWidget);
      },
          () => MockClient((request) async {
                switch (request.url.path) {
                  case '/v1/mobile/admin/apparatus':
                    return http.Response('[]', 200);
                  case '/v1/mobile/admin/production-maps/progress-qr/report':
                    qrReportCalls++;
                    return http.Response(
                      jsonEncode({'error': 'progress_batch_not_found'}),
                      404,
                    );
                  case '/v1/mobile/admin/production-maps/paddons/qr/report':
                    palletReportCalls++;
                    return http.Response(
                      jsonEncode({
                        'paddon': {
                          'id': 'paddon-1',
                          'code': '00001',
                          'location': 'Rezka',
                          'item_count': 2,
                          'total_gross_kg': 21.25,
                          'total_net_kg': 19.875,
                        },
                        'items': [],
                      }),
                      200,
                    );
                  default:
                    throw StateError(
                        'Unexpected request ${request.method} ${request.url}');
                }
              }));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    }
  });

  for (final language in ['uz', 'en', 'ru']) {
    testWidgets(
      'admin pallet contents are readable and localized in $language',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        try {
          await tester.binding.setSurfaceSize(
            Size(language == 'ru' ? 360 : 430, 1000),
          );
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final locale = Locale(language);
          await tester.runAsync(() async {
            await GlobalMaterialLocalizations.delegate.load(locale);
            await GlobalCupertinoLocalizations.delegate.load(locale);
            const fontPath = String.fromEnvironment('ADMIN_PADDON_QR_FONT');
            if (fontPath.isNotEmpty) {
              await (FontLoader('Roboto')
                    ..addFont(File(fontPath)
                        .readAsBytes()
                        .then((bytes) => bytes.buffer.asByteData())))
                  .load();
            }
          });
          final l10n = AppLocalizations(locale);
          await http.runWithClient(
            () async {
              await tester.pumpWidget(
                MaterialApp(
                  theme: ThemeData.dark(useMaterial3: true),
                  locale: locale,
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                  ],
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(language == 'ru' ? 1.3 : 1),
                    ),
                    child: RepaintBoundary(
                      key: const ValueKey('admin-paddon-test-capture'),
                      child: child!,
                    ),
                  ),
                  home: const AdminProgressQrScanScreen(),
                ),
              );
              await tester.pumpAndSettle();
              await tester.tap(find.byIcon(Icons.keyboard_alt_outlined));
              await tester.pumpAndSettle();
              await tester.enterText(find.byType(TextField), '00001');
              await tester.tap(
                find.text(l10n.productionText('worker.scanner.manual.verify')),
              );
              await tester.pumpAndSettle();

              expect(find.byType(Card), findsOneWidget);
              expect(
                find.text('1. Avella 120 sht tayyor mahsulot'),
                findsOneWidget,
              );
              expect(find.text('6. WIP'), findsOneWidget);
              expect(find.textContaining('Batch ID'), findsNothing);
              expect(find.textContaining('progress-batch:'), findsNothing);
              expect(find.textContaining('apparatus:'), findsNothing);
              expect(find.textContaining('backend_state_v2'), findsNothing);
              expect(find.textContaining('processed'), findsNothing);
              expect(find.textContaining('completed'), findsNothing);
              expect(find.text('zakaz-0002'), findsNWidgets(6));
              expect(find.text('120 sht'), findsNWidgets(6));
              expect(find.text('400118D6CD6A449F6C8806D3'), findsOneWidget);
              expect(find.text('qobil oka • Rezka'), findsNWidgets(5));
              expect(
                find.byKey(const ValueKey('admin-paddon-qr-weights')),
                findsOneWidget,
              );
              final expectedStatuses = switch (language) {
                'uz' => [
                    'Keyingi bosqichda ishlatilgan',
                    'Keyingi bosqichni kutmoqda',
                    'Ushbu rulon omborga qabulni kutmoqda',
                    'Ish jarayonida',
                    'Omborga qabul qilingan',
                    'Belgilanmagan',
                  ],
                'en' => [
                    'Used by the next stage',
                    'Waiting for the next stage',
                    'This roll is awaiting warehouse receipt',
                    'In production',
                    'Accepted into warehouse stock',
                    'Not specified',
                  ],
                _ => [
                    'Использовано на следующем этапе',
                    'Ожидает следующего этапа',
                    'Этот рулон ожидает приёмки на склад',
                    'В производстве',
                    'Принято на склад',
                    'Не указано',
                  ],
              };
              for (var index = 0; index < expectedStatuses.length; index++) {
                final row = find.byKey(
                  ValueKey('admin-paddon-wip-${index + 1}'),
                );
                await tester.ensureVisible(row);
                await tester.pumpAndSettle();
                expect(
                  find.descendant(
                    of: row,
                    matching: find.textContaining(expectedStatuses[index]),
                  ),
                  findsOneWidget,
                );
                expect(tester.takeException(), isNull);
              }

              const screenshot = String.fromEnvironment(
                'ADMIN_PADDON_QR_SCREENSHOT',
              );
              if (screenshot.isNotEmpty && language == 'uz') {
                await tester.ensureVisible(find.text('00001'));
                await tester.pumpAndSettle();
                final boundary = tester.renderObject<RenderRepaintBoundary>(
                  find.byKey(const ValueKey('admin-paddon-test-capture')),
                );
                await tester.runAsync(() async {
                  final image = await boundary.toImage(pixelRatio: 2);
                  final bytes = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  await File(screenshot)
                      .writeAsBytes(bytes!.buffer.asUint8List());
                  image.dispose();
                });
              }
              await tester.scrollUntilVisible(
                find.byIcon(Icons.qr_code_scanner_rounded),
                500,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.tap(find.byIcon(Icons.qr_code_scanner_rounded));
              await tester.pumpAndSettle();
              expect(
                find.byKey(const ValueKey('admin-paddon-qr-card')),
                findsNothing,
              );
              expect(find.byIcon(Icons.keyboard_alt_outlined), findsOneWidget);
            },
            () => MockClient((request) async {
              if (request.url.path.endsWith('/apparatus')) {
                return http.Response(
                  jsonEncode([
                    {
                      'apparatus_id': 'apparatus:default:asset-010',
                      'display': {'display_name': 'Rezka'},
                      'execution_profile': {
                        'operation': 'cutting',
                        'technology': 'slitting',
                      },
                      'source_revision': 1,
                      'source_aasx_sha256': 'a' * 64,
                    },
                  ]),
                  200,
                );
              }
              if (request.url.path.endsWith('/progress-qr/report')) {
                return http.Response(
                  jsonEncode({'error': 'progress_batch_not_found'}),
                  404,
                );
              }
              if (request.url.path.endsWith('/paddons/qr/report')) {
                return http.Response(jsonEncode(_palletWithContents()), 200);
              }
              throw StateError(
                'Unexpected request ${request.method} ${request.url}',
              );
            }),
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}

Map<String, dynamic> _palletWithContents() {
  const statuses = [
    ('processed', 'consumed_by_next_stage'),
    ('waiting', 'waiting_next_stage'),
    ('waiting', 'free_wip'),
    ('in_use', ''),
    ('processed', 'accepted_to_stock'),
    ('backend_state_v2', 'backend_flow_v2'),
  ];
  return {
    'paddon': {
      'id': 'paddon-1',
      'code': '00001',
      'location': 'Rezka',
      'item_count': statuses.length,
      'total_gross_kg': 21.25,
      'total_net_kg': 19.875,
    },
    'items': [
      for (var index = 0; index < statuses.length; index++)
        {
          'batch_id': 'progress-batch:178984375827877000:frame:$index',
          'apparatus':
              'apparatus:default:${index == 5 ? 'unknown' : 'asset-010'}',
          'current_location': 'qobil oka',
          'order_id': 'zakaz-0002',
          'label_item_name': index == 5
              ? 'progress-batch:178984375827877000:frame:$index'
              : 'Avella 120 sht tayyor mahsulot, apparat: apparatus:default:asset-010, ish tugatildi',
          'produced_qty': 120,
          'uom': 'sht',
          'qr_payload':
              index == 0 ? '400118D6CD6A449F6C8806D3' : '4001QR$index',
          'status': index == 5 ? 'backend_state_v2' : 'completed',
          'wip_status': statuses[index].$1,
          'status_detail': {
            'work_status': index == 5 ? 'backend_state_v2' : 'completed',
            'wip_status': statuses[index].$1,
            'flow_status': statuses[index].$2,
          },
        },
    ],
  };
}
