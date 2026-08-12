import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/inventory_movement_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
    AppSession.instance.token = null;
  });

  test('unavailable training batch list does not block the training page',
      () async {
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'token';
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response('', 404);
    });

    final batches = await http.runWithClient(
      () => MobileApi.instance.adminTrainingInputBatches(),
      () => client,
    );

    expect(batches, isEmpty);
    expect(requests.single.url.path,
        endsWith('/v1/mobile/admin/training/input-batches'));
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

  test('training laminatsiya order gets a Bosma input batch on generation',
      () async {
    await TestModeController.instance.setEnabled(true);
    const draftId = 'zakaz-draft-laminatsiya-input-1';
    const apparatus = 'Laminatsiya 1';
    final saved = await MobileApi.instance.adminSaveTrainingProductionMap(
      const ProductionMapDefinition(
        id: draftId,
        productCode: 'TRAINING-LAM-1',
        title: 'Training laminatsiya order',
        orderKg: 10,
        nodes: [
          ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
          ProductionMapNode(
            id: 'laminatsiya',
            kind: 'apparatus',
            title: apparatus,
          ),
          ProductionMapNode(id: 'end', kind: 'end', title: 'End'),
        ],
        edges: [
          ProductionMapEdge(from: 'start', to: 'laminatsiya'),
          ProductionMapEdge(from: 'laminatsiya', to: 'end'),
        ],
      ),
    );
    expect(saved.map.id, startsWith('training-'));
    final orderId = saved.map.id;
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: apparatus,
      orderIds: [orderId],
    );

    expect(
      await MobileApi.instance.adminWipBatches(
        status: 'all',
        apparatus: 'Bosma aparat',
        nextApparatus: apparatus,
        orderId: orderId,
      ),
      isEmpty,
    );
    await expectLater(
      () => MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: apparatus,
        orderId: orderId,
        action: 'start',
      ),
      throwsA(
        isA<MobileApiException>().having(
          (error) => error.code,
          'code',
          'progress_qr_required',
        ),
      ),
    );

    final generated = await MobileApi.instance.adminGenerateTrainingInputBatch(
      orderId: orderId,
    );
    expect(generated.qrPayload, 'TRAINING-INPUT:$orderId');

    final batches = await MobileApi.instance.adminWipBatches(
      status: 'all',
      apparatus: 'Bosma aparat',
      nextApparatus: apparatus,
      orderId: orderId,
    );
    expect(batches, hasLength(1));
    expect(batches.single.qrPayload, 'TRAINING-INPUT:$orderId');
    expect(batches.single.batchId, 'training-input-batch-$orderId');
    expect(batches.single.payloadJson['training_input'], isTrue);
    expect(batches.single.wipStatus, 'waiting');

    final started = await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: apparatus,
      orderId: orderId,
      action: 'start',
      qrPayload: batches.single.qrPayload,
      progressBatchId: batches.single.batchId,
    );
    expect(started.states[orderId], 'in_progress');

    final completed = await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: apparatus,
      orderId: orderId,
      action: 'complete',
      producedQty: 100,
      grossQty: 10,
      laminationFilmLeftoverRolls: 1,
      totalWaste: 1,
      finishedGoodsKg: 10,
      finishedGoodsMeter: 100,
      uom: 'm',
    );
    expect(completed.states[orderId], 'completed');
  });
}
