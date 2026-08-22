import '../models/production_map_models.dart';
import '../../shared/models/app_models.dart';

bool trainingOrderHasApparatus(ProductionMapDefinition map) {
  return map.nodes.any(
    (node) => node.kind == 'apparatus' && node.apparatusId.trim().isNotEmpty,
  );
}

ProductionMapDefinition assignTrainingOrderToApparatus({
  required ProductionMapDefinition map,
  required AdminApparatus apparatus,
}) {
  final targetId = apparatus.id.trim();
  final targetName = apparatus.name.trim();
  if (targetId.isEmpty || targetName.isEmpty) {
    throw ArgumentError.value(apparatus.id, 'apparatus.id');
  }
  if (trainingOrderHasApparatus(map)) {
    throw StateError('Order allaqachon aparatga ulangan');
  }

  ProductionMapNode? orderNode;
  for (final node in map.nodes) {
    if (node.kind == 'task') {
      orderNode = node;
      break;
    }
  }
  final endIndex = map.nodes.indexWhere((node) => node.kind == 'end');
  if (orderNode == null || endIndex < 0) {
    throw StateError('Training order map tuzilmasi noto‘g‘ri');
  }

  final endNode = map.nodes[endIndex];
  var apparatusId = 'training-apparatus';
  var suffix = 2;
  while (map.nodes.any((node) => node.id == apparatusId)) {
    apparatusId = 'training-apparatus-$suffix';
    suffix += 1;
  }
  final apparatusNode = ProductionMapNode(
    id: apparatusId,
    kind: 'apparatus',
    title: targetName,
    apparatusId: targetId,
    roleCode: switch (apparatus.operation.trim().toLowerCase()) {
      'laminate' => 'laminatsiya',
      'cut' => 'rezka',
      'print' => 'pechat',
      final value => value,
    },
    x: endNode.x,
    y: endNode.y,
  );
  final shiftedEnd = endNode.copyWith(y: endNode.y + 132);
  final nodes = [
    for (var index = 0; index < map.nodes.length; index++)
      if (index == endIndex) ...[
        apparatusNode,
        shiftedEnd,
      ] else
        map.nodes[index],
  ];

  final edges = <ProductionMapEdge>[];
  var orderToEndReplaced = false;
  for (final edge in map.edges) {
    if (edge.from == orderNode.id && edge.to == endNode.id) {
      edges.add(ProductionMapEdge(from: orderNode.id, to: apparatusId));
      orderToEndReplaced = true;
    } else {
      edges.add(edge);
    }
  }
  if (!orderToEndReplaced) {
    edges.add(ProductionMapEdge(from: orderNode.id, to: apparatusId));
  }
  edges.add(ProductionMapEdge(from: apparatusId, to: endNode.id));

  return map.copyWith(nodes: nodes, edges: edges);
}
