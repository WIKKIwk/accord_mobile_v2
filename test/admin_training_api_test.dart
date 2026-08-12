import 'dart:convert';

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

  test('legacy training server still generates a printable input batch',
      () async {
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'token';
    const orderId = 'training-legacy-laminatsiya-1';
    const apparatus = 'Laminatsiya 1';
    final map = const ProductionMapDefinition(
      id: orderId,
      productCode: 'TRAINING-LEGACY-1',
      title: 'Legacy training laminatsiya order',
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
    );
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'POST' &&
          request.url.path
              .endsWith('/v1/mobile/admin/training/input-batches')) {
        return http.Response('', 404);
      }
      if (request.method == 'GET' &&
          request.url.path
              .endsWith('/v1/mobile/admin/training/production-maps')) {
        return http.Response(
          jsonEncode({
            'map': map.toJson(),
            'program': {
              'map_id': orderId,
              'product_code': map.productCode,
              'operations': const [],
            },
          }),
          200,
        );
      }
      if (request.method == 'GET' &&
          request.url.path
              .endsWith('/v1/mobile/admin/training/input-batches')) {
        return http.Response('', 404);
      }
      return http.Response('unexpected request', 500);
    });

    final generated = await http.runWithClient(
      () => MobileApi.instance.adminGenerateTrainingInputBatch(
        orderId: orderId,
        apparatus: apparatus,
      ),
      () => client,
    );
    expect(generated.qrPayload, 'TRAINING-INPUT:$orderId');
    expect(generated.batchId, 'training-input-batch-$orderId');
    expect(generated.nextApparatus, apparatus);

    final listed = await http.runWithClient(
      () => MobileApi.instance.adminTrainingInputBatches(orderId: orderId),
      () => client,
    );
    expect(listed, hasLength(1));
    expect(listed.single.qrPayload, generated.qrPayload);
    resetMobileApiTestModeData();
    final listedAfterReload = await http.runWithClient(
      () => MobileApi.instance.adminTrainingInputBatches(orderId: orderId),
      () => client,
    );
    expect(listedAfterReload, hasLength(1));
    expect(listedAfterReload.single.qrPayload, generated.qrPayload);
    expect(
      requests.map((request) => request.url.path),
      contains('/v1/mobile/admin/training/input-batches'),
    );
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
    expect(generated.qrPayload, matches(RegExp(r'^4001[0-9A-F]{20}$')));
    expect(generated.batchId, startsWith('progress-batch:'));
    expect(generated.qrPayload, _productionProgressQr(generated.batchId));

    final scanned = await MobileApi.instance.adminProgressQrLookup(
      generated.qrPayload.toUpperCase(),
    );
    expect(scanned.batchId, generated.batchId);
    expect(scanned.qrPayload, generated.qrPayload);
    final report = await MobileApi.instance.adminProgressQrReport(
      generated.qrPayload.toUpperCase(),
    );
    expect(report.scannedBatch.batchId, generated.batchId);
    final reprint = await MobileApi.instance.adminProgressQrReprint(
      qrPayload: generated.qrPayload.toUpperCase(),
    );
    expect(reprint.batch.batchId, generated.batchId);
    final scannedLegacyLabel = await MobileApi.instance.adminProgressQrLookup(
      'TRAINING-INPUT:$orderId',
    );
    expect(scannedLegacyLabel.batchId, generated.batchId);

    final batches = await MobileApi.instance.adminWipBatches(
      status: 'all',
      apparatus: 'Bosma aparat',
      nextApparatus: apparatus,
      orderId: orderId,
    );
    expect(batches, hasLength(1));
    expect(batches.single.qrPayload, generated.qrPayload);
    expect(batches.single.batchId, generated.batchId);
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

    await MobileApi.instance.adminDeleteTrainingInputBatch(
      orderId: orderId,
      apparatus: apparatus,
      qrPayload: generated.qrPayload,
    );
    expect(
      await MobileApi.instance.adminTrainingInputBatches(orderId: orderId),
      isEmpty,
    );
    await expectLater(
      () => MobileApi.instance.adminProgressQrLookup(generated.qrPayload),
      throwsA(
        isA<MobileApiException>().having(
          (error) => error.code,
          'code',
          'progress_batch_not_found',
        ),
      ),
    );
  });

  test('training rezka order gets a Laminatsiya input batch on generation',
      () async {
    await TestModeController.instance.setEnabled(true);
    const apparatus = 'Rezka 1';
    final result =
        await MobileApi.instance.adminSaveTrainingProductionMapWithOrder(
      map: const ProductionMapDefinition(
        id: 'zakaz-draft-rezka-input-1',
        productCode: 'TRAINING-REZKA-1',
        title: 'Training rezka order',
        orderKg: 10,
        nodes: [
          ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
          ProductionMapNode(
            id: 'rezka',
            kind: 'apparatus',
            title: apparatus,
          ),
          ProductionMapNode(id: 'end', kind: 'end', title: 'End'),
        ],
        edges: [
          ProductionMapEdge(from: 'start', to: 'rezka'),
          ProductionMapEdge(from: 'rezka', to: 'end'),
        ],
      ),
      template: CalculateOrderTemplate.fromJson(const {
        'name': 'Training rezka order',
        'product': 'Training rezka order',
        'frame_product_size_mm': 200,
        'frame_count': 4,
        'width_mm': 810,
        'waste_percent': 5,
      }),
    );
    final saved = result.saved;
    expect(
      saved.map.nodes.firstWhere((node) => node.id == 'rezka').rezkaKadrCount,
      4,
    );
    final orderId = saved.map.id;
    final legacyMap = saved.map.copyWith(
      nodes: saved.map.nodes
          .map(
            (node) => node.id == 'rezka'
                ? const ProductionMapNode(
                    id: 'rezka',
                    kind: 'apparatus',
                    title: apparatus,
                  )
                : node,
          )
          .toList(growable: false),
    );
    await MobileApi.instance.adminSaveTrainingProductionMap(legacyMap);
    expect(
      (await MobileApi.instance.adminTrainingProductionMaps(id: orderId))
          .single
          .map
          .nodes
          .firstWhere((node) => node.id == 'rezka')
          .rezkaKadrCount,
      isNull,
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: apparatus,
      orderIds: [orderId],
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
    expect(generated.apparatus, 'Laminatsiya aparat');
    expect(generated.nextApparatus, apparatus);
    expect(generated.qrPayload, matches(RegExp(r'^4001[0-9A-F]{20}$')));
    expect(generated.qrPayload, _productionProgressQr(generated.batchId));

    final scanned = await MobileApi.instance.adminProgressQrLookup(
      generated.qrPayload,
    );
    expect(scanned.batchId, generated.batchId);
    expect(scanned.apparatus, 'Laminatsiya aparat');
    expect(scanned.nextApparatus, apparatus);

    final batches = await MobileApi.instance.adminWipBatches(
      status: 'all',
      apparatus: 'Laminatsiya aparat',
      nextApparatus: apparatus,
      orderId: orderId,
    );
    expect(batches, hasLength(1));
    expect(batches.single.qrPayload, generated.qrPayload);

    final started = await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: apparatus,
      orderId: orderId,
      action: 'start',
      qrPayload: generated.qrPayload,
      progressBatchId: generated.batchId,
    );
    expect(started.states[orderId], 'in_progress');

    final detached = await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: apparatus,
      orderId: orderId,
      action: 'detach_roll',
      producedQty: 450,
      grossQty: 52,
      finishedGoodsKg: 50,
      finishedGoodsMeter: 450,
      bobinaKg: 2,
      diameter: 30,
      rezkaBosmaWaste: 0.5,
      rezkaLaminationWaste: 1,
      rezkaEdgeWaste: 1.5,
      totalWaste: 3,
      uom: 'm',
    );
    expect(detached.states[orderId], 'paused');
    expect(detached.progressBatches, hasLength(4));
    expect(detached.printJobs, hasLength(4));
    expect(detached.progressBatches.first.totalWaste, 3);
    expect(detached.progressBatches[1].totalWaste, isNull);
    for (var index = 0; index < detached.progressBatches.length; index += 1) {
      final batch = detached.progressBatches[index];
      expect(batch.action, 'detach_roll');
      expect(batch.status, 'roll_detached');
      expect(batch.batchId, endsWith(':frame:${index + 1}'));
      expect(batch.qrPayload, _productionProgressQr(batch.batchId));
      expect(detached.printJobs[index].epc, batch.qrPayload);
    }

    final resumed = await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: apparatus,
      orderId: orderId,
      action: 'resume',
      qrPayload: detached.progressBatches.first.qrPayload,
      progressBatchId: detached.progressBatches.first.batchId,
    );
    expect(resumed.states[orderId], 'in_progress');
    expect(resumed.progressBatches, hasLength(4));
    expect(
      resumed.progressBatches.every((batch) => batch.status == 'resumed'),
      isTrue,
    );

    final completed = await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: apparatus,
      orderId: orderId,
      action: 'complete',
      producedQty: 900,
      grossQty: 104,
      finishedGoodsKg: 100,
      finishedGoodsMeter: 900,
      bobinaKg: 4,
      diameter: 42,
      rezkaBosmaWaste: 1,
      rezkaLaminationWaste: 2,
      rezkaEdgeWaste: 3,
      totalWaste: 6,
      uom: 'm',
    );
    expect(completed.states[orderId], 'completed');
    expect(completed.progressBatches, hasLength(4));
    expect(completed.printJobs, hasLength(4));
    expect(
      completed.progressBatch?.batchId,
      completed.progressBatches.first.batchId,
    );
    expect(completed.printJob?.epc, completed.printJobs.first.epc);
    expect(
      completed.progressBatches.map((batch) => batch.batchId).toSet(),
      hasLength(4),
    );
    expect(
      completed.progressBatches.map((batch) => batch.qrPayload).toSet(),
      hasLength(4),
    );
    for (var index = 0; index < completed.progressBatches.length; index += 1) {
      final batch = completed.progressBatches[index];
      expect(batch.batchId, endsWith(':frame:${index + 1}'));
      expect(batch.qrPayload, _productionProgressQr(batch.batchId));
      expect(batch.parentBatchId, generated.batchId);
      expect(batch.payloadJson['rezka_frame_index'], index + 1);
      expect(batch.payloadJson['rezka_frame_count'], 4);
      expect(batch.payloadJson['rezka_output_kind'], 'frame');
      expect(batch.payloadJson['rezka_metrics_owner'], index == 0);
      expect(completed.printJobs[index].epc, batch.qrPayload);
      final lookedUp = await MobileApi.instance.adminProgressQrLookup(
        batch.qrPayload,
      );
      expect(lookedUp.batchId, batch.batchId);
    }
    expect(completed.progressBatches.first.diameter, 42);
    expect(completed.progressBatches.first.totalWaste, 6);
    expect(completed.progressBatches.first.bobinaKg, 4);
    expect(completed.progressBatches[1].diameter, isNull);
    expect(completed.progressBatches[1].totalWaste, isNull);
    expect(completed.progressBatches[1].bobinaKg, isNull);
    final report = await MobileApi.instance.adminProgressQrReport(
      completed.progressBatches.last.qrPayload,
    );
    expect(
      report.progressBatches.where(
        (batch) =>
            batch.action == 'complete' &&
            batch.payloadJson['rezka_output_kind'] == 'frame',
      ),
      hasLength(4),
    );
  });
}

String _productionProgressQr(String batchId) {
  final stamp = BigInt.parse(batchId.split(':')[1]);
  var hash = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = BigInt.parse('ffffffffffffffff', radix: 16);
  for (final byte in utf8.encode(batchId.trim())) {
    hash = hash ^ BigInt.from(byte);
    hash = (hash * prime) & mask;
  }
  final checksum =
      (hash & BigInt.from(0xffff)).toRadixString(16).padLeft(4, '0');
  return '4001${(stamp & mask).toRadixString(16).padLeft(16, '0')}$checksum'
      .toUpperCase();
}
