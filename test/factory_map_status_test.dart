import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/features/admin/logic/apparatus_queue_state.dart';
import 'package:accord_mobile_v2/src/features/admin/logic/factory_map_status.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

AdminApparatusQueueOrderActionControl control({
  String state = 'pending',
  String stageNodeId = '',
  AdminQueueInteractionMode mode = AdminQueueInteractionMode.freshStart,
  Set<String> actions = const {'start'},
  AdminQueuePreviousWipMode wip = AdminQueuePreviousWipMode.scanRequired,
  AdminQueuePreviousWipMode opening = AdminQueuePreviousWipMode.notRequired,
  String reason = '',
}) =>
    AdminApparatusQueueOrderActionControl(
      state: state,
      stageNodeId: stageNodeId,
      allowedActions: actions,
      hasOnlyKnownActions: true,
      previousStage: 'producer',
      previousStageReady: false,
      interaction: AdminQueueWorkerInteraction(
        mode: mode,
        startMaterialsMode: AdminQueueStartMaterialsMode.hidden,
        materialScanRequired: false,
        assignedMaterialsDisplayOnly: true,
        materialIntakeAllowed: false,
        previousWipMode: wip,
        openingWipMode: opening,
        qolipMode: AdminQueueQolipMode.notRequired,
        blockingReasonCode: reason,
      ),
    );

void main() {
  test('waiting input is ready even while its producer is not complete', () {
    expect(
        productionQueueDisplayStatus(queueState: 'pending', control: control()),
        FactoryMapStatus.wipReady);
    expect(
        productionQueueDisplayStatus(
            queueState: 'pending',
            control: control(
                wip: AdminQueuePreviousWipMode.notRequired,
                opening: AdminQueuePreviousWipMode.scanRequired)),
        FactoryMapStatus.wipReady);
  });

  test('available WIP does not override queue or machine restrictions', () {
    for (final reason in [
      'waiting_sequence',
      'apparatus_busy',
      'material_required'
    ]) {
      expect(
          productionQueueDisplayStatus(
              queueState: 'pending',
              control: control(
                  mode: AdminQueueInteractionMode.freshStartBlocked,
                  actions: {},
                  reason: reason)),
          FactoryMapStatus.wipWaiting);
    }
    expect(
        productionQueueDisplayStatus(
            queueState: 'pending',
            control: control(
                mode: AdminQueueInteractionMode.waitingPreviousStage,
                actions: {},
                reason: 'previous_stage_not_ready',
                wip: AdminQueuePreviousWipMode.waiting)),
        FactoryMapStatus.waitingWip);
  });

  test('pending resumable work is explicitly requeued', () {
    for (final ready in [true, false]) {
      expect(
          productionQueueDisplayStatus(
              queueState: 'pending',
              control: control(
                  mode: ready
                      ? AdminQueueInteractionMode.requeuedReady
                      : AdminQueueInteractionMode.requeuedWaiting,
                  actions: ready ? {'resume'} : {},
                  reason: ready ? '' : 'waiting_sequence')),
          ready
              ? FactoryMapStatus.requeuedReady
              : FactoryMapStatus.requeuedWaiting);
    }
  });

  test('active, frozen, closed and inconsistent states cannot claim ready WIP',
      () {
    expect(
        productionQueueDisplayStatus(
            queueState: 'in_progress',
            control: control(
                state: 'in_progress',
                mode: AdminQueueInteractionMode.inProgress,
                actions: {'pause'})),
        FactoryMapStatus.inProgress);
    expect(
        productionQueueDisplayStatus(
            queueState: 'paused',
            control: control(
                state: 'paused',
                mode: AdminQueueInteractionMode.paused,
                actions: {'resume'})),
        FactoryMapStatus.paused);
    expect(
        productionQueueDisplayStatus(
            queueState: 'pending',
            control: control(),
            orderControl: AdminOrderControlState.frozen),
        FactoryMapStatus.frozen);
    expect(
        productionQueueDisplayStatus(
            queueState: 'pending', control: control(), lifecycle: 'closed'),
        FactoryMapStatus.completed);
    expect(
        productionQueueDisplayStatus(
            queueState: 'completed',
            control: control(
                state: 'completed',
                mode: AdminQueueInteractionMode.completed,
                actions: {})),
        FactoryMapStatus.completed);
    expect(
        productionQueueDisplayStatus(queueState: 'paused', control: control()),
        FactoryMapStatus.unknown);
    expect(productionQueueDisplayStatus(queueState: 'pending'),
        FactoryMapStatus.pending);
  });

  test('factory map selects server-ready WIP after a waiting order', () {
    AdminApparatusQueueSnapshot snapshot({bool running = false}) =>
        AdminApparatusQueueSnapshot(
          sequences: const {
            'a': ['waiting', 'ready', 'running']
          },
          visibleOrderIds: {
            'a': ['waiting', 'ready', if (running) 'running']
          },
          queueStates: {
            'a': {
              'waiting': 'pending',
              'ready': 'pending',
              if (running) 'running': 'in_progress'
            }
          },
          queuePolicies: const {},
          orderControls: const {},
          queueActionControls: {
            'a': {
              'waiting': control(
                  mode: AdminQueueInteractionMode.waitingPreviousStage,
                  actions: {},
                  reason: 'previous_stage_not_ready',
                  wip: AdminQueuePreviousWipMode.waiting),
              'ready': control(),
            }
          },
        );
    final ready =
        factoryMapMachineStatus(snapshot: snapshot(), apparatusId: 'a');
    expect(ready.orderId, 'ready');
    expect(ready.status, FactoryMapStatus.wipReady);
    expect(
        factoryMapMachineStatus(
                snapshot: snapshot(running: true), apparatusId: 'a')
            .orderId,
        'running');
  });

  test('map readiness stays within its stage occurrence and alternatives', () {
    const map =
        ProductionMapDefinition(id: 'o', productCode: '', title: '', nodes: [
      ProductionMapNode(
          id: 'first',
          kind: 'apparatus',
          title: '',
          apparatusId: 'a',
          alternativeGroupId: 'g'),
      ProductionMapNode(
          id: 'peer',
          kind: 'apparatus',
          title: '',
          apparatusId: 'b',
          alternativeGroupId: 'g'),
      ProductionMapNode(
          id: 'later', kind: 'apparatus', title: '', apparatusId: 'a'),
    ], edges: []);
    final current = control(stageNodeId: 'first');
    expect(
      productionMapStageDisplayStatus(
        map: map,
        node: map.nodes.first,
        queueState: ApparatusQueueOrderState.completed,
        control: current,
        orderControl: AdminOrderControlState.frozen,
      ),
      FactoryMapStatus.completed,
    );
    for (final node in map.nodes) {
      expect(
          productionMapStageDisplayStatus(
              map: map,
              node: node,
              queueState: ApparatusQueueOrderState.pending,
              control: current),
          node.id == 'later'
              ? FactoryMapStatus.pending
              : FactoryMapStatus.wipReady);
    }
    expect(
        productionMapStageDisplayStatus(
            map: map,
            node: map.nodes.first,
            queueState: ApparatusQueueOrderState.pending,
            control: control()),
        FactoryMapStatus.pending);
  });

  test('all new status labels are localized', () {
    for (final locale in ['uz', 'en', 'ru']) {
      final l10n = AppLocalizations(Locale(locale));
      for (final status in [
        FactoryMapStatus.wipReady,
        FactoryMapStatus.wipWaiting,
        FactoryMapStatus.waitingWip,
        FactoryMapStatus.requeuedReady,
        FactoryMapStatus.requeuedWaiting
      ]) {
        expect(
            l10n.adminText(status.labelKey), isNot(contains('factory_map.')));
      }
    }
  });
}
