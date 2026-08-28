part of '../mobile_api.dart';

class AdminApparatusQueueActionResult {
  const AdminApparatusQueueActionResult({
    required this.states,
    this.orderStatus = const AdminProductionOrderStatusDetail(),
    this.orderControl,
    this.progressBatch,
    this.progressBatches = const [],
    this.completionRequest,
    this.printJob,
    this.printJobs = const [],
  });

  final Map<String, String> states;
  final AdminProductionOrderStatusDetail orderStatus;
  final AdminOrderControlState? orderControl;
  final AdminProgressBatch? progressBatch;
  final List<AdminProgressBatch> progressBatches;
  final AdminCompletionRequestNotification? completionRequest;
  final UsbRpsPrintRequest? printJob;
  final List<UsbRpsPrintRequest> printJobs;
}

extension MobileApiAdminQueueActions on MobileApi {
Future<Map<String, String>> adminApparatusQueueAction({
    required String apparatus,
    required String orderId,
    required String action,
    String materialBarcode = '',
    List<String> materialBarcodes = const [],
    String qolipCode = '',
    List<String> qolipCodes = const [],
    double? producedQty,
    double? grossQty,
    double? bobinaKg,
    double? diameter,
    double? returnInkKg,
    double? laminationPrintLeftoverRolls,
    double? laminationFilmLeftoverRolls,
    double? rezkaBosmaWaste,
    double? rezkaLaminationWaste,
    double? rezkaEdgeWaste,
    double? totalWaste,
    double? finishedGoodsKg,
    double? finishedGoodsMeter,
    List<Map<String, dynamic>> rezkaFrames = const [],
    String uom = '',
    String qrPayload = '',
    String progressBatchId = '',
    String customerName = '',
    String driverUrl = '',
    PrintTransport printTransport = PrintTransport.wifi,
    String printer = '',
    String printMode = '',
    String completionRequestNote = '',
    List<ReturnedPaintItemInput> returnedPaintItems = const [],
    String returnedPaintImageId = '',
    bool fullCompletionReportRequired = false,
  }) async {
    final result = await adminApparatusQueueActionResult(
      apparatus: apparatus,
      orderId: orderId,
      action: action,
      materialBarcode: materialBarcode,
      materialBarcodes: materialBarcodes,
      qolipCode: qolipCode,
      qolipCodes: qolipCodes,
      producedQty: producedQty,
      grossQty: grossQty,
      bobinaKg: bobinaKg,
      diameter: diameter,
      returnInkKg: returnInkKg,
      laminationPrintLeftoverRolls: laminationPrintLeftoverRolls,
      laminationFilmLeftoverRolls: laminationFilmLeftoverRolls,
      rezkaBosmaWaste: rezkaBosmaWaste,
      rezkaLaminationWaste: rezkaLaminationWaste,
      rezkaEdgeWaste: rezkaEdgeWaste,
      totalWaste: totalWaste,
      finishedGoodsKg: finishedGoodsKg,
      finishedGoodsMeter: finishedGoodsMeter,
      rezkaFrames: rezkaFrames,
      uom: uom,
      qrPayload: qrPayload,
      progressBatchId: progressBatchId,
      customerName: customerName,
      driverUrl: driverUrl,
      printTransport: printTransport,
      printer: printer,
      printMode: printMode,
      completionRequestNote: completionRequestNote,
      returnedPaintItems: returnedPaintItems,
      returnedPaintImageId: returnedPaintImageId,
      fullCompletionReportRequired: fullCompletionReportRequired,
    );
    return result.states;
  }

Future<AdminApparatusQueueActionResult> adminApparatusQueueActionResult({
    required String apparatus,
    required String orderId,
    required String action,
    String materialBarcode = '',
    List<String> materialBarcodes = const [],
    String qolipCode = '',
    List<String> qolipCodes = const [],
    double? producedQty,
    double? grossQty,
    double? bobinaKg,
    double? diameter,
    double? returnInkKg,
    double? laminationPrintLeftoverRolls,
    double? laminationFilmLeftoverRolls,
    double? rezkaBosmaWaste,
    double? rezkaLaminationWaste,
    double? rezkaEdgeWaste,
    double? totalWaste,
    double? finishedGoodsKg,
    double? finishedGoodsMeter,
    List<Map<String, dynamic>> rezkaFrames = const [],
    String uom = '',
    String qrPayload = '',
    String progressBatchId = '',
    String customerName = '',
    String driverUrl = '',
    PrintTransport printTransport = PrintTransport.wifi,
    String printer = '',
    String printMode = '',
    String completionRequestNote = '',
    List<ReturnedPaintItemInput> returnedPaintItems = const [],
    String returnedPaintImageId = '',
    bool fullCompletionReportRequired = false,
    bool workerHandoff = false,
    bool removeRollFromApparatus = false,
    String freezeRequestId = '',
    bool freezeWithIssue = false,
    String issueNote = '',
  }) async {
    final normalizedApparatusId = apparatus.trim();
    if (!isCanonicalApparatusId(normalizedApparatusId)) {
      throw const MobileApiException(
        code: 'apparatus_id_invalid',
        message: 'Canonical apparatus ID noto‘g‘ri',
      );
    }
    final trimmedIssueNote = issueNote.trim();
    if (freezeWithIssue && trimmedIssueNote.isEmpty) {
      throw const MobileApiException(
        code: 'issue_note_required',
        message: 'Muammo izohini kiriting',
      );
    }
    if (freezeWithIssue && action != 'freeze') {
      throw const MobileApiException(
        code: 'freeze_with_issue_only_on_freeze',
        message: 'Muammo bilan yakunlash faqat muzlatish amalida mumkin',
      );
    }
    if (action == 'freeze' && !freezeWithIssue) {
      throw const MobileApiException(
        code: 'freeze_action_requires_issue',
        message: 'Muzlatish amalida muammo izohi majburiy',
      );
    }
    final issueFreezeRequested = action == 'freeze' && freezeWithIssue;
    if (await TestModeController.instance.isEnabled()) {
      final canonicalApparatus =
          _testModeRequiredApparatus(normalizedApparatusId);
      final operation = canonicalApparatus.operation.trim().toLowerCase();
      final storageKey = canonicalApparatus.id.trim();
      final sequence = _testModeApparatusSequences[storageKey] ?? const [];
      final states = Map<String, String>.from(
        _testModeApparatusQueueStates[storageKey] ?? const {},
      );
      final control = _testModeOrderControls[orderId.trim()] ??
          AdminOrderControlState.active;
      final freezeRequestSafeStop =
          control == AdminOrderControlState.freezeRequested &&
              (action == 'pause' || action == 'detach_roll');
      if (control == AdminOrderControlState.frozen) {
        throw const MobileApiException(
          code: 'order_frozen',
          message: 'Buyurtma muzlatilgan',
        );
      }
      if (control == AdminOrderControlState.freezeRequested &&
          action != 'pause' &&
          action != 'detach_roll' &&
          !issueFreezeRequested) {
        throw const MobileApiException(
          code: 'order_freeze_requested',
          message: 'Buyurtmani muzlatish uchun worker pauzasi kutilmoqda',
        );
      }
      if (freezeRequestSafeStop &&
          freezeRequestId.trim() != 'test-freeze-${orderId.trim()}') {
        throw const MobileApiException(
          code: 'order_freeze_request_mismatch',
          message: 'Muzlatish so‘rovi yangilangan. Sahifani qayta oching',
        );
      }
      final frozenOnAnotherApparatus =
          _testModeApparatusQueueStates.entries.any(
        (entry) =>
            entry.key != storageKey &&
            entry.value[orderId.trim()]?.trim().toLowerCase() == 'frozen',
      );
      if (issueFreezeRequested &&
          control == AdminOrderControlState.active &&
          frozenOnAnotherApparatus) {
        throw const MobileApiException(
          code: 'order_frozen',
          message: 'Buyurtma boshqa apparatda muzlatilgan',
        );
      }
      final actionableStates = Map<String, String>.from(states)
        ..removeWhere(
          (id, _) =>
              _testModeOrderControls[id] == AdminOrderControlState.frozen,
        );
      final policy = _effectiveTestModeQueuePolicy(
        storageKey,
      ).policy;
      final progressKey =
          qrPayload.trim().isEmpty ? progressBatchId.trim() : qrPayload.trim();
      final startUsesProgressQr = action == 'start' && progressKey.isNotEmpty;
      final startInputBatch = startUsesProgressQr
          ? _testModeProgressBatchForKey(progressKey)
          : null;
      final queueInputKey = _testModeProgressQueueKey(
        storageKey,
        orderId.trim(),
      );
      final sessionInputBatch = action == 'start'
          ? null
          : _testModeProgressBatchForKey(
              _testModeActiveProgressInputByQueue[queueInputKey] ?? '',
            );
      final activeInputBatch = action == 'start'
          ? null
          : _testModeProgressBatchForKey(
              progressKey.isEmpty
                  ? (_testModeActiveProgressInputByQueue[queueInputKey] ?? '')
                  : progressKey,
            );
      final isLaminatsiya = operation == 'laminate';
      final laminatsiyaWipCanReuseMaterial = isLaminatsiya &&
          startInputBatch != null &&
          startInputBatch.wipStatus.trim().toLowerCase() == 'waiting' &&
          (startInputBatch.nextApparatus.trim().isEmpty ||
              startInputBatch.nextApparatus.trim() == storageKey);
      if (!sequence.map((id) => id.trim()).contains(orderId.trim())) {
        throw const MobileApiException(
          code: 'queue_action_not_allowed',
          message: 'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
        );
      }
      if (policy == ApparatusQueuePolicy.strictSequence &&
          !startUsesProgressQr) {
        final actionable = firstActionableQueueOrderId(
          sequence: sequence,
          states: actionableStates,
        );
        if (actionable != orderId.trim()) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message: 'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
          );
        }
      }
      final current = apparatusQueueOrderStateFromRaw(states[orderId.trim()]);
      final isRezka = operation == 'cut';
      final isPauseOrDetach = action == 'pause' || action == 'detach_roll';
      final isRezkaProgressAction =
          isPauseOrDetach || action == 'roll_complete' || action == 'complete';
      bool isPositive(double? value) =>
          value != null && value.isFinite && value > 0;
      double? frameMetric(Map<String, dynamic> frame, String key) {
        final value = frame[key];
        return value is num ? value.toDouble() : null;
      }

      final configuredRezkaKadrCount = isRezka
          ? _testModeRezkaKadrCount(orderId: orderId, apparatus: apparatus)
          : null;
      final hasRezkaFrameIssues = rezkaFrames.any(
        (frame) => (frame['issue_note']?.toString().trim() ?? '').isNotEmpty,
      );
      if (hasRezkaFrameIssues &&
          action != 'roll_complete' &&
          action != 'complete') {
        throw const MobileApiException(
          code: 'rezka_frame_issue_only_on_roll_progress',
          message: 'Kadr muammosi faqat Rezka tugatish amalida belgilanadi',
        );
      }
      final hasExplicitRezkaFrameMetrics = isRezka &&
          rezkaFrames.isNotEmpty &&
          configuredRezkaKadrCount != null &&
          rezkaFrames.length == configuredRezkaKadrCount &&
          rezkaFrames.every(
            (frame) =>
                (frame['issue_note']?.toString().trim() ?? '').isNotEmpty ||
                (isPositive(
                      frameMetric(frame, 'produced_qty') ??
                          frameMetric(frame, 'finished_goods_meter'),
                    ) &&
                    isPositive(
                      frameMetric(frame, 'gross_qty') ??
                          frameMetric(frame, 'finished_goods_kg'),
                    ) &&
                    isPositive(frameMetric(frame, 'diameter'))),
          );
      if (rezkaFrames.isNotEmpty && (!isRezka || !isRezkaProgressAction)) {
        throw const MobileApiException(
          code: 'rezka_frames_only_on_rezka_progress',
          message: 'Kadr qiymatlari faqat Rezka progress amalida yuboriladi',
        );
      }
      if (isRezkaProgressAction &&
          rezkaFrames.isNotEmpty &&
          configuredRezkaKadrCount != null &&
          rezkaFrames.length != configuredRezkaKadrCount) {
        throw const MobileApiException(
          code: 'rezka_frame_count_mismatch',
          message: 'Kadr qiymatlari soni sozlangan kadr soniga teng emas',
        );
      }
      if (isRezkaProgressAction &&
          rezkaFrames.isNotEmpty &&
          configuredRezkaKadrCount != null &&
          rezkaFrames.length == configuredRezkaKadrCount &&
          !hasExplicitRezkaFrameMetrics) {
        throw const MobileApiException(
          code: 'rezka_progress_metrics_required',
          message: 'Har bir kadr uchun metraj, og‘irlik va diametrni kiriting',
        );
      }
      if (issueFreezeRequested) {
        if (current != ApparatusQueueOrderState.inProgress) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message: 'Muammo faqat jarayondagi zakaz uchun bildiriladi',
          );
        }
        states[orderId.trim()] = 'frozen';
        _testModeOrderControls[orderId.trim()] = AdminOrderControlState.frozen;
        _testModeFrozenIssueNotesByOrderId[orderId.trim()] = trimmedIssueNote;
        _testModeApparatusQueueStates[storageKey] = states;
        _testModeSyncScheduleReservationStatus(
          orderId: orderId,
          apparatusId: storageKey,
          status: 'frozen',
        );
        _testModeRemoveOrderFromQueueSequence(orderId);
        return AdminApparatusQueueActionResult(
          states: Map<String, String>.unmodifiable(states),
          orderStatus: const AdminProductionOrderStatusDetail(
            orderStatus: 'frozen',
            workStatus: 'frozen',
            flowStatus: 'frozen',
          ),
          orderControl: AdminOrderControlState.frozen,
        );
      }
      final hasRezkaQuantityMetrics =
          isPositive(producedQty ?? finishedGoodsMeter) &&
              isPositive(grossQty ?? finishedGoodsKg);
      final hasRezkaDiameter = isPositive(diameter);
      final hasRezkaWaste = [
        totalWaste,
        rezkaBosmaWaste,
        rezkaLaminationWaste,
        rezkaEdgeWaste,
      ].any(isPositive);
      final hasRezkaFrameWaste = rezkaFrames.any(
        (frame) => [
          frameMetric(frame, 'total_waste'),
          frameMetric(frame, 'rezka_bosma_waste'),
          frameMetric(frame, 'rezka_lamination_waste'),
          frameMetric(frame, 'rezka_edge_waste'),
        ].any(isPositive),
      );
      if (isRezka &&
          (isPauseOrDetach ||
              action == 'roll_complete' ||
              action == 'complete') &&
          (!hasExplicitRezkaFrameMetrics &&
              (!hasRezkaQuantityMetrics || !hasRezkaDiameter))) {
        throw const MobileApiException(
          code: 'rezka_progress_metrics_required',
          message: 'Rezka uchun metraj, og‘irlik va diametrni kiriting',
        );
      }
      if (isRezka &&
          (isPauseOrDetach ||
              action == 'roll_complete' ||
              action == 'complete') &&
          configuredRezkaKadrCount == null) {
        throw const MobileApiException(
          code: 'rezka_kadr_count_required',
          message: 'Rezka uchun kadr soni sozlanmagan',
        );
      }
      final testModeOrderMap = _testModeOrderById(orderId)?.map;
      final previousStage = testModeOrderMap == null
          ? null
          : _testModeTrainingPreviousStage(
              map: testModeOrderMap,
              station: apparatus,
            );
      final hasPreviousStage = previousStage != null;
      final usesVirtualTrainingInput = testModeOrderMap != null &&
          _testModeUsesVirtualTrainingInput(
            map: testModeOrderMap,
            station: apparatus,
          );
      final previousStageCompleted = hasPreviousStage &&
          (usesVirtualTrainingInput
              ? _testModeTrainingInputBatchGeneratedOrderIds.contains(
                  orderId.trim(),
                )
              : _testModeApparatusQueueStates.entries.any((entry) {
                  final state = apparatusQueueOrderStateFromRaw(
                    entry.value[orderId.trim()],
                  );
                  return entry.key.trim() == previousStage &&
                      state == ApparatusQueueOrderState.completed;
                }));
      bool isPreviousStageBatch(AdminProgressBatch batch) {
        if (!hasPreviousStage ||
            batch.orderId.trim() != orderId.trim() ||
            batch.apparatus.trim() != previousStage ||
            (batch.nextApparatus.trim().isNotEmpty &&
                batch.nextApparatus.trim() != storageKey)) {
          return false;
        }
        final actionName = batch.action.trim().toLowerCase();
        if (actionName != 'pause' &&
            actionName != 'detach_roll' &&
            actionName != 'roll_complete' &&
            actionName != 'complete') {
          return false;
        }
        final wipStatus = batch.wipStatus.trim().toLowerCase();
        return wipStatus == 'waiting' ||
            (wipStatus == 'in_use' &&
                (batch.usedByApparatus.trim().isEmpty
                        ? batch.currentApparatus.trim()
                        : batch.usedByApparatus.trim()) ==
                    storageKey);
      }

      final hasUnprocessedPreviousWip = (isLaminatsiya || isRezka) &&
          hasPreviousStage &&
          (!previousStageCompleted ||
              _testModeProgressBatchesByQr.values.any((batch) {
                if (!isPreviousStageBatch(batch)) {
                  return false;
                }
                if (activeInputBatch != null &&
                    (batch.batchId.trim() == activeInputBatch.batchId.trim() ||
                        batch.qrPayload.trim().toLowerCase() ==
                            activeInputBatch.qrPayload.trim().toLowerCase())) {
                  return false;
                }
                return true;
              }));
      final allowPartialStationCompletion = (isLaminatsiya || isRezka) &&
          action == 'complete' &&
          !fullCompletionReportRequired &&
          hasUnprocessedPreviousWip;
      if (isRezka &&
          action == 'complete' &&
          !allowPartialStationCompletion &&
          !hasRezkaWaste &&
          !hasRezkaFrameWaste) {
        throw const MobileApiException(
          code: 'rezka_progress_metrics_required',
          message: 'Yakuniy Rezka tugatishida chiqindi hisoboti shart',
        );
      }
      if (isRezka &&
          (isPauseOrDetach ||
              action == 'roll_complete' ||
              action == 'complete') &&
          hasPreviousStage &&
          activeInputBatch == null) {
        throw const MobileApiException(
          code: 'progress_qr_required',
          message: 'Rezka uchun keyingi laminatsiya ruloni QR sini scan qiling',
        );
      }
      if (isLaminatsiya &&
          hasPreviousStage &&
          (isPauseOrDetach || action == 'complete') &&
          activeInputBatch == null) {
        throw const MobileApiException(
          code: 'progress_qr_required',
          message: 'Laminatsiya uchun oldingi bosqich QR sini scan qiling',
        );
      }
      if (activeInputBatch != null &&
          (activeInputBatch.orderId.trim() != orderId.trim() ||
              activeInputBatch.wipStatus.trim().toLowerCase() == 'processed')) {
        throw const MobileApiException(
          code: 'progress_batch_not_accepted',
          message: 'Bu WIP ushbu Rezka orderi uchun yaroqsiz',
        );
      }
      final explicitProgressInput =
          action != 'start' && action != 'resume' && progressKey.isNotEmpty;
      if (explicitProgressInput && hasPreviousStage) {
        final input = activeInputBatch;
        final inputWipStatus = input?.wipStatus.trim().toLowerCase() ?? '';
        final inputNextApparatus = input?.nextApparatus.trim() ?? '';
        final inputUsedByApparatus =
            input?.usedByApparatus.trim().isNotEmpty == true
                ? input!.usedByApparatus.trim()
                : input?.currentApparatus.trim() ?? '';
        if (input == null) {
          throw const MobileApiException(
            code: 'progress_batch_not_accepted',
            message: 'Bu QR oldingi bosqich mahsulotiga mos emas',
          );
        }
        final sessionInputIsDifferent = sessionInputBatch != null &&
            sessionInputBatch.wipStatus.trim().toLowerCase() == 'in_use' &&
            sessionInputBatch.batchId.trim() != input.batchId.trim();
        if (sessionInputIsDifferent) {
          throw const MobileApiException(
            code: 'progress_batch_not_accepted',
            message: 'Avval joriy Rezka rulonini tugating',
          );
        }
        final inputWipIsUsable = inputWipStatus == 'waiting' ||
            (inputWipStatus == 'in_use' && inputUsedByApparatus == storageKey);
        if (!inputWipIsUsable ||
            input.apparatus.trim() != previousStage ||
            (inputNextApparatus.isNotEmpty &&
                inputNextApparatus != storageKey)) {
          throw const MobileApiException(
            code: 'progress_batch_not_accepted',
            message: 'Bu QR oldingi bosqich mahsulotiga mos emas',
          );
        }
      }
      if (action == 'start') {
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
      } else if ((action == 'pause' && workerHandoff) ||
          (action == 'detach_roll' && removeRollFromApparatus)) {
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
      } else if (isPauseOrDetach) {
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
      } else if (action == 'roll_complete') {
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
      } else if (action == 'resume') {
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
          _testModeProgressBatchesByQr[resumed.qrPayload] = resumed;
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
      } else if (action == 'complete') {
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
      } else {
        throw const MobileApiException(
          code: 'queue_action_not_allowed',
          message: 'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
        );
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
    final trimmedBarcode = materialBarcode.trim();
    final trimmedQolipCode = qolipCode.trim();
    final trimmedQolipCodes = <String>[];
    for (final code in qolipCodes) {
      final trimmed = code.trim();
      if (trimmed.isEmpty ||
          trimmedQolipCodes.any(
            (existing) => existing.toLowerCase() == trimmed.toLowerCase(),
          )) {
        continue;
      }
      trimmedQolipCodes.add(trimmed);
    }
    final trimmedBarcodes = [
      for (final barcode in materialBarcodes)
        if (barcode.trim().isNotEmpty) barcode.trim(),
    ];
    final trimmedDriverUrl = driverUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final trimmedCompletionRequestNote = completionRequestNote.trim();
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/queue-action'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'apparatus': apparatus,
          'order_id': orderId,
          'action': action,
          if (freezeWithIssue) 'freeze_with_issue': true,
          if (freezeWithIssue) 'issue_note': trimmedIssueNote,
          if (freezeRequestId.trim().isNotEmpty)
            'freeze_request_id': freezeRequestId.trim(),
          if (trimmedBarcodes.isNotEmpty) 'material_barcodes': trimmedBarcodes,
          if (trimmedBarcodes.isEmpty && trimmedBarcode.isNotEmpty)
            'material_barcode': trimmedBarcode,
          if (trimmedQolipCodes.isNotEmpty) 'qolip_codes': trimmedQolipCodes,
          if (trimmedQolipCodes.isEmpty && trimmedQolipCode.isNotEmpty)
            'qolip_code': trimmedQolipCode,
          if (producedQty != null) 'produced_qty': producedQty,
          if (grossQty != null) 'gross_qty': grossQty,
          if (bobinaKg != null) 'bobina_kg': bobinaKg,
          if (diameter != null) 'diameter': diameter,
          if (returnInkKg != null) 'return_ink_kg': returnInkKg,
          if (laminationPrintLeftoverRolls != null)
            'lamination_print_leftover_rolls': laminationPrintLeftoverRolls,
          if (laminationFilmLeftoverRolls != null)
            'lamination_film_leftover_rolls': laminationFilmLeftoverRolls,
          if (rezkaBosmaWaste != null) 'rezka_bosma_waste': rezkaBosmaWaste,
          if (rezkaLaminationWaste != null)
            'rezka_lamination_waste': rezkaLaminationWaste,
          if (rezkaEdgeWaste != null) 'rezka_edge_waste': rezkaEdgeWaste,
          if (totalWaste != null) 'total_waste': totalWaste,
          if (finishedGoodsKg != null) 'finished_goods_kg': finishedGoodsKg,
          if (finishedGoodsMeter != null)
            'finished_goods_meter': finishedGoodsMeter,
          if (rezkaFrames.isNotEmpty) 'rezka_frames': rezkaFrames,
          if (uom.trim().isNotEmpty) 'uom': uom.trim(),
          if (qrPayload.trim().isNotEmpty) 'qr_payload': qrPayload.trim(),
          if (progressBatchId.trim().isNotEmpty)
            'progress_batch_id': progressBatchId.trim(),
          if (customerName.trim().isNotEmpty)
            'customer_name': customerName.trim(),
          if (trimmedDriverUrl.isNotEmpty) 'driver_url': trimmedDriverUrl,
          if (printTransport.isLocal)
            'print_transport': printTransport.clientApiValue,
          if (printer.trim().isNotEmpty) 'printer': printer.trim(),
          if (printMode.trim().isNotEmpty) 'print_mode': printMode.trim(),
          if (trimmedCompletionRequestNote.isNotEmpty)
            'completion_request_note': trimmedCompletionRequestNote,
          if (fullCompletionReportRequired)
            'full_completion_report_required': true,
          if (workerHandoff) 'worker_handoff': true,
          if (removeRollFromApparatus) 'remove_roll_from_apparatus': true,
          if (returnedPaintItems.isNotEmpty)
            'returned_paint_items': returnedPaintItems
                .map((item) => item.toJson())
                .toList(growable: false),
          if (returnedPaintImageId.trim().isNotEmpty)
            'returned_paint_image_id': returnedPaintImageId.trim(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'queue_action_not_allowed');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['states'];
    final rawOrderControl = payload['order_control'];
    final orderControl = rawOrderControl is Map
        ? AdminOrderControlState.fromRaw(rawOrderControl['state'])
        : null;
    final orderStatus = AdminProductionOrderStatusDetail.fromJson(
      payload['order_status'],
    );
    if (raw is! Map) {
      return AdminApparatusQueueActionResult(
        states: const {},
        orderStatus: orderStatus,
        orderControl: orderControl,
      );
    }
    final progressRaw = payload['progress_batch'];
    final progressBatches = <AdminProgressBatch>[
      if (payload['progress_batches'] is List)
        for (final item in payload['progress_batches'] as List)
          if (item is Map)
            AdminProgressBatch.fromJson(item.cast<String, dynamic>()),
    ];
    final requestRaw = payload['completion_request'];
    final printRaw = payload['print'];
    final parsedPrintJobs = <UsbRpsPrintRequest>[
      if (payload['prints'] is List)
        for (final item in payload['prints'] as List)
          if (item is Map && item['ok'] == true)
            UsbRpsPrintRequest.fromPrintJson(item.cast<String, dynamic>()),
    ];
    final trainingLocalPrintJobs = orderId.trim().startsWith('training-') &&
            printTransport.isLocal &&
            parsedPrintJobs.isEmpty
        ? _testModeProgressPrintJobs(
            batches: progressBatches,
            printer: printer,
            printMode: printMode,
            customerName: customerName,
          )
        : const <UsbRpsPrintRequest>[];
    final printJobs = <UsbRpsPrintRequest>[
      ...parsedPrintJobs,
      ...trainingLocalPrintJobs,
    ];
    final legacyProgressBatch = progressRaw is Map
        ? AdminProgressBatch.fromJson(progressRaw.cast<String, dynamic>())
        : (progressBatches.isEmpty ? null : progressBatches.first);
    final legacyPrintJob = printRaw is Map && printRaw['ok'] == true
        ? UsbRpsPrintRequest.fromPrintJson(printRaw.cast<String, dynamic>())
        : (printJobs.isEmpty ? null : printJobs.first);
    final parsedStates = <String, String>{
      for (final entry in raw.entries)
        entry.key.toString(): entry.value.toString(),
    };
    return AdminApparatusQueueActionResult(
      states: Map<String, String>.unmodifiable(parsedStates),
      orderStatus: orderStatus,
      orderControl: orderControl,
      progressBatch: legacyProgressBatch,
      progressBatches: progressBatches,
      completionRequest: requestRaw is Map
          ? AdminCompletionRequestNotification.fromJson(
              requestRaw.cast<String, dynamic>(),
            )
          : null,
      printJob: legacyPrintJob,
      printJobs: printJobs,
    );
  }
}
