import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'order_scan_bootstrap_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.token = 'queue-test-token';
    await TestModeController.instance.setEnabled(false);
  });
  tearDown(() => AppSession.instance.token = null);

  for (final cursor in <Map<String, dynamic>>[
    {'rev': 8, 'epoch': 'server'},
    {'rev': 0, 'epoch': 'server'},
    {},
    {'rev': -1, 'epoch': 'server'},
    {'rev': '8', 'epoch': 'server'},
    {'rev': 8.5, 'epoch': 'server'},
    {'rev': 8, 'epoch': ''},
    {'rev': 8, 'epoch': null},
  ]) {
    test('queue ACK optional cursor $cursor preserves committed payload',
        () async {
      final valid = cursor['rev'] is int &&
          (cursor['rev'] as int) >= 0 &&
          cursor['epoch'] is String &&
          (cursor['epoch'] as String).isNotEmpty;
      var writes = 0;
      await http.runWithClient(() async {
        final result = await MobileApi.instance.adminApparatusQueueActionResult(
            apparatus: scanApparatus, orderId: scanOrder, action: 'start');
        expect(result.states[scanOrder], 'in_progress');
        expect(result.orderControl, AdminOrderControlState.active);
        expect(result.hasSnapshotCursor, valid);
        expect(result.hasOrderStatus, isFalse);
        expect(result.controlState, isNull);
        expect(writes, 1);
      },
          () => MockClient((request) async {
                expect(request.method, 'POST');
                expect(jsonDecode(request.body).containsKey('include_control'), isFalse);
                writes++;
                return http.Response(
                    jsonEncode({
                      'ok': true,
                      ...cursor,
                      'states': {scanOrder: 'in_progress'},
                      'order_control': {'state': 'active'},
                    }),
                    200);
              }));
    });
  }

  for (final entry in <Object?>[
    scanBootstrap()['control_state'],
    null,
    {'rev': 8, 'control': 'invalid'},
    {
      ...scanBootstrap()['control_state'] as Map<String, dynamic>,
      'queue_state': 'frozen',
    },
  ].indexed) {
    final control = entry.$2;
    test('queue ACK opt-in control tolerates legacy/malformed presentation: ${entry.$1}',
        () async {
      var writes = 0;
      await http.runWithClient(() async {
        final result = await MobileApi.instance.adminApparatusQueueActionResult(
            apparatus: scanApparatus, orderId: scanOrder, action: 'start',
            includeControl: true);
        expect(result.states[scanOrder], 'in_progress');
        expect(result.controlState != null,
            control is Map && control['queue_state'] == 'pending');
        expect(writes, 1);
      }, () => MockClient((request) async {
        writes++;
        expect(jsonDecode(request.body)['include_control'], isTrue);
        return http.Response(jsonEncode({
          'ok': true, 'rev': 8, 'epoch': 'scan-server',
          'states': {scanOrder: 'in_progress'}, 'control_state': control,
        }), 200);
      }));
    });
  }

  test(
      'control signature covers unknown fields, repeated stages and rezka reports',
      () {
    final before =
        AdminApparatusQueueOrderActionControl.fromJson(scanControl());
    for (final field in [
      'future_server_field',
      'stage_node_id',
      'rezka_output_report',
      'rezka_input_lineage',
      'rezka_active_partial_rolls',
      'rezka_output_kadr_counts',
      'complete_requires_rezka_total_waste_only'
    ]) {
      final after = AdminApparatusQueueOrderActionControl.fromJson({
        ...scanControl(),
        field: field == 'stage_node_id' ? 'another-stage' : null,
      });
      expect(
          after.serverContractSignature, isNot(before.serverContractSignature),
          reason: '$field must not be treated as unchanged');
    }
  });

  test('thin control read sends no material scan values and remains scoped',
      () async {
    await http.runWithClient(() async {
      final result = await MobileApi.instance.adminOrderScanBootstrap(
          apparatus: scanApparatus, orderId: scanOrder, includeSections: false);
      expect(result!.controlState.revision, 7);
    },
        () => MockClient((request) async {
              expect(request.method, 'GET');
              expect(request.url.queryParameters, {
                'apparatus': scanApparatus,
                'order_id': scanOrder,
                'include_sections': 'false',
              });
              return http.Response(jsonEncode(scanBootstrap()), 200);
            }));
  });
}
