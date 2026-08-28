part of '../mobile_api.dart';

extension _MobileApiAdminQueueActionResume on _TestModeQueueActionContext {
Future<AdminApparatusQueueActionResult> _runResume() async {
final requeued = _testModeRequeuedOrderIds.contains(orderId.trim());
        if (current != ApparatusQueueOrderState.paused &&
            current != ApparatusQueueOrderState.frozen &&
            !(requeued && current == ApparatusQueueOrderState.pending)) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message: 'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
          );
        }
        AdminProgressBatch? resumed;
        final resumedBatches = <AdminProgressBatch>[];
        if (progressKey.isNotEmpty) {
          final batch = _testModeProgressBatchForKey(progressKey);
          if (batch == null ||
              (batch.status != 'paused' && batch.status != 'roll_detached') ||
              batch.orderId != orderId.trim() ||
              batch.apparatus.trim() != storageKey) {
            throw const MobileApiException(
              code: 'progress_batch_not_resumable',
              message: 'Bu progress QR davom ettirishga yaramaydi',
            );
          }
          final siblings = _testModeProgressBatchesByQr.values
              .where(
                (candidate) =>
                    candidate.orderId.trim() == orderId.trim() &&
                    candidate.apparatus.trim() == storageKey &&
                    (candidate.action.trim().toLowerCase() == 'pause' ||
                        candidate.action.trim().toLowerCase() ==
                            'detach_roll') &&
                    (candidate.status.trim().toLowerCase() == 'paused' ||
                        candidate.status.trim().toLowerCase() ==
                            'roll_detached') &&
                    candidate.sessionId.trim() == batch.sessionId.trim() &&
                    candidate.parentBatchId.trim() ==
                        batch.parentBatchId.trim(),
              )
              .toList(growable: false);
          for (final sibling in siblings) {
            final updated = sibling.copyWith(status: 'resumed');
            _testModeProgressBatchesByQr[updated.qrPayload] = updated;
            resumedBatches.add(updated);
          }
          resumed = resumedBatches.isEmpty
              ? batch.copyWith(status: 'resumed')
              : resumedBatches.first;
          if (resumedBatches.isEmpty) {
            _testModeProgressBatchesByQr[resumed.qrPayload] = resumed;
            resumedBatches.add(resumed);
          }
        } else if (activeInputBatch != null &&
            (activeInputBatch.payloadJson['worker_handoff'] == true ||
                activeInputBatch.payloadJson['roll_removed_from_apparatus'] ==
                    true)) {
          resumed = activeInputBatch.copyWith(
            wipStatus: 'in_use',
            currentApparatus: storageKey,
            currentLocation: storageKey,
            usedBySessionId: 'test-session-${orderId.trim()}',
            usedByApparatus: storageKey,
            payloadJson: {
              ...activeInputBatch.payloadJson,
              'worker_handoff': false,
              'roll_removed_from_apparatus': false,
              'roll_claimed_after_handoff_at_unix':
                  DateTime.now().millisecondsSinceEpoch ~/ 1000,
            },
          );
          _testModeProgressBatchesByQr[resumed!.qrPayload] = resumed;
          _testModeActiveProgressInputByQueue[queueInputKey] =
              resumed.qrPayload;
        } else if (activeInputBatch != null) {
          final pausedOutputs = _testModeProgressBatchesByQr.values
              .where(
                (batch) =>
                    batch.orderId.trim() == orderId.trim() &&
                    batch.apparatus.trim() == storageKey &&
                    (batch.action.trim().toLowerCase() == 'pause' ||
                        batch.action.trim().toLowerCase() == 'detach_roll') &&
                    (batch.status.trim().toLowerCase() == 'paused' ||
                        batch.status.trim().toLowerCase() == 'roll_detached') &&
                    batch.parentBatchId.trim() ==
                        activeInputBatch.batchId.trim(),
              )
              .toList(growable: false);
          for (final batch in pausedOutputs) {
            final updated = batch.copyWith(status: 'resumed');
            _testModeProgressBatchesByQr[updated.qrPayload] = updated;
            resumedBatches.add(updated);
          }
          if (resumedBatches.isNotEmpty) {
            resumed = resumedBatches.first;
          }
        }
        _testModeEnsureApparatusExecutionCapacity(
          apparatusId: storageKey,
          orderId: orderId,
        );
        states[orderId.trim()] = 'in_progress';
        _testModeRequeuedOrderIds.remove(orderId.trim());
        _testModeSyncScheduleReservationStatus(
          orderId: orderId,
          apparatusId: storageKey,
          status: 'active',
        );
        _testModeApparatusQueueStates[storageKey] = states;
        return AdminApparatusQueueActionResult(
          states: Map<String, String>.unmodifiable(states),
          progressBatch: resumed,
          progressBatches: List<AdminProgressBatch>.unmodifiable(
            resumedBatches,
          ),
        );
}
}
