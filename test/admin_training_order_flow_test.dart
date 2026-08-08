import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_test_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('training order flow includes the selected apparatus stage', () {
    const context = ProductionMapOrderContext(
      orderName: 'Training order',
      productName: 'Demo mahsulot',
      itemCode: 'DEMO-001',
      apparatus: '7 ta rangli bosma aparat',
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
}
