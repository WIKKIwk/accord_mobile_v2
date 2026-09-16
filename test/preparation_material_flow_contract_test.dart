import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/features/gscale/gscale_mobile_app.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const apparatus = 'apparatus:default:bosma_9';

  test('receipt order and explicit apparatus travel in the batch request', () {
    final request = buildGScaleRpsBatchStartRequest(
      orderId: 'zakaz-17', apparatus: apparatus,
      driverUrl: 'http://localhost:3000',
      item: const MobileItem(itemCode: 'PE', itemName: 'PE', requiresDimensions: true),
      warehouse: 'Raw W', printer: 'zebra', printMode: 'label',
      quantitySource: 'manual', manualQtyKg: 48, tareEnabled: false, tareKg: 0,
      widthMm: 2030, micron: 12, lengthM: 100,
    );
    expect(request.toJson()['order_id'], 'zakaz-17');
    expect(request.toJson()['apparatus'], apparatus);
    expect(request.toJson()['width_mm'], 2030);
  });

  test('server batch restores immutable order context for printing and updates', () {
    final batch = GScaleRpsBatchSession.fromJson({
      'id': 'batch-1', 'active': true, 'revision': 2,
      'order_assignment': {'order_id': 'zakaz-17', 'apparatus': apparatus},
    });
    final update = GScaleRpsBatchUpdateRequest(
      batchId: batch.id, expectedRevision: batch.revision,
      itemCode: 'PE', itemName: 'PE', warehouse: 'Raw W',
      orderId: batch.orderId, apparatus: batch.apparatus,
    );
    expect(update.toJson()['order_id'], 'zakaz-17');
    expect(update.toJson()['apparatus'], apparatus);
    expect(GScaleRpsBatchSession.fromJson({'id': 'legacy'}).orderId, isEmpty);
  });

  test('catalog keeps server-authorized apparatus choices and display labels', () {
    final item = SupplierItem.fromJson({
      'code': 'PE', 'name': 'PE',
      'order_apparatus_options': {apparatus: '9 ta rangli pechat'},
    });
    expect(item.orderApparatusOptions, {apparatus: '9 ta rangli pechat'});
  });

  test('worker keeps pending and ready materials distinct after stock updates', () {
    for (final status in ['needs_cutting', 'width_mismatch', 'awaiting_delivery', 'ready', 'in_use']) {
      final material = AdminRawMaterialAssignment.fromJson({
        'order_id': 'zakaz-17', 'apparatus': apparatus, 'barcode': '30AA',
        'execution_status': status,
      });
      expect(material.executionStatus, status);
      expect(material.copyWith(stockQty: 9).executionStatus, status);
    }
  });
}
