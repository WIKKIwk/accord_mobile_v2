import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/core/theme/theme_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_raw_material_rules_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'admin_raw_material_rules_screen_test_helpers_part_01.dart';
part 'admin_raw_material_rules_screen_test_declarations_part_02.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['admin.access', 'raw_material.rule.manage'],
    );
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('apparatus API uses canonical identity and draft payload', () async {
    final seenRequests = <String>[];

    await HttpOverrides.runZoned(() async {
      final apparatus = await MobileApi.instance.adminApparatus(query: 'pech');
      final created = await MobileApi.instance.adminCreateApparatus(
        'Bobst 1',
        family: 'pechat',
        kind: 'color_pechat',
      );

      expect(apparatus.map((item) => item.name), ['Pechat']);
      expect(apparatus.single.id, _apparatusId);
      expect(created.name, 'Bobst 1');
      expect(created.id, 'apparatus:accord:asset-bobst-001');
      final createBody = seenRequests.singleWhere(
        (request) => request.startsWith(
          'BODY POST /v1/mobile/admin/apparatus ',
        ),
      );
      expect(createBody, contains('"display":{"display_name":"Bobst 1"'));
      expect(createBody, contains('"operation":"print"'));
      expect(createBody, contains('"technology":"rotogravure"'));
      expect(createBody, isNot(contains('"name":"Bobst 1"')));
    }, createHttpClient: (_) => _RawMaterialRulesHttpClient(seenRequests));
  });

  testWidgets('group save preserves optional canonical material policy', (
    tester,
  ) async {
    final seenRequests = <String>[];

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(AppThemeVariant.kalmar),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminRawMaterialRulesScreen(
            initialTab: AdminRawMaterialSettingsTab.rules,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Saqlash'));
      await tester.pumpAndSettle();

      expect(
        seenRequests,
        contains(
          'BODY PUT /v1/mobile/admin/raw-material-rules '
          '{"apparatus_id":"$_apparatusId","expected_revision":7,'
          '"material":{"mode":"not_required",'
          '"item_group_ids":["Kraska"]},'
          '"tooling":{"mode":"not_required"}}',
        ),
      );
      await tester.pump(const Duration(seconds: 2));
    },
        createHttpClient: (_) => _RawMaterialRulesHttpClient(
              seenRequests,
              initialRules: const [
                {
                  'apparatus_id': _apparatusId,
                  'source_revision': 7,
                  'source_aasx_sha256': _aasxSha256,
                  'policy': {
                    'mode': 'not_required',
                    'item_group_ids': ['Kraska'],
                  },
                  'tooling': {'mode': 'not_required'},
                },
              ],
            ));
  });

  test('apparatus create reuses one idempotency key and draft on auth retry',
      () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{
      'last_login_phone': '+998901112233',
      'last_login_code': '70ABCDEF1234',
    });
    final seenRequests = <String>[];
    final client = _RawMaterialRulesHttpClient(
      seenRequests,
      unauthorizedApparatusCreates: 1,
    );

    await HttpOverrides.runZoned(() async {
      await MobileApi.instance.adminCreateApparatus(
        'Bobst retry',
        family: 'pechat',
        kind: 'color_pechat',
      );
    }, createHttpClient: (_) => client);

    final createHeaders = seenRequests
        .where(
          (request) => request.startsWith(
            'HEADERS POST /v1/mobile/admin/apparatus ',
          ),
        )
        .toList(growable: false);
    expect(createHeaders, hasLength(2));
    final idempotencyKeys = createHeaders
        .map((entry) => entry.split('idempotency-key=').last)
        .toList(growable: false);
    expect(idempotencyKeys.toSet(), hasLength(1));
    final idempotencyKey = idempotencyKeys.first;
    expect(
      idempotencyKey,
      matches(
        RegExp(r'^mobile:canonical-apparatus:create:[A-Za-z0-9-]+$'),
      ),
    );
    expect(idempotencyKey.length, lessThanOrEqualTo(128));

    final createBodies = seenRequests
        .where(
          (request) => request.startsWith(
            'BODY POST /v1/mobile/admin/apparatus ',
          ),
        )
        .toList(growable: false);
    expect(createBodies, hasLength(2));
    expect(createBodies.toSet(), hasLength(1));
  });

  test('canonical apparatus patch sends an idempotency key', () async {
    final seenRequests = <String>[];

    await HttpOverrides.runZoned(() async {
      await MobileApi.instance.adminPatchCanonicalApparatus(
        apparatus: AdminApparatus.fromJson(
          (_committedApparatus(
            apparatusId: _apparatusId,
            displayName: 'Pechat',
            revision: 7,
            material: const {'mode': 'not_required'},
          )['runtime_projection'] as Map<Object?, Object?>)
              .cast<String, dynamic>(),
        ),
        patch: const {
          'display': {
            'display_name': 'Pechat yangi',
            'description': '',
            'catalog_order': 5,
          },
        },
      );
    }, createHttpClient: (_) => _RawMaterialRulesHttpClient(seenRequests));

    final patchHeader = seenRequests.singleWhere(
      (request) => request.startsWith(
        'HEADERS PATCH /v1/mobile/admin/apparatus/',
      ),
    );
    final idempotencyKey = patchHeader.split('idempotency-key=').last;
    expect(
      idempotencyKey,
      matches(RegExp(r'^mobile:canonical-apparatus:patch:[A-Za-z0-9-]+$')),
    );
    expect(idempotencyKey.length, lessThanOrEqualTo(128));
  });

  test('canonical queue policy write sends an idempotency key', () async {
    final seenRequests = <String>[];

    await HttpOverrides.runZoned(() async {
      await MobileApi.instance.adminUpdateApparatusQueuePolicy(
        apparatusId: _apparatusId,
        expectedRevision: 7,
        policy: ApparatusQueuePolicy.freePick,
      );
    }, createHttpClient: (_) => _RawMaterialRulesHttpClient(seenRequests));

    final header = seenRequests.singleWhere(
      (request) => request.startsWith(
        'HEADERS PUT /v1/mobile/admin/production-maps/queue-policies ',
      ),
    );
    expect(
      header.split('idempotency-key=').last,
      matches(
        RegExp(r'^mobile:canonical-apparatus:queue-policy:[A-Za-z0-9-]+$'),
      ),
    );
  });

  test('canonical capacity write sends an idempotency key', () async {
    final seenRequests = <String>[];

    await HttpOverrides.runZoned(() async {
      await MobileApi.instance.adminSaveApparatusCapacityProfile(
        const AdminApparatusCapacityProfile(
          apparatusId: _apparatusId,
          apparatus: 'Pechat',
          sourceRevision: 7,
          capacitySlots: 2,
        ),
      );
    }, createHttpClient: (_) => _RawMaterialRulesHttpClient(seenRequests));

    final header = seenRequests.singleWhere(
      (request) => request.startsWith(
        'HEADERS PUT /v1/mobile/admin/production-maps/capacity ',
      ),
    );
    expect(
      header.split('idempotency-key=').last,
      matches(
        RegExp(r'^mobile:canonical-apparatus:capacity:[A-Za-z0-9-]+$'),
      ),
    );
  });

  testWidgets('raw material group field lists homashyo child groups', (
    tester,
  ) async {
    final seenRequests = <String>[];

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(AppThemeVariant.kalmar),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminRawMaterialRulesScreen(
            initialTab: AdminRawMaterialSettingsTab.rules,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(seenRequests, contains('GET /v1/mobile/admin/item-groups/tree'));

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('raw-material-group-checkbox-Kraska')),
        findsOneWidget,
      );
      expect(find.text('Tayyor mahsulot'), findsNothing);
    }, createHttpClient: (_) => _RawMaterialRulesHttpClient(seenRequests));
  });

  testWidgets('raw material group picker saves alternative requirement groups',
      (
    tester,
  ) async {
    final seenRequests = <String>[];

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(AppThemeVariant.kalmar),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminRawMaterialRulesScreen(
            initialTab: AdminRawMaterialSettingsTab.rules,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('State’dagi barcha homashyolar').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Har bir guruhdan minimum').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const Key('raw-material-group-checkbox-Kley')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('raw-material-group-expand-Kley')));
      await tester.pumpAndSettle();
      expect(find.text('Alternativlar'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('raw-material-alternative-checkbox-Kley-Kraska')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tanlash'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saqlash'));
      await tester.pumpAndSettle();

      expect(
        seenRequests,
        contains(
          'BODY PUT /v1/mobile/admin/raw-material-rules '
          '{"apparatus_id":"$_apparatusId","expected_revision":7,'
          '"material":{"mode":"requirement_sets","sets":['
          '{"requirement_id":"Kley","item_group_ids":["Kley","Kraska"],'
          '"minimum_required_count":1},'
          '{"requirement_id":"Kraska","item_group_ids":["Kraska"],'
          '"minimum_required_count":1}]},"tooling":{"mode":"not_required"}}',
        ),
      );
      final materialHeader = seenRequests.singleWhere(
        (request) => request.startsWith(
          'HEADERS PUT /v1/mobile/admin/raw-material-rules ',
        ),
      );
      expect(
        materialHeader.split('idempotency-key=').last,
        matches(
          RegExp(
            r'^mobile:canonical-apparatus:material-policy:[A-Za-z0-9-]+$',
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
    },
        createHttpClient: (_) => _RawMaterialRulesHttpClient(
              seenRequests,
              initialRules: const [
                {
                  'apparatus_id': _apparatusId,
                  'source_revision': 7,
                  'source_aasx_sha256': _aasxSha256,
                  'policy': {
                    'mode': 'all_required',
                    'item_group_ids': ['Kraska'],
                  },
                  'tooling': {'mode': 'not_required'},
                },
              ],
            ));
  });

  testWidgets('raw material group picker keeps only one expanded card open', (
    tester,
  ) async {
    final seenRequests = <String>[];

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(AppThemeVariant.kalmar),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminRawMaterialRulesScreen(
            initialTab: AdminRawMaterialSettingsTab.rules,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('raw-material-group-expand-Kley')));
      await tester.pumpAndSettle();
      expect(
          find.byKey(
              const Key('raw-material-alternative-checkbox-Kley-Kraska')),
          findsOneWidget);

      await tester
          .tap(find.byKey(const Key('raw-material-group-expand-Kraska')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('raw-material-alternative-checkbox-Kley-Kraska')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('raw-material-alternative-checkbox-Kraska-Kley')),
        findsOneWidget,
      );
    }, createHttpClient: (_) => _RawMaterialRulesHttpClient(seenRequests));
  });

  testWidgets('required switch does not fake success when backend ignores flag',
      (
    tester,
  ) async {
    final seenRequests = <String>[];

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(AppThemeVariant.kalmar),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminRawMaterialRulesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Majburiylik').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(find.text('Backend majburiylikni saqlamadi'), findsOneWidget);
      expect(find.text('Majburiylik saqlandi'), findsNothing);
      expect(
        seenRequests,
        contains(
          'BODY PUT /v1/mobile/admin/raw-material-rules '
          '{"apparatus_id":"$_apparatusId","expected_revision":7,'
          '"material":{"mode":"not_required",'
          '"item_group_ids":["Kraska"]},'
          '"tooling":{"mode":"not_required"}}',
        ),
      );
      await tester.pump(const Duration(seconds: 2));
    },
        createHttpClient: (_) => _RawMaterialRulesHttpClient(
              seenRequests,
              initialRules: const [
                {
                  'apparatus_id': _apparatusId,
                  'source_revision': 7,
                  'source_aasx_sha256': _aasxSha256,
                  'policy': {
                    'mode': 'all_required',
                    'item_group_ids': ['Kraska'],
                  },
                  'tooling': {'mode': 'not_required'},
                },
              ],
              ignoreMaterialWrite: true,
            ));
  });
}

const _apparatusId = 'apparatus:default:asset-005';
const _aasxSha256 =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
