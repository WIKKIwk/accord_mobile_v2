import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/inventory_movement_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    resetMobileApiTestModeData();
  });

  tearDown(() async {
    resetMobileApiTestModeData();
    await TestModeController.instance.setEnabled(false);
  });

  test('training raw material is linked to order and apparatus state',
      () async {
    await TestModeController.instance.setEnabled(true);
    const orderId = 'training-zakaz-1';
    const apparatus = 'Training aparat';
    await MobileApi.instance.adminSaveProductionMap(
      const ProductionMapDefinition(
        id: orderId,
        productCode: 'TRAINING-1',
        title: 'Training order',
        nodes: [
          ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
          ProductionMapNode(
            id: 'training-apparatus',
            kind: 'apparatus',
            title: apparatus,
          ),
          ProductionMapNode(id: 'end', kind: 'end', title: 'End'),
        ],
        edges: [],
      ),
    );
    final material = (await MobileApi.instance.calculateMaterials()).first;

    final assignment = await MobileApi.instance.adminLinkTrainingRawMaterial(
      orderId: orderId,
      apparatus: apparatus,
      materialId: material.id,
      materialName: material.name,
      micron: 50,
      barcode: 'TRN-TRAINING-1',
    );

    expect(assignment.orderId, orderId);
    expect(assignment.apparatus, apparatus);
    expect(assignment.itemName, '${material.name} / 50 mikron');
    expect(assignment.stockStatus, 'available');

    final assignments = await MobileApi.instance.adminRawMaterialAssignments(
      orderId: orderId,
      apparatus: apparatus,
    );
    expect(assignments.map((item) => item.barcode), contains('TRN-TRAINING-1'));
    final lookup = await MobileApi.instance.adminRawMaterialLookup(
      barcode: 'TRN-TRAINING-1',
    );
    expect(lookup.itemName, '${material.name} / 50 mikron');
    expect(lookup.qty, 1);
    expect(lookup.order?.id, orderId);

    final locations = await MobileApi.instance.inventoryLocations();
    expect(
      locations.any(
        (location) =>
            location.isState &&
            location.apparatus.any((item) => item.name == apparatus),
      ),
      isTrue,
    );
    final assets = await MobileApi.instance.inventoryAssets(
      assetKind: InventoryAssetKind.rawMaterial,
      query: 'TRN-TRAINING-1',
    );
    expect(assets, hasLength(1));
    expect(assets.single.physicalLocation.kind, InventoryLocationKind.state);

    final requirements =
        await MobileApi.instance.adminRawMaterialStartRequirements(
      orderId: orderId,
      apparatus: apparatus,
      materialBarcodes: const ['TRN-TRAINING-1'],
    );
    expect(requirements.stagedBarcodes, contains('TRN-TRAINING-1'));
    expect(requirements.scanSatisfied, isTrue);

    await MobileApi.instance.adminDeleteTrainingProductionMap(orderId);
    expect(
      await MobileApi.instance.adminTrainingProductionMaps(id: orderId),
      isEmpty,
    );
    expect(
      await MobileApi.instance.adminRawMaterialAssignments(
        orderId: orderId,
        apparatus: apparatus,
      ),
      isEmpty,
    );
    expect(
      await MobileApi.instance.inventoryAssets(
        assetKind: InventoryAssetKind.rawMaterial,
        query: 'TRN-TRAINING-1',
      ),
      isEmpty,
    );
  });
}
