import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _from = 'apparatus:default:bosma_7';
const _to = 'apparatus:default:bosma_8';
const _a = 'zakaz-colour-a';
const _b = 'zakaz-waiting-b';
const _c = 'zakaz-target-c';
const _d = 'zakaz-target-d';

ProductionMapDefinition _map(String id, String apparatus) =>
    ProductionMapDefinition.fromJson({
      'id': id,
      'title': id,
      'product_code': 'SYNTHETIC-PRINT',
      'roll_count': 7,
      'width_mm': 650,
      'nodes': [
        {'id': 'start', 'kind': 'start', 'title': 'Start'},
        {
          'id': 'print',
          'kind': 'apparatus',
          'title': apparatus == _from
              ? '7 ta rangli bosma aparat'
              : '8 ta rangli bosma aparat',
          'apparatus_id': apparatus,
        },
        {
          'id': 'end',
          'kind': 'end',
          'title': 'Synthetic print product',
          'item_code': 'SYNTHETIC-PRINT',
        },
      ],
      'edges': [
        {'from': 'start', 'to': 'print'},
        {'from': 'print', 'to': 'end'},
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    resetMobileApiTestModeData();
    AppSession.instance.token = 'pending-move-token';
  });
  tearDown(() async {
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = null;
  });

  for (final batch in [true, false]) {
    test('pending move: TestMode ${batch ? 'batch' : 'single'} persists tail',
        () async {
      await TestModeController.instance.setEnabled(true);
      for (final pair in [(_a, _from), (_b, _from), (_c, _to), (_d, _to)]) {
        await MobileApi.instance.adminSaveProductionMap(_map(pair.$1, pair.$2));
      }
      await MobileApi.instance.adminSaveProductionMapSequence(
        apparatus: _from,
        orderIds: [_a, _b],
      );
      await MobileApi.instance.adminSaveProductionMapSequence(
        apparatus: _to,
        orderIds: [_c],
      );
      final before = await MobileApi.instance.adminProductionMapSequences();
      final expectedTarget = [...before[_to]!, _b];
      expect(before[_to], containsAllInOrder([_c, _d]));
      if (batch) {
        final saved =
            await MobileApi.instance.adminMoveProductionMapOrdersBatch(
          mapIds: [_b, _b],
          fromApparatus: _from,
          toApparatus: _to,
        );
        expect(saved, hasLength(1));
      } else {
        await MobileApi.instance.adminMoveProductionMapOrder(
          mapId: _b,
          fromApparatus: _from,
          toApparatus: _to,
        );
      }
      for (var refresh = 0; refresh < 2; refresh++) {
        final snapshot =
            await MobileApi.instance.adminProductionMapQueueSnapshot(
          fresh: true,
        );
        expect(snapshot.sequences[_to], expectedTarget);
        expect(
            snapshot.sequences[_from], before[_from]!.where((id) => id != _b));
        expect(snapshot.queueStates[_to]?[_b] ?? 'pending', 'pending');
        final maps = await MobileApi.instance.adminProductionMaps();
        expect(
          maps
              .singleWhere((saved) => saved.map.id == _b)
              .map
              .nodes[1]
              .apparatusId,
          _to,
        );
      }
      await expectLater(
        MobileApi.instance.adminMoveProductionMapOrdersBatch(
          mapIds: [_b],
          fromApparatus: _from,
          toApparatus: _to,
        ),
        throwsA(isA<MobileApiException>()),
      );
      expect((await MobileApi.instance.adminProductionMapSequences())[_to],
          expectedTarget);
    });
  }

  test(
      'pending move: HTTP sends only the selected order and canonical apparatus',
      () async {
    await TestModeController.instance.setEnabled(false);
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode({
          'saved': [
            {'map': _map(_b, _to).toJson(), 'program': <String, dynamic>{}},
          ],
        }),
        200,
      );
    });
    await http.runWithClient(() async {
      final saved = await MobileApi.instance.adminMoveProductionMapOrdersBatch(
        mapIds: [_b],
        fromApparatus: _from,
        toApparatus: _to,
      );
      expect(saved.single.map.nodes[1].apparatusId, _to);
      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(requests.single.url.path,
          '/v1/mobile/admin/production-maps/move-batch');
      expect(jsonDecode(requests.single.body), {
        'from_apparatus': _from,
        'to_apparatus': _to,
        'map_ids': [_b],
      });
    }, () => client);
  });

  test(
      'pending move: own active reservation preserves HTTP conflict diagnostics',
      () async {
    await TestModeController.instance.setEnabled(false);
    final client = MockClient((request) async => http.Response(
          jsonEncode({'error': 'print_preflight_active'}),
          409,
          headers: {'x-request-id': 'own-colour-reservation'},
        ));
    await http.runWithClient(() async {
      await expectLater(
        MobileApi.instance.adminMoveProductionMapOrdersBatch(
          mapIds: [_a],
          fromApparatus: _from,
          toApparatus: _to,
        ),
        throwsA(isA<MobileApiException>()
            .having((error) => error.code, 'code', 'print_preflight_active')
            .having((error) => error.statusCode, 'HTTP status', 409)
            .having((error) => error.requestId, 'request id',
                'own-colour-reservation')
            .having((error) => error.message, 'message',
                'Buyurtmaning rang sinovi rezervi faol. Hozir bu amalni bajarib bo‘lmaydi.')),
      );
    }, () => client);
  });
}
