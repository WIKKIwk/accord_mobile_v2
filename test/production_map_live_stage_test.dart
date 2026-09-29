import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/features/admin/logic/apparatus_queue_state.dart';
import 'package:accord_mobile_v2/src/features/admin/logic/factory_map_status.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _cut1 = 'apparatus:default:asset-010';
const _cut5 = 'apparatus:default:asset-014';
const _first = ProductionMapNode(
    id: 'cut1',
    kind: 'apparatus',
    title: 'Rezka',
    apparatusId: _cut1,
    alternativeGroupId: 'cut');
const _active = ProductionMapNode(
    id: 'cut5',
    kind: 'apparatus',
    title: 'Rezka 5',
    apparatusId: _cut5,
    alternativeGroupId: 'cut');
const _later = ProductionMapNode(
    id: 'later', kind: 'apparatus', title: 'Rezka 5 again', apparatusId: _cut5);
ProductionMapDefinition _map({bool repeated = false}) =>
    ProductionMapDefinition(
      id: 'o',
      productCode: '',
      title: '',
      nodes: [_first, _active, if (repeated) _later],
      edges: const [],
    );

void main() {
  for (final stage in ['pending', 'in_progress']) {
    test('active alternative wins over pending representative: stage=$stage',
        () {
      final map = _map();
      final queues = {
        _cut1: {'o': 'pending'},
        _cut5: {'o': 'in_progress'}
      };
      final stages = {'cut1': 'pending', 'cut5': stage};
      final node = productionMapLiveStageNode(
          map: map,
          node: _first,
          orderId: 'o',
          queueStates: queues,
          stageStates: stages,
          controls: const {});
      expect(node.id, 'cut5');
      expect(
          productionMapStageQueueState(
              map: map,
              node: node,
              orderId: 'o',
              queueStates: queues,
              stageStates: stages,
              controls: const {}),
          ApparatusQueueOrderState.inProgress);
    });
  }
  test('another order on an alternative cannot mark this stage active', () {
    expect(
        productionMapLiveStageNode(
            map: _map(),
            node: _first,
            orderId: 'o',
            queueStates: {
              _cut5: {'other': 'in_progress'}
            },
            stageStates: const {
              'cut1': 'pending',
              'cut5': 'pending'
            },
            controls: const {}).id,
        'cut1');
  });
  test('completed alternative is preserved without completing pending peers',
      () {
    final map = _map();
    const stages = {'cut1': 'pending', 'cut5': 'completed'};
    expect(
        productionMapLiveStageNode(
            map: map,
            node: _first,
            orderId: 'o',
            queueStates: const {},
            stageStates: stages,
            controls: const {}).id,
        'cut5');
    expect(
        productionMapStageQueueState(
            map: map,
            node: _active,
            orderId: 'o',
            queueStates: {
              _cut5: {'o': 'pending'}
            },
            stageStates: stages,
            controls: const {}),
        ApparatusQueueOrderState.completed);
  });
  test('a repeated apparatus needs occurrence evidence for an active queue',
      () {
    final map = _map(repeated: true);
    final queues = {
      _cut5: {'o': 'in_progress'}
    };
    expect(
        productionMapStageQueueState(
            map: map,
            node: _active,
            orderId: 'o',
            queueStates: queues,
            stageStates: const {},
            controls: const {}),
        isNull);
    final controls = {
      _cut5: {
        'o': const AdminApparatusQueueOrderActionControl(
          state: 'in_progress',
          stageNodeId: 'later',
          allowedActions: {},
          hasOnlyKnownActions: true,
        )
      }
    };
    expect(
        productionMapStageQueueState(
            map: map,
            node: _active,
            orderId: 'o',
            queueStates: queues,
            stageStates: const {},
            controls: controls),
        isNull);
    expect(
        productionMapStageQueueState(
            map: map,
            node: _later,
            orderId: 'o',
            queueStates: queues,
            stageStates: const {},
            controls: controls),
        ApparatusQueueOrderState.inProgress);
  });
}
