import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/print_transport.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _laminationId = 'apparatus:default:asset-007';
const _printingId = 'apparatus:default:bosma_7';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    resetMobileApiTestModeData();
    await TestModeController.instance.setEnabled(true);
  });

  tearDown(() async {
    resetMobileApiTestModeData();
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    await TestModeController.instance.setEnabled(false);
  });

  test('serializes the complete Opening WIP roll passport', () {
    const input = AdminOpeningWipBatchInput(
      quantityBasis: AdminOpeningWipQuantityBasis.measured,
      finishedGoodsMeter: 125,
      finishedGoodsKg: 12,
      bobinaKg: 1,
    );

    expect(input.toJson(), {
      'quantity_basis': 'measured',
      'finished_goods_meter': 125,
      'finished_goods_kg': 12,
      'bobina_kg': 1,
    });
  });

  test('parses the durable Opening WIP intake and batch contract', () {
    final record = AdminOpeningWipRecord.fromJson({
      'intake': {
        'intake_id': 'opening-wip-1',
        'idempotency_key': 'request-1',
        'order_id': 'ORDER-1',
        'entry_apparatus': _laminationId,
        'source_operation': 'Bosma',
        'current_location': 'Laminatsiya oldi',
        'resume_apparatus': _laminationId,
        'resume_stage_node_id': 'lamination',
        'history_status': 'unavailable_before_cutover',
        'status': 'confirmed',
        'actor': {
          'role': 'admin',
          'ref_': 'admin-1',
          'display_name': 'Admin One',
        },
        'created_at_unix': 100,
        'updated_at_unix': 100,
      },
      'batches': [
        {
          'batch_id': 'opening-wip-batch-1',
          'intake_id': 'opening-wip-1',
          'order_id': 'ORDER-1',
          'sequence_no': 1,
          'qr_payload': 'OPENING-WIP:batch-1',
          'quantity_basis': 'estimated',
          'quantity': 125.5,
          'uom': 'kg',
          'finished_goods_meter': 125.5,
          'finished_goods_kg': 12.5,
          'bobina_kg': 1.1,
          'wip_status': 'waiting',
          'label_item_code': 'ORDER-1',
          'label_item_name': 'Opening WIP 1/1',
          'created_at_unix': 100,
          'updated_at_unix': 100,
        },
      ],
    });

    expect(record.intake.historyStatus, 'unavailable_before_cutover');
    expect(record.intake.resumeApparatus, _laminationId);
    expect(record.intake.resumeStageNodeId, 'lamination');
    expect(record.intake.actorDisplayName, 'Admin One');
    expect(
      record.batches.single.quantityBasis,
      AdminOpeningWipQuantityBasis.estimated,
    );
    expect(record.batches.single.quantity, 125.5);
    expect(record.batches.single.finishedGoodsMeter, 125.5);
    expect(record.batches.single.finishedGoodsKg, 12.5);
    expect(record.batches.single.bobinaKg, 1.1);
  });

  test('test mode creates idempotently, lists, and prepares every roll QR',
      () async {
    await MobileApi.instance.adminSaveProductionMap(_openingWipMap());
    const input = AdminOpeningWipCreateInput(
      idempotencyKey: 'opening-wip-request-1',
      orderId: 'ORDER-1',
      sourceApparatus: _printingId,
      sourceStageNodeId: 'printing',
      batches: [
        AdminOpeningWipBatchInput(
          quantityBasis: AdminOpeningWipQuantityBasis.estimated,
          finishedGoodsMeter: 100,
          finishedGoodsKg: 10,
          bobinaKg: 1,
        ),
        AdminOpeningWipBatchInput(
          quantityBasis: AdminOpeningWipQuantityBasis.measured,
          finishedGoodsMeter: 120,
          finishedGoodsKg: 12,
          bobinaKg: 1.2,
        ),
      ],
    );

    final created = await MobileApi.instance.adminCreateOpeningWip(input);
    final replayed = await MobileApi.instance.adminCreateOpeningWip(input);
    final records = await MobileApi.instance.adminOpeningWipRecords(
      orderId: 'ORDER-1',
      status: 'waiting',
    );

    expect(created.batches, hasLength(2));
    expect(created.intake.entryApparatus, _printingId);
    expect(created.intake.sourceApparatus, _printingId);
    expect(created.intake.sourceStageNodeId, 'printing');
    expect(created.intake.resumeApparatus, isEmpty);
    expect(replayed.intake.intakeId, created.intake.intakeId);
    expect(records, hasLength(1));

    await AppSession.instance.setSession(
      token: 'opening-wip-worker-token',
      profile: const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Laminatsiya worker',
        legalName: '',
        ref: 'opening-wip-worker',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.manage'],
        assignedApparatus: [_printingId, _laminationId],
      ),
    );
    final candidates = await MobileApi.instance.adminOpeningWipCandidates(
      apparatus: _laminationId,
      orderId: 'ORDER-1',
    );
    expect(candidates.map((batch) => batch.batchId), [
      for (final batch in created.batches) batch.batchId,
    ]);
    final lookedUp = await MobileApi.instance.adminLookupOpeningWip(
      apparatus: _laminationId,
      orderId: 'ORDER-1',
      qrPayload: created.batches.first.qrPayload,
    );
    expect(lookedUp.batchId, created.batches.first.batchId);
    await expectLater(
      MobileApi.instance.adminLookupOpeningWip(
        apparatus: _printingId,
        orderId: 'ORDER-1',
        qrPayload: created.batches.first.qrPayload,
      ),
      throwsA(
        isA<MobileApiException>().having(
          (error) => error.code,
          'code',
          'opening_wip_qr_mismatch',
        ),
      ),
    );
    await expectLater(
      MobileApi.instance.adminLookupOpeningWip(
        apparatus: _laminationId,
        orderId: 'ORDER-OTHER',
        qrPayload: created.batches.first.qrPayload,
      ),
      throwsA(
        isA<MobileApiException>().having(
          (error) => error.code,
          'code',
          'opening_wip_qr_mismatch',
        ),
      ),
    );

    for (final batch in created.batches) {
      final printed = await MobileApi.instance.adminPrintOpeningWip(
        batchId: batch.batchId,
        printTransport: PrintTransport.offline,
      );
      expect(printed.ok, isTrue);
      expect(printed.printJob?.epc, batch.qrPayload);
      expect(printed.printJob?.isProgressLabel, isTrue);
      expect(printed.printJob?.grossQty, batch.finishedGoodsKg);
      expect(printed.printJob?.progressQty, batch.finishedGoodsMeter);
      expect(printed.printJob?.tareKg, batch.bobinaKg);
    }

    await expectLater(
      MobileApi.instance.adminCreateOpeningWip(
        const AdminOpeningWipCreateInput(
          idempotencyKey: 'opening-wip-request-1',
          orderId: 'ORDER-1',
          sourceApparatus: _printingId,
          sourceStageNodeId: 'printing',
          note: 'conflicting replay',
          batches: [
            AdminOpeningWipBatchInput(
              quantityBasis: AdminOpeningWipQuantityBasis.measured,
              finishedGoodsMeter: 100,
              finishedGoodsKg: 10,
              bobinaKg: 1,
            ),
          ],
        ),
      ),
      throwsA(
        isA<MobileApiException>().having(
          (error) => error.code,
          'code',
          'opening_wip_idempotency_conflict',
        ),
      ),
    );
  });
}

ProductionMapDefinition _openingWipMap() {
  return const ProductionMapDefinition(
    id: 'ORDER-1',
    productCode: 'OPENING-WIP',
    title: 'Opening WIP',
    nodes: [
      ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
      ProductionMapNode(
        id: 'printing',
        kind: 'apparatus',
        title: '7 ta rangli bosma aparat',
        apparatusId: _printingId,
      ),
      ProductionMapNode(
        id: 'lamination',
        kind: 'apparatus',
        title: 'Laminatsiya 1',
        apparatusId: _laminationId,
      ),
      ProductionMapNode(id: 'end', kind: 'end', title: 'End'),
    ],
    edges: [
      ProductionMapEdge(from: 'start', to: 'printing'),
      ProductionMapEdge(from: 'printing', to: 'lamination'),
      ProductionMapEdge(from: 'lamination', to: 'end'),
    ],
  );
}
