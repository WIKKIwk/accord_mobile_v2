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
