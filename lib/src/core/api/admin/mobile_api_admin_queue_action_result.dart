part of '../mobile_api.dart';

extension MobileApiAdminQueueActionResult on MobileApi {
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
      return _adminApparatusQueueActionResultTestMode(
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
      workerHandoff: workerHandoff,
      removeRollFromApparatus: removeRollFromApparatus,
      freezeRequestId: freezeRequestId,
      freezeWithIssue: freezeWithIssue,
      issueNote: issueNote,
      normalizedApparatusId: normalizedApparatusId,
      trimmedIssueNote: trimmedIssueNote,
      issueFreezeRequested: issueFreezeRequested,
      );
    }
    return _adminApparatusQueueActionResultBackend(
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
      workerHandoff: workerHandoff,
      removeRollFromApparatus: removeRollFromApparatus,
      freezeRequestId: freezeRequestId,
      freezeWithIssue: freezeWithIssue,
      issueNote: issueNote,
      trimmedIssueNote: trimmedIssueNote,
    );
  }
}
