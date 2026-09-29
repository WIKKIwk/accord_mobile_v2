import '../../../core/api/mobile_api.dart';
import '../models/production_map_models.dart';
import 'production_map_chain.dart';

class ProductionMapStageWipFacts {
  const ProductionMapStageWipFacts({
    this.produced = 0,
    this.waitingInput = 0,
    this.inUseInput = 0,
    this.processedInput = 0,
  });

  final int produced;
  final int waitingInput;
  final int inUseInput;
  final int processedInput;
}

/// Output proves that a stage produced material, not that its operation closed.
/// Input status belongs to the consumer, never to the producing machine.
ProductionMapStageWipFacts productionMapStageWipFacts({
  required ProductionMapDefinition map,
  required ProductionMapNode node,
  required Iterable<AdminProgressBatch> batches,
}) {
  var produced = 0;
  var waiting = 0;
  var inUse = 0;
  var processed = 0;
  final seen = <String>{};
  for (final batch in batches) {
    if (batch.orderId.trim() != map.id.trim() || batch.wipStatus == 'void') {
      continue;
    }
    final key = batch.batchId.trim().isNotEmpty
        ? batch.batchId.trim()
        : batch.qrPayload.trim();
    if (key.isEmpty || !seen.add(key)) continue;
    final sourceNodeId =
        batch.payloadJson['stage_node_id']?.toString().trim() ?? '';
    // The same occurrence resolver handles alternative apparatuses. With no
    // node id, a repeated machine is ambiguous and must not label every step.
    if (productionMapWipConsumerIds(
      map: map,
      nextApparatus: batch.apparatus,
      nextStageNodeId: sourceNodeId,
      consumerStageNodeId: node.id,
    ).contains(node.apparatusId.trim())) {
      produced++;
    }
    if (!productionMapWipConsumerIds(
      map: map,
      nextApparatus: batch.nextApparatus,
      nextStageNodeId:
          batch.payloadJson['next_stage_node_id']?.toString() ?? '',
      consumerStageNodeId: node.id,
    ).contains(node.apparatusId.trim())) {
      continue;
    }
    switch (batch.wipStatus.trim().toLowerCase()) {
      case 'waiting':
        waiting++;
      case 'in_use':
        inUse++;
      case 'processed':
        processed++;
    }
  }
  return ProductionMapStageWipFacts(
      produced: produced,
      waitingInput: waiting,
      inUseInput: inUse,
      processedInput: processed);
}
