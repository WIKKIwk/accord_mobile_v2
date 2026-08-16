import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('production map live snapshot parses backend visible order ids', () {
    final snapshot = AdminProductionMapLiveSnapshot.fromJson({
      'ok': true,
      'maps': const [],
      'sequences': const {},
      'visible_order_ids': const {
        '7 ta rangli pechat': ['zakaz-visible-alt'],
        'Laminatsiya 1': ['zakaz-visible-alt'],
      },
      'queue_states': const {},
      'queue_policies': const [],
      'queue_action_controls': const {
        '7 ta rangli pechat': {
          'zakaz-visible-alt': {
            'state': 'in_progress',
            'allowed_actions': ['pause', 'detach_roll'],
            'freeze_request': {
              'request_id': 'freeze-request-1',
              'status': 'pending',
              'target_session_id': 'session-1',
              'target_apparatus': '7 ta rangli pechat',
              'target_worker_role': 'aparatchi',
              'target_worker_ref': 'worker-1',
              'target_worker_display_name': 'Worker 1',
              'requested_at_unix': 1710000000,
              'transitioned_at_unix': 0,
            },
          },
        },
      },
      'completed_orders': const [],
      'completion_requests': const [],
      'completion_request_decisions': const [],
      'order_controls': const {
        'zakaz-visible-alt': {'state': 'freeze_requested'},
        'zakaz-frozen': {'state': 'frozen'},
      },
      'order_customers': const {
        'zakaz-visible-alt': '555 kukuruz',
      },
      'order_statuses': const {
        'zakaz-visible-alt': {
          'order_status': 'in_progress',
          'active_session_count': 1,
        },
        'zakaz-issue': {
          'order_status': 'completed_with_issue',
          'completed_with_issue_count': 1,
        },
      },
      'frozen_orders_by_apparatus': const {
        'Pechat': [
          {
            'order_id': 'zakaz-frozen',
            'apparatus': 'Pechat',
            'issue_note': 'Val notekis chiqdi',
            'frozen_at_unix': 1710000000,
            'frozen_by': 'Aparatchi',
          },
        ],
      },
    });

    expect(
      snapshot.visibleOrderIds['7 ta rangli pechat'],
      ['zakaz-visible-alt'],
    );
    expect(snapshot.visibleOrderIds['Laminatsiya 2'], isNull);
    expect(
      snapshot.orderControls['zakaz-visible-alt'],
      AdminOrderControlState.freezeRequested,
    );
    expect(
      snapshot.orderControls['zakaz-frozen'],
      AdminOrderControlState.frozen,
    );
    expect(
      snapshot.orderStatuses['zakaz-visible-alt']?.orderStatus,
      'in_progress',
    );
    expect(
      snapshot.orderStatuses['zakaz-issue']?.completedWithIssueCount,
      1,
    );
    expect(snapshot.orderCustomers['zakaz-visible-alt'], '555 kukuruz');
    final freezeRequest = snapshot
        .queueActionControls['7 ta rangli pechat']?['zakaz-visible-alt']
        ?.freezeRequest;
    expect(freezeRequest?.requestId, 'freeze-request-1');
    expect(freezeRequest?.status, 'pending');
    expect(freezeRequest?.targetSessionId, 'session-1');
    expect(freezeRequest?.targetApparatus, '7 ta rangli pechat');
    expect(
      snapshot.frozenOrdersByApparatus['Pechat']?.single.issueNote,
      'Val notekis chiqdi',
    );
    expect(
      snapshot.frozenOrdersByApparatus['Pechat']?.single.orderId,
      'zakaz-frozen',
    );
  });

  test('test mode issue freeze removes and unfreeze requeues at the tail',
      () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await TestModeController.instance.setEnabled(true);
    resetMobileApiTestModeData();
    const apparatus = 'Godex aparat - DEMO';
    const frozenOrderId = 'zakaz-frozen-test-mode';
    const nextOrderId = 'zakaz-next-test-mode';

    const frozenMap = ProductionMapDefinition(
      id: frozenOrderId,
      productCode: 'FREEZE-1',
      title: 'Freeze test order',
      nodes: [
        ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
        ProductionMapNode(
          id: 'apparatus',
          kind: 'apparatus',
          title: apparatus,
        ),
        ProductionMapNode(id: 'end', kind: 'end', title: 'End'),
      ],
      edges: [
        ProductionMapEdge(from: 'start', to: 'apparatus'),
        ProductionMapEdge(from: 'apparatus', to: 'end'),
      ],
    );
    const nextMap = ProductionMapDefinition(
      id: nextOrderId,
      productCode: 'FREEZE-2',
      title: 'Next test order',
      nodes: [
        ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
        ProductionMapNode(
          id: 'apparatus',
          kind: 'apparatus',
          title: apparatus,
        ),
        ProductionMapNode(id: 'end', kind: 'end', title: 'End'),
      ],
      edges: [
        ProductionMapEdge(from: 'start', to: 'apparatus'),
        ProductionMapEdge(from: 'apparatus', to: 'end'),
      ],
    );

    try {
      await MobileApi.instance.adminSaveProductionMap(frozenMap);
      await MobileApi.instance.adminSaveProductionMap(nextMap);
      await MobileApi.instance.adminSaveProductionMapSequence(
        apparatus: apparatus,
        orderIds: const [frozenOrderId, nextOrderId],
      );
      await MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: apparatus,
        orderId: frozenOrderId,
        action: 'start',
      );
      await MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: apparatus,
        orderId: frozenOrderId,
        action: 'freeze',
        freezeWithIssue: true,
        issueNote: 'Sinov muammosi',
      );

      var snapshot = await MobileApi.instance.adminProductionMapQueueSnapshot();
      expect(snapshot.sequences[apparatus], [nextOrderId]);
      expect(
        snapshot.frozenOrdersByApparatus[apparatus]?.single.issueNote,
        'Sinov muammosi',
      );

      await MobileApi.instance.adminProductionMapOrderControl(
        orderId: frozenOrderId,
        action: AdminOrderControlAction.unfreeze,
      );
      snapshot = await MobileApi.instance.adminProductionMapQueueSnapshot();
      expect(snapshot.sequences[apparatus], [nextOrderId, frozenOrderId]);
      expect(
        snapshot.queueStates[apparatus]?[frozenOrderId],
        'pending',
      );
      expect(
        snapshot.queueActionControls[apparatus]?[frozenOrderId]?.allowedActions,
        isEmpty,
      );
      await MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: apparatus,
        orderId: nextOrderId,
        action: 'start',
      );
      await MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: apparatus,
        orderId: nextOrderId,
        action: 'complete',
      );
      snapshot = await MobileApi.instance.adminProductionMapQueueSnapshot();
      expect(
        snapshot.queueActionControls[apparatus]?[frozenOrderId]?.allowedActions,
        contains('resume'),
      );
      await expectLater(
        MobileApi.instance.adminApparatusQueueActionResult(
          apparatus: apparatus,
          orderId: frozenOrderId,
          action: 'start',
        ),
        throwsA(
          isA<MobileApiException>().having(
            (error) => error.code,
            'code',
            'queue_action_not_allowed',
          ),
        ),
      );
      await MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: apparatus,
        orderId: frozenOrderId,
        action: 'resume',
      );
      snapshot = await MobileApi.instance.adminProductionMapQueueSnapshot();
      expect(snapshot.queueStates[apparatus]?[frozenOrderId], 'in_progress');
    } finally {
      resetMobileApiTestModeData();
      await TestModeController.instance.setEnabled(false);
    }
  });

  test('live snapshot projects frozen control over stale queue data', () {
    final snapshot = AdminProductionMapLiveSnapshot.fromJson({
      'maps': const [],
      'sequences': const {},
      'visible_order_ids': const {
        'Pechat': ['zakaz-frozen'],
      },
      'queue_states': const {
        'Pechat': {'zakaz-frozen': 'paused'},
      },
      'queue_policies': const [],
      'queue_action_controls': const {
        'Pechat': {
          'zakaz-frozen': {
            'state': 'paused',
            'allowed_actions': ['resume'],
          },
        },
      },
      'completed_orders': const [],
      'completion_requests': const [],
      'completion_request_decisions': const [],
      'order_controls': const {
        'zakaz-frozen': {'state': 'frozen'},
      },
      'order_statuses': const {
        'zakaz-frozen': {
          'order_status': 'in_progress',
          'work_status': 'in_progress',
          'flow_status': 'in_progress',
        },
      },
    });

    expect(snapshot.queueStates['Pechat']?['zakaz-frozen'], 'frozen');
    expect(
      snapshot.queueActionControls['Pechat']?['zakaz-frozen']?.state,
      'frozen',
    );
    expect(
      snapshot.queueActionControls['Pechat']?['zakaz-frozen']?.allowedActions,
      isEmpty,
    );
    expect(snapshot.orderStatuses['zakaz-frozen']?.orderStatus, 'frozen');
    expect(snapshot.orderStatuses['zakaz-frozen']?.workStatus, 'frozen');
    expect(snapshot.orderStatuses['zakaz-frozen']?.flowStatus, 'frozen');
  });

  test('production map definition keeps server customer name', () {
    final map = ProductionMapDefinition.fromJson({
      'id': 'zakaz-7657',
      'product_code': 'YASHIL',
      'title': 'yashil',
      'customer_name': '555 kukuruz',
      'nodes': const [],
      'edges': const [],
    });

    expect(map.customerName, '555 kukuruz');
    expect(map.toJson()['customer_name'], '555 kukuruz');
  });

  test('production map live snapshot requires backend visible order ids', () {
    expect(
      () => AdminProductionMapLiveSnapshot.fromJson({
        'ok': true,
        'maps': const [],
        'sequences': const {},
        'queue_states': const {},
        'queue_policies': const [],
        'completed_orders': const [],
        'completion_requests': const [],
        'completion_request_decisions': const [],
      }),
      throwsA(
        isA<MobileApiException>().having(
          (error) => error.code,
          'code',
          'production_map_visible_order_ids_missing',
        ),
      ),
    );
  });
}
