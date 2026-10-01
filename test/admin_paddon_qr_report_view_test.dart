import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_progress_qr_scan_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
        await tester.pumpWidget(MaterialApp(
          locale: const Locale('uz'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: const AdminProgressQrScanScreen(),
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
}
