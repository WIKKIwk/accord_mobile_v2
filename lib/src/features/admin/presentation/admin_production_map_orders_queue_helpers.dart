part of 'admin_production_map_orders_screen.dart';

bool _frozenOrdersEqual(
  List<AdminFrozenQueueOrder> left,
  List<AdminFrozenQueueOrder> right,
) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    final current = left[index];
    final next = right[index];
    if (current.apparatus != next.apparatus ||
        current.orderId != next.orderId ||
        current.issueNote != next.issueNote ||
        current.frozenAtUnix != next.frozenAtUnix ||
        current.frozenBy != next.frozenBy) {
      return false;
    }
  }
  return true;
}

bool _queueActionControlsEqual(
  Map<String, AdminApparatusQueueOrderActionControl> left,
  Map<String, AdminApparatusQueueOrderActionControl> right,
) {
  if (left.length != right.length) {
    return false;
  }
  for (final entry in left.entries) {
    final other = right[entry.key];
    final control = entry.value;
    if (other == null ||
        control.state != other.state ||
        control.previousStage != other.previousStage ||
        control.previousStageReady != other.previousStageReady ||
        control.completeRequiresFullReport !=
            other.completeRequiresFullReport ||
        control.contractValid != other.contractValid ||
        control.interaction?.mode != other.interaction?.mode ||
        control.interaction?.startMaterialsMode !=
            other.interaction?.startMaterialsMode ||
        control.interaction?.materialScanRequired !=
            other.interaction?.materialScanRequired ||
        control.interaction?.assignedMaterialsDisplayOnly !=
            other.interaction?.assignedMaterialsDisplayOnly ||
        control.interaction?.materialIntakeAllowed !=
            other.interaction?.materialIntakeAllowed ||
        control.interaction?.previousWipMode !=
            other.interaction?.previousWipMode ||
        control.interaction?.openingWipMode !=
            other.interaction?.openingWipMode ||
        control.interaction?.qolipMode != other.interaction?.qolipMode ||
        control.interaction?.blockingReasonCode !=
            other.interaction?.blockingReasonCode ||
        control.freezeRequest?.requestId != other.freezeRequest?.requestId ||
        control.freezeRequest?.status != other.freezeRequest?.status ||
        control.freezeRequest?.targetApparatus !=
            other.freezeRequest?.targetApparatus ||
        control.freezeRequest?.targetSessionId !=
            other.freezeRequest?.targetSessionId ||
        control.allowedActions.length != other.allowedActions.length ||
        !control.allowedActions.containsAll(other.allowedActions)) {
      return false;
    }
  }
  return true;
}

int _ordersRevision(List<ProductionMapSaved> orders) {
  return Object.hashAll(
    orders.map(
      (item) => Object.hash(
        item.map.id,
        item.map.code,
        item.map.orderNumber,
        item.map.title,
        item.map.productCode,
        item.map.rollCount,
        item.map.widthMm,
        item.map.nodes.length,
        Object.hashAll(
          item.map.nodes.map(
            (node) => Object.hash(
              node.id,
              node.kind,
              node.title,
              node.alternativeGroupId,
              node.alternativeAssignedTitle,
            ),
          ),
        ),
        item.map.edges.length,
        Object.hashAll(
          item.map.edges.map(
            (edge) => Object.hash(edge.from, edge.to, edge.branch),
          ),
        ),
      ),
    ),
  );
}

Map<String, String> _queueStatesForApparatus(
  AdminApparatus apparatus, {
  required Map<String, Map<String, String>> queueStatesByApparatus,
}) {
  return queueStatesByApparatus[apparatus.id.trim()] ?? const {};
}

List<String> _sequenceOrderIdsForApparatus(
  AdminApparatus apparatus, {
  required Map<String, List<String>> sequenceByApparatus,
}) {
  return sequenceByApparatus[apparatus.id.trim()] ?? const [];
}

ApparatusQueuePolicy _queuePolicyForApparatus(
  AdminApparatus apparatus, {
  required Map<String, AdminApparatusQueuePolicy> queuePoliciesByApparatus,
}) {
  return queuePoliciesByApparatus[apparatus.id.trim()]?.policy ??
      ApparatusQueuePolicy.strictSequence;
}

bool _queueActionSentCompletionRequest({
  required String completionRequestNote,
  required AdminApparatusQueueActionResult result,
}) {
  return completionRequestNote.trim().isNotEmpty &&
      result.completionRequest != null;
}

Future<AdminApparatusQueueActionResult> _submitAdminApparatusQueueAction(
  _ReadOnlyQueueActionRequest request, {
  required String apparatusKey,
}) {
  return MobileApi.instance.adminApparatusQueueActionResult(
    apparatus: apparatusKey,
    orderId: request.order.map.id,
    action: request.action,
    materialBarcodes: request.materialBarcodes,
    qolipCodes: request.qolipCodes,
    producedQty: request.producedQty,
    grossQty: request.grossQty,
    bobinaKg: request.bobinaKg,
    diameter: request.diameter,
    returnInkKg: request.returnInkKg,
    laminationPrintLeftoverRolls: request.laminationPrintLeftoverRolls,
    laminationFilmLeftoverRolls: request.laminationFilmLeftoverRolls,
    rezkaBosmaWaste: request.rezkaBosmaWaste,
    rezkaLaminationWaste: request.rezkaLaminationWaste,
    rezkaEdgeWaste: request.rezkaEdgeWaste,
    totalWaste: request.totalWaste,
    finishedGoodsKg: request.finishedGoodsKg,
    finishedGoodsMeter: request.finishedGoodsMeter,
    rezkaFrames: request.rezkaFrames,
    rezkaOutputCycle: request.rezkaOutputCycle,
    uom: request.uom,
    qrPayload: request.qrPayload,
    progressBatchId: request.progressBatchId,
    customerName: request.customerName,
    driverUrl: request.driverUrl,
    printTransport: request.printTransport,
    printer: request.printer,
    printMode: request.printMode,
    completionRequestNote: request.completionRequestNote,
    returnedPaintItems: request.returnedPaintItems,
    returnedPaintImageId: request.returnedPaintImageId,
    fullCompletionReportRequired: request.fullCompletionReportRequired,
    workerHandoff: request.workerHandoff,
    removeRollFromApparatus: request.removeRollFromApparatus,
    freezeRequestId: request.freezeRequestId,
    freezeWithIssue: request.freezeWithIssue,
    issueNote: request.issueNote,
  );
}
