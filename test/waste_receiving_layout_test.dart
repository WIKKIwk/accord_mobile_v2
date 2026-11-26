import 'dart:convert';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/widgets/lists/app_segment_surface_card.dart';
import 'package:accord_mobile_v2/src/core/widgets/navigation/app_navigation_bar.dart';
import 'package:accord_mobile_v2/src/core/widgets/navigation/role_dock.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/waste/presentation/waste_receiving_screen.dart';
import 'package:accord_mobile_v2/src/features/waste/presentation/waste_warehouses_screen.dart';
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
    AppSession.instance.token = 'waste-layout-token';
    AppSession.instance.profile = SessionProfile.fromJson({
      'role': 'chiqindi_qabulchi',
      'ref': 'waste-layout-worker',
      'display_name': 'Chiqindi qabul qiluvchi',
      'capabilities': ['waste.receive'],
    });
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('receiver uses the shared dock and a wide spaced form on a phone',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final paths = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const WasteReceivingScreen(),
        routes: {
          AppRoutes.wasteWarehouses: (_) => const WasteWarehousesScreen(),
        },
      ));
      await tester.pumpAndSettle();

      expect(find.byType(RoleDock), findsOneWidget);
      final navigation =
          tester.widget<AppNavigationBar>(find.byType(AppNavigationBar));
      expect(navigation.destinations.map((item) => item.label),
          ['Qabul', 'Omborlar', 'Profil', 'Chat']);

      final newBin = find.text('Yangi quti');
      final actionCard = find.ancestor(
          of: newBin, matching: find.byType(AppSegmentSurfaceCard));
      expect(tester.getSize(actionCard).width, greaterThan(365));
      await tester.tap(newBin);
      await tester.pumpAndSettle();

      final fields = [
        for (final label in [
          'Quti kodi',
          'Bo‘sh quti vazni (kg)',
          'Ruxsat etilgan farq (kg)',
        ])
          tester.getRect(find.widgetWithText(TextFormField, label)),
      ];
      expect(fields.first.width, greaterThanOrEqualTo(290));
      expect(fields[1].top - fields[0].bottom, greaterThanOrEqualTo(12));
      expect(fields[2].top - fields[1].bottom, greaterThanOrEqualTo(12));

      await tester.tap(find.text('Bekor qilish'));
      await tester.pumpAndSettle();
      navigation.onDestinationSelected(1);
      // RoleDock uses AppRootNavigation, which schedules the route after a frame.
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('G‘arbiy chiqindi ombori'), findsOneWidget);
      expect(find.text('18 kg'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              paths.add(request.url.path);
              final response = request.url.path == '/v1/mobile/waste/warehouses'
                  ? {
                      'warehouses': [
                        {
                          'id': 'warehouse-waste-west',
                          'warehouse': 'G‘arbiy chiqindi ombori',
                          'on_hand_kg': 18,
                          'receipt_count': 1,
                        },
                      ],
                    }
                  : {'bins': []};
              return http.Response(
                jsonEncode(response),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }));
    expect(paths, ['/v1/mobile/waste/bins', '/v1/mobile/waste/warehouses']);
  });
}
