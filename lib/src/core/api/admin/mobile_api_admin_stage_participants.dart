part of '../mobile_api.dart';

class AdminStageParticipant {
  const AdminStageParticipant({
    required this.displayName,
    required this.started,
    required this.state,
  });

  final String displayName;
  final bool started;
  final String state;

  factory AdminStageParticipant.fromJson(Map<String, dynamic> json) {
    if (json['display_name'] is! String ||
        json['started'] is! bool ||
        !const {'working', 'paused', 'stopped', 'participated'}
            .contains(json['state'])) {
      throw const FormatException('Invalid stage participant');
    }
    return AdminStageParticipant(
      displayName: (json['display_name'] as String).trim(),
      started: json['started'] as bool,
      state: json['state'] as String,
    );
  }
}

extension MobileApiAdminStageParticipants on MobileApi {
  Future<List<AdminStageParticipant>> adminStageParticipants({
    required String orderId,
    required String stageNodeId,
    required String apparatus,
  }) async {
    final scope = currentSessionReadScope();
    final id = orderId.trim();
    final stage = stageNodeId.trim();
    final machine = _requireCanonicalApparatusId(apparatus);
    if (id.isEmpty || stage.isEmpty) {
      throw const FormatException('Invalid stage participant scope');
    }
    if (await TestModeController.instance.isEnabled()) return const [];
    if (scope != currentSessionReadScope()) {
      throw const MobileApiException(
          code: 'session_scope_changed', message: '');
    }
    final response = await _sendAuthorized(() => _get(
          Uri.parse(
                  '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/stage-participants')
              .replace(queryParameters: {
            'order_id': id,
            'stage_node_id': stage,
            'apparatus': machine,
          }),
          headers: _headers(requireToken()),
        ));
    if (scope != currentSessionReadScope()) {
      throw const MobileApiException(
          code: 'session_scope_changed', message: '');
    }
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'stage_participants');
    }
    final body = jsonDecode(response.body);
    if (body is! Map || body['participants'] is! List) {
      throw const FormatException('Invalid stage participants response');
    }
    return List.unmodifiable([
      for (final item in body['participants'] as List)
        if (item is Map)
          AdminStageParticipant.fromJson(item.cast<String, dynamic>())
        else
          throw const FormatException('Invalid stage participant'),
    ]);
  }
}
