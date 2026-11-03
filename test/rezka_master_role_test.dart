import 'dart:convert';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_worker_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rezka master enters the reused operator workspace and scoped settings',
      () {
    final session = AppSession.instance;
    session.token = 'master-token';
    session.profile = SessionProfile.fromJson({
      'role': 'rezka_master',
      'display_name': 'Rezka master',
      'ref': 'rezka_master_test',
      'capabilities': [
        'rezka.master.access',
        'apparatus.queue.read',
        'apparatus.queue.manage',
      ],
      'assigned_apparatus': ['apparatus:default:asset-010'],
    });
    addTearDown(() {
      session.token = null;
      session.profile = null;
    });

    expect(session.profile!.role, UserRole.rezkaMaster);
    expect(session.profile!.toJson()['role'], 'rezka_master');
    expect(session.homeRoute, AppRoutes.apparatusQueue);
    expect(session.canUseAdminComponents, isFalse);
    for (final route in [
      AppRoutes.apparatusQueue,
      AppRoutes.apparatusDailyWork,
      AppRoutes.apparatusPaddons,
      AppRoutes.apparatusPaddonDetail,
      AppRoutes.adminWorkerSettings,
      AppRoutes.adminAdditionalSettings,
    ]) {
      expect(AppRouter.canOpenRoute(route), isTrue, reason: route);
    }
    for (final route in [
      AppRoutes.adminHome,
      AppRoutes.adminUserCreate,
      AppRoutes.adminProductionMapTest,
      AppRoutes.adminWarehouses,
    ]) {
      expect(AppRouter.canOpenRoute(route), isFalse, reason: route);
    }
  });

  testWidgets('master can move or add cutting apparatus and cannot save none',
      (tester) async {
    const cut1 = 'apparatus:default:asset-010';
    const cut2 = 'apparatus:default:asset-011';
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    final session = AppSession.instance;
    session.token = 'master-token';
    session.profile = SessionProfile.fromJson({
      'role': 'rezka_master',
      'display_name': 'Rezka master',
      'ref': 'rezka_master_test',
      'capabilities': ['rezka.master.access', 'apparatus.queue.read'],
      'assigned_apparatus': [cut1, cut2],
    });
    addTearDown(() {
      session.token = null;
      session.profile = null;
    });
    List<String> assignment = [cut1];
    var saves = 0;
    var blockFirstMove = true;
    final client = MockClient((request) async {
      final path = request.url.path;
      final Object body;
      if (path == '/v1/mobile/admin/apparatus') {
        body = [
          for (final (id, name) in [(cut1, 'Rezka 1'), (cut2, 'Rezka 2')])
            {
              'apparatus_id': id,
              'display': {'display_name': name},
              'source_revision': 1,
              'source_aasx_sha256': 'a' * 64,
              'execution_profile': {
                'operation': 'cut',
                'technology': 'slitting'
              },
            },
        ];
      } else if (path == '/v1/mobile/rezka-master/workers' &&
          request.method == 'PUT') {
        final input = jsonDecode(request.body) as Map<String, dynamic>;
        expect(input['worker_id'], 'worker-ali');
        expect(input['previous_apparatus_ids'], assignment);
        if (blockFirstMove) {
          blockFirstMove = false;
          expect(input['apparatus_ids'], [cut2]);
          return http.Response(
            jsonEncode({
              'error': 'rezka_worker_has_open_run',
              'blocked_apparatus_ids': [cut1],
            }),
            409,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        assignment = List<String>.from(input['apparatus_ids'] as List);
        saves++;
        body = {'ok': true};
      } else if (path == '/v1/mobile/rezka-master/workers') {
        body = {
          'workers': [
            {'id': 'worker-bek', 'name': 'Bek', 'level': 'Master'},
            {'id': 'worker-ali', 'name': 'Ali', 'level': 'Master'},
          ],
          'assignments': [
            {
              'principal_role': 'aparatchi',
              'principal_ref': 'worker-ali',
              'role_id': 'aparatchi',
              'assigned_apparatus': assignment,
            },
          ],
        };
      } else {
        throw StateError('Unexpected ${request.method} $path');
      }
      return http.Response(jsonEncode(body), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('uz'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: AdminWorkerSettingsScreen(),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ali'));
      await tester.pumpAndSettle();
      final picker =
          find.byKey(const ValueKey('worker-apparatus-picker-worker-ali'));
      final save = find.byKey(const ValueKey('worker-apparatus-save'));
      await tester.tap(picker);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
            of: find.byType(BottomSheet), matching: find.text('Ali')),
        findsOneWidget,
      );
      expect(
        find.text('Kamida bitta rezka apparatini tanlang.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Rezka 1'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(saves, 0);
      expect(assignment, [cut1]);

      await tester.tap(find.widgetWithText(CheckboxListTile, 'Rezka 2'));
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Alining Rezka 1 bo‘yicha ochiq ishi bor. Avval ishni yakunlang yoki topshiring.',
        ),
        findsOneWidget,
      );
      expect(assignment, [cut1]);
      expect(saves, 0);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(assignment, [cut2]);
      expect(saves, 1);

      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Rezka 1'));
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(assignment, [cut1, cut2]);
      expect(saves, 2);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, () => client);
  });
}
