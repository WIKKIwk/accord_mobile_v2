import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/features/admin/logic/apparatus_queue_state.dart';
import 'package:accord_mobile_v2/src/features/admin/logic/factory_map_status.dart';
import 'package:accord_mobile_v2/src/features/admin/logic/production_map_wip_facts.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:flutter_test/flutter_test.dart';

const lam1 = 'apparatus:default:asset-007';
const lam2 = 'apparatus:default:asset-008';
const cut = 'apparatus:default:asset-010';
const map =
    ProductionMapDefinition(id: 'o', productCode: '', title: '', nodes: [
  ProductionMapNode(id: 'start', kind: 'start', title: ''),
  ProductionMapNode(
      id: 'lam1',
      kind: 'apparatus',
      title: '',
      apparatusId: lam1,
      alternativeGroupId: 'lam'),
  ProductionMapNode(
      id: 'lam2',
      kind: 'apparatus',
      title: '',
      apparatusId: lam2,
      alternativeGroupId: 'lam'),
  ProductionMapNode(id: 'cut', kind: 'apparatus', title: '', apparatusId: cut),
  ProductionMapNode(
      id: 'later', kind: 'apparatus', title: '', apparatusId: lam1),
  ProductionMapNode(id: 'end', kind: 'end', title: ''),
], edges: [
  ProductionMapEdge(from: 'start', to: 'lam1'),
  ProductionMapEdge(from: 'start', to: 'lam2'),
  ProductionMapEdge(from: 'lam1', to: 'cut'),
  ProductionMapEdge(from: 'lam2', to: 'cut'),
  ProductionMapEdge(from: 'cut', to: 'later'),
  ProductionMapEdge(from: 'later', to: 'end'),
]);

AdminProgressBatch batch(String id,
        {String status = 'waiting',
        String producer = lam2,
        String stage = 'lam2',
        String order = 'o'}) =>
    AdminProgressBatch.fromJson({
      'batch_id': id,
      'order_id': order,
      'apparatus': producer,
      'current_apparatus': cut,
      'next_apparatus': cut,
      'action': 'complete',
      'wip_status': status,
      'produced_qty': 9000,
      'uom': 'm',
      'payload_json': {'stage_node_id': stage, 'next_stage_node_id': 'cut'},
    });

void main() {
  test('outputs stay with their producing stage after downstream use', () {
    final batches = [
      for (var i = 0; i < 8; i++)
        batch('$i',
            status: i == 6
                ? 'in_use'
                : i == 7
                    ? 'processed'
                    : 'waiting'),
      batch('0'), // duplicate history row
      batch('other', order: 'another-order'),
      batch('void', status: 'void'),
    ];
    final output = productionMapStageWipFacts(
        map: map, node: map.nodes[1], batches: batches);
    expect(output.produced, 8);
    expect(output.inUseInput, 0);
    final input = productionMapStageWipFacts(
        map: map, node: map.nodes[3], batches: batches);
    expect(input.produced, 0);
    expect(input.waitingInput, 6);
    expect(input.inUseInput, 1);
    expect(input.processedInput, 1);
    expect(
        productionMapStageWipFacts(
                map: map, node: map.nodes[4], batches: batches)
            .produced,
        0);
  });

  test('repeated machines require a concrete source occurrence', () {
    final batches = [
      batch('later', producer: lam1, stage: 'later'),
      batch('ambiguous', producer: lam1, stage: '')
    ];
    expect(
        productionMapStageWipFacts(
                map: map, node: map.nodes[1], batches: batches)
            .produced,
        0);
    expect(
        productionMapStageWipFacts(
                map: map, node: map.nodes[4], batches: batches)
            .produced,
        1);
  });

  test('WIP facts never assert operation completion or permission to start',
      () {
    const output = ProductionMapStageWipFacts(produced: 8);
    expect(
        productionMapStageDisplayStatus(
            map: map,
            node: map.nodes[1],
            queueState: ApparatusQueueOrderState.pending,
            wip: output),
        FactoryMapStatus.wipProduced);
    expect(
        productionMapStageDisplayStatus(
            map: map,
            node: map.nodes[1],
            queueState: ApparatusQueueOrderState.completed,
            wip: output),
        FactoryMapStatus.completed);
    expect(
        productionMapStageDisplayStatus(
            map: map,
            node: map.nodes[1],
            queueState: ApparatusQueueOrderState.paused,
            wip: output),
        FactoryMapStatus.paused);
    expect(
        productionMapStageDisplayStatus(
            map: map,
            node: map.nodes[1],
            queueState: null,
            orderControl: AdminOrderControlState.frozen,
            wip: output),
        FactoryMapStatus.frozen);
    expect(
        productionMapStageDisplayStatus(
            map: map,
            node: map.nodes[3],
            queueState: null,
            wip: const ProductionMapStageWipFacts(waitingInput: 6)),
        FactoryMapStatus.wipAvailable);
    expect(
        productionMapStageDisplayStatus(
            map: map,
            node: map.nodes[3],
            queueState: null,
            wip: const ProductionMapStageWipFacts(
                waitingInput: 6, inUseInput: 1, processedInput: 1)),
        FactoryMapStatus.wipReceived);
    expect(
        productionMapStageDisplayStatus(
            map: map, node: map.nodes[3], queueState: null),
        FactoryMapStatus.unknown);
  });
}
