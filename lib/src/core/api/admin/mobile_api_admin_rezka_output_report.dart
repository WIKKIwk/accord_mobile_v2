part of '../mobile_api.dart';

class AdminRezkaOutputSnapshot {
  const AdminRezkaOutputSnapshot({
    required this.report,
    required this.kadrCounts,
    required this.revision,
    required this.epoch,
  });

  final AdminRezkaOutputReport report;
  final List<int> kadrCounts;
  final int revision;
  final String epoch;

  factory AdminRezkaOutputSnapshot.fromJson(
    Map<String, dynamic> json, {
    required String apparatus,
    required String orderId,
  }) {
    final report =
        AdminRezkaOutputReport.tryFromJson(json['rezka_output_report']);
    final counts = json['kadr_counts'];
    final revision = json['rev'];
    final epoch = json['epoch'];
    if (json['ok'] != true ||
        json['apparatus'] != apparatus ||
        json['order_id'] != orderId ||
        json['session_status'] != 'active' ||
        json['order_control'] != 'active' ||
        report == null ||
        counts is! List ||
        counts.isEmpty ||
        counts.any((count) => count is! int || count <= 0) ||
        report.frames.any((frame) => frame.index > counts.length) ||
        revision is! int ||
        revision < 0 ||
        epoch is! String ||
        epoch.trim().isEmpty) {
      throw _productionMapQueueContractException('invalid Rezka output report');
    }
    return AdminRezkaOutputSnapshot(
      report: report,
      kadrCounts: List<int>.unmodifiable(counts.cast<int>()),
      revision: revision,
      epoch: epoch,
    );
  }
}

extension MobileApiAdminRezkaOutputReport on MobileApi {
  /// A bare 404 means this server has no narrow report route. Authorization,
  /// inactive-cycle and malformed responses must never use a broader reader.
  Future<AdminRezkaOutputSnapshot?> adminRezkaOutputReport({
    required String apparatus,
    required String orderId,
  }) async {
    final station = _requireCanonicalApparatusId(apparatus);
    final order = orderId.trim();
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/rezka-output-report',
        ).replace(queryParameters: {'apparatus': station, 'order_id': order}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode == 404 && response.body.trim().isEmpty) return null;
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
          response, 'rezka_output_report_failed');
    }
    return AdminRezkaOutputSnapshot.fromJson(
      await decodeJsonMapPayload(response.body),
      apparatus: station,
      orderId: order,
    );
  }
}
