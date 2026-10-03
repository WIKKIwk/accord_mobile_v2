part of '../mobile_api.dart';

class AdminPrintPreflightResponse {
  const AdminPrintPreflightResponse({required this.hold, this.controlState});

  final AdminPrintPreflightHold hold;
  final AdminPrintPreflightControlState? controlState;

  factory AdminPrintPreflightResponse.fromJson(Map<String, dynamic> json) {
    final rawHold = json['hold'];
    final hold = AdminPrintPreflightHold.tryFromJson(rawHold);
    if (hold == null) {
      throw const MobileApiException(
        code: 'print_preflight_invalid_response',
        message: 'Rang sinovi javobi noto‘g‘ri',
      );
    }
    return AdminPrintPreflightResponse(
      hold: hold,
      controlState:
          AdminPrintPreflightControlState.tryFromJson(json['control_state']),
    );
  }
}

class AdminPrintPreflightControlState {
  const AdminPrintPreflightControlState({
    required this.apparatus,
    required this.orderId,
    required this.revision,
    required this.epoch,
    required this.control,
    required this.queueState,
    required this.stageStates,
    required this.orderControl,
  });

  final String apparatus;
  final String orderId;
  final int revision;
  final String epoch;
  final AdminApparatusQueueOrderActionControl control;
  final String queueState;
  final Map<String, String> stageStates;
  final AdminOrderControlState orderControl;

  static AdminPrintPreflightControlState? tryFromJson(Object? raw) {
    if (raw is! Map ||
        raw['control'] is! Map ||
        raw['stage_states'] is! Map ||
        raw['rev'] is! int ||
        (raw['rev'] as int) < 0 ||
        raw['epoch'] is! String ||
        (raw['epoch'] as String).isEmpty ||
        raw['apparatus'] is! String ||
        raw['order_id'] is! String ||
        !const {'active', 'freeze_requested', 'frozen'}
            .contains(raw['order_control'])) {
      return null;
    }
    try {
      final control = AdminApparatusQueueOrderActionControl.fromJson(
        (raw['control'] as Map).cast<String, dynamic>(),
      );
      final queueState = raw['queue_state'];
      final orderControl = AdminOrderControlState.fromRaw(raw['order_control']);
      if (queueState is! String ||
          !control.isConsistentWith(orderControl, queueState: queueState))
        return null;
      final stageStates = _parseProductionMapStageStates(
          {raw['order_id']: raw['stage_states']});
      return AdminPrintPreflightControlState(
        apparatus: raw['apparatus'] as String,
        orderId: raw['order_id'] as String,
        revision: raw['rev'] as int,
        epoch: raw['epoch'] as String,
        control: control,
        queueState: queueState,
        stageStates: stageStates[raw['order_id']] ?? const {},
        orderControl: orderControl,
      );
    } catch (_) {
      // The committed hold is still valid; malformed/legacy controls are
      // refreshed read-only before another action is enabled.
      return null;
    }
  }
}

extension MobileApiAdminPrintPreflight on MobileApi {
  Future<AdminPrintPreflightResponse> adminPrintPreflight({
    required String apparatus,
    required String orderId,
    required String action,
    String holdId = '',
    String idempotencyKey = '',
  }) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/print-preflight',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'apparatus': apparatus,
          'order_id': orderId,
          'action': action,
          'include_control': true,
          if (holdId.trim().isNotEmpty) 'hold_id': holdId.trim(),
          if (idempotencyKey.trim().isNotEmpty)
            'idempotency_key': idempotencyKey.trim(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'print_preflight_not_ready');
    }
    return AdminPrintPreflightResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
