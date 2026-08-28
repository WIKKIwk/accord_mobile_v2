part of 'admin_production_map_orders_screen.dart';

bool _queueSnapshotChanged({
  required AdminApparatusQueueSnapshot snapshot,
  required Map<String, List<String>> sequenceByApparatus,
  required Map<String, List<String>> visibleOrderIdsByApparatus,
  required Map<String, Map<String, String>> queueStatesByApparatus,
  required Map<String, Map<String, String>> stageStatesByOrderId,
  required Map<String, AdminApparatusQueuePolicy> queuePoliciesByApparatus,
  required Map<String, Map<String, AdminApparatusQueueOrderActionControl>>
      queueActionControlsByApparatus,
  required Map<String, AdminOrderControlState> orderControlsByOrderId,
  required Map<String, String> orderCustomersByOrderId,
  required Map<String, AdminProductionOrderStatusDetail> orderStatusesByOrderId,
  required Map<String, AdminQolipOrderNote> qolipOrderNotesByOrderId,
  required Map<String, List<AdminFrozenQueueOrder>> frozenOrdersByApparatus,
}) {
  if (sequenceByApparatus.length != snapshot.sequences.length ||
      visibleOrderIdsByApparatus.length != snapshot.visibleOrderIds.length ||
      queueStatesByApparatus.length != snapshot.queueStates.length ||
      stageStatesByOrderId.length != snapshot.stageStates.length ||
      queuePoliciesByApparatus.length != snapshot.queuePolicies.length ||
      queueActionControlsByApparatus.length !=
          snapshot.queueActionControls.length ||
      orderControlsByOrderId.length != snapshot.orderControls.length ||
      orderCustomersByOrderId.length != snapshot.orderCustomers.length ||
      orderStatusesByOrderId.length != snapshot.orderStatuses.length ||
      qolipOrderNotesByOrderId.length != snapshot.qolipOrderNotes.length ||
      frozenOrdersByApparatus.length !=
          snapshot.frozenOrdersByApparatus.length) {
    return true;
  }
  for (final entry in snapshot.sequences.entries) {
    final current = sequenceByApparatus[entry.key];
    if (current == null ||
        current.length != entry.value.length ||
        !_stringListsEqual(current, entry.value)) {
      return true;
    }
  }
  for (final entry in snapshot.visibleOrderIds.entries) {
    final current = visibleOrderIdsByApparatus[entry.key];
    if (current == null ||
        current.length != entry.value.length ||
        !_stringListsEqual(current, entry.value)) {
      return true;
    }
  }
  for (final entry in snapshot.queueStates.entries) {
    final current = queueStatesByApparatus[entry.key];
    if (current == null || !_stringMapsEqual(current, entry.value)) {
      return true;
    }
  }
  for (final entry in snapshot.stageStates.entries) {
    final current = stageStatesByOrderId[entry.key];
    if (current == null || !_stringMapsEqual(current, entry.value)) {
      return true;
    }
  }
  for (final entry in snapshot.queuePolicies.entries) {
    final current = queuePoliciesByApparatus[entry.key];
    if (current == null ||
        current.policy != entry.value.policy ||
        current.locked != entry.value.locked) {
      return true;
    }
  }
  for (final entry in snapshot.queueActionControls.entries) {
    final current = queueActionControlsByApparatus[entry.key];
    if (current == null || !_queueActionControlsEqual(current, entry.value)) {
      return true;
    }
  }
  for (final entry in snapshot.orderControls.entries) {
    if (orderControlsByOrderId[entry.key] != entry.value) {
      return true;
    }
  }
  for (final entry in snapshot.orderCustomers.entries) {
    if (orderCustomersByOrderId[entry.key] != entry.value) {
      return true;
    }
  }
  for (final entry in snapshot.orderStatuses.entries) {
    final current = orderStatusesByOrderId[entry.key];
    if (current == null ||
        current.orderStatus != entry.value.orderStatus ||
        current.completedWithIssueCount !=
            entry.value.completedWithIssueCount) {
      return true;
    }
  }
  for (final entry in snapshot.qolipOrderNotes.entries) {
    final current = qolipOrderNotesByOrderId[entry.key];
    if (current == null ||
        current.status != entry.value.status ||
        current.itemCode != entry.value.itemCode ||
        current.itemName != entry.value.itemName ||
        !_stringListsEqual(current.qolipCodes, entry.value.qolipCodes)) {
      return true;
    }
  }
  for (final entry in snapshot.frozenOrdersByApparatus.entries) {
    final current = frozenOrdersByApparatus[entry.key];
    if (current == null || !_frozenOrdersEqual(current, entry.value)) {
      return true;
    }
  }
  return false;
}

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

bool _stringListsEqual(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

bool _stringMapsEqual(Map<String, String> left, Map<String, String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) {
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

Future<AdminApparatusQueueSnapshot> _loadQueueSnapshot() async {
  return MobileApi.instance.adminProductionMapQueueSnapshot();
}
