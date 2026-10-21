import 'dart:async';
import 'dart:convert';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/raw_material_scan_dialog.dart';
import 'package:accord_mobile_v2/src/features/material_link/presentation/worker_material_use_panel.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(ValueChanged<String> onUsed) => MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      home: Scaffold(
          body: WorkerMaterialUsePanel(
              orderId: 'zakaz-1',
              apparatusId: 'apparatus:test:print',
              onMaterialsUsed: onUsed)),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'worker-token';
    AppSession.instance.profile = const SessionProfile(
        role: UserRole.aparatchi,
        ref: 'worker',
        displayName: 'Worker',
        legalName: '',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.manage']);
  });

  for (final enabled in [false, true]) {
    testWidgets('no button without eligible material, permission=$enabled',
        (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(app((_) {}));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('worker-material-use-button')),
            findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
          () => MockClient((_) async => http.Response(
              jsonEncode({
                'enabled': enabled,
                'candidates': [
                  if (!enabled) {'barcode': 'R1', 'placement_version': 1}
                ]
              }),
              200)));
    }, variant: const TargetPlatformVariant({TargetPlatform.linux}));
  }

  for (final scenario in ['confirm', 'cancel', 'wrong', 'changed']) {
    testWidgets('precomputed material scan: $scenario', (tester) async {
      var posts = 0;
      var available = true;
      final used = <String>[];
      await http.runWithClient(() async {
        await tester.pumpWidget(app(used.add));
        await tester.pumpAndSettle();
        await tester
            .tap(find.byKey(const ValueKey('worker-material-use-button')));
        await tester.pumpAndSettle();
        final scanner = tester.widget<ProductionQuickScannerPanel>(
            find.byType(ProductionQuickScannerPanel));
        unawaited(scanner.onCodeDetected(scenario == 'wrong' ? 'OTHER' : 'R1'));
        await tester.pumpAndSettle();
        final feedback = tester
            .widget<ProductionQuickScannerPanel>(
                find.byType(ProductionQuickScannerPanel))
            .feedback;
        expect(
            feedback,
            scenario == 'wrong'
                ? ProductionQuickScanFeedback.rejected
                : ProductionQuickScanFeedback.accepted);
        expect(posts, 0);
        if (scenario == 'wrong') {
          expect(find.byKey(const ValueKey('worker-material-use-confirm')),
              findsNothing);
        } else {
          expect(
              find.text('Ushbu xomashyoni buyurtma uchun sarflamoqchimisiz?'),
              findsOneWidget);
          await tester.tap(scenario == 'cancel'
              ? find.text('Yo‘q')
              : find.byKey(const ValueKey('worker-material-use-confirm')));
          await tester.pumpAndSettle();
          expect(posts, scenario == 'cancel' ? 0 : 1);
          expect(used, scenario == 'confirm' ? ['R1'] : isEmpty);
          if (scenario == 'confirm') {
            expect(find.byKey(const ValueKey('worker-material-use-button')),
                findsNothing);
          }
          if (scenario == 'changed') {
            expect(
                tester
                    .widget<ProductionQuickScannerPanel>(
                        find.byType(ProductionQuickScannerPanel))
                    .feedback,
                ProductionQuickScanFeedback.rejected);
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
          () => MockClient((request) async {
                expect(request.headers['authorization'], 'Bearer worker-token');
                if (request.method == 'POST') {
                  posts++;
                  expect(jsonDecode(request.body), {
                    'order_id': 'zakaz-1',
                    'apparatus': 'apparatus:test:print',
                    'barcode': 'R1',
                    'placement_version': 7
                  });
                  if (scenario == 'changed') {
                    return http.Response(
                        '{"error":"raw_material_stock_unavailable"}', 409);
                  }
                  available = false;
                  return http.Response(
                      '{"ok":true,"barcode":"R1","in_use":true}', 200);
                }
                expect(request.url.queryParameters['order_id'], 'zakaz-1');
                return http.Response(
                    jsonEncode({
                      'enabled': true,
                      'candidates': [
                        if (available)
                          {
                            'barcode': 'R1',
                            'item_name': 'PET 1000/12',
                            'placement_version': 7
                          },
                      ]
                    }),
                    200);
              }));
    }, variant: const TargetPlatformVariant({TargetPlatform.linux}));
  }
  testWidgets(
      'switching accounts while confirmation is open cannot use old material',
      (tester) async {
    var posts = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(
          app((_) => fail('old account material must not be used')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('worker-material-use-button')));
      await tester.pumpAndSettle();
      unawaited(tester
          .widget<ProductionQuickScannerPanel>(
              find.byType(ProductionQuickScannerPanel))
          .onCodeDetected('R1'));
      await tester.pumpAndSettle();
      AppSession.instance.token = 'other-token';
      AppSession.instance.profile = const SessionProfile(
          role: UserRole.aparatchi,
          ref: 'other',
          displayName: 'Other',
          legalName: '',
          phone: '',
          avatarUrl: '',
          capabilities: ['apparatus.queue.manage']);
      AppSession.instance.revision.value++;
      await tester.pump();
      await tester
          .tap(find.byKey(const ValueKey('worker-material-use-confirm')));
      await tester.pumpAndSettle();
      expect(posts, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              if (request.method == 'POST') posts++;
              return http.Response(
                  jsonEncode({
                    'enabled': true,
                    'candidates': [
                      {'barcode': 'R1', 'placement_version': 1}
                    ]
                  }),
                  200);
            }));
  }, variant: const TargetPlatformVariant({TargetPlatform.linux}));
}
