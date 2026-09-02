part of '../mobile_api.dart';

extension _MobileApiAdminQueueActionMerge on _TestModeQueueActionContext {
  Future<AdminApparatusQueueActionResult> _runMerge() async {
    if (!isRezka || current != ApparatusQueueOrderState.inProgress) {
      throw const MobileApiException(
        code: 'queue_action_not_allowed',
        message: 'Merge faqat faol Rezka orderida mumkin',
      );
    }
    if (qrPayload.trim().isEmpty) {
      throw const MobileApiException(
        code: 'merge_input_required',
        message: 'Ulanadigan WIP QR sini scan qiling',
      );
    }
    final hasOutputMetrics = rezkaFrames.isNotEmpty ||
        producedQty != null ||
        grossQty != null ||
        bobinaKg != null ||
        diameter != null ||
        returnInkKg != null ||
        laminationPrintLeftoverRolls != null ||
        laminationFilmLeftoverRolls != null ||
        rezkaBosmaWaste != null ||
        rezkaLaminationWaste != null ||
        rezkaEdgeWaste != null ||
        finishedGoodsKg != null ||
        finishedGoodsMeter != null ||
        (uom.trim().isNotEmpty && uom.trim().toLowerCase() != 'kg');
    if (hasOutputMetrics ||
        (totalWaste != null && (!totalWaste.isFinite || totalWaste < 0))) {
      throw const MobileApiException(
        code: 'progress_input_invalid',
        message: 'Merge paytida chiqish o‘lchovlari yuborilmaydi',
      );
    }

    final currentInput = sessionInputBatch as AdminProgressBatch?;
    final nextInput = activeInputBatch as AdminProgressBatch?;
    if (!hasPreviousStage || currentInput == null || nextInput == null) {
      throw const MobileApiException(
        code: 'merge_input_not_accepted',
        message: 'Bu WIP ushbu Rezka bosqichiga mos emas',
      );
    }
    final currentInputStatus = currentInput.wipStatus.trim().toLowerCase();
    final currentInputUsedBy = currentInput.usedByApparatus.trim().isNotEmpty
        ? currentInput.usedByApparatus.trim()
        : currentInput.currentApparatus.trim();
    final acceptedProgressActions = const {
      'pause',
      'detach_roll',
      'roll_complete',
      'complete',
    };
    final acceptedProgressStatuses = const {
      'paused',
      'roll_detached',
      'completed',
      'resumed',
    };
    if (currentInput.batchId.trim().isEmpty ||
        currentInput.orderId.trim() != orderId.trim() ||
        currentInput.apparatus.trim() != previousStage ||
        !acceptedProgressActions
            .contains(currentInput.action.trim().toLowerCase()) ||
        !acceptedProgressStatuses
            .contains(currentInput.status.trim().toLowerCase()) ||
        currentInputStatus != 'in_use' ||
        currentInputUsedBy != storageKey ||
        (currentInput.nextApparatus.trim().isNotEmpty &&
            currentInput.nextApparatus.trim() != storageKey)) {
      throw const MobileApiException(
        code: 'merge_input_not_accepted',
        message: 'Joriy Rezka WIP holati mos emas',
      );
    }
    if (currentInput.batchId.trim() == nextInput.batchId.trim()) {
      throw const MobileApiException(
        code: 'merge_input_same',
        message: 'Bu WIP hozir ishlatilmoqda',
      );
    }
    if ((progressBatchId.trim().isNotEmpty &&
            progressBatchId.trim() != nextInput.batchId.trim()) ||
        nextInput.orderId.trim() != orderId.trim() ||
        nextInput.apparatus.trim() != previousStage ||
        !acceptedProgressActions
            .contains(nextInput.action.trim().toLowerCase()) ||
        !acceptedProgressStatuses
            .contains(nextInput.status.trim().toLowerCase()) ||
        nextInput.wipStatus.trim().toLowerCase() != 'waiting' ||
        (nextInput.nextApparatus.trim().isNotEmpty &&
            nextInput.nextApparatus.trim() != storageKey)) {
      throw const MobileApiException(
        code: 'merge_input_not_accepted',
        message: 'Bu WIP ushbu Rezka bosqichiga mos emas',
      );
    }

    _testModeEnsureApparatusExecutionCapacity(
      apparatusId: storageKey,
      orderId: orderId,
    );
    _advanceTestModeMergeControl(
      currentInputBatchId: currentInput.batchId,
      nextInputBatchId: nextInput.batchId,
      nextInputContainedKadrCount:
          _positiveJsonInt(nextInput.payloadJson['contained_kadr_count']),
    );
    final processedInput = _testModeMarkProgressInputProcessed(
      batch: currentInput,
      apparatus: storageKey,
      orderId: orderId,
    );
    final inUseInput = nextInput.copyWith(
      wipStatus: 'in_use',
      currentApparatus: storageKey,
      currentLocation: storageKey,
      usedBySessionId: 'test-session-${orderId.trim()}',
      usedByApparatus: storageKey,
    );
    _testModeProgressBatchesByQr[processedInput.qrPayload] = processedInput;
    _testModeProgressBatchesByQr[inUseInput.qrPayload] = inUseInput;
    _testModeActiveProgressInputByQueue[queueInputKey] = inUseInput.qrPayload;
    _testModeSyncScheduleReservationStatus(
      orderId: orderId,
      apparatusId: storageKey,
      status: 'active',
    );
    _testModeApparatusQueueStates[storageKey] = states;
    return AdminApparatusQueueActionResult(
      states: Map<String, String>.unmodifiable(states),
    );
  }

  void _advanceTestModeMergeControl({
    required String currentInputBatchId,
    required String nextInputBatchId,
    required int? nextInputContainedKadrCount,
  }) {
    final normalizedOrderId = orderId.trim();
    final normalizedCurrentInputBatchId = currentInputBatchId.trim();
    final normalizedNextInputBatchId = nextInputBatchId.trim();
    final fixture =
        _testModeQueueActionControlFixtures[storageKey]?[normalizedOrderId];
    if (fixture == null) return;
    if (!fixture.hasValidRezkaMergeState) {
      throw const MobileApiException(
        code: 'merge_input_not_accepted',
        message: 'Merge holati server bilan mos emas',
      );
    }

    final activeFixtureInputs = fixture.rezkaInputLineage
        .where((link) => link.inUse)
        .toList(growable: false);
    final lineageBatchIds = <String>{};
    final lineageSequenceNos = <int>{};
    final lineageIsValid = fixture.rezkaInputLineage.every(
      (link) =>
          link.inputBatchId.trim().isNotEmpty &&
          link.sequenceNo > 0 &&
          lineageBatchIds.add(link.inputBatchId.trim()) &&
          lineageSequenceNos.add(link.sequenceNo),
    );
    if (fixture.rezkaInputLineage.isNotEmpty &&
        (!lineageIsValid ||
            activeFixtureInputs.length != 1 ||
            activeFixtureInputs.single.inputBatchId.trim() !=
                normalizedCurrentInputBatchId)) {
      throw const MobileApiException(
        code: 'merge_input_not_accepted',
        message: 'Merge holati server bilan mos emas',
      );
    }
    if (fixture.rezkaInputLineage.any(
      (link) => link.inputBatchId.trim() == normalizedNextInputBatchId,
    )) {
      throw const MobileApiException(
        code: 'merge_input_already_used',
        message: 'Bu WIP oldin ishlatilgan',
      );
    }
    final activeRollSlots = <int>{};
    final activeRollsAreValid = fixture.rezkaActivePartialRolls.every((roll) {
      final sourceIds = <String>{};
      return roll.slotIndex > 0 &&
          roll.generation > 0 &&
          activeRollSlots.add(roll.slotIndex) &&
          roll.sourceInputBatchIds.isNotEmpty &&
          roll.sourceInputBatchIds.every(
            (sourceId) =>
                sourceId.trim().isNotEmpty &&
                sourceIds.add(sourceId.trim()) &&
                lineageBatchIds.contains(sourceId.trim()),
          ) &&
          sourceIds.contains(normalizedCurrentInputBatchId);
    });
    if (!activeRollsAreValid) {
      throw const MobileApiException(
        code: 'merge_input_not_accepted',
        message: 'Merge rulon manbalari joriy WIP bilan mos emas',
      );
    }
    final activeKadrCount = fixture.rezkaActivePartialRolls.isEmpty
        ? fixture.rezkaOutputKadrCounts
            .fold<int>(0, (sum, count) => sum + count)
        : fixture.rezkaActivePartialRolls.fold<int>(
            0,
            (sum, roll) => sum + roll.containedKadrCount,
          );
    if (nextInputContainedKadrCount != null &&
        nextInputContainedKadrCount != activeKadrCount) {
      throw MobileApiException(
        code: 'merge_input_frame_count_mismatch',
        message:
            'Merge qilinmadi: joriy Rezka $activeKadrCount kadr, scan qilingan WIP $nextInputContainedKadrCount kadr',
        activeKadrCount: activeKadrCount,
        scannedKadrCount: nextInputContainedKadrCount,
      );
    }

    final lineage = fixture.rezkaInputLineage.isEmpty
        ? <AdminRezkaInputLink>[
            AdminRezkaInputLink(
              inputBatchId: normalizedCurrentInputBatchId,
              sequenceNo: 1,
              status: 'processed',
            ),
          ]
        : [
            for (final link in fixture.rezkaInputLineage)
              AdminRezkaInputLink(
                inputBatchId: link.inputBatchId,
                sequenceNo: link.sequenceNo,
                status:
                    link.inputBatchId.trim() == normalizedCurrentInputBatchId
                        ? 'processed'
                        : link.status,
              ),
          ];
    final nextSequence = lineage.fold<int>(
          0,
          (maximum, link) =>
              link.sequenceNo > maximum ? link.sequenceNo : maximum,
        ) +
        1;
    lineage.add(
      AdminRezkaInputLink(
        inputBatchId: normalizedNextInputBatchId,
        sequenceNo: nextSequence,
        status: 'in_use',
      ),
    );

    final activeRolls = fixture.rezkaActivePartialRolls.isEmpty
        ? [
            for (var index = 0;
                index < fixture.rezkaOutputKadrCounts.length;
                index += 1)
              AdminRezkaActivePartialRoll(
                slotIndex: index + 1,
                generation: 1,
                containedKadrCount: fixture.rezkaOutputKadrCounts[index],
                sourceInputBatchIds: [
                  normalizedCurrentInputBatchId,
                  normalizedNextInputBatchId,
                ],
              ),
          ]
        : [
            for (final roll in fixture.rezkaActivePartialRolls)
              AdminRezkaActivePartialRoll(
                slotIndex: roll.slotIndex,
                generation: roll.generation,
                containedKadrCount: roll.containedKadrCount,
                sourceInputBatchIds: [
                  ...roll.sourceInputBatchIds,
                  if (!roll.sourceInputBatchIds
                      .contains(normalizedNextInputBatchId))
                    normalizedNextInputBatchId,
                ],
              ),
          ];
    _testModeQueueActionControlFixtures[storageKey]![normalizedOrderId] =
        AdminApparatusQueueOrderActionControl(
      state: fixture.state,
      allowedActions: fixture.allowedActions,
      interaction: fixture.interaction,
      hasOnlyKnownActions: fixture.hasOnlyKnownActions,
      hasRequiredFields: fixture.hasRequiredFields,
      previousStage: fixture.previousStage,
      stageNodeId: fixture.stageNodeId,
      previousStageReady: fixture.previousStageReady,
      rezkaOutputKadrCounts: fixture.rezkaOutputKadrCounts,
      rezkaInputLineage: List<AdminRezkaInputLink>.unmodifiable(lineage),
      rezkaActivePartialRolls:
          List<AdminRezkaActivePartialRoll>.unmodifiable(activeRolls),
      hasValidRezkaMergeState: true,
      completeRequiresFullReport: fixture.completeRequiresFullReport,
      completeRequiresRezkaTotalWasteOnly:
          fixture.completeRequiresRezkaTotalWasteOnly,
      freezeRequest: fixture.freezeRequest,
    );
  }
}
