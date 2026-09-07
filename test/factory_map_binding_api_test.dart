import 'dart:convert';

import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/admin/logic/factory_map_bindings.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSession.instance.setSession(
        token: 'map-test-token',
        profile: const SessionProfile(
            role: UserRole.admin,
            ref: 'admin',
            displayName: 'Admin',
            legalName: '',
            phone: '',
            avatarUrl: '',
            capabilities: ['admin.access', 'production.map.manage']));
  });
  tearDown(() => AppSession.instance.clear());

  test(
      'real API facade sends authenticated revision PATCH with explicit null; reload persists',
      () async {
    final data = <String, dynamic>{
      'apparatus_id': 'apparatus:test:machine',
      'source_revision': 4,
      'source_aasx_sha256': 'a' * 64,
      'display': {'display_name': 'Machine'},
      'execution_profile': {'operation': 'print', 'technology': 'flexographic'},
      'lifecycle': {'state': 'active'},
      'placement': {'factory_map_object_id': 'node:7'},
    };
    final bodies = <Map<String, dynamic>>[];
    final keys = <String>{};
    final bindings = FactoryMapBindings();
    await http.runWithClient(() async {
      await bindings.refresh();
      final detached = await bindings.save(bindings.apparatus.single, '');
      expect(detached.factoryMapObjectId, isEmpty);
      final linked = await bindings.save(detached, 'node:20:instance:2');
      expect(linked.factoryMapObjectId, 'node:20');
      final reopened = FactoryMapBindings();
      await reopened.refresh();
      expect(reopened.apparatus.single.factoryMapObjectId, 'node:20');
      expect(reopened.apparatus.single.sourceRevision, 6);
      reopened.dispose();
    },
        () => MockClient((request) async {
              expect(request.headers['Authorization'], 'Bearer map-test-token');
              if (request.method == 'PATCH') {
                expect(Uri.decodeComponent(request.url.path),
                    '/v1/mobile/admin/apparatus/apparatus:test:machine');
                final body = jsonDecode(request.body) as Map<String, dynamic>;
                bodies.add(body);
                final key = request.headers['Idempotency-Key'] ??
                    request.headers['idempotency-key'];
                expect(key, isNotEmpty);
                keys.add(key!);
                expect(body['expected_revision'], data['source_revision']);
                expect((body['patch'] as Map).keys, ['placement']);
                data['placement'] = body['patch']['placement'];
                data['source_revision'] = (data['source_revision'] as int) + 1;
                return http.Response(
                    jsonEncode({'runtime_projection': data}), 200);
              }
              expect(request.method, 'GET');
              final list = request.url.path == '/v1/mobile/admin/apparatus';
              return http.Response(jsonEncode(list ? [data] : data), 200);
            }));
    bindings.dispose();
    expect(bodies, [
      {
        'expected_revision': 4,
        'patch': {'placement': null}
      },
      {
        'expected_revision': 5,
        'patch': {
          'placement': {'factory_map_object_id': 'node:20'}
        }
      },
    ]);
    expect(keys.length, 2);
  });
}
