import 'package:accord_mobile_v2/src/features/admin/logic/production_map_pechat_rules.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default bosma apparatus names require qolip scan', () {
    for (final colorCount in [7, 8, 9]) {
      final name = '$colorCount ta rangli bosma aparat';
      expect(productionMapPechatColorCount(name), colorCount);
      expect(productionMapApparatusRequiresQolipScan(name), isTrue);
      expect(productionMapQolipScanAllowsStart(name, ''), isFalse);
      expect(productionMapQolipScanAllowsStart(name, 'QOLIP-QR'), isTrue);
    }
  });

  test('legacy pechat aliases still require qolip scan', () {
    expect(
      productionMapApparatusRequiresQolipScan('7 ta rangli pechat - A'),
      isTrue,
    );
    expect(productionMapApparatusRequiresQolipScan('Laminatsiya 1'), isFalse);
  });

  test('flexo belongs to the bosma family without a color count', () {
    expect(productionMapPechatColorCount('Flexo pechat - A'), isNull);
    expect(productionMapIsFlexoApparatus('Flexo pechat - A'), isTrue);
    expect(productionMapIsPechatApparatus('Flexo bosma aparat'), isTrue);
    expect(productionMapApparatusRequiresQolipScan('Flexo pechat'), isTrue);
  });

  test('flexo order is detected from its apparatus node', () {
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
        ),
        ProductionMapNode(id: 'end', kind: 'end', title: 'ABCD Family'),
      ],
      edges: [],
    );

    expect(productionMapIsFlexoOrder(map), isTrue);
    expect(
      productionMapCanMoveOrderToApparatus(
        nodes: map.nodes,
        fromApparatus: 'Flexo pechat',
        toApparatus: '7 ta rangli bosma aparat',
        rollCount: map.rollCount,
        widthMm: map.widthMm,
        isFlexoOrder: productionMapIsFlexoOrder(map),
      ),
      isFalse,
    );
  });

  test('color pechat order cannot move into flexo', () {
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
        ),
        ProductionMapNode(
          id: 'end',
          kind: 'end',
          title: 'Imperator salyami',
        ),
      ],
      edges: [],
    );

    expect(productionMapIsFlexoOrder(map), isFalse);
    expect(
      productionMapCanMoveOrderToApparatus(
        nodes: map.nodes,
        fromApparatus: '7 ta rangli bosma aparat',
        toApparatus: 'Flexo pechat',
        rollCount: map.rollCount,
        widthMm: map.widthMm,
        isFlexoOrder: productionMapIsFlexoOrder(map),
      ),
      isFalse,
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
