import 'dart:convert';

import 'package:accord_mobile_v2/src/core/godex_rps_renderer.dart';
import 'package:accord_mobile_v2/src/core/native_usb_printer.dart';
import 'package:accord_mobile_v2/src/core/printing/progress_bluetooth_layout.dart';
import 'package:accord_mobile_v2/src/core/zebra_rps_renderer.dart';
import 'package:accord_mobile_v2/src/features/admin/logic/production_map_chain.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cut = 'apparatus:default:asset-010';
  const lamination = 'apparatus:default:asset-007';
  const map = ProductionMapDefinition(
    id: 'order',
    productCode: 'PRODUCT',
    title: 'Order',
    includeBobinaInNet: true,
    nodes: [
      ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
      ProductionMapNode(
          id: 'cut1', kind: 'apparatus', title: 'Rezka', apparatusId: cut),
      ProductionMapNode(
          id: 'lam',
          kind: 'apparatus',
          title: 'Laminatsiya',
          apparatusId: lamination),
      ProductionMapNode(
          id: 'cut2', kind: 'apparatus', title: 'Rezka', apparatusId: cut),
      ProductionMapNode(id: 'end', kind: 'end', title: 'End'),
    ],
    edges: [
      ProductionMapEdge(from: 'start', to: 'cut1'),
      ProductionMapEdge(from: 'cut1', to: 'lam'),
      ProductionMapEdge(from: 'lam', to: 'cut2'),
      ProductionMapEdge(from: 'cut2', to: 'end'),
    ],
  );

  test('only the final cutting occurrence includes the bobina', () {
    bool enabled(ProductionMapDefinition order, String stage,
            {bool cut = true}) =>
        productionMapIncludesBobinaInOutputNet(
            map: order, isRezka: cut, stageNodeId: stage);
    expect(enabled(map, 'cut1'), isFalse);
    expect(enabled(map, 'cut2'), isTrue);
    expect(enabled(map, 'cut2', cut: false), isFalse);
    expect(enabled(map, ''), isFalse);
    expect(enabled(map, 'unknown'), isFalse);
    expect(enabled(map.copyWith(includeBobinaInNet: false), 'cut2'), isFalse);
    expect(ProductionMapDefinition.fromJson(map.toJson()).includeBobinaInNet,
        isTrue);
  });

  test('special progress label keeps total as netto without brutto', () {
    final request = UsbRpsPrintRequest.fromPrintJson({
      'epc': '3034257BF7194E406994036B',
      'item_code': 'PRODUCT',
      'item_name': 'Product',
      'warehouse': 'Accord',
      'printer': 'zebra',
      'print_mode': 'label',
      'gross_qty': 51.0,
      'tare_enabled': true,
      'tare_kg': 1.0,
      'label_kind': 'progress',
      'progress_qty': 100.0,
      'progress_unit': 'm',
      'include_bobina_in_net': true,
    });
    expect(request.netQty, 51);
    expect(request.toJson()['include_bobina_in_net'], isTrue);
    final lines = buildBluetoothProgressLayout(request.toJson())
        .lines
        .map((line) => line['text'].toString())
        .join(' ');
    expect(lines, contains('NETTO: 51.00'));
    expect(lines, isNot(contains('BRUTTO:')));
    final zebra = utf8.decode(ZebraRpsRenderer.render(request));
    expect(zebra, contains('NETTO: 51 kg'));
    expect(zebra, isNot(contains('BRUTTO:')));
    final godex = String.fromCharCodes(GodexRpsRenderer.render(request));
    expect(godex, contains('NETTO: 51 KG'));
    expect(godex, isNot(contains('BRUTTO:')));
  });

  test('ordinary Bluetooth label still subtracts the bobina', () {
    final lines = buildBluetoothProgressLayout({
      'item_name': 'Product',
      'gross_qty': 51.0,
      'tare_kg': 1.0,
    }).lines.map((line) => line['text'].toString()).join(' ');
    expect(lines, contains('NETTO: 50.00'));
    expect(lines, contains('BRUTTO: 51.00'));
  });
}
