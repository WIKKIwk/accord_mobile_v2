import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('live snapshot keeps actor stage-history statuses', () {
    final snapshot = AdminProductionMapLiveSnapshot.fromJson({
      'ok': true,
      'maps': const [],
      'sequences': const {},
      'visible_order_ids': const {},
      'queue_states': const {},
      'queue_policies': const [],
      'queue_action_controls': const {},
      'completed_orders': const [
        {
          'apparatus': 'Pechat',
          'order_id': 'zakaz-stage-history',
          'status': 'completed',
        },
        {
          'apparatus': 'Laminatsiya 1',
          'order_id': 'zakaz-partial-history',
          'status': 'in_progress',
        },
      ],
      'completion_requests': const [],
      'completion_request_decisions': const [],
      'order_controls': const {},
      'order_statuses': const {},
      'frozen_orders_by_apparatus': const {},
    });

    expect(snapshot.completedOrders, hasLength(2));
    expect(snapshot.completedOrders[0].status, 'completed');
    expect(snapshot.completedOrders[0].apparatus, 'Pechat');
    expect(snapshot.completedOrders[1].status, 'in_progress');
    expect(snapshot.completedOrders[1].apparatus, 'Laminatsiya 1');
  });

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
            'allowed_actions': ['pause'],
            'interaction': {
              'mode': 'freeze_requested',
              'start_materials_mode': 'hidden',
              'material_scan_required': false,
              'assigned_materials_display_only': true,
              'material_intake_allowed': false,
              'previous_wip_mode': 'not_required',
              'qolip_mode': 'not_required',
              'blocking_reason_code': 'order_freeze_requested',
            },
            'previous_stage_ready': false,
            'complete_requires_full_report': false,
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
      var snapshot = await MobileApi.instance.adminProductionMapQueueSnapshot();
      expect(
        snapshot.queueActionControls[apparatus]?[frozenOrderId],
        isNull,
      );
      setMobileApiTestModeQueueActionControlFixture(
        apparatus: apparatus,
        orderId: frozenOrderId,
        control: const AdminApparatusQueueOrderActionControl(
          state: 'in_progress',
          allowedActions: {'pause', 'freeze', 'complete'},
          hasOnlyKnownActions: true,
          completeRequiresFullReport: true,
          interaction: AdminQueueWorkerInteraction(
            mode: AdminQueueInteractionMode.inProgress,
            startMaterialsMode: AdminQueueStartMaterialsMode.hidden,
            materialScanRequired: false,
            assignedMaterialsDisplayOnly: false,
            materialIntakeAllowed: true,
            previousWipMode: AdminQueuePreviousWipMode.notRequired,
            qolipMode: AdminQueueQolipMode.notRequired,
          ),
        ),
      );
      snapshot = await MobileApi.instance.adminProductionMapQueueSnapshot();
      expect(
        snapshot.queueActionControls[apparatus]?[frozenOrderId]?.allowedActions,
        contains('freeze'),
      );
      await MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: apparatus,
        orderId: frozenOrderId,
        action: 'freeze',
        freezeWithIssue: true,
        issueNote: 'Sinov muammosi',
      );

      setMobileApiTestModeQueueActionControlFixture(
        apparatus: apparatus,
        orderId: frozenOrderId,
        control: const AdminApparatusQueueOrderActionControl(
          state: 'frozen',
          allowedActions: {},
          hasOnlyKnownActions: true,
          interaction: AdminQueueWorkerInteraction(
            mode: AdminQueueInteractionMode.frozen,
            startMaterialsMode: AdminQueueStartMaterialsMode.hidden,
            materialScanRequired: false,
            assignedMaterialsDisplayOnly: true,
            materialIntakeAllowed: false,
            previousWipMode: AdminQueuePreviousWipMode.notRequired,
            qolipMode: AdminQueueQolipMode.notRequired,
            blockingReasonCode: 'order_frozen',
          ),
        ),
      );
      snapshot = await MobileApi.instance.adminProductionMapQueueSnapshot();
      expect(snapshot.sequences[apparatus], [nextOrderId]);
      expect(
        snapshot.frozenOrdersByApparatus[apparatus]?.single.issueNote,
        'Sinov muammosi',
      );

      await MobileApi.instance.adminProductionMapOrderControl(
        orderId: frozenOrderId,
        action: AdminOrderControlAction.unfreeze,
      );
      setMobileApiTestModeQueueActionControlFixture(
        apparatus: apparatus,
        orderId: frozenOrderId,
        control: const AdminApparatusQueueOrderActionControl(
          state: 'pending',
          allowedActions: {},
          hasOnlyKnownActions: true,
          interaction: AdminQueueWorkerInteraction(
            mode: AdminQueueInteractionMode.requeuedWaiting,
            startMaterialsMode: AdminQueueStartMaterialsMode.hidden,
            materialScanRequired: false,
            assignedMaterialsDisplayOnly: true,
            materialIntakeAllowed: false,
            previousWipMode: AdminQueuePreviousWipMode.notRequired,
            qolipMode: AdminQueueQolipMode.notRequired,
            blockingReasonCode: 'waiting_sequence',
          ),
        ),
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
      expect(
        snapshot
            .queueActionControls[apparatus]?[frozenOrderId]?.interaction?.mode,
        AdminQueueInteractionMode.requeuedWaiting,
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
      setMobileApiTestModeQueueActionControlFixture(
        apparatus: apparatus,
        orderId: frozenOrderId,
        control: const AdminApparatusQueueOrderActionControl(
          state: 'pending',
          allowedActions: {'resume'},
          hasOnlyKnownActions: true,
          interaction: AdminQueueWorkerInteraction(
            mode: AdminQueueInteractionMode.requeuedReady,
            startMaterialsMode: AdminQueueStartMaterialsMode.hidden,
            materialScanRequired: false,
            assignedMaterialsDisplayOnly: true,
            materialIntakeAllowed: false,
            previousWipMode: AdminQueuePreviousWipMode.notRequired,
            qolipMode: AdminQueueQolipMode.notRequired,
          ),
        ),
      );
      snapshot = await MobileApi.instance.adminProductionMapQueueSnapshot();
      expect(
        snapshot.queueActionControls[apparatus]?[frozenOrderId]?.allowedActions,
        contains('resume'),
      );
      expect(
        snapshot
            .queueActionControls[apparatus]?[frozenOrderId]?.interaction?.mode,
        AdminQueueInteractionMode.requeuedReady,
      );
      expect(
        snapshot.queueActionControls[apparatus]?[frozenOrderId]?.interaction
            ?.startMaterialsMode,
        AdminQueueStartMaterialsMode.hidden,
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
      setMobileApiTestModeQueueActionControlFixture(
        apparatus: apparatus,
        orderId: frozenOrderId,
        control: const AdminApparatusQueueOrderActionControl(
          state: 'in_progress',
          allowedActions: {'pause', 'freeze', 'complete'},
          hasOnlyKnownActions: true,
          completeRequiresFullReport: true,
          interaction: AdminQueueWorkerInteraction(
            mode: AdminQueueInteractionMode.inProgress,
            startMaterialsMode: AdminQueueStartMaterialsMode.hidden,
            materialScanRequired: false,
            assignedMaterialsDisplayOnly: false,
            materialIntakeAllowed: true,
            previousWipMode: AdminQueuePreviousWipMode.notRequired,
            qolipMode: AdminQueueQolipMode.notRequired,
          ),
        ),
      );
      snapshot = await MobileApi.instance.adminProductionMapQueueSnapshot();
      expect(snapshot.queueStates[apparatus]?[frozenOrderId], 'in_progress');
    } finally {
      resetMobileApiTestModeData();
      await TestModeController.instance.setEnabled(false);
    }
  });

  test('live snapshot preserves stale server data and fails closed', () {
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
            'interaction': {
              'mode': 'paused',
              'start_materials_mode': 'hidden',
              'material_scan_required': false,
              'assigned_materials_display_only': false,
              'material_intake_allowed': true,
              'previous_wip_mode': 'not_required',
              'qolip_mode': 'not_required',
            },
            'previous_stage_ready': false,
            'complete_requires_full_report': false,
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

    expect(snapshot.queueStates['Pechat']?['zakaz-frozen'], 'paused');
    expect(
      snapshot.queueActionControls['Pechat']?['zakaz-frozen']?.state,
      'paused',
    );
    expect(
      snapshot.queueActionControls['Pechat']?['zakaz-frozen']?.allowedActions,
      contains('resume'),
    );
    final control = snapshot.queueActionControls['Pechat']?['zakaz-frozen'];
    expect(control?.contractValid, isTrue);
    expect(
      control?.isConsistentWith(AdminOrderControlState.frozen),
      isFalse,
    );
    expect(snapshot.orderStatuses['zakaz-frozen']?.orderStatus, 'in_progress');
    expect(snapshot.orderStatuses['zakaz-frozen']?.workStatus, 'in_progress');
    expect(snapshot.orderStatuses['zakaz-frozen']?.flowStatus, 'in_progress');
  });

  test('worker interaction contract controls requeue and input sections', () {
    AdminApparatusQueueOrderActionControl parse({
      required String state,
      required List<String> actions,
      required String mode,
      required String startMaterialsMode,
      bool materialScanRequired = false,
    }) {
      return AdminApparatusQueueOrderActionControl.fromJson({
        'state': state,
        'allowed_actions': actions,
        'interaction': {
          'mode': mode,
          'start_materials_mode': startMaterialsMode,
          'material_scan_required': materialScanRequired,
          'assigned_materials_display_only': true,
          'material_intake_allowed': false,
          'previous_wip_mode': 'not_required',
          'qolip_mode': 'not_required',
        },
        'previous_stage_ready': false,
        'complete_requires_full_report': false,
      });
    }

    final requeuedReady = parse(
      state: 'pending',
      actions: const ['resume'],
      mode: 'requeued_ready',
      startMaterialsMode: 'hidden',
    );
    expect(requeuedReady.contractValid, isTrue);
    expect(requeuedReady.allows('resume'), isTrue);
    expect(requeuedReady.allows('start'), isFalse);
    expect(
      requeuedReady.interaction?.startMaterialsMode,
      AdminQueueStartMaterialsMode.hidden,
    );

    final pausedWithoutResume = parse(
      state: 'paused',
      actions: const [],
      mode: 'paused',
      startMaterialsMode: 'hidden',
    );
    expect(pausedWithoutResume.contractValid, isTrue);
    expect(pausedWithoutResume.allows('resume'), isFalse);

    final freshStart = parse(
      state: 'pending',
      actions: const ['start'],
      mode: 'fresh_start',
      startMaterialsMode: 'scan_required',
      materialScanRequired: true,
    );
    expect(freshStart.contractValid, isTrue);
    expect(
      freshStart.interaction?.startMaterialsMode,
      AdminQueueStartMaterialsMode.scanRequired,
    );
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

  test('worker action controls reject contradictory action modes', () {
    final freezeOnPaused = AdminApparatusQueueOrderActionControl.fromJson({
      'state': 'paused',
      'allowed_actions': ['freeze'],
      'interaction': {
        'mode': 'paused',
        'start_materials_mode': 'hidden',
        'material_scan_required': false,
        'assigned_materials_display_only': false,
        'material_intake_allowed': true,
        'previous_wip_mode': 'not_required',
        'qolip_mode': 'not_required',
      },
      'previous_stage_ready': false,
      'complete_requires_full_report': false,
    });
    expect(freezeOnPaused.contractValid, isFalse);

    final resumeOnInProgress = AdminApparatusQueueOrderActionControl.fromJson({
      'state': 'in_progress',
      'allowed_actions': ['resume'],
      'interaction': {
        'mode': 'in_progress',
        'start_materials_mode': 'hidden',
        'material_scan_required': false,
        'assigned_materials_display_only': false,
        'material_intake_allowed': true,
        'previous_wip_mode': 'not_required',
        'qolip_mode': 'not_required',
      },
      'previous_stage_ready': false,
      'complete_requires_full_report': false,
    });
    expect(resumeOnInProgress.contractValid, isFalse);
  });

  test('live snapshot rejects unknown queue states and state mismatches', () {
    final base = <String, dynamic>{
      'maps': const [],
      'sequences': const {'Pechat': ['order-1']},
      'visible_order_ids': const {'Pechat': ['order-1']},
      'queue_policies': const [],
      'order_controls': const {},
    };

    expect(
      () => AdminProductionMapLiveSnapshot.fromJson({
        ...base,
        'queue_states': const {
          'Pechat': {'order-1': 'not_a_backend_state'},
        },
        'queue_action_controls': const {},
      }),
      throwsA(
        isA<MobileApiException>().having(
          (error) => error.code,
          'code',
          'production_map_snapshot_contract_invalid',
        ),
      ),
    );

    expect(
      () => AdminProductionMapLiveSnapshot.fromJson({
        ...base,
        'queue_states': const {
          'Pechat': {'order-1': 'paused'},
        },
        'queue_action_controls': const {
          'Pechat': {
            'order-1': {
              'state': 'pending',
              'allowed_actions': ['start'],
              'interaction': {
                'mode': 'fresh_start',
                'start_materials_mode': 'hidden',
                'material_scan_required': false,
                'assigned_materials_display_only': false,
                'material_intake_allowed': true,
                'previous_wip_mode': 'not_required',
                'qolip_mode': 'not_required',
              },
              'previous_stage_ready': false,
              'complete_requires_full_report': false,
            },
          },
        },
      }),
      throwsA(
        isA<MobileApiException>().having(
          (error) => error.code,
          'code',
          'production_map_snapshot_contract_invalid',
        ),
      ),
    );
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
