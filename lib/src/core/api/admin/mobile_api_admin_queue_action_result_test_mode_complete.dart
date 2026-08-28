part of '../mobile_api.dart';

extension _MobileApiAdminQueueActionComplete on _TestModeQueueActionContext {
Future<AdminApparatusQueueActionResult> _runComplete() async {
if (current != ApparatusQueueOrderState.inProgress) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message: 'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
          );
        }
        final note = completionRequestNote.trim();
        final hasReturnedPaintReport = returnedPaintItems.isNotEmpty ||
            returnedPaintImageId.trim().isNotEmpty;
        final hasCompleteMetrics =
            (returnInkKg != null || hasReturnedPaintReport) &&
                totalWaste != null &&
                finishedGoodsKg != null &&
                finishedGoodsMeter != null;
        final hasLaminatsiyaCompleteMetrics = allowPartialStationCompletion
            ? isPositive(finishedGoodsKg) && isPositive(finishedGoodsMeter)
            : (laminationPrintLeftoverRolls != null ||
                    laminationFilmLeftoverRolls != null) &&
                isPositive(totalWaste) &&
                isPositive(finishedGoodsKg) &&
                isPositive(finishedGoodsMeter);
        final zeroMetricCodes = <String>[
          if (producedQty == 0) 'produced_qty',
          if (grossQty == 0) 'gross_qty',
          if (returnInkKg == 0) 'return_ink_kg',
          if (laminationPrintLeftoverRolls == 0)
            'lamination_print_leftover_rolls',
          if (laminationFilmLeftoverRolls == 0)
            'lamination_film_leftover_rolls',
          if (rezkaBosmaWaste == 0) 'rezka_bosma_waste',
          if (rezkaLaminationWaste == 0) 'rezka_lamination_waste',
          if (rezkaEdgeWaste == 0) 'rezka_edge_waste',
          if (totalWaste == 0) 'total_waste',
          if (finishedGoodsKg == 0) 'finished_goods_kg',
          if (finishedGoodsMeter == 0) 'finished_goods_meter',
          if (bobinaKg == 0) 'bobina_kg',
        ];
        if (zeroMetricCodes.isNotEmpty && note.isEmpty) {
          throw const MobileApiException(
            code: 'zero_metric_explanation_required',
            message: '0 qiymat kiritilganda sababini yozing',
          );
        }
        if (isLaminatsiya && !hasLaminatsiyaCompleteMetrics && note.isEmpty) {
          throw const MobileApiException(
            code: 'laminatsiya_completion_metrics_required',
            message: 'Laminatsiya uchun metraj va og‘irlikni kiriting',
          );
        }
        final missingOutputWithReason = note.isNotEmpty &&
            !hasCompleteMetrics &&
            !hasLaminatsiyaCompleteMetrics &&
            !hasRezkaQuantityMetrics &&
            !hasExplicitRezkaFrameMetrics &&
            grossQty == null;
        if (zeroMetricCodes.isNotEmpty || missingOutputWithReason) {
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final map = _testModeProductionMaps
              .where((item) => item.map.id.trim() == orderId.trim())
              .cast<ProductionMapSaved?>()
              .firstWhere((item) => item != null, orElse: () => null);
          _testModeCompletionRequests.insert(
            0,
            AdminCompletionRequestNotification(
              eventId: 'test-completion-request-$now-${orderId.trim()}',
              apparatus: storageKey,
              orderId: orderId.trim(),
              orderNumber: map?.map.orderNumber.trim() ?? '',
              orderTitle: map?.map.title.trim() ?? '',
              productCode: map?.map.productCode.trim() ?? '',
              workerRole: AppSession.instance.profile?.role.name ?? '',
              workerRef: AppSession.instance.profile?.ref.trim() ?? '',
              workerDisplayName:
                  AppSession.instance.profile?.displayName.trim() ?? '',
              description: note,
              zeroMetricCodes: zeroMetricCodes,
              createdAtUnix: now,
            ),
          );
          return AdminApparatusQueueActionResult(
            states: Map<String, String>.unmodifiable(states),
            completionRequest: _testModeCompletionRequests.first,
          );
        }
        final rezkaFrameCount = isRezka
            ? _testModeRezkaKadrCount(orderId: orderId, apparatus: apparatus)
            : null;
        final rezkaFrameIssues = isRezka && rezkaFrameCount != null
            ? _testModeRezkaFrameIssues(
                rezkaFrames: rezkaFrames,
                frameCount: rezkaFrameCount,
                inputProgressBatchId: activeInputBatch?.batchId ?? '',
              )
            : const <Map<String, dynamic>>[];
        if (isRezka && rezkaFrameCount == null) {
          throw const MobileApiException(
            code: 'rezka_kadr_count_required',
            message: 'Rezka uchun kadr soni sozlanmagan',
          );
        }
        if (isRezka) {
          _testModeRezkaFrameIssuesByQueue[queueInputKey] = rezkaFrameIssues;
        }
        final outputBatches = isRezka
            ? _testModeRezkaProgressBatches(
                apparatus: storageKey,
                orderId: orderId.trim(),
                action: 'complete',
                status: 'completed',
                producedQty: producedQty ?? finishedGoodsMeter ?? 1,
                uom: uom.trim().isEmpty && finishedGoodsMeter != null
                    ? 'm'
                    : (uom.trim().isEmpty ? 'kg' : uom.trim()),
                frameCount: rezkaFrameCount!,
                inputBatch: activeInputBatch,
                rezkaFrames: rezkaFrames,
                diameter: diameter,
                returnInkKg: returnInkKg,
                laminationPrintLeftoverRolls: laminationPrintLeftoverRolls,
                laminationFilmLeftoverRolls: laminationFilmLeftoverRolls,
                rezkaBosmaWaste:
                    allowPartialStationCompletion ? null : rezkaBosmaWaste,
                rezkaLaminationWaste:
                    allowPartialStationCompletion ? null : rezkaLaminationWaste,
                rezkaEdgeWaste:
                    allowPartialStationCompletion ? null : rezkaEdgeWaste,
                totalWaste: allowPartialStationCompletion ? null : totalWaste,
                finishedGoodsKg: finishedGoodsKg ?? grossQty,
                finishedGoodsMeter: finishedGoodsMeter ?? producedQty,
                bobinaKg: bobinaKg,
                rezkaFrameIssues: rezkaFrameIssues,
              )
            : [
                _testModeProgressBatch(
                  apparatus: storageKey,
                  orderId: orderId.trim(),
                  action: 'complete',
                  status: 'completed',
                  producedQty: producedQty ?? finishedGoodsMeter ?? 1,
                  uom: uom.trim().isEmpty && finishedGoodsMeter != null
                      ? 'm'
                      : (uom.trim().isEmpty ? 'kg' : uom.trim()),
                  parentBatchId: activeInputBatch?.batchId ?? '',
                  returnInkKg: returnInkKg,
                  laminationPrintLeftoverRolls: laminationPrintLeftoverRolls,
                  laminationFilmLeftoverRolls: laminationFilmLeftoverRolls,
                  rezkaBosmaWaste: rezkaBosmaWaste,
                  rezkaLaminationWaste: rezkaLaminationWaste,
                  rezkaEdgeWaste: rezkaEdgeWaste,
                  totalWaste: totalWaste,
                  finishedGoodsKg: finishedGoodsKg,
                  finishedGoodsMeter: finishedGoodsMeter,
                  bobinaKg: bobinaKg,
                ),
              ];
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
        final batch = outputBatches.isEmpty ? null : outputBatches.first;
        states[orderId.trim()] =
            hasUnprocessedPreviousWip ? 'pending' : 'completed';
        _testModeApparatusQueueStates[storageKey] = states;
        final actorRef = AppSession.instance.profile?.ref.trim() ?? '';
        final completedOrderId = orderId.trim();
        final historyStatus = _testModeQueueHistoryStatus(
          apparatus: storageKey,
          orderId: completedOrderId,
          fallbackStatus: 'completed',
        );
        if (actorRef.isNotEmpty &&
            completedOrderId.isNotEmpty &&
            historyStatus.isNotEmpty) {
          _testModeRecordCompletedQueueOrder(
            actorRef: actorRef,
            apparatus: storageKey,
            orderId: completedOrderId,
            status: historyStatus,
          );
        }
        if (returnedPaintItems.isNotEmpty ||
            returnedPaintImageId.trim().isNotEmpty) {
          final reportId =
              'returned-paint-complete:$completedOrderId:$storageKey';
          if (!_testModeReturnedPaintRequests.any(
            (request) => request.id == reportId,
          )) {
            final map = _testModeProductionMaps
                .where((item) => item.map.id.trim() == completedOrderId)
                .cast<ProductionMapSaved?>()
                .firstWhere((item) => item != null, orElse: () => null);
            final profile = AppSession.instance.profile;
            final operatorName = profile?.displayName.trim().isNotEmpty == true
                ? profile!.displayName.trim()
                : 'Operator';
            final orderCode = map?.map.code.trim().isNotEmpty == true
                ? map!.map.code.trim()
                : map?.map.orderNumber.trim() ?? '';
            final image =
                _testModeReturnedPaintImages[returnedPaintImageId.trim()];
            final waiting = returnedPaintItems.isEmpty && image != null;
            _testModeReturnedPaintRequests.insert(
              0,
              ReturnedPaintRequest(
                id: reportId,
                orderId: completedOrderId,
                orderCode: orderCode,
                orderName: map?.map.title.trim() ?? '',
                apparatus: storageKey,
                senderRole: profile?.role ?? UserRole.aparatchi,
                senderRef: profile?.ref.trim() ?? 'test-user',
                senderDisplayName: operatorName,
                items: returnedPaintItems,
                status: waiting
                    ? ReturnedPaintStatus.waitingForBoyoqchiInput
                    : ReturnedPaintStatus.completed,
                image: image,
                calculation: waiting
                    ? null
                    : const ReturnedPaintCalculation(
                        rasxotMixTotal: '0',
                        astatkaMixTotal: '0',
                        rasxotAlcohol: '0',
                        astatkaAlcohol: '0',
                        finalUsedAlcohol: '0',
                        rasxotPurePaint: '0',
                        astatkaPurePaint: '0',
                        finalUsedPaint: '0',
                      ),
                message:
                    '$operatorName orderni $completedOrderId apparatida muvaffaqiyatli yopdi. Rasxot bo‘yoq sarfi va Astatka qolgan bo‘yoq miqdorlari qayd etildi.',
                createdAt: DateTime.now(),
              ),
            );
          }
        }
        _testModeSyncScheduleReservationStatus(
          orderId: completedOrderId,
          apparatusId: storageKey,
          status: 'completed',
        );
        final printJobs = _testModeProgressPrintJobs(
          batches: outputBatches,
          printer: printer,
          printMode: printMode,
          customerName: customerName,
        );
        return AdminApparatusQueueActionResult(
          states: Map<String, String>.unmodifiable(states),
          progressBatch: batch,
          progressBatches: List<AdminProgressBatch>.unmodifiable(outputBatches),
          printJob: printJobs.isEmpty ? null : printJobs.first,
          printJobs: List<UsbRpsPrintRequest>.unmodifiable(printJobs),
        );
}
}
