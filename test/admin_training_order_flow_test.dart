import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_test_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_training_order_helpers.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('training order flow includes the selected apparatus stage', () {
    const context = ProductionMapOrderContext(
      orderName: 'Training order',
      productName: 'Demo mahsulot',
      itemCode: 'DEMO-001',
      apparatus: '7 ta rangli bosma aparat',
      apparatusId: 'apparatus:default:bosma_7',
    );

    final nodes = productionMapOrderFlowNodes(context);
    final edges = productionMapOrderFlowEdges(context);

    expect(
      nodes.where((node) => node.kind == 'apparatus').map((node) => node.title),
      ['7 ta rangli bosma aparat'],
    );
    expect(
      edges.map((edge) => '${edge.from}->${edge.to}'),
      ['start->order', 'order->apparatus', 'apparatus->end'],
    );
  });

  test('regular order flow stays unchanged without an apparatus', () {
    const context = ProductionMapOrderContext(
      orderName: 'Zakaz',
      productName: 'Mahsulot',
      itemCode: 'ITEM-001',
    );

    expect(productionMapOrderFlowNodes(context), hasLength(3));
    expect(
      productionMapOrderFlowEdges(context)
          .map((edge) => '${edge.from}->${edge.to}'),
      ['start->order', 'order->end'],
    );
  });

  test('order flow rejects a display name without canonical apparatus id', () {
    const context = ProductionMapOrderContext(
      orderName: 'Training order',
      productName: 'Demo mahsulot',
      itemCode: 'DEMO-001',
      apparatus: '7 ta rangli bosma aparat',
    );

    expect(
      () => productionMapOrderFlowNodes(context),
      throwsArgumentError,
    );
    expect(
      () => productionMapOrderFlowEdges(context),
      throwsArgumentError,
    );
  });

  test('linking a training order adds the selected apparatus stage', () {
    const map = ProductionMapDefinition(
      id: 'zakaz-0001',
      productCode: 'DEMO-001',
      title: 'Training order',
      nodes: [
        ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
        ProductionMapNode(id: 'order', kind: 'task', title: 'Training order'),
        ProductionMapNode(id: 'end', kind: 'end', title: 'Demo mahsulot'),
      ],
      edges: [
        ProductionMapEdge(from: 'start', to: 'order'),
        ProductionMapEdge(from: 'order', to: 'end'),
      ],
    );

    final linked = assignTrainingOrderToApparatus(
      map: map,
      apparatus: const AdminApparatus(
        id: 'apparatus:test:print-7',
        name: '7 ta rangli bosma aparat',
        operation: 'print',
      ),
    );

    expect(
      linked.nodes.map((node) => '${node.kind}:${node.title}'),
      [
        'start:Start',
        'task:Training order',
        'apparatus:7 ta rangli bosma aparat',
        'end:Demo mahsulot',
      ],
    );
    expect(
      linked.edges.map((edge) => '${edge.from}->${edge.to}'),
      ['start->order', 'order->training-apparatus', 'training-apparatus->end'],
    );
  });

  test('linking a training order supports a non-printing apparatus', () {
    const map = ProductionMapDefinition(
      id: 'training-laminatsiya-0001',
      productCode: 'DEMO-001',
      title: 'Training order',
      nodes: [
        ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
        ProductionMapNode(id: 'order', kind: 'task', title: 'Training order'),
        ProductionMapNode(id: 'end', kind: 'end', title: 'Demo mahsulot'),
      ],
      edges: [
        ProductionMapEdge(from: 'start', to: 'order'),
        ProductionMapEdge(from: 'order', to: 'end'),
      ],
    );

    final linked = assignTrainingOrderToApparatus(
      map: map,
      apparatus: const AdminApparatus(
        id: 'apparatus:test:lamination-1',
        name: 'Laminatsiya 1',
        operation: 'laminate',
      ),
    );

    expect(
      linked.nodes
          .where((node) => node.kind == 'apparatus')
          .map((node) => node.title),
      ['Laminatsiya 1'],
    );
  });

  test('training order resolves its mold by exact product code', () {
    const order = ProductionMapSaved(
      map: ProductionMapDefinition(
        id: 'training-0001',
        productCode: 'PROD-42',
        title: 'Demo mahsulot',
        nodes: [],
        edges: [],
      ),
      program: ProductionMapProgram(
        mapId: 'training-0001',
        productCode: 'PROD-42',
        operations: [],
      ),
    );
    const products = [
      QolipProduct(
        code: 'PROD-4',
        name: 'Boshqa mahsulot',
        itemGroup: 'group',
        qolipCode: 'MOLD-WRONG',
      ),
      QolipProduct(
        code: 'PROD-42',
        name: 'Demo mahsulot',
        itemGroup: 'group',
        qolipCode: 'MOLD-42',
      ),
    ];

    expect(
      trainingQolipForOrder(order: order, products: products)?.qolipCode,
      'MOLD-42',
    );
  });

  test('training order does not resolve a mold from a partial product code',
      () {
    const order = ProductionMapSaved(
      map: ProductionMapDefinition(
        id: 'training-0002',
        productCode: 'PROD-42',
        title: 'Demo mahsulot',
        nodes: [],
        edges: [],
      ),
      program: ProductionMapProgram(
        mapId: 'training-0002',
        productCode: 'PROD-42',
        operations: [],
      ),
    );

    expect(
      trainingQolipForOrder(
        order: order,
        products: const [
          QolipProduct(
            code: 'PROD-4',
            name: 'Boshqa mahsulot',
            itemGroup: 'group',
            qolipCode: 'MOLD-WRONG',
          ),
        ],
      ),
      isNull,
    );
  });
}
