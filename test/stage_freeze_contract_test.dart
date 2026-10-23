import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'order_scan_bootstrap_fixtures.dart';

Map<String, dynamic> _stageHold({String state = 'frozen'}) => {
      'order_id': scanOrder,
      'stage_node_id': 'apparatus',
      'state': state,
      'freeze_request': {'target_apparatus': scanApparatus},
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'stage-freeze-test';
  });
  tearDown(() => AppSession.instance.token = null);

  test('stage hold survives cache and delta without becoming a global hold',
      () async {
    final wire = scanSequence()..['stage_order_controls'] = [_stageHold()];
    final snapshot =
        await decodeProductionMapQueueSnapshotPayload(jsonEncode(wire));
    expect(snapshot.stageFreezeSupported, isTrue);
    expect(snapshot.orderControlFor(scanOrder), AdminOrderControlState.active);
    expect(snapshot.stageOrderControls.single.stageNodeId, 'apparatus');
    final cached = decodeCachedProductionMapQueueSnapshot(
        encodeProductionMapQueueSnapshot(snapshot));
    expect(cached.stageFreezeSupported, isTrue);
    expect(
        cached.stageOrderControls.single.state, AdminOrderControlState.frozen);
    final delta = AdminProductionMapLiveStateDelta.fromJson({
      'type': 'state_delta',
      'protocol': 'state_delta_v1',
      'epoch': snapshot.epoch,
      'scope': snapshot.scope,
      'base_rev': snapshot.revision,
      'rev': snapshot.revision! + 1,
      'patch': {'stage_order_controls': []},
    });
    final unheld = delta.applyTo(cached);
    expect(unheld.stageOrderControls, isEmpty);
    expect(unheld.stageFreezeSupported, isTrue);
    expect(unheld.orderControlFor(scanOrder), AdminOrderControlState.active);
  });

  test('legacy snapshots and caches cannot advertise stage freeze support',
      () async {
    final snapshot = await decodeProductionMapQueueSnapshotPayload(
        jsonEncode(scanSequence()));
    expect(snapshot.stageFreezeSupported, isFalse);
    final encoded = encodeProductionMapQueueSnapshot(snapshot);
    expect(encoded.containsKey('stage_order_controls'), isFalse);
    expect(decodeCachedProductionMapQueueSnapshot(encoded).stageFreezeSupported,
        isFalse);
  });

  test('local frozen contract requires an explicit stage override', () {
    final json = scanControl()
      ..['state'] = 'frozen'
      ..['allowed_actions'] = [];
    (json['interaction'] as Map)['mode'] = 'frozen';
    final legacy = AdminApparatusQueueOrderActionControl.fromJson(json);
    expect(legacy.contractValid, isTrue);
    expect(legacy.isConsistentWith(AdminOrderControlState.active), isFalse);
    json['stage_control_state'] = 'frozen';
    final local = AdminApparatusQueueOrderActionControl.fromJson(json);
    expect(local.isConsistentWith(AdminOrderControlState.active), isTrue);
    expect(local.allows('start'), isFalse);
    expect(local.isConsistentWith(AdminOrderControlState.frozen), isTrue);
  });

  test('stage API sends an exact node and never changes scope implicitly',
      () async {
    for (final action in [
      AdminOrderControlAction.freeze,
      AdminOrderControlAction.cancelFreeze,
      AdminOrderControlAction.unfreeze
    ]) {
      await http.runWithClient(() async {
        await MobileApi.instance.adminProductionMapOrderControl(
            orderId: scanOrder,
            action: action,
            apparatus: scanApparatus,
            stageNodeId: 'apparatus',
            stageFreezeSupported: true);
      },
          () => MockClient((request) async {
                expect(jsonDecode(request.body), {
                  'order_id': scanOrder,
                  'action': action.apiValue,
                  'scope': 'stage',
                  'apparatus': scanApparatus,
                  'stage_node_id': 'apparatus',
                });
                return http.Response(
                    jsonEncode({'control': _stageHold()}), 200);
              }));
    }
    await http.runWithClient(() async {
      await MobileApi.instance.adminProductionMapOrderControl(
          orderId: scanOrder, action: AdminOrderControlAction.freeze);
    },
        () => MockClient((request) async {
              final body = jsonDecode(request.body) as Map;
              expect(body['scope'], 'order');
              expect(body.containsKey('apparatus'), isFalse);
              return http.Response(
                  jsonEncode({
                    'control': {'state': 'frozen'}
                  }),
                  200);
            }));
  });

  test('stage API fails before sending on unsupported server or missing target',
      () async {
    var sent = false;
    await http.runWithClient(() async {
      await expectLater(
          MobileApi.instance.adminProductionMapOrderControl(
              orderId: scanOrder,
              action: AdminOrderControlAction.freeze,
              apparatus: scanApparatus,
              stageNodeId: 'apparatus'),
          throwsA(isA<MobileApiException>()
              .having((e) => e.code, 'code', 'stage_freeze_unsupported')));
      await expectLater(
          MobileApi.instance.adminProductionMapOrderControl(
              orderId: scanOrder,
              action: AdminOrderControlAction.freeze,
              apparatus: scanApparatus,
              stageFreezeSupported: true),
          throwsA(isA<MobileApiException>()));
    },
        () => MockClient((_) async {
              sent = true;
              return http.Response('{}', 200);
            }));
    expect(sent, isFalse);
  });
  test('global wildcard stop request and local request remain distinct', () {
    final json = scanControl()
      ..['state'] = 'in_progress'
      ..['allowed_actions'] = ['pause']
      ..['freeze_request'] = {
        'scope': 'order',
        'request_id': 'all-active',
        'status': 'pending',
        'target_apparatus': '',
        'target_session_id': '',
        'target_worker_ref': '',
      };
    (json['interaction'] as Map)['mode'] = 'freeze_requested';
    final global = AdminApparatusQueueOrderActionControl.fromJson(json);
    expect(global.freezeRequest?.isGlobalWildcard, isTrue);
    expect(global.isConsistentWith(AdminOrderControlState.freezeRequested),
        isTrue);
    expect(global.isConsistentWith(AdminOrderControlState.active), isFalse);
    json['stage_control_state'] = 'freeze_requested';
    final overlapping = AdminApparatusQueueOrderActionControl.fromJson(json);
    expect(overlapping.isConsistentWith(AdminOrderControlState.freezeRequested),
        isTrue,
        reason: 'the global request takes precedence over the local request');
    expect(overlapping.isConsistentWith(AdminOrderControlState.active), isFalse,
        reason: 'a local hold cannot use a global wildcard');
    json['freeze_request'] = {
      'scope': 'stage',
      'stage_node_id': 'apparatus',
      'request_id': 'one-stage',
      'status': 'pending',
      'target_apparatus': scanApparatus,
      'target_session_id': 'active-session',
      'target_worker_ref': 'worker',
    };
    final local = AdminApparatusQueueOrderActionControl.fromJson(json);
    expect(local.isConsistentWith(AdminOrderControlState.active), isTrue);
    expect(local.freezeRequest?.isGlobalWildcard, isFalse);
    (json['freeze_request'] as Map)['stage_node_id'] = 'another-occurrence';
    expect(
        AdminApparatusQueueOrderActionControl.fromJson(json)
            .isConsistentWith(AdminOrderControlState.active),
        isFalse);
  });

  test('global pending freeze blocks passive pending and locally frozen stages',
      () {
    for (final state in ['pending', 'frozen']) {
      final json = scanControl()
        ..['state'] = state
        ..['allowed_actions'] = []
        ..['stage_control_state'] = state == 'frozen' ? 'frozen' : '';
      (json['interaction'] as Map)
        ..['mode'] = state == 'frozen' ? 'frozen' : 'fresh_start_blocked'
        ..['blocking_reason_code'] = 'order_freeze_requested';
      final passive = AdminApparatusQueueOrderActionControl.fromJson(json);
      expect(passive.contractValid, isTrue);
      expect(passive.isConsistentWith(AdminOrderControlState.freezeRequested),
          isTrue);
      expect(passive.allows('start'), isFalse);
      expect(passive.allows('resume'), isFalse);
      json['allowed_actions'] = ['start'];
      expect(
          AdminApparatusQueueOrderActionControl.fromJson(json)
              .isConsistentWith(AdminOrderControlState.freezeRequested),
          isFalse,
          reason: 'global freeze cannot permit production at passive stages');
    }
  });
}
