part of '../mobile_api.dart';

extension _MobileApiAdminQueueActionPause on _TestModeQueueActionContext {
Future<AdminApparatusQueueActionResult> _runPauseOrDetach() async {
if (current != ApparatusQueueOrderState.inProgress) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message: 'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
          );
        }
        final hasFreezeSafeStopOutput = rezkaFrames.isNotEmpty ||
            producedQty != null ||
            grossQty != null ||
            finishedGoodsMeter != null ||
            finishedGoodsKg != null ||
            bobinaKg != null ||
            diameter != null ||
            returnInkKg != null ||
            laminationPrintLeftoverRolls != null ||
            laminationFilmLeftoverRolls != null ||
            rezkaBosmaWaste != null ||
            rezkaLaminationWaste != null ||
            rezkaEdgeWaste != null ||
            totalWaste != null;
        final freezeSafeStopIssueNote = completionRequestNote.trim();
        if (freezeRequestSafeStop &&
            !hasFreezeSafeStopOutput &&
            freezeSafeStopIssueNote.isNotEmpty) {
          states[orderId.trim()] = 'frozen';
          _testModeOrderControls[orderId.trim()] =
              AdminOrderControlState.frozen;
          _testModeFrozenIssueNotesByOrderId[orderId.trim()] =
              freezeSafeStopIssueNote;
          _testModeSyncScheduleReservationStatus(
            orderId: orderId,
            apparatusId: storageKey,
            status: 'paused',
          );
          _testModeApparatusQueueStates[storageKey] = states;
          return AdminApparatusQueueActionResult(
            states: Map<String, String>.unmodifiable(states),
            orderControl: AdminOrderControlState.frozen,
          );
        }
        final qty = producedQty ?? finishedGoodsMeter ?? 1;
        final outputBatches = isRezka
            ? _testModeRezkaProgressBatches(
                apparatus: storageKey,
                orderId: orderId.trim(),
                action: action,
                status: action == 'detach_roll' ? 'roll_detached' : 'paused',
                producedQty: qty,
                uom: uom.trim().isEmpty ? 'm' : uom.trim(),
                frameCount: configuredRezkaKadrCount!,
                inputBatch: activeInputBatch,
                rezkaFrames: rezkaFrames,
                diameter: diameter,
                laminationPrintLeftoverRolls: laminationPrintLeftoverRolls,
                laminationFilmLeftoverRolls: laminationFilmLeftoverRolls,
                rezkaBosmaWaste: rezkaBosmaWaste,
                rezkaLaminationWaste: rezkaLaminationWaste,
                rezkaEdgeWaste: rezkaEdgeWaste,
                totalWaste: totalWaste,
                finishedGoodsKg: finishedGoodsKg ?? grossQty,
                finishedGoodsMeter: finishedGoodsMeter ?? producedQty,
                bobinaKg: bobinaKg,
              )
            : [
                _testModeProgressBatch(
                  apparatus: storageKey,
                  orderId: orderId.trim(),
                  action: action,
                  status: action == 'detach_roll' ? 'roll_detached' : 'paused',
                  producedQty: qty,
                  uom: uom.trim().isEmpty && finishedGoodsMeter != null
                      ? 'm'
                      : (uom.trim().isEmpty ? 'kg' : uom.trim()),
                  parentBatchId: activeInputBatch?.batchId ?? '',
                  laminationPrintLeftoverRolls: null,
                  laminationFilmLeftoverRolls:
                      isLaminatsiya ? null : laminationFilmLeftoverRolls,
                  rezkaBosmaWaste: rezkaBosmaWaste,
                  rezkaLaminationWaste: rezkaLaminationWaste,
                  rezkaEdgeWaste: rezkaEdgeWaste,
                  totalWaste: isLaminatsiya ? null : totalWaste,
                  finishedGoodsKg: finishedGoodsKg,
                  finishedGoodsMeter: finishedGoodsMeter,
                  bobinaKg: bobinaKg,
                ),
              ];
        for (final batch in outputBatches) {
          _testModeProgressBatchesByQr[batch.qrPayload] = batch;
        }
        states[orderId.trim()] =
            control == AdminOrderControlState.freezeRequested
                ? 'frozen'
                : 'paused';
        _testModeSyncScheduleReservationStatus(
          orderId: orderId,
          apparatusId: storageKey,
          status: 'paused',
        );
        if (control == AdminOrderControlState.freezeRequested) {
          _testModeOrderControls[orderId.trim()] =
              AdminOrderControlState.frozen;
        }
        _testModeApparatusQueueStates[storageKey] = states;
        final printJobs = _testModeProgressPrintJobs(
          batches: outputBatches,
          printer: printer,
          printMode: printMode,
          customerName: customerName,
        );
        return AdminApparatusQueueActionResult(
          states: Map<String, String>.unmodifiable(states),
          orderControl: control == AdminOrderControlState.freezeRequested
              ? AdminOrderControlState.frozen
              : null,
          progressBatch: outputBatches.first,
          progressBatches: List<AdminProgressBatch>.unmodifiable(outputBatches),
          printJob: printJobs.isEmpty ? null : printJobs.first,
          printJobs: List<UsbRpsPrintRequest>.unmodifiable(printJobs),
        );
}
}
