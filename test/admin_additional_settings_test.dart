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
  late bool mandatoryUpdates;
  late bool failUpdateRead;
  late int updateWrites;
  late bool laminationRequired;
  late int laminationWrites;
  late bool automaticQolips;
  late int qolipRevision;
  late int qolipWrites;
  late bool failQolipRead;
  late MockClient client;
  setUp(() {
    AppSession.instance.token = 'token';
    AppSession.instance.profile = _profile(UserRole.admin);
    enabled = false;
    workerVisibility = false;
    failWrite = false;
    writes = 0;
    mandatoryUpdates = false;
    failUpdateRead = false;
    updateWrites = 0;
    laminationRequired = true;
    laminationWrites = 0;
    automaticQolips = false;
    qolipRevision = 0;
    qolipWrites = 0;
    failQolipRead = false;
    client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer token');
      if (request.url.path.endsWith('/qolip-start-settings')) {
        if (request.method == 'PUT') {
          qolipWrites++;
          if (failWrite) return http.Response('{}', 500);
          automaticQolips = (jsonDecode(request.body)
              as Map)['automatic_confirmation_enabled'] as bool;
          qolipRevision++;
        } else if (failQolipRead) {
          return http.Response('{}', 503);
        }
        return http.Response(
            jsonEncode({
              'ok': true,
              'settings': {
                'automatic_confirmation_enabled': automaticQolips,
                'revision': qolipRevision,
              }
            }),
            200);
      }
      if (request.url.path.endsWith('/lamination-settings')) {
        if (request.method == 'PUT') {
          laminationWrites++;
          if (failWrite) return http.Response('{}', 500);
          laminationRequired = (jsonDecode(request.body)
              as Map)['layer_remainders_required'] as bool;
        }
        return http.Response(
            jsonEncode({
              'ok': true,
              'settings': {'layer_remainders_required': laminationRequired},
            }),
            200);
      }
      if (request.url.path.endsWith('/app-update/settings')) {
        if (request.method == 'PUT') {
          updateWrites++;
          if (failWrite) return http.Response('{}', 500);
          mandatoryUpdates = (jsonDecode(request.body)
              as Map)['mandatory_updates_enabled'] as bool;
        } else if (failUpdateRead) {
          return http.Response('{}', 503);
        }
        return http.Response(
            jsonEncode({
              'ok': true,
              'settings': {'mandatory_updates_enabled': mandatoryUpdates},
            }),
            200);
      }
      expect(request.url.path.endsWith('/paddons/management-settings'), isTrue);
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

  testWidgets('brigader can save every existing additional settings card', (tester) async {
    AppSession.instance.profile = SessionProfile.fromJson({
      'role': 'brigader', 'ref': 'brigader_test',
      'capabilities': ['brigader.access'],
    });
    expect(AppRouter.canOpenRoute(AppRoutes.adminAdditionalSettings), isTrue);
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      for (final key in [
        'mandatory-app-update-switch',
        'paddon-worker-visibility-switch',
        'lamination-layer-remainders-switch',
        'qolip-automatic-confirmation-switch',
      ]) {
        final finder = find.byKey(ValueKey(key));
        await tester.scrollUntilVisible(finder, 180);
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(finder).onChanged, isNotNull);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }
      expect(mandatoryUpdates, isTrue);
      expect(workerVisibility, isTrue);
      expect(laminationRequired, isFalse);
      expect(automaticQolips, isTrue);
      expect(updateWrites, 1);
      expect(writes, 1);
      expect(laminationWrites, 1);
      expect(qolipWrites, 1);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('paddon-free-movement-switch')), -180);
      await tester.ensureVisible(find.byKey(const ValueKey('paddon-free-movement-switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('paddon-free-movement-switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('paddon-free-movement-confirm')));
      await tester.pumpAndSettle();
      expect(enabled, isTrue);
      expect(writes, 2);
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets(
      'automatic mold confirmation defaults off and persists independently',
      (tester) async {
    const key = ValueKey('qolip-automatic-confirmation-switch');
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(key), 200);
      expect(tester.widget<SwitchListTile>(find.byKey(key)).value, isFalse);
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      expect(automaticQolips, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(key), 200);
      expect(tester.widget<SwitchListTile>(find.byKey(key)).value, isTrue);
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      expect(automaticQolips, isFalse);
      expect(qolipWrites, 2);
      expect(writes, 0);
      expect(updateWrites, 0);
      expect(laminationWrites, 0);
    }, () => client);
  });

  testWidgets('automatic mold setting failed save retains the server value',
      (tester) async {
    automaticQolips = true;
    failWrite = true;
    const key = ValueKey('qolip-automatic-confirmation-switch');
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(key), 200);
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      expect(automaticQolips, isTrue);
      expect(tester.widget<SwitchListTile>(find.byKey(key)).value, isTrue);
      expect(
          find.text(
              'Qolipni tasdiqlash sozlamasi saqlanmadi. Qayta urinib ko‘ring.'),
          findsOneWidget);
    }, () => client);
  });

  testWidgets(
      'automatic mold setting cannot be enabled before a successful read',
      (tester) async {
    failQolipRead = true;
    const key = ValueKey('qolip-automatic-confirmation-switch');
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(key), 200);
      expect(tester.widget<SwitchListTile>(find.byKey(key)).value, isFalse);
      expect(tester.widget<SwitchListTile>(find.byKey(key)).onChanged, isNull);
      failQolipRead = false;
      automaticQolips = true;
      final retry = find.descendant(
          of: find
              .ancestor(of: find.byKey(key), matching: find.byType(Card))
              .first,
          matching: find.byType(TextButton));
      await Scrollable.ensureVisible(tester.element(retry), alignment: 0.25);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(find.byKey(key)).value, isTrue);
      expect(
          tester.widget<SwitchListTile>(find.byKey(key)).onChanged, isNotNull);
      expect(qolipWrites, 0);
    }, () => client);
  });

  testWidgets('admin can persist and disable mandatory updates independently',
      (tester) async {
    enabled = true;
    workerVisibility = true;
    const key = ValueKey('mandatory-app-update-switch');
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Majburiy yangilash'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byKey(key)).value, isFalse);
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      expect(mandatoryUpdates, isTrue);
      expect(tester.widget<SwitchListTile>(find.byKey(key)).value, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(find.byKey(key)).value, isTrue);
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      expect(mandatoryUpdates, isFalse);
      expect(tester.widget<SwitchListTile>(find.byKey(key)).value, isFalse);
      expect(updateWrites, 2);
      expect(writes, 0);
      expect(enabled, isTrue);
      expect(workerVisibility, isTrue);
    }, () => client);
  });

  testWidgets('failed mandatory update save retains the server value',
      (tester) async {
    mandatoryUpdates = true;
    failWrite = true;
    const key = ValueKey('mandatory-app-update-switch');
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      expect(mandatoryUpdates, isTrue);
      expect(tester.widget<SwitchListTile>(find.byKey(key)).value, isTrue);
      expect(find.text('Yangilash sozlamasi saqlanmadi. Qayta urinib ko‘ring.'),
          findsOneWidget);
    }, () => client);
  });

  testWidgets(
      'lamination QR requirement persists independently of other settings',
      (tester) async {
    const key = ValueKey('lamination-layer-remainders-switch');
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(key), 200);
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Laminatsiyachi ikki qatlamdan birini kiritish majburiyati'),
          findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byKey(key)).value, isTrue);
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      expect(laminationRequired, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(key), 200);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(find.byKey(key)).value, isFalse);
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      expect(laminationRequired, isTrue);
      expect(laminationWrites, 2);
      expect(writes, 0);
      expect(updateWrites, 0);
    }, () => client);
  });

  testWidgets('failed lamination save keeps the server requirement enabled',
      (tester) async {
    failWrite = true;
    const key = ValueKey('lamination-layer-remainders-switch');
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(key), 200);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      expect(laminationRequired, isTrue);
      expect(tester.widget<SwitchListTile>(find.byKey(key)).value, isTrue);
      expect(
          find.text('Laminatsiya sozlamasi saqlanmadi. Qayta urinib ko‘ring.'),
          findsOneWidget);
    }, () => client);
  });

  testWidgets('failed mandatory setting load disables the switch and can retry',
      (tester) async {
    failUpdateRead = true;
    mandatoryUpdates = true;
    const key = ValueKey('mandatory-app-update-switch');
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(find.byKey(key)).onChanged, isNull);
      failUpdateRead = false;
      await tester.tap(find.text('Qayta urinish'));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(find.byKey(key)).value, isTrue);
      expect(
          tester.widget<SwitchListTile>(find.byKey(key)).onChanged, isNotNull);
      expect(updateWrites, 0);
    }, () => client);
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
    },
        () => MockClient((_) async =>
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
