part of '../mobile_api.dart';

extension _MobileApiAdminQueueActionStart on _TestModeQueueActionContext {
Future<AdminApparatusQueueActionResult> _runStart() async {
if (_testModeRequeuedOrderIds.contains(orderId.trim())) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message:
                'Muzlatishdan qaytgan order Resume orqali davom ettiriladi',
          );
        }
        if (hasPreviousStage && startInputBatch == null) {
          throw const MobileApiException(
            code: 'progress_qr_required',
            message: 'Oldingi bosqich QR sini scan qiling',
          );
        }
        if (progressKey.isNotEmpty) {
          final batch = startInputBatch;
          final batchAction = batch?.action.trim().toLowerCase() ?? '';
          final batchStatus = batch?.status.trim().toLowerCase() ?? '';
          final batchWipStatus = batch?.wipStatus.trim().toLowerCase() ?? '';
          final batchNextApparatus = batch?.nextApparatus.trim() ?? '';
          if (batch == null) {
            throw const MobileApiException(
              code: 'progress_batch_not_accepted',
              message: 'Bu QR oldingi bosqich mahsulotiga mos emas',
            );
          }
          if ((progressBatchId.trim().isNotEmpty &&
                  batch.batchId.trim() != progressBatchId.trim()) ||
              batch.orderId.trim() != orderId.trim() ||
              (batchAction != 'pause' &&
                  batchAction != 'detach_roll' &&
                  batchAction != 'roll_complete' &&
                  batchAction != 'complete') ||
              (batchStatus != 'paused' &&
                  batchStatus != 'roll_detached' &&
                  batchStatus != 'completed' &&
                  batchStatus != 'resumed') ||
              (hasPreviousStage &&
                  ((batchWipStatus.isNotEmpty && batchWipStatus != 'waiting') ||
                      batch.apparatus.trim() != previousStage ||
                      (batchNextApparatus.isNotEmpty &&
                          batchNextApparatus != storageKey)))) {
            throw const MobileApiException(
              code: 'progress_batch_not_accepted',
              message: 'Bu QR oldingi bosqich mahsulotiga mos emas',
            );
          }
        }
        if (current != ApparatusQueueOrderState.pending) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message: 'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
          );
        }
        final requiredMaterials = _testModeRawMaterialAssignments
            .where(
              (assignment) =>
                  assignment.orderId.trim() == orderId.trim() &&
                  assignment.apparatus.trim() == storageKey,
            )
            .toList(growable: false);
        final requiredBarcodes = {
          for (final assignment in requiredMaterials)
            _normalizeRawMaterialBarcode(assignment.barcode),
        }..remove('');
        final scannedBarcodes = {
          for (final barcode in [
            ...materialBarcodes,
            if (materialBarcode.trim().isNotEmpty) materialBarcode,
          ])
            _normalizeRawMaterialBarcode(barcode),
        }..remove('');
        if (!laminatsiyaWipCanReuseMaterial) {
          final requirements = await adminRawMaterialStartRequirements(
            orderId: orderId,
            apparatus: apparatus,
            materialBarcodes: scannedBarcodes.toList(growable: false),
          );
          if (requiredBarcodes.isEmpty &&
              requirements.requiresMaterial &&
              !isLaminatsiya) {
            throw const MobileApiException(
              code: 'raw_material_assignment_not_found',
              message: 'Homashyo biriktirilmagan',
            );
          }
          if (requiredBarcodes.isNotEmpty && scannedBarcodes.isEmpty) {
            throw const MobileApiException(
              code: 'raw_material_scan_required',
              message:
                  'Ishni boshlash uchun biriktirilgan homashyolarni skaner qiling',
            );
          }
          if (!requiredBarcodes.containsAll(scannedBarcodes)) {
            throw const MobileApiException(
              code: 'raw_material_mismatch',
              message: 'Bu homashyo ish boshlash uchun mos emas',
            );
          }
          if (requirements.policy == AdminRawMaterialStartPolicy.stateAll &&
              requiredBarcodes.isNotEmpty &&
              requirements.normalizedStagedBarcodes.isEmpty) {
            throw const MobileApiException(
              code: 'raw_material_state_not_ready',
              message: 'Apparat oldiga homashyo olib kelinmagan',
            );
          }
          if (!requirements.assignmentsSatisfied &&
              !(isLaminatsiya && requiredBarcodes.isEmpty)) {
            throw const MobileApiException(
              code: 'raw_material_assignment_not_found',
              message: 'Majburiy homashyo guruhlari to‘liq biriktirilmagan',
            );
          }
          if (requiredBarcodes.isNotEmpty && !requirements.scanSatisfied) {
            throw MobileApiException(
              code: requirements.policy == AdminRawMaterialStartPolicy.stateAll
                  ? 'raw_material_scan_incomplete'
                  : 'raw_material_requirement_not_met',
              message: requirements.policy ==
                      AdminRawMaterialStartPolicy.stateAll
                  ? 'Apparat oldidagi barcha homashyolarni skaner qiling'
                  : 'Har bir majburiy guruhdan minimum homashyo skaner qiling',
            );
          }
        }
        if (startInputBatch != null) {
          final inputForStation = startInputBatch.copyWith(
            wipStatus: 'in_use',
            currentApparatus: apparatus,
            currentLocation: apparatus,
            usedBySessionId: 'test-session-${orderId.trim()}',
            usedByApparatus: apparatus,
          );
          _testModeProgressBatchesByQr[inputForStation.qrPayload] =
              inputForStation;
          _testModeActiveProgressInputByQueue[queueInputKey] =
              inputForStation.qrPayload;
          if (inputForStation.payloadJson['training_input'] == true) {
            _testModeTrainingInputBatchSetClosedOrderIds.add(orderId.trim());
          }
        }
        _testModeEnsureApparatusExecutionCapacity(
          apparatusId: storageKey,
          orderId: orderId,
        );
        states[orderId.trim()] = 'in_progress';
        _testModeOrderStartedAtUnix.putIfAbsent(
          orderId.trim(),
          _testModeUnixSeconds,
        );
        for (var index = 0;
            index < _testModeRawMaterialAssignments.length;
            index += 1) {
          final assignment = _testModeRawMaterialAssignments[index];
          if (assignment.orderId.trim() == orderId.trim() &&
              assignment.apparatus.trim() == storageKey &&
              scannedBarcodes.contains(
                assignment.barcode.trim().toUpperCase(),
              )) {
            _testModeRawMaterialAssignments[index] = assignment.copyWith(
              stockStatus: 'in_use',
              reservedOrderId: orderId.trim(),
            );
          }
        }
if (action == 'start') {
        _testModeSyncScheduleReservationStatus(
          orderId: orderId,
          apparatusId: storageKey,
          status: 'active',
        );
      }
      _testModeApparatusQueueStates[storageKey] = states;
      return AdminApparatusQueueActionResult(
        states: Map<String, String>.unmodifiable(states),
      );
}
}
