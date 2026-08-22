import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _apparatusId = 'apparatus:default:asset-007';
const _apparatus = AdminApparatus(
  id: _apparatusId,
  name: 'Laminatsiya 1',
  sourceRevision: 2,
  sourceAasxSha256:
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  operation: 'laminate',
  technology: 'adhesive_lamination',
);

const _catalogProjection = <String, dynamic>{
  'apparatus_id': _apparatusId,
  'source_revision': 2,
  'source_aasx_sha256':
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'display': {'display_name': 'Laminatsiya 1', 'catalog_order': 7},
  'capabilities': {'laminate': 1},
  'execution_profile': {
    'operation': 'laminate',
    'technology': 'adhesive_lamination',
  },
  'training': {
    'enabled': true,
    'queue_enabled': true,
    'material_tracking_enabled': true,
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'token';
  });

  tearDown(() {
    AppSession.instance.token = null;
  });

  test('training toggle writes the dedicated canonical-id mode switch',
      () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'PUT' &&
          request.url.path == '/v1/mobile/admin/training/apparatus') {
        return http.Response('{}', 200);
      }
      return http.Response('unexpected request', 500);
    });

    await http.runWithClient(
      () => MobileApi.instance.adminSetTrainingApparatusMode(
        apparatus: _apparatus,
        enabled: false,
      ),
      () => client,
    );

    expect(requests, hasLength(1));
    expect(requests.single.method, 'PUT');
    expect(requests.single.url.path, '/v1/mobile/admin/training/apparatus');
    expect(
      jsonDecode(requests.single.body),
      {'apparatus': _apparatusId, 'enabled': false},
    );
  });

  test('training page reads its mode from the dedicated switch', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET' &&
          request.url.path == '/v1/mobile/admin/apparatus') {
        return http.Response(jsonEncode([_catalogProjection]), 200);
      }
      if (request.method == 'GET' &&
          request.url.path == '/v1/mobile/admin/training/apparatus') {
        return http.Response(
          jsonEncode({
            'modes': {_apparatusId: false},
          }),
          200,
        );
      }
      return http.Response('unexpected request', 500);
    });

    final apparatus = await http.runWithClient(
      () => MobileApi.instance.adminTrainingApparatus(),
      () => client,
    );

    expect(apparatus, hasLength(1));
    expect(apparatus.single.id, _apparatusId);
    expect(apparatus.single.trainingEnabled, isFalse);
    expect(
      requests.map((request) => '${request.method} ${request.url.path}'),
      [
        'GET /v1/mobile/admin/apparatus',
        'GET /v1/mobile/admin/training/apparatus',
      ],
    );
  });
}
