import 'package:accord_mobile_v2/src/features/admin/logic/apparatus_queue_state.dart';
import 'package:accord_mobile_v2/src/features/admin/logic/production_map_chain.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _printId = 'apparatus:default:asset-005';
const _lamination1Id = 'apparatus:default:asset-007';
const _lamination2Id = 'apparatus:default:asset-008';
const _cutId = 'apparatus:default:asset-010';

ProductionMapNode _node(
  String id,
  String kind,
  String title, {
  String apparatusId = '',
}) {
  return ProductionMapNode(
    id: id,
    kind: kind,
    title: title,
    apparatusId: apparatusId,
  );
}

ProductionMapDefinition _canonicalMap() {
  return ProductionMapDefinition(
    id: 'zakaz-hot',
    productCode: 'HOT',
    title: 'Hotlunch',
    nodes: [
      _node('start', 'start', 'Start'),
      _node('order', 'task', 'Hotlunch mahsulot'),
      _node(
        'pechat',
        'apparatus',
        'Flexo pechat',
        apparatusId: _printId,
      ),
      _node('lamin-note', 'task', 'Laminatsiya nazorati'),
      _node(
        'rezka',
        'apparatus',
        'Rezka',
        apparatusId: _cutId,
      ),
      _node('end', 'end', 'End'),
    ],
    edges: const [
      ProductionMapEdge(from: 'start', to: 'order'),
      ProductionMapEdge(from: 'order', to: 'pechat'),
      ProductionMapEdge(from: 'pechat', to: 'lamin-note'),
      ProductionMapEdge(from: 'lamin-note', to: 'rezka'),
      ProductionMapEdge(from: 'rezka', to: 'end'),
    ],
  );
}

ProductionMapDefinition _openingWipCutoverMap() {
  return ProductionMapDefinition(
    id: 'zakaz-opening-wip-cutover',
    productCode: 'OWIP',
    title: 'Opening WIP cutover',
    nodes: [
      _node('start', 'start', 'Start'),
      _node('print', 'apparatus', 'Bosma', apparatusId: _printId),
      _node(
        'lamination',
        'apparatus',
        'Laminatsiya',
        apparatusId: _lamination1Id,
      ),
      _node('rezka', 'apparatus', 'Rezka', apparatusId: _cutId),
      _node('end', 'end', 'End'),
    ],
    edges: const [
      ProductionMapEdge(from: 'start', to: 'print'),
      ProductionMapEdge(from: 'print', to: 'lamination'),
      ProductionMapEdge(from: 'lamination', to: 'rezka'),
      ProductionMapEdge(from: 'rezka', to: 'end'),
    ],
  );
}

void main() {
  test('Opening WIP source advances exactly after its target completes', () {
    final map = _openingWipCutoverMap();

    expect(
      productionMapOpeningWipSourceStages(
        map: map,
        stageStates: const {},
      ).map((stage) => stage.nodeId),
      const ['print', 'lamination'],
    );
    expect(
      productionMapOpeningWipSourceStages(
        map: map,
        stageStates: const {
          'print': 'completed',
          'lamination': 'completed',
          'rezka': 'pending',
        },
      ).map((stage) => stage.nodeId),
      const ['lamination'],
    );
    expect(
      productionMapOpeningWipSourceStages(
        map: map,
        stageStates: const {
          'print': 'completed',
          'lamination': 'completed',
          'rezka': 'completed',
        },
      ),
      isEmpty,
    );
  });

  test('authorized apparatus are exact canonical ids in topology order', () {
    expect(
      productionMapAuthorizedOrderApparatus(
        map: _canonicalMap(),
        assignedApparatus: const [_cutId, _printId],
      ),
      const [_printId, _cutId],
    );
    expect(
      productionMapAuthorizedOrderApparatus(
        map: _canonicalMap(),
        assignedApparatus: const ['Flexo pechat', 'Rezka'],
      ),
      isEmpty,
    );
  });

  test('queue activity state scans canonical apparatus keys', () {
    expect(
      queueActivityStateForOrder(
        orderId: 'zakaz-active',
        queueStatesByApparatus: const {
          _printId: {'zakaz-active': 'completed'},
          _cutId: {'zakaz-active': 'in_progress'},
        },
      ),
      OrderQueueActivityState.inProgress,
    );
    expect(
      queueActivityStateForOrder(
        orderId: 'zakaz-between-stages',
        queueStatesByApparatus: const {
          _printId: {'zakaz-between-stages': 'completed'},
          _cutId: {'zakaz-between-stages': 'pending'},
        },
      ),
      OrderQueueActivityState.waitingNextStage,
    );
    expect(
      queueActivityStateForOrder(
        orderId: 'zakaz-done',
        queueStatesByApparatus: const {
          _printId: {'zakaz-done': 'completed'},
          _cutId: {'zakaz-done': 'completed'},
        },
      ),
      OrderQueueActivityState.completed,
    );
    expect(
      queueActivityStatesForOrders(
        orderIds: const [
          'zakaz-active',
          'zakaz-between-stages',
          'zakaz-visible-waiting',
        ],
        queueStatesByApparatus: const {
          _printId: {
            'zakaz-active': 'completed',
            'zakaz-between-stages': 'completed',
          },
          _cutId: {'zakaz-active': 'in_progress'},
        },
        visibleOrderIdsByApparatus: const {
          _printId: [
            'zakaz-active',
            'zakaz-between-stages',
            'zakaz-visible-waiting',
          ],
          _cutId: ['zakaz-active', 'zakaz-between-stages'],
        },
      ),
      const {
        'zakaz-active': OrderQueueActivityState.inProgress,
        'zakaz-between-stages': OrderQueueActivityState.waitingNextStage,
        'zakaz-visible-waiting': OrderQueueActivityState.pending,
      },
    );
  });

  test('production map node preserves canonical alternative metadata', () {
    const node = ProductionMapNode(
      id: 'apparatus-7',
      kind: 'apparatus',
      title: 'Flexo pechat',
      apparatusId: _printId,
      alternativeGroupId: 'alt-pechat-1',
      alternativeGroupLabel: 'Bosma',
      alternativeAssignedTitle: 'Flexo pechat',
      alternativeAssignedApparatusId: _printId,
    );

    final restored = ProductionMapNode.fromJson(node.toJson());

    expect(restored.apparatusId, _printId);
    expect(restored.alternativeGroupId, 'alt-pechat-1');
    expect(restored.alternativeGroupLabel, 'Bosma');
    expect(restored.alternativeAssignedTitle, 'Flexo pechat');
    expect(restored.alternativeAssignedApparatusId, _printId);
    expect(restored.toJson()['apparatus_id'], _printId);
    expect(restored.toJson()['alternative_assigned_apparatus_id'], _printId);
  });

  test('production map clears alternative title and id together', () {
    const map = ProductionMapDefinition(
      id: 'zakaz-template',
      productCode: 'ITEM-1',
      title: 'Template',
      nodes: [
        ProductionMapNode(
          id: 'apparatus-7',
          kind: 'apparatus',
          title: 'Flexo pechat',
          apparatusId: _printId,
          alternativeGroupId: 'alt-pechat-1',
          alternativeGroupLabel: 'Bosma',
          alternativeAssignedTitle: 'Flexo pechat',
          alternativeAssignedApparatusId: _printId,
        ),
      ],
      edges: [],
    );

    final cleanNode = map.withoutAlternativeAssignments().nodes.single;

    expect(cleanNode.apparatusId, _printId);
    expect(cleanNode.alternativeGroupId, 'alt-pechat-1');
    expect(cleanNode.alternativeAssignedTitle, isEmpty);
    expect(cleanNode.alternativeAssignedApparatusId, isEmpty);
  });

  test('linear stages separate stable identity from display title', () {
    final stages = productionMapLinearWorkStages(_canonicalMap());

    expect(
      stages.map((stage) => stage.stageId).toList(),
      const [_printId, 'task:lamin-note', _cutId],
    );
    expect(
      stages.map((stage) => stage.displayTitle).toList(),
      const ['Flexo pechat', 'Laminatsiya nazorati', 'Rezka'],
    );
    expect(
      stages.map((stage) => stage.apparatusId).toList(),
      const [_printId, null, _cutId],
    );
  });

  test('linear stages retain repeated physical apparatus occurrences', () {
    const map = ProductionMapDefinition(
      id: 'zakaz-repeated-rezka',
      productCode: 'REZKA-REENTRY',
      title: 'Repeated Rezka',
      nodes: [
        ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
        ProductionMapNode(
          id: 'bosma',
          kind: 'apparatus',
          title: 'Flexo pechat',
          apparatusId: _printId,
        ),
        ProductionMapNode(
          id: 'rezka-before-lamination',
          kind: 'apparatus',
          title: 'Rezka',
          apparatusId: _cutId,
        ),
        ProductionMapNode(
          id: 'lamination',
          kind: 'apparatus',
          title: 'Laminatsiya 1',
          apparatusId: _lamination1Id,
        ),
        ProductionMapNode(
          id: 'rezka-final',
          kind: 'apparatus',
          title: 'Rezka',
          apparatusId: _cutId,
        ),
        ProductionMapNode(id: 'end', kind: 'end', title: 'End'),
      ],
      edges: [
        ProductionMapEdge(from: 'start', to: 'bosma'),
        ProductionMapEdge(from: 'bosma', to: 'rezka-before-lamination'),
        ProductionMapEdge(
          from: 'rezka-before-lamination',
          to: 'lamination',
        ),
        ProductionMapEdge(from: 'lamination', to: 'rezka-final'),
        ProductionMapEdge(from: 'rezka-final', to: 'end'),
      ],
    );

    final stages = productionMapLinearWorkStages(map);

    expect(
      stages.map((stage) => stage.nodeId),
      const [
        'bosma',
        'rezka-before-lamination',
        'lamination',
        'rezka-final',
      ],
    );
    expect(
      stages.map((stage) => stage.stageId),
      const [_printId, _cutId, _lamination1Id, _cutId],
    );
  });

  test('stage states keep final Rezka pending after intermediate completion',
      () {
    const orderId = 'zakaz-repeated-rezka';
    const intermediateRezka = ProductionMapNode(
      id: 'rezka-before-lamination',
      kind: 'apparatus',
      title: 'Rezka',
      apparatusId: _cutId,
    );
    const finalRezka = ProductionMapNode(
      id: 'rezka-final',
      kind: 'apparatus',
      title: 'Rezka',
      apparatusId: _cutId,
    );
    const contaminatedCanonicalStates = {
      _cutId: {orderId: 'completed'},
    };
    const stageStates = {
      'rezka-before-lamination': 'completed',
      'lamination': 'pending',
      'rezka-final': 'pending',
    };

    expect(
      productionMapNodeQueueState(
        node: intermediateRezka,
        orderId: orderId,
        currentStation: _lamination1Id,
        currentQueueStates: const {orderId: 'pending'},
        queueStatesByApparatus: contaminatedCanonicalStates,
        stageStates: stageStates,
      ),
      ApparatusQueueOrderState.completed,
    );
    expect(
      productionMapNodeQueueState(
        node: finalRezka,
        orderId: orderId,
        currentStation: _lamination1Id,
        currentQueueStates: const {orderId: 'pending'},
        queueStatesByApparatus: contaminatedCanonicalStates,
        stageStates: stageStates,
      ),
      ApparatusQueueOrderState.pending,
    );
    expect(
      productionMapNodeIsCurrentOccurrence(
        node: intermediateRezka,
        currentStation: _cutId,
        currentStageNodeId: 'rezka-final',
      ),
      isFalse,
    );
    expect(
      productionMapNodeIsCurrentOccurrence(
        node: finalRezka,
        currentStation: _cutId,
        currentStageNodeId: 'rezka-final',
      ),
      isTrue,
    );
  });

  test('display rename does not change stage identity', () {
    final original = _canonicalMap();
    final renamed = original.copyWith(
      nodes: [
        for (final node in original.nodes)
          node.id == 'pechat' ? node.copyWith(title: 'Yangi bosma nomi') : node,
      ],
    );

    expect(
      productionMapLinearWorkStages(renamed)
          .map((stage) => stage.stageId)
          .toList(),
      productionMapLinearWorkStages(original)
          .map((stage) => stage.stageId)
          .toList(),
    );
    expect(
      productionMapMapHasWorkStageForStation(
        map: renamed,
        station: 'Yangi bosma nomi',
      ),
      isFalse,
    );
  });

  test('invalid apparatus identity cannot authorize downstream task stage', () {
    const map = ProductionMapDefinition(
      id: 'zakaz-invalid-apparatus',
      productCode: 'INVALID',
      title: 'Invalid apparatus identity',
      nodes: [
        ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
        ProductionMapNode(
          id: 'legacy-apparatus',
          kind: 'apparatus',
          title: 'Flexo pechat',
        ),
        ProductionMapNode(
          id: 'legacy-task',
          kind: 'task',
          title: 'Legacy downstream task',
        ),
        ProductionMapNode(
          id: 'rezka',
          kind: 'apparatus',
          title: 'Rezka',
          apparatusId: _cutId,
        ),
        ProductionMapNode(id: 'end', kind: 'end', title: 'End'),
      ],
      edges: [
        ProductionMapEdge(from: 'start', to: 'legacy-apparatus'),
        ProductionMapEdge(from: 'legacy-apparatus', to: 'legacy-task'),
        ProductionMapEdge(from: 'legacy-task', to: 'rezka'),
        ProductionMapEdge(from: 'rezka', to: 'end'),
      ],
    );

    expect(
      productionMapLinearWorkStages(map).map((stage) => stage.stageId),
      const [_cutId],
    );
  });

  test('next and previous skip virtual tasks and return physical ids', () {
    final map = _canonicalMap();

    expect(
      productionMapNextWorkStageStation(map: map, station: _printId),
      _cutId,
    );
    expect(
      productionMapPreviousWorkStageStation(map: map, station: _cutId),
      _printId,
    );
    expect(
      productionMapIsFinalWorkStageStation(map: map, station: _cutId),
      isTrue,
    );
    expect(
      productionMapIsFinalWorkStageStation(
        map: map,
        station: 'task:lamin-note',
      ),
      isFalse,
    );
  });

  test('unassigned alternative group exposes canonical candidates', () {
    const map = ProductionMapDefinition(
      id: 'zakaz-unassigned-laminatsiya',
      productCode: 'ALT',
      title: 'Unassigned laminatsiya',
      nodes: [
        ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
        ProductionMapNode(
          id: 'pechat',
          kind: 'apparatus',
          title: 'Flexo pechat',
          apparatusId: _printId,
        ),
        ProductionMapNode(
          id: 'lamin-1',
          kind: 'apparatus',
          title: 'Laminatsiya 1',
          apparatusId: _lamination1Id,
          alternativeGroupId: 'alt-laminatsiya',
          alternativeGroupLabel: 'Laminatsiya',
        ),
        ProductionMapNode(
          id: 'lamin-2',
          kind: 'apparatus',
          title: 'Laminatsiya 2',
          apparatusId: _lamination2Id,
          alternativeGroupId: 'alt-laminatsiya',
          alternativeGroupLabel: 'Laminatsiya',
        ),
        ProductionMapNode(id: 'end', kind: 'end', title: 'End'),
      ],
      edges: [
        ProductionMapEdge(from: 'start', to: 'pechat'),
        ProductionMapEdge(from: 'pechat', to: 'lamin-1'),
        ProductionMapEdge(from: 'pechat', to: 'lamin-2'),
        ProductionMapEdge(from: 'lamin-1', to: 'end'),
        ProductionMapEdge(from: 'lamin-2', to: 'end'),
      ],
    );

    expect(
      productionMapLinearWorkStages(map).map((stage) => stage.stageId).toList(),
      const [_printId, _lamination1Id, _lamination2Id],
    );
    expect(
      productionMapPreviousWorkStageStation(
        map: map,
        station: _lamination2Id,
      ),
      _printId,
    );
  });

  test('assigned alternative uses assigned canonical id', () {
    const map = ProductionMapDefinition(
      id: 'zakaz-alt-chain',
      productCode: 'ALT',
      title: 'Alternative chain',
      nodes: [
        ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
        ProductionMapNode(
          id: 'pechat',
          kind: 'apparatus',
          title: 'Flexo pechat',
          apparatusId: _printId,
          alternativeGroupId: 'alt-print',
          alternativeAssignedTitle: 'Laminatsiya 1',
          alternativeAssignedApparatusId: _lamination1Id,
        ),
        ProductionMapNode(
          id: 'rezka',
          kind: 'apparatus',
          title: 'Rezka',
          apparatusId: _cutId,
        ),
        ProductionMapNode(id: 'end', kind: 'end', title: 'End'),
      ],
      edges: [
        ProductionMapEdge(from: 'start', to: 'pechat'),
        ProductionMapEdge(from: 'pechat', to: 'rezka'),
        ProductionMapEdge(from: 'rezka', to: 'end'),
      ],
    );

    expect(
      productionMapLinearWorkStages(map).map((stage) => stage.stageId).toList(),
      const [_lamination1Id, _cutId],
    );
    expect(
      productionMapStageDisplayTitle(map: map, station: _lamination1Id),
      'Laminatsiya 1',
    );
  });

  test('later stage readiness reads exact previous apparatus key', () {
    final map = _canonicalMap();

    expect(
      productionMapOrderReadyForStation(
        map: map,
        orderId: 'zakaz-hot',
        station: _cutId,
        queueStatesByApparatus: const {
          _printId: {'zakaz-hot': 'completed'},
        },
      ),
      isTrue,
    );
    expect(
      productionMapOrderReadyForStation(
        map: map,
        orderId: 'zakaz-hot',
        station: _cutId,
        queueStatesByApparatus: const {
          'Flexo pechat': {'zakaz-hot': 'completed'},
        },
      ),
      isFalse,
    );
  });

  test('backend visible order ids accept canonical key only', () {
    const visible = {
      _printId: ['zakaz-visible'],
      _lamination1Id: ['zakaz-visible'],
    };

    expect(
      productionMapVisibleOrderIdsForStation(
        visibleOrderIdsByApparatus: visible,
        station: _printId,
      ),
      const ['zakaz-visible'],
    );
    expect(
      productionMapVisibleOrderIdsForStation(
        visibleOrderIdsByApparatus: visible,
        station: 'Flexo pechat',
      ),
      isNull,
    );
  });

  test('station orders come only from backend canonical visibility', () {
    final map = _canonicalMap();
    final order = ProductionMapSaved(
      map: map,
      program: const ProductionMapProgram(
        mapId: 'zakaz-hot',
        productCode: 'HOT',
        operations: [],
      ),
    );

    expect(
      productionMapOrdersVisibleByBackendIds(
        orders: [order],
        visibleOrderIdsByApparatus: const {
          _printId: ['zakaz-hot'],
        },
        station: _printId,
      ),
      [order],
    );
    expect(
      productionMapOrdersVisibleByBackendIds(
        orders: [order],
        visibleOrderIdsByApparatus: const {
          'Flexo pechat': ['zakaz-hot'],
        },
        station: _printId,
      ),
      isEmpty,
    );
  });

  test('effective queue sequence removes stale ids and appends visible orders',
      () {
    expect(
      effectiveQueueSequence(
        sequence: const ['old-zakaz', 'zakaz-b'],
        visibleOrderIds: const ['zakaz-a', 'zakaz-b'],
      ),
      const ['zakaz-b', 'zakaz-a'],
    );
  });

  test('first actionable prioritizes active work', () {
    expect(
      firstActionableQueueOrderId(
        sequence: const ['zakaz-a', 'zakaz-b'],
        states: const {'zakaz-b': 'in_progress'},
      ),
      'zakaz-b',
    );
  });
}
