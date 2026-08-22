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

Map<String, Object?> _committedApparatus({
  required String apparatusId,
  required String displayName,
  required int revision,
  required Map<String, Object> material,
  String queue = 'strict_sequence',
  Map<String, Object>? capacity,
}) {
  final display = <String, Object>{
    'display_name': displayName,
    'description': '',
    'catalog_order': 5,
  };
  return {
    'revision': {
      'apparatus_id': apparatusId,
      'display': display,
      'policies': {
        'queue': queue,
        'material': material,
        'tooling': {'mode': 'not_required'},
      },
      if (capacity != null) 'capacity': capacity,
      'revision_metadata': {'revision': revision},
    },
    'runtime_projection': {
      'apparatus_id': apparatusId,
      'source_revision': revision,
      'source_aasx_sha256': _aasxSha256,
      'display': display,
      'equipment_class_id': 'equipment-class:accord:print',
      'physical_asset_id': 'physical-asset:accord:pechat-005',
      'hierarchy': {
        'enterprise_id': 'enterprise:accord',
        'site_id': 'site:main',
        'area_id': 'area:production',
        'work_center_id': 'work-center:print',
        'work_unit_id': 'work-unit:pechat-005',
      },
      'capabilities': {'print': 1},
      'execution_profile': {
        'operation': 'print',
        'technology': 'rotogravure',
        'color_station_count': 8,
        'virtual_tasks': 'disabled',
        'capability_compatible_reroute': true,
      },
      'placement': null,
      'training': {
        'enabled': false,
        'queue_enabled': false,
        'material_tracking_enabled': false,
      },
      'lifecycle': {'state': 'active'},
    },
    'aasx_sha256': _aasxSha256,
  };
}

class _RawMaterialRulesHttpClient implements HttpClient {
  _RawMaterialRulesHttpClient(
    this.seenRequests, {
    this.initialRules = const [
      {
        'apparatus_id': _apparatusId,
        'source_revision': 7,
        'source_aasx_sha256': _aasxSha256,
        'policy': {
          'mode': 'not_required',
        },
        'tooling': {'mode': 'not_required'},
      },
    ],
    this.ignoreMaterialWrite = false,
    this.unauthorizedApparatusCreates = 0,
  });

  final List<String> seenRequests;
  final List<Map<String, Object>> initialRules;
  final bool ignoreMaterialWrite;
  int unauthorizedApparatusCreates;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final key = '$method ${url.path}';
    seenRequests.add(key);

    Object body;
    var statusCode = HttpStatus.ok;
    switch (key) {
      case 'POST /v1/mobile/auth/login':
        body = const {
          'token': 'refreshed-token',
          'profile': {
            'role': 'admin',
            'display_name': 'Admin',
            'legal_name': 'Admin',
            'ref': 'admin',
            'phone': '+998901112233',
            'avatar_url': '',
          },
          'capabilities': ['admin.access', 'production_map.manage'],
          'assigned_apparatus': <Object>[],
          'assigned_item_groups': <Object>[],
          'assigned_warehouses': <Object>[],
        };
      case 'GET /v1/mobile/admin/apparatus':
        body = const [
          {
            'apparatus_id': _apparatusId,
            'source_revision': 7,
            'source_aasx_sha256': _aasxSha256,
            'display': {
              'display_name': 'Pechat',
              'description': '',
              'catalog_order': 5,
            },
            'equipment_class_id': 'equipment-class:accord:print',
            'physical_asset_id': 'physical-asset:accord:pechat-005',
            'hierarchy': {
              'enterprise_id': 'enterprise:accord',
              'site_id': 'site:main',
              'area_id': 'area:production',
              'work_center_id': 'work-center:print',
              'work_unit_id': 'work-unit:pechat-005',
            },
            'capabilities': {'print': 1},
            'execution_profile': {
              'operation': 'print',
              'technology': 'rotogravure',
              'color_station_count': 8,
              'virtual_tasks': 'disabled',
              'capability_compatible_reroute': true,
            },
            'placement': null,
            'training': {
              'enabled': false,
              'queue_enabled': false,
              'material_tracking_enabled': false,
            },
            'lifecycle': {'state': 'active'},
          },
        ];
      case 'POST /v1/mobile/admin/apparatus':
        if (unauthorizedApparatusCreates > 0) {
          unauthorizedApparatusCreates--;
          statusCode = HttpStatus.unauthorized;
          body = const {'error': 'unauthorized'};
        } else {
          body = _committedApparatus(
            apparatusId: 'apparatus:accord:asset-bobst-001',
            displayName: 'Bobst 1',
            revision: 1,
            material: const {'mode': 'not_required'},
          );
        }
      case final value
          when value.startsWith('PATCH /v1/mobile/admin/apparatus/'):
        body = _committedApparatus(
          apparatusId: _apparatusId,
          displayName: 'Pechat yangi',
          revision: 8,
          material: const {'mode': 'not_required'},
        );
      case 'GET /v1/mobile/admin/raw-material-rules':
        body = initialRules;
      case 'PUT /v1/mobile/admin/raw-material-rules':
        body = _committedApparatus(
          apparatusId: _apparatusId,
          displayName: 'Pechat',
          revision: 8,
          material: ignoreMaterialWrite
              ? const {
                  'mode': 'all_required',
                  'item_group_ids': ['Kraska'],
                }
              : const {
                  'mode': 'requirement_sets',
                  'sets': [
                    {
                      'requirement_id': 'Kley',
                      'item_group_ids': ['Kley', 'Kraska'],
                      'minimum_required_count': 1,
                    },
                  ],
                },
        );
      case 'PUT /v1/mobile/admin/production-maps/queue-policies':
        body = {
          'ok': true,
          'revision': _committedApparatus(
            apparatusId: _apparatusId,
            displayName: 'Pechat',
            revision: 8,
            material: const {'mode': 'not_required'},
            queue: 'free_pick',
          ),
        };
      case 'PUT /v1/mobile/admin/production-maps/capacity':
        body = {
          'ok': true,
          'revision': _committedApparatus(
            apparatusId: _apparatusId,
            displayName: 'Pechat',
            revision: 8,
            material: const {'mode': 'not_required'},
            capacity: const {
              'capacity_slots': 2,
              'setup_minutes': 0,
              'cleanup_minutes': 0,
              'efficiency_percent': 100,
              'finite_capacity': true,
              'availability': {'mode': 'always'},
            },
          ),
        };
      case 'GET /v1/mobile/admin/item-groups/tree':
        body = const [
          {
            'name': 'Kley',
            'item_group_name': 'Kley',
            'parent_item_group': 'homashyo',
            'is_group': true,
          },
          {
            'name': 'Kraska',
            'item_group_name': 'Kraska',
            'parent_item_group': 'homashyo',
            'is_group': true,
          },
          {
            'name': 'Tayyor mahsulot',
            'item_group_name': 'Tayyor mahsulot',
            'parent_item_group': 'mahsulot',
            'is_group': true,
          },
        ];
      default:
        body = {'error': 'Unhandled request: $key'};
        return _FakeHttpClientRequest(
          response: _FakeHttpClientResponse(
            body: jsonEncode(body),
            statusCode: HttpStatus.notFound,
            requestKey: key,
            seenRequests: seenRequests,
          ),
        );
    }

    return _FakeHttpClientRequest(
      response: _FakeHttpClientResponse(
        body: jsonEncode(body),
        statusCode: statusCode,
        requestKey: key,
        seenRequests: seenRequests,
      ),
    );
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  void close({bool force = false}) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest({required this.response});

  final _FakeHttpClientResponse response;
  final BytesBuilder _body = BytesBuilder();
  final _headers = _FakeHttpHeaders();

  @override
  bool persistentConnection = true;

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  int contentLength = -1;

  @override
  bool bufferOutput = true;

  @override
  List<Cookie> get cookies => const <Cookie>[];

  @override
  void write(Object? object) {
    if (object != null) {
      _body.add(utf8.encode(object.toString()));
    }
  }

  @override
  void add(List<int> data) {
    _body.add(data);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      _body.add(data);
    }
  }

  @override
  Future<HttpClientResponse> close() async {
    final body = utf8.decode(_body.takeBytes());
    final idempotencyKey = _headers.value('idempotency-key');
    if (idempotencyKey != null) {
      response.seenRequests.add(
        'HEADERS ${response.requestKey} idempotency-key=$idempotencyKey',
      );
    }
    if (body.isNotEmpty) {
      response.seenRequests.add('BODY ${response.requestKey} $body');
    }
    return response;
  }

  @override
  HttpHeaders get headers => _headers;

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding value) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse({
    required this.body,
    required this.statusCode,
    required this.requestKey,
    required this.seenRequests,
  });

  final String body;
  final String requestKey;
  final List<String> seenRequests;

  @override
  final int statusCode;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([utf8.encode(body)]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  int get contentLength => utf8.encode(body).length;

  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => '';

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  List<Cookie> get cookies => const <Cookie>[];

  @override
  Future<Socket> detachSocket() => throw UnsupportedError('detachSocket');

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) =>
      Future<HttpClientResponse>.value(this);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _values = {};

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _values.putIfAbsent(name, () => <String>[]).add(value.toString());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name] = [value.toString()];
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _values.forEach(action);
  }

  @override
  String? value(String name) {
    final normalized = name.toLowerCase();
    for (final entry in _values.entries) {
      if (entry.key.toLowerCase() == normalized) {
        return entry.value.join(',');
      }
    }
    return null;
  }
}
