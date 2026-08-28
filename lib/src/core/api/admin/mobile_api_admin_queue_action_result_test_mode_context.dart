part of '../mobile_api.dart';

class _TestModeQueueActionContext {
  _TestModeQueueActionContext({
    required this.api,
    required this.apparatus,
    required this.orderId,
    required this.action,
    required this.materialBarcode,
    required this.materialBarcodes,
    required this.qolipCode,
    required this.qolipCodes,
    required this.producedQty,
    required this.grossQty,
    required this.bobinaKg,
    required this.diameter,
    required this.returnInkKg,
    required this.laminationPrintLeftoverRolls,
    required this.laminationFilmLeftoverRolls,
    required this.rezkaBosmaWaste,
    required this.rezkaLaminationWaste,
    required this.rezkaEdgeWaste,
    required this.totalWaste,
    required this.finishedGoodsKg,
    required this.finishedGoodsMeter,
    required this.rezkaFrames,
    required this.uom,
    required this.qrPayload,
    required this.progressBatchId,
    required this.customerName,
    required this.driverUrl,
    required this.printTransport,
    required this.printer,
    required this.printMode,
    required this.completionRequestNote,
    required this.returnedPaintItems,
    required this.returnedPaintImageId,
    required this.fullCompletionReportRequired,
    required this.workerHandoff,
    required this.removeRollFromApparatus,
    required this.freezeRequestId,
    required this.freezeWithIssue,
    required this.issueNote,
    required this.normalizedApparatusId,
    required this.trimmedIssueNote,
    required this.issueFreezeRequested,
    required this.canonicalApparatus,
    required this.operation,
    required this.storageKey,
    required this.sequence,
    required this.states,
    required this.control,
    required this.freezeRequestSafeStop,
    required this.frozenOnAnotherApparatus,
    required this.actionableStates,
    required this.policy,
    required this.progressKey,
    required this.startUsesProgressQr,
    required this.startInputBatch,
    required this.queueInputKey,
    required this.sessionInputBatch,
    required this.activeInputBatch,
    required this.isLaminatsiya,
    required this.laminatsiyaWipCanReuseMaterial,
    required this.current,
    required this.isRezka,
    required this.isPauseOrDetach,
    required this.isRezkaProgressAction,
    required this.isPositive,
    required this.frameMetric,
    required this.configuredRezkaKadrCount,
    required this.hasRezkaFrameIssues,
    required this.hasExplicitRezkaFrameMetrics,
    required this.hasRezkaQuantityMetrics,
    required this.hasRezkaDiameter,
    required this.hasRezkaWaste,
    required this.hasRezkaFrameWaste,
    required this.testModeOrderMap,
    required this.previousStage,
    required this.hasPreviousStage,
    required this.usesVirtualTrainingInput,
    required this.previousStageCompleted,
    required this.isPreviousStageBatch,
    required this.hasUnprocessedPreviousWip,
    required this.allowPartialStationCompletion,
    required this.explicitProgressInput,
  });

  final MobileApi api;
  final dynamic apparatus;
  final dynamic orderId;
  final dynamic action;
  final dynamic materialBarcode;
  final dynamic materialBarcodes;
  final dynamic qolipCode;
  final dynamic qolipCodes;
  final dynamic producedQty;
  final dynamic grossQty;
  final dynamic bobinaKg;
  final dynamic diameter;
  final dynamic returnInkKg;
  final dynamic laminationPrintLeftoverRolls;
  final dynamic laminationFilmLeftoverRolls;
  final dynamic rezkaBosmaWaste;
  final dynamic rezkaLaminationWaste;
  final dynamic rezkaEdgeWaste;
  final dynamic totalWaste;
  final dynamic finishedGoodsKg;
  final dynamic finishedGoodsMeter;
  final dynamic rezkaFrames;
  final dynamic uom;
  final dynamic qrPayload;
  final dynamic progressBatchId;
  final dynamic customerName;
  final dynamic driverUrl;
  final dynamic printTransport;
  final dynamic printer;
  final dynamic printMode;
  final dynamic completionRequestNote;
  final dynamic returnedPaintItems;
  final dynamic returnedPaintImageId;
  final dynamic fullCompletionReportRequired;
  final dynamic workerHandoff;
  final dynamic removeRollFromApparatus;
  final dynamic freezeRequestId;
  final dynamic freezeWithIssue;
  final dynamic issueNote;
  final dynamic normalizedApparatusId;
  final dynamic trimmedIssueNote;
  final dynamic issueFreezeRequested;
  final dynamic canonicalApparatus;
  final dynamic operation;
  final dynamic storageKey;
  final dynamic sequence;
  final dynamic states;
  final dynamic control;
  final dynamic freezeRequestSafeStop;
  final dynamic frozenOnAnotherApparatus;
  final dynamic actionableStates;
  final dynamic policy;
  final dynamic progressKey;
  final dynamic startUsesProgressQr;
  final dynamic startInputBatch;
  final dynamic queueInputKey;
  final dynamic sessionInputBatch;
  final dynamic activeInputBatch;
  final dynamic isLaminatsiya;
  final dynamic laminatsiyaWipCanReuseMaterial;
  final dynamic current;
  final dynamic isRezka;
  final dynamic isPauseOrDetach;
  final dynamic isRezkaProgressAction;
  final dynamic isPositive;
  final dynamic frameMetric;
  final dynamic configuredRezkaKadrCount;
  final dynamic hasRezkaFrameIssues;
  final dynamic hasExplicitRezkaFrameMetrics;
  final dynamic hasRezkaQuantityMetrics;
  final dynamic hasRezkaDiameter;
  final dynamic hasRezkaWaste;
  final dynamic hasRezkaFrameWaste;
  final dynamic testModeOrderMap;
  final dynamic previousStage;
  final dynamic hasPreviousStage;
  final dynamic usesVirtualTrainingInput;
  final dynamic previousStageCompleted;
  final dynamic isPreviousStageBatch;
  final dynamic hasUnprocessedPreviousWip;
  final dynamic allowPartialStationCompletion;
  final dynamic explicitProgressInput;

  Future<AdminRawMaterialStartRequirements>
      adminRawMaterialStartRequirements({
    required String orderId,
    required String apparatus,
    required List<String> materialBarcodes,
  }) {
    return api.adminRawMaterialStartRequirements(
      orderId: orderId,
      apparatus: apparatus,
      materialBarcodes: materialBarcodes,
    );
  }
}
