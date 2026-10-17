part of '../mobile_api.dart';

/// A server-resolved execution occurrence. The token also identifies an
/// idempotent operation; a client must never derive an occurrence from a label.
class AdminWorkReactivationTarget {
  const AdminWorkReactivationTarget._({
    required this.apparatus,
    required this.orderId,
    required this.batchId,
    required this.sessionId,
    required this.stageNodeId,
    required this.token,
    required String readScope,
  }) : _readScope = readScope;

  final String _readScope;
  final String apparatus;
  final String orderId;
  final String batchId;
  final String sessionId;
  final String stageNodeId;
  final String token;

  Map<String, String> toJson() => {
        'apparatus': apparatus,
        'order_id': orderId,
        if (batchId.isNotEmpty) 'batch_id': batchId,
        'session_id': sessionId,
        'stage_node_id': stageNodeId,
        'token': token,
      };
}

class AdminWorkReactivationPreview {
  const AdminWorkReactivationPreview._({
    required this.denialReason,
    required this.target,
  });

  final String denialReason;
  final AdminWorkReactivationTarget? target;
  bool get available => target != null;

  factory AdminWorkReactivationPreview.fromJson(
    Map<String, dynamic> json, {
    required String apparatus,
    required String orderId,
    required String batchId,
    required String readScope,
  }) {
    if (json['available'] == false) {
      final reason = json['denial_reason'];
      if (reason is! String || reason.trim().isEmpty) {
        throw const FormatException('Missing reactivation denial');
      }
      return AdminWorkReactivationPreview._(denialReason: reason, target: null);
    }
    final raw = json['target'];
    if (json['available'] != true || raw is! Map) {
      throw const FormatException('Invalid reactivation preview');
    }
    String read(String key, {bool allowEmpty = false}) {
      final value = raw[key];
      if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
        throw FormatException('Invalid reactivation $key');
      }
      return value;
    }

    final target = AdminWorkReactivationTarget._(
      apparatus: read('apparatus'),
      orderId: read('order_id'),
      batchId: read('batch_id', allowEmpty: true),
      sessionId: read('session_id'),
      stageNodeId: read('stage_node_id'),
      token: read('token'),
      readScope: readScope,
    );
    if (target.apparatus != apparatus ||
        target.orderId != orderId ||
        target.batchId != batchId) {
      throw const FormatException('Reactivation target mismatch');
    }
    return AdminWorkReactivationPreview._(denialReason: '', target: target);
  }
}

extension MobileApiWorkReactivation on MobileApi {
  Future<AdminWorkReactivationPreview> adminWorkReactivationPreview({
    required String apparatus,
    required String orderId,
    String batchId = '',
  }) async {
    final scope = currentSessionReadScope();
    _requireCanonicalApparatusId(apparatus);
    if (orderId.trim().isEmpty ||
        orderId.startsWith('training-') ||
        await TestModeController.instance.isEnabled()) {
      throw const MobileApiException(
          code: 'reactivation_unavailable', message: '');
    }
    final body = jsonEncode({
      'apparatus': apparatus,
      'order_id': orderId,
      if (batchId.isNotEmpty) 'batch_id': batchId,
    });
    final response = await _sendAuthorized(() {
      if (scope != currentSessionReadScope()) {
        throw const MobileApiException(
            code: 'session_scope_changed', message: '');
      }
      return _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/'
            'reactivation/preview'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: body,
      );
    });
    if (scope != currentSessionReadScope()) {
      throw const MobileApiException(
          code: 'session_scope_changed', message: '');
    }
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'reactivation_unavailable');
    }
    final raw = jsonDecode(response.body);
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid reactivation response');
    }
    return AdminWorkReactivationPreview.fromJson(raw,
        apparatus: apparatus,
        orderId: orderId,
        batchId: batchId,
        readScope: scope);
  }

  Future<void> adminReactivateCompletedWork(
      AdminWorkReactivationTarget target) async {
    final scope = currentSessionReadScope();
    if (target._readScope != scope ||
        await TestModeController.instance.isEnabled()) {
      throw const MobileApiException(
          code: 'reactivation_unavailable', message: '');
    }
    final body = jsonEncode(target.toJson());
    final response = await _sendAuthorized(() {
      if (scope != currentSessionReadScope()) {
        throw const MobileApiException(
            code: 'session_scope_changed', message: '');
      }
      return _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/'
            'reactivation'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: body,
      );
    });
    if (scope != currentSessionReadScope()) {
      throw const MobileApiException(
          code: 'session_scope_changed', message: '');
    }
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'reactivation_unavailable');
    }
    final raw = jsonDecode(response.body);
    if (raw is! Map || raw['ok'] != true) {
      throw const FormatException('Reactivation was not acknowledged');
    }
  }
}
