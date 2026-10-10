import 'dart:convert';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_retry_state.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_additional_settings_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

SessionProfile _profile(UserRole role) => SessionProfile(
    role: role,
    displayName: 'User',
    legalName: '',
    ref: 'user',
    phone: '',
    avatarUrl: '',
    capabilities: const ['admin.access']);

Widget _app() => const MaterialApp(
    locale: Locale('uz'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate
    ],
    home: AdminAdditionalSettingsScreen());

void main() {
  late bool enabled;
  late bool workerVisibility;
  late bool failWrite;
  late int writes;
  late MockClient client;
  setUp(() {
    AppSession.instance.token = 'token';
    AppSession.instance.profile = _profile(UserRole.admin);
    enabled = false;
    workerVisibility = false;
    failWrite = false;
    writes = 0;
    client = MockClient((request) async {
      expect(request.url.path.endsWith('/paddons/management-settings'), isTrue);
      expect(request.headers['Authorization'], 'Bearer token');
      if (request.method == 'PUT') {
        writes++;
        if (failWrite) return http.Response('{"error":"store_failed"}', 500);
        final input = jsonDecode(request.body) as Map;
        if (input.containsKey('free_movement_enabled')) {
          enabled = input['free_movement_enabled'] as bool;
        }
        if (input.containsKey('worker_visibility_enabled')) {
          workerVisibility = input['worker_visibility_enabled'] as bool;
        }
      }
      return http.Response(
          jsonEncode({
            'ok': true,
            'settings': {
              'free_movement_enabled': enabled,
              'worker_visibility_enabled': workerVisibility,
            }
          }),
          200);
    });
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test(
      'additional settings route requires the admin role even with admin capability',
      () {
    expect(AppRouter.canOpenRoute(AppRoutes.adminAdditionalSettings), isTrue);
    AppSession.instance.profile = _profile(UserRole.aparatchi);
    expect(AppRouter.canOpenRoute(AppRoutes.adminAdditionalSettings), isFalse);
  });

  testWidgets('admin confirms enable and can disable the shared server setting',
      (tester) async {
    workerVisibility = true;
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Qo‘shimcha sozlamalar'), findsWidgets);
      expect(
          tester
              .widget<SwitchListTile>(
                  find.byKey(const ValueKey('paddon-free-movement-switch')))
              .value,
          isFalse);
      await tester
          .tap(find.byKey(const ValueKey('paddon-free-movement-switch')));
      await tester.pumpAndSettle();
      expect(writes, 0);
      await tester
          .tap(find.byKey(const ValueKey('paddon-free-movement-confirm')));
      await tester.pumpAndSettle();
      expect(enabled, isTrue);
      expect(
          tester
              .widget<SwitchListTile>(
                  find.byKey(const ValueKey('paddon-free-movement-switch')))
              .value,
          isTrue);
      await tester
          .tap(find.byKey(const ValueKey('paddon-free-movement-switch')));
      await tester.pumpAndSettle();
      expect(enabled, isFalse);
      expect(writes, 2);
      expect(workerVisibility, isTrue);
    }, () => client);
  });

  testWidgets('cancelling leaves the mode disabled', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('paddon-free-movement-switch')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('paddon-free-movement-cancel')));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(enabled, isFalse);
    }, () => client);
  });

  testWidgets('admin can enable and disable worker visibility independently',
      (tester) async {
    enabled = true;
    const key = ValueKey('paddon-worker-visibility-switch');
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(find.byKey(key)).value, isFalse);
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      expect(workerVisibility, isTrue);
      expect(enabled, isTrue);
      expect(tester.widget<SwitchListTile>(find.byKey(key)).value, isTrue);
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      expect(workerVisibility, isFalse);
      expect(enabled, isTrue);
      expect(writes, 2);
      expect(tester.widget<SwitchListTile>(find.byKey(key)).value, isFalse);
    }, () => client);
  });

  testWidgets('failed visibility save restores the server setting',
      (tester) async {
    workerVisibility = true;
    failWrite = true;
    const key = ValueKey('paddon-worker-visibility-switch');
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      expect(workerVisibility, isTrue);
      expect(tester.widget<SwitchListTile>(find.byKey(key)).value, isTrue);
      expect(find.text('Sozlama saqlanmadi. Qayta urinib ko‘ring.'),
          findsOneWidget);
    }, () => client);
  });

  testWidgets('worker with admin capability cannot access either setting',
      (tester) async {
    AppSession.instance.profile = _profile(UserRole.aparatchi);
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsNothing);
      expect(writes, 0);
    }, () => MockClient((_) async =>
        throw StateError('worker must not load admin settings')));
  });

  testWidgets('failed save keeps the authoritative server value',
      (tester) async {
    enabled = true;
    failWrite = true;
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('paddon-free-movement-switch')));
      await tester.pumpAndSettle();
      expect(enabled, isTrue);
      expect(
          tester
              .widget<SwitchListTile>(
                  find.byKey(const ValueKey('paddon-free-movement-switch')))
              .value,
          isTrue);
      expect(find.text('Sozlama saqlanmadi. Qayta urinib ko‘ring.'),
          findsOneWidget);
    }, () => client);
  });

  testWidgets('failed load exposes retry and no usable switch', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byType(AppRetryState), findsOneWidget);
      expect(find.byKey(const ValueKey('paddon-free-movement-switch')),
          findsNothing);
    }, () => MockClient((_) async => http.Response('{}', 503)));
  });

  test('paddon snapshot permits printed edits only with server permission', () {
    final data = {
      'paddon': {'id': 'p', 'code': '00001', 'locked_at_unix': 1},
      'items': <Object>[],
      'free_movement_enabled': true,
      'can_manage_items': true
    };
    expect(AdminPaddonSnapshot.fromJson(data).canManageItems, isTrue);
    data['can_manage_items'] = false;
    expect(AdminPaddonSnapshot.fromJson(data).canManageItems, isFalse);
    data.remove('can_manage_items');
    expect(AdminPaddonSnapshot.fromJson(data).canManageItems, isFalse);
  });
}
