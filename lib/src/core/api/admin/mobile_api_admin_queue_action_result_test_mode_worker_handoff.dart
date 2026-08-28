part of '../mobile_api.dart';

extension _MobileApiAdminQueueActionWorkerHandoff on _TestModeQueueActionContext {
Future<AdminApparatusQueueActionResult> _runWorkerHandoff() async {
if (!isLaminatsiya ||
            (workerHandoff && removeRollFromApparatus) ||
            (workerHandoff && current != ApparatusQueueOrderState.inProgress) ||
            (removeRollFromApparatus &&
                current != ApparatusQueueOrderState.paused)) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message: 'Bu laminatsiya worker handoff amali hozir mumkin emas',
          );
        }
        bool isNonNegative(double? value) =>
            value != null && value.isFinite && value >= 0;
        final handoffMetricsReady =
            isNonNegative(laminationPrintLeftoverRolls) &&
                isNonNegative(laminationFilmLeftoverRolls) &&
                isNonNegative(totalWaste);
        if (workerHandoff && !handoffMetricsReady) {
          throw const MobileApiException(
            code: 'laminatsiya_completion_metrics_required',
            message: 'Bosmadan, plyonkadan ortgan rulon va chiqindini kiriting',
          );
        }
        final handoffInput = activeInputBatch;
        if (handoffInput == null ||
            handoffInput.wipStatus.trim().toLowerCase() != 'in_use') {
          throw const MobileApiException(
            code: 'progress_batch_not_accepted',
            message: 'Apparatdagi joriy laminatsiya ruloni topilmadi',
          );
        }
        final isHandoff = handoffInput.payloadJson['worker_handoff'] == true;
        if (removeRollFromApparatus && !isHandoff) {
          throw const MobileApiException(
            code: 'progress_batch_not_accepted',
            message: 'Bu rulon worker handoff holatida emas',
          );
        }
        if (removeRollFromApparatus &&
            (!isPositive(finishedGoodsMeter ?? producedQty) ||
                !isPositive(finishedGoodsKg ?? grossQty))) {
          throw const MobileApiException(
            code: 'laminatsiya_completion_metrics_required',
            message: 'Rulonni yechish uchun metraj va og‘irlikni kiriting',
          );
        }
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final updatedInput = removeRollFromApparatus
            ? handoffInput.copyWith(
                wipStatus: 'waiting',
                currentApparatus: storageKey,
                currentLocation: '$storageKey olib tashlandi',
                usedBySessionId: '',
                usedByApparatus: '',
                payloadJson: {
                  ...handoffInput.payloadJson,
                  'worker_handoff': false,
                  'roll_removed_from_apparatus': true,
                  'roll_removed_at_unix': now,
                  'roll_removed_finished_goods_meter':
                      finishedGoodsMeter ?? producedQty,
                  'roll_removed_finished_goods_kg': finishedGoodsKg ?? grossQty,
                  if (bobinaKg != null) 'roll_removed_bobina_kg': bobinaKg,
                },
              )
            : handoffInput.copyWith(
                wipStatus: 'in_use',
                currentApparatus: storageKey,
                currentLocation: storageKey,
                usedBySessionId: 'test-session-${orderId.trim()}',
                usedByApparatus: storageKey,
                payloadJson: {
                  ...handoffInput.payloadJson,
                  'worker_handoff': true,
                  'roll_removed_from_apparatus': false,
                  'worker_handoff_at_unix': now,
                  'lamination_print_leftover_rolls':
                      laminationPrintLeftoverRolls,
                  'lamination_film_leftover_rolls': laminationFilmLeftoverRolls,
                  'total_waste': totalWaste,
                  if (bobinaKg != null) 'bobina_kg': bobinaKg,
                },
              );
        _testModeProgressBatchesByQr[updatedInput.qrPayload] = updatedInput;
        _testModeActiveProgressInputByQueue[queueInputKey] =
            updatedInput.qrPayload;
        states[orderId.trim()] = 'paused';
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
        return AdminApparatusQueueActionResult(
          states: Map<String, String>.unmodifiable(states),
        );
}
}
