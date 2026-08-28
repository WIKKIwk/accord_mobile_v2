part of '../mobile_api.dart';

extension _MobileApiAdminQueueActionRollComplete on _TestModeQueueActionContext {
Future<AdminApparatusQueueActionResult> _runRollComplete() async {
if (!isRezka || current != ApparatusQueueOrderState.inProgress) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message: 'Rulonni faqat faol Rezka orderida tugatish mumkin',
          );
        }
        final frameCount = configuredRezkaKadrCount;
        if (frameCount == null) {
          throw const MobileApiException(
            code: 'rezka_kadr_count_required',
            message: 'Rezka uchun kadr soni sozlanmagan',
          );
        }
        final rezkaFrameIssues = _testModeRezkaFrameIssues(
          rezkaFrames: rezkaFrames,
          frameCount: frameCount,
          inputProgressBatchId: activeInputBatch?.batchId ?? '',
        );
        _testModeRezkaFrameIssuesByQueue[queueInputKey] = rezkaFrameIssues;
        final outputBatches = _testModeRezkaProgressBatches(
          apparatus: storageKey,
          orderId: orderId.trim(),
          action: 'roll_complete',
          status: 'completed',
          producedQty: producedQty ?? finishedGoodsMeter ?? 1,
          uom: uom.trim().isEmpty ? 'm' : uom.trim(),
          frameCount: frameCount,
          inputBatch: activeInputBatch,
          rezkaFrames: rezkaFrames,
          diameter: diameter,
          rezkaBosmaWaste: rezkaBosmaWaste,
          rezkaLaminationWaste: rezkaLaminationWaste,
          rezkaEdgeWaste: rezkaEdgeWaste,
          totalWaste: totalWaste,
          finishedGoodsKg: finishedGoodsKg ?? grossQty,
          finishedGoodsMeter: finishedGoodsMeter ?? producedQty,
          bobinaKg: bobinaKg,
          rezkaFrameIssues: rezkaFrameIssues,
        );
        for (final batch in outputBatches) {
          _testModeProgressBatchesByQr[batch.qrPayload] = batch;
        }
        if (activeInputBatch != null) {
          final processedInput = _testModeMarkProgressInputProcessed(
            batch: activeInputBatch,
            apparatus: storageKey,
            orderId: orderId,
            rezkaFrameIssues: rezkaFrameIssues,
          );
          _testModeProgressBatchesByQr[processedInput.qrPayload] =
              processedInput;
        }
        _testModeActiveProgressInputByQueue.remove(queueInputKey);
        _testModeEnsureApparatusExecutionCapacity(
          apparatusId: storageKey,
          orderId: orderId,
        );
        _testModeSyncScheduleReservationStatus(
          orderId: orderId,
          apparatusId: storageKey,
          status: 'active',
        );
        _testModeApparatusQueueStates[storageKey] = states;
        final printJobs = _testModeProgressPrintJobs(
          batches: outputBatches,
          printer: printer,
          printMode: printMode,
          customerName: customerName,
        );
        return AdminApparatusQueueActionResult(
          states: Map<String, String>.unmodifiable(states),
          progressBatch: outputBatches.isEmpty ? null : outputBatches.first,
          progressBatches: List<AdminProgressBatch>.unmodifiable(outputBatches),
          printJob: printJobs.isEmpty ? null : printJobs.first,
          printJobs: List<UsbRpsPrintRequest>.unmodifiable(printJobs),
        );
}
}
