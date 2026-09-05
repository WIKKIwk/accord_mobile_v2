part of '../mobile_api.dart';

class AdminRecordedRezkaFrame {
  const AdminRecordedRezkaFrame({
    required this.index,
    required this.batchId,
    required this.qrPayload,
    required this.input,
  });

  final int index;
  final String batchId;
  final String qrPayload;
  final Map<String, dynamic> input;

  String get issueNote => (input['issue_note'] as String? ?? '').trim();
  bool get isIssue => issueNote.isNotEmpty;
}

class AdminRezkaOutputReport {
  const AdminRezkaOutputReport({required this.cycleId, this.frames = const []});

  final String cycleId;
  final List<AdminRecordedRezkaFrame> frames;

  AdminRecordedRezkaFrame? frameAt(int zeroBasedIndex) {
    for (final frame in frames) {
      if (frame.index == zeroBasedIndex + 1) return frame;
    }
    return null;
  }

  static AdminRezkaOutputReport? fromSession(Map session) {
    final payload = session['payload_json'];
    if (payload is! Map) return null;
    return tryFromJson({
      'cycle_id': payload['rezka_output_cycle'] ?? session['session_id'],
      'frames': payload['rezka_output_report'] ?? const [],
    });
  }

  static AdminRezkaOutputReport? tryFromJson(dynamic raw) {
    if (raw is! Map || raw['cycle_id'] is! String || raw['frames'] is! List) {
      return null;
    }
    final cycle = (raw['cycle_id'] as String).trim();
    if (cycle.isEmpty) return null;
    final frames = <AdminRecordedRezkaFrame>[];
    final indices = <int>{};
    final batches = <String>{};
    for (final slot in raw['frames'] as List) {
      if (slot is! Map ||
          slot['frame_index'] is! int ||
          slot['input'] is! Map) {
        return null;
      }
      final index = slot['frame_index'] as int;
      final batchId = slot['batch_id']?.toString() ?? '';
      final qr = slot['qr_payload']?.toString() ?? '';
      final input = slot['input'] as Map;
      final note = input['issue_note'];
      if (note != null && note is! String) return null;
      final isIssue = note is String && note.trim().isNotEmpty;
      if (index <= 0 ||
          !indices.add(index) ||
          (isIssue
              ? batchId.isNotEmpty || qr.isNotEmpty
              : batchId.isEmpty || qr.isEmpty || !batches.add(batchId))) {
        return null;
      }
      frames.add(AdminRecordedRezkaFrame(
        index: index,
        batchId: batchId,
        qrPayload: qr,
        input: Map<String, dynamic>.unmodifiable(
            (slot['input'] as Map).cast<String, dynamic>()),
      ));
    }
    return AdminRezkaOutputReport(
        cycleId: cycle, frames: List.unmodifiable(frames));
  }
}

class AdminApparatusQueueActionResult {
  const AdminApparatusQueueActionResult({
    required this.states,
    this.orderStatus = const AdminProductionOrderStatusDetail(),
    this.orderControl,
    this.progressBatch,
    this.progressBatches = const [],
    this.rezkaOutputReport,
    this.completionRequest,
    this.printJob,
    this.printJobs = const [],
  });

  final Map<String, String> states;
  final AdminProductionOrderStatusDetail orderStatus;
  final AdminOrderControlState? orderControl;
  final AdminProgressBatch? progressBatch;
  final List<AdminProgressBatch> progressBatches;
  final AdminRezkaOutputReport? rezkaOutputReport;
  final AdminCompletionRequestNotification? completionRequest;
  final UsbRpsPrintRequest? printJob;
  final List<UsbRpsPrintRequest> printJobs;
}
