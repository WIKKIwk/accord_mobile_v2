import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/widgets/feedback/rps_qr_reprint_sheet.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_shell.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_progress_qr_scan_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_dock.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/aparatchi_paddon_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/presentation/widgets/worker_wip_details.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
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
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: 'Admin',
      ref: 'ADMIN-PADDON-QR',
      phone: '',
      avatarUrl: '',
      capabilities: ['admin.access', 'production.map.manage'],
    );
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
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
        expect(find.byKey(const ValueKey('paddon-detail-weights')),
            findsOneWidget);
        expect(find.text('Jami brutto: 21.25 kg'), findsOneWidget);
        expect(find.text('Jami netto: 19.875 kg'), findsOneWidget);
        await tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh();
        await tester.pumpAndSettle();
        expect(palletReportCalls, 2);
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
            final fontLoader = FontLoader(AppTheme.fontFamily)
              ..addFont(rootBundle
                  .load('assets/fonts/google_sans/GoogleSans-Regular.ttf'))
              ..addFont(rootBundle
                  .load('assets/fonts/google_sans/GoogleSans-Medium.ttf'))
              ..addFont(rootBundle
                  .load('assets/fonts/google_sans/GoogleSans-Bold.ttf'))
              ..addFont(rootBundle
                  .load('assets/fonts/google_sans/GoogleSans-Italic.ttf'))
              ..addFont(rootBundle
                  .load('assets/fonts/google_sans/GoogleSans-MediumItalic.ttf'))
              ..addFont(rootBundle
                  .load('assets/fonts/google_sans/GoogleSans-BoldItalic.ttf'));
            await fontLoader.load();
            await (FontLoader('MaterialIcons')
                  ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
                .load();
            await GlobalMaterialLocalizations.delegate.load(locale);
            await GlobalCupertinoLocalizations.delegate.load(locale);
          });
          final l10n = AppLocalizations(locale);
          await http.runWithClient(
            () async {
              await tester.pumpWidget(
                MaterialApp(
                  theme: AppTheme.dark(),
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

              final detail = tester.widget<AparatchiPaddonDetailScreen>(
                find.byType(AparatchiPaddonDetailScreen),
              );
              expect(detail.manageItems, isFalse);
              expect(detail.snapshot!.items, hasLength(6));
              expect(find.byType(AppShell), findsOneWidget);
              expect(find.byType(AdminDock), findsOneWidget);
              expect(tester.widget<AdminDock>(find.byType(AdminDock)).activeTab,
                  AdminDockTab.home);
              expect(find.byType(WorkerWipDetails), findsNWidgets(6));
              expect(
                  find.byKey(const ValueKey('app-primary-navigation-button')),
                  findsOneWidget);
              expect(
                  tester
                      .widget<ActionChip>(
                          find.byKey(const ValueKey('paddon-unlock')))
                      .onPressed,
                  isNull);
              expect(find.textContaining('Batch ID'), findsNothing);
              expect(find.textContaining('progress-batch:'), findsNothing);
              expect(find.textContaining('apparatus:'), findsNothing);
              expect(find.textContaining('backend_state_v2'), findsNothing);
              expect(find.textContaining('processed'), findsNothing);
              expect(find.textContaining('completed'), findsNothing);
              expect(find.text('120 sht'), findsNWidgets(6));
              expect(
                  find.text('4001 18D6 CD6A 449F 6C88 06D3'), findsOneWidget);
              expect(find.text('Anis'), findsNWidgets(6));
              expect(
                find.byKey(const ValueKey('paddon-detail-weights')),
                findsOneWidget,
              );
              final expectedStatuses = [
                'worker.wip.status.consumed_next',
                'worker.wip.status.waiting_next',
                'worker.wip.status.free',
                'worker.wip.status.in_progress',
                'worker.wip.status.accepted',
                'worker.daily.wip',
              ];
              Finder wip(int index) => find.byKey(ValueKey(
                    'paddon-wip-card-progress-batch:178984375827877000:frame:$index',
                  ));
              for (var index = 0; index < expectedStatuses.length; index++) {
                final row = wip(index);
                await tester.ensureVisible(row);
                await tester.pumpAndSettle();
                expect(
                  find.descendant(
                    of: row,
                    matching:
                        find.text(l10n.productionText(expectedStatuses[index])),
                  ),
                  findsOneWidget,
                );
                expect(tester.takeException(), isNull);
              }

              final group = find.byKey(
                const ValueKey('paddon-bobina-group-2000000'),
              );
              await tester.scrollUntilVisible(group, -500,
                  scrollable: find.byType(Scrollable).first);
              await tester.pumpAndSettle();
              expect(
                  find.descendant(
                      of: group, matching: find.text(l10n.productionCount(3))),
                  findsOneWidget);
              expect(find.byKey(const ValueKey('paddon-bobina-group-4000000')),
                  findsOneWidget);
              await tester.tap(group);
              await tester.pumpAndSettle();
              expect(find.byType(WorkerWipDetails), findsNWidgets(3));
              for (var index = 0; index < 6; index++) {
                expect(
                    wip(index), index.isEven ? findsOneWidget : findsNothing);
              }
              await tester.ensureVisible(wip(0));
              await tester.pumpAndSettle();
              expect(find.descendant(of: wip(0), matching: find.text('10 kg')),
                  findsOneWidget);
              expect(find.descendant(of: wip(0), matching: find.text('8 kg')),
                  findsOneWidget);
              expect(find.descendant(of: wip(0), matching: find.text('2 kg')),
                  findsOneWidget);
              await tester.longPress(wip(0));
              await tester.pumpAndSettle();
              final sheet = find.byType(RpsQrReprintSheet);
              expect(sheet, findsOneWidget);
              expect(find.descendant(of: sheet, matching: find.text('Anis')),
                  findsOneWidget);
              expect(find.descendant(of: sheet, matching: find.text('8 kg')),
                  findsOneWidget);
              await tester.tap(find.byIcon(Icons.close_rounded));
              await tester.pumpAndSettle();
              await tester.scrollUntilVisible(group, -500,
                  scrollable: find.byType(Scrollable).first);
              await tester.tap(group);
              await tester.pumpAndSettle();
              expect(find.byType(WorkerWipDetails), findsNWidgets(6));

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
                find.byKey(const ValueKey('admin-paddon-scan-again')),
                500,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.tap(find.byKey(
                const ValueKey('admin-paddon-scan-again'),
              ));
              await tester.pumpAndSettle();
              expect(
                find.byType(AparatchiPaddonDetailScreen),
                findsNothing,
              );
              expect(find.byIcon(Icons.keyboard_alt_outlined), findsOneWidget);
            },
            () => MockClient((request) async {
              expect(request.method, 'GET');
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
              if (request.url.path.endsWith('/order-image/view')) {
                return http.Response(
                    jsonEncode({'error': 'image_not_found'}), 404);
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
      'total_gross_kg': 75,
      'total_net_kg': 57,
      'locked_at_unix': 1700000000,
    },
    'can_unlock': true,
    'can_manage_items': true,
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
          'finished_goods_kg': 10 + index,
          'finished_goods_meter': 100 + index,
          'bobina_kg': index.isEven ? 2 : 4,
          'worker_display_name': 'Anis',
          'completed_at_unix': 1700000000,
          'payload_json': {
            'order_number': '0002',
            'order_title': index == 5 ? 'WIP' : 'Avella 120 sht',
          },
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
