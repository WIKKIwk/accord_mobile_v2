import 'package:accord_mobile_v2/src/features/admin/logic/production_map_pechat_rules.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _flexoApparatus = AdminApparatus(
  id: 'apparatus:test:flexo',
  name: 'Flexo pechat',
  operation: 'print',
  technology: 'flexographic',
  colorStations: 8,
  minWebWidthMm: 400,
  maxWebWidthMm: 800,
);
const _colorPrintApparatus = AdminApparatus(
  id: 'apparatus:test:color-print-7',
  name: '7 ta rangli bosma aparat',
  operation: 'print',
  technology: 'rotogravure',
  colorStations: 7,
);

void main() {
  test('transfer checks physical limits even for assigned alternatives', () {
    final source = _colorPrintApparatus.copyWith(colorStations: 8);
    final target = _colorPrintApparatus.copyWith(id: 'apparatus:test:target',
        colorStations: 8, minWebWidthMm: 400, maxWebWidthMm: 600);
    final nodes = [for (final apparatus in [source, target])
      ProductionMapNode(id: apparatus.id, kind: 'apparatus', title: apparatus.name,
          apparatusId: apparatus.id, alternativeGroupId: 'choice',
          alternativeAssignedApparatusId: source.id)];
    bool allowed(AdminApparatus machine, double width) => productionMapCanMoveOrderToApparatus(
        nodes: nodes, fromApparatus: source, toApparatus: machine,
        rollCount: 7, widthMm: width);
    expect(allowed(target, 600), isTrue);
    expect(allowed(target, 601), isFalse);
    expect(allowed(target, 399), isFalse);
    expect(allowed(target.copyWith(lifecycleState: 'inactive'), 600), isFalse);
    expect(productionMapPechatCanHandleOrder(apparatusColorCount: 9,
        rollCount: 7, widthMm: 1500), isFalse);
    expect(allowed(target.copyWith(technology: 'flexographic', maxWebWidthMm: 1500), 1500), isTrue);
  });

  test('print transfer retains original nodes and selects only remaining work', () {
    const target = AdminApparatus(id: 'apparatus:test:target-8', name: 'Bosma 8',
        operation: 'print', technology: 'rotogravure', colorStations: 8);
    var map = ProductionMapDefinition(id: 'zakaz-transfer-history', productCode: 'P', title: 'P',
        nodes: [
          const ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
          ProductionMapNode(id: 'print', kind: 'apparatus', title: 'Bosma 7',
              apparatusId: _colorPrintApparatus.id),
          const ProductionMapNode(id: 'end', kind: 'end', title: 'End'),
        ], edges: const [ProductionMapEdge(from: 'start', to: 'print'),
          ProductionMapEdge(from: 'print', to: 'end')]);
    map = productionMapTransferPrintOccurrence(map: map,
        fromApparatus: _colorPrintApparatus, toApparatus: target)!;
    expect(map.nodes.firstWhere((node) => node.id == 'print').apparatusId, _colorPrintApparatus.id);
    expect(productionMapPrintAssignmentAllowsOrder(map: map, apparatus: _colorPrintApparatus), isFalse);
    expect(productionMapPrintAssignmentAllowsOrder(map: map, apparatus: target), isTrue);
    final third = target.copyWith(id: 'apparatus:test:target-9', colorStations: 9);
    expect(productionMapCanMoveOrderToApparatus(nodes: map.nodes,
        fromApparatus: target, toApparatus: third, rollCount: 7, widthMm: 800), isTrue);
    map = productionMapTransferPrintOccurrence(map: map, fromApparatus: target, toApparatus: third)!;
    expect(map.nodes.where((node) => node.kind == 'apparatus'), hasLength(3));
    expect(productionMapPrintAssignmentAllowsOrder(map: map, apparatus: target), isFalse);
    expect(productionMapPrintAssignmentAllowsOrder(map: map, apparatus: third), isTrue);
  });

  test('single unassigned print candidate needs no dispatch', () {
    for (final machine in [_flexoApparatus, _colorPrintApparatus]) {
      var map = ProductionMapDefinition(
        id: 'zakaz-single-print',
        productCode: 'SINGLE',
        title: 'Single print',
        nodes: [
          ProductionMapNode(
            id: 'print',
            kind: 'apparatus',
            title: 'Display',
            apparatusId: machine.id,
            alternativeGroupId: 'print-group',
          ),
        ],
        edges: const [],
      );
      bool visible(AdminApparatus apparatus) =>
          productionMapPrintAssignmentAllowsOrder(
              map: map, apparatus: apparatus);
      final peer = machine.id == _flexoApparatus.id
          ? _colorPrintApparatus
          : _flexoApparatus;
      expect(visible(machine), isTrue);
      expect(visible(peer), isFalse);

      map = map.copyWith(nodes: [
        map.nodes.single.copyWith(alternativeAssignedApparatusId: machine.id),
      ]);
      expect(visible(machine), isTrue);

      map = map.copyWith(nodes: [
        map.nodes.single.copyWith(alternativeAssignedApparatusId: peer.id),
      ]);
      expect(visible(machine), isFalse,
          reason: 'an explicit assignment must not be overridden');
      expect(visible(peer), isFalse);
    }
  });

  test(
      'printing alternatives require assignment by ID, other operations do not',
      () {
    const peer = AdminApparatus(
        id: 'apparatus:test:opaque',
        name: 'Laminatsiya',
        operation: 'print',
        technology: 'rotogravure',
        colorStations: 8);
    var map = ProductionMapDefinition(
      id: 'zakaz-dispatch',
      productCode: 'DISPATCH',
      title: 'Dispatch',
      nodes: [
        for (final machine in [_flexoApparatus, peer])
          ProductionMapNode(
              id: machine.id,
              kind: 'apparatus',
              title: 'Display',
              apparatusId: machine.id,
              alternativeGroupId: 'group')
      ],
      edges: const [],
    );
    bool visible(AdminApparatus machine) =>
        productionMapPrintAssignmentAllowsOrder(map: map, apparatus: machine);
    expect(visible(_flexoApparatus), isFalse);
    expect(visible(peer), isFalse);
    for (final operation in ['laminate', 'cut', 'glue', 'package']) {
      expect(
          visible(
              AdminApparatus(id: peer.id, name: 'Bosma', operation: operation)),
          isTrue);
    }
    map = map.copyWith(nodes: [
      for (final node in map.nodes)
        node.copyWith(alternativeAssignedApparatusId: peer.id)
    ]);
    expect(visible(_flexoApparatus), isFalse);
    expect(visible(peer), isTrue);
    map = map.copyWith(nodes: [
      for (final node in map.nodes)
        node.copyWith(alternativeAssignedApparatusId: _flexoApparatus.id)
    ]);
    expect(visible(_flexoApparatus), isTrue);
    expect(visible(peer), isFalse);
    map = map.copyWith(nodes: [
      for (final node in map.nodes)
        node.copyWith(alternativeAssignedApparatusId: '')
    ]);
    expect(visible(_flexoApparatus), isFalse);
    expect(visible(peer), isFalse);
    map =
        map.copyWith(nodes: [map.nodes.first.copyWith(alternativeGroupId: '')]);
    expect(visible(_flexoApparatus), isTrue,
        reason: 'a direct Flexo needs no dispatch');
  });

  test('apparatus type comes from canonical metadata, not display title', () {
    expect(_flexoApparatus.operation, 'print');
    expect(_flexoApparatus.technology, 'flexographic');
    expect(_colorPrintApparatus.operation, 'print');
    expect(_colorPrintApparatus.technology, 'rotogravure');
    expect(_colorPrintApparatus.colorStations, 7);
  });

  test('Flexo profile accepts 400-800mm and at most 8 rolls', () {
    expect(
      productionMapApparatusProfileCanHandleOrder(
        apparatus: _flexoApparatus,
        rollCount: 1,
        widthMm: 400,
      ),
      isTrue,
    );
    expect(
      productionMapApparatusProfileCanHandleOrder(
        apparatus: _flexoApparatus,
        rollCount: 8,
        widthMm: 800,
      ),
      isTrue,
    );
    for (final invalid in const [
      (rollCount: 8.0, widthMm: 399.0),
      (rollCount: 8.0, widthMm: 801.0),
      (rollCount: 9.0, widthMm: 650.0),
    ]) {
      expect(
        productionMapApparatusProfileCanHandleOrder(
          apparatus: _flexoApparatus,
          rollCount: invalid.rollCount,
          widthMm: invalid.widthMm,
        ),
        isFalse,
      );
    }
  });

  test('flexo order moves to compatible pechat with the same formula', () {
    const map = ProductionMapDefinition(
      id: 'zakaz-1119',
      productCode: 'ABCD Family',
      title: 'ABCD Family',
      code: '1119',
      rollCount: 7,
      widthMm: 765,
      nodes: [
        ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
        ProductionMapNode(
          id: 'apparatus',
          kind: 'apparatus',
          title: 'Flexo pechat',
          apparatusId: 'apparatus:test:flexo',
        ),
        ProductionMapNode(id: 'end', kind: 'end', title: 'ABCD Family'),
      ],
      edges: [],
    );

    expect(
      productionMapCanMoveOrderToApparatus(
        nodes: map.nodes,
        fromApparatus: _flexoApparatus,
        toApparatus: _colorPrintApparatus,
        rollCount: map.rollCount,
        widthMm: map.widthMm,
      ),
      isTrue,
    );
  });

  test('color pechat order moves into compatible flexo with the same formula',
      () {
    const map = ProductionMapDefinition(
      id: 'zakaz-0002',
      productCode: 'Imperator salyami',
      title: 'Imperator salyami',
      code: '0002',
      rollCount: 7,
      widthMm: 515,
      nodes: [
        ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
        ProductionMapNode(
          id: 'apparatus',
          kind: 'apparatus',
          title: '7 ta rangli bosma aparat',
          apparatusId: 'apparatus:test:color-print-7',
        ),
        ProductionMapNode(
          id: 'end',
          kind: 'end',
          title: 'Imperator salyami',
        ),
      ],
      edges: [],
    );

    expect(
      productionMapCanMoveOrderToApparatus(
        nodes: map.nodes,
        fromApparatus: _colorPrintApparatus,
        toApparatus: _flexoApparatus,
        rollCount: map.rollCount,
        widthMm: map.widthMm,
      ),
      isTrue,
    );
  });

  test('all product qolips must be scanned as an exact unique set', () {
    const required = ['QOLIP-1', 'QOLIP-2', 'QOLIP-3', 'QOLIP-4'];

    expect(
      productionMapAllRequiredQolipsScanned(
        requiredQolipCodes: required,
        scannedQolipCodes: const ['QOLIP-1', 'QOLIP-2', 'QOLIP-3'],
      ),
      isFalse,
    );
    expect(
      productionMapAllRequiredQolipsScanned(
        requiredQolipCodes: required,
        scannedQolipCodes: const [
          'qolip-3',
          'QOLIP-1',
          'QOLIP-2',
          'qolip-2',
          'QOLIP-4',
        ],
      ),
      isTrue,
    );
    expect(
      productionMapAllRequiredQolipsScanned(
        requiredQolipCodes: required,
        scannedQolipCodes: const [
          'QOLIP-1',
          'QOLIP-2',
          'QOLIP-3',
          'QOLIP-4',
          'QOLIP-5',
        ],
      ),
      isFalse,
    );
  });
}
