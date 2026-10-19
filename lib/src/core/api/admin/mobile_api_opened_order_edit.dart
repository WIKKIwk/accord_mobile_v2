part of '../mobile_api.dart';

/// Keep the server snapshot losslessly for optimistic concurrency. Rebuilding
/// it through UI models would discard fields unknown to older mobile clients.
class OpenedOrderEditSource {
  OpenedOrderEditSource.fromJson(Map<String, dynamic> json)
      : original = json,
        template = CalculateOrderTemplate.fromJson(
          (json['template'] as Map).cast<String, dynamic>(),
        ),
        restrictions = OpenedOrderEditRestrictions.fromJson(json['restrictions']) {
    if (restrictions.lockedLayerIndices.any(
        (index) => index >= template.effectiveLayers.length) ||
        (restrictions.unresolvedMaterials &&
            restrictions.lockedLayerIndices.length != template.effectiveLayers.length)) {
      throw const FormatException('Invalid order edit layer restrictions');
    }
  }

  final Map<String, dynamic> original;
  final CalculateOrderTemplate template;
  final OpenedOrderEditRestrictions restrictions;
  String get orderId => (original['map'] as Map)['id'] as String;
}

class OpenedOrderEditRestrictions {
  const OpenedOrderEditRestrictions({
    this.lockedLayerIndices = const {},
    this.dimensionsLocked = false,
    this.layerStructureLocked = false,
    this.unresolvedMaterials = false,
  });

  factory OpenedOrderEditRestrictions.fromJson(dynamic value) {
    // Old servers enforce the original blanket gate and have no field policy.
    if (value == null) return const OpenedOrderEditRestrictions();
    if (value is! Map ||
        value['locked_layer_indices'] is! List ||
        value['dimensions_locked'] is! bool ||
        value['layer_structure_locked'] is! bool ||
        value['unresolved_materials'] is! bool) {
      throw const FormatException('Invalid order edit restrictions');
    }
    final indices = value['locked_layer_indices'] as List;
    if (indices.any((index) => index is! int || index < 0)) {
      throw const FormatException('Invalid order edit layer restrictions');
    }
    if (value['dimensions_locked'] != value['layer_structure_locked'] ||
        ((indices.isNotEmpty || value['unresolved_materials'] == true) &&
            value['layer_structure_locked'] != true)) {
      throw const FormatException('Inconsistent order edit restrictions');
    }
    return OpenedOrderEditRestrictions(
      lockedLayerIndices: Set.unmodifiable(indices.cast<int>()),
      dimensionsLocked: value['dimensions_locked'] as bool,
      layerStructureLocked: value['layer_structure_locked'] as bool,
      unresolvedMaterials: value['unresolved_materials'] as bool,
    );
  }

  final Set<int> lockedLayerIndices;
  final bool dimensionsLocked;
  final bool layerStructureLocked;
  final bool unresolvedMaterials;
}

extension MobileApiOpenedOrderEdit on MobileApi {
  Future<OpenedOrderEditSource> adminOpenedOrderEditSource(
      String orderId) async {
    if (await TestModeController.instance.isEnabled()) {
      throw const MobileApiException(
        code: 'order_edit',
        message: 'Order tahriri uchun server tekshiruvi kerak',
      );
    }
    final response = await _sendAuthorized(() => _get(
          Uri.parse(
                  '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/order-edit')
              .replace(queryParameters: {'id': orderId}),
          headers: _headers(requireToken()),
        ));
    if (response.statusCode != 200) {
      throw _openedOrderEditException(response);
    }
    return OpenedOrderEditSource.fromJson(
      (jsonDecode(response.body) as Map).cast<String, dynamic>(),
    );
  }

  Future<OpenedOrderEditSource> adminSaveOpenedOrderEdit({
    required OpenedOrderEditSource source,
    required CalculateOrderTemplate template,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      throw const MobileApiException(
        code: 'order_edit',
        message: 'Order tahriri uchun server tekshiruvi kerak',
      );
    }
    final response = await _sendAuthorized(() => _put(
          Uri.parse(
                  '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/order-edit')
              .replace(queryParameters: {'id': source.orderId}),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode(
              {'original': source.original, 'template': template.toJson()}),
        ));
    if (response.statusCode != 200) {
      throw _openedOrderEditException(response);
    }
    return OpenedOrderEditSource.fromJson(
      (jsonDecode(response.body) as Map).cast<String, dynamic>(),
    );
  }
}

MobileApiException _openedOrderEditException(http.Response response) {
  // Only the endpoint's explicit, operator-facing diagnostic contract may
  // bypass the generic 5xx fallback. Never display raw database/proxy bodies.
  try {
    final payload = jsonDecode(response.body);
    if (payload is Map &&
        payload['error'] is String &&
        payload['message'] is String &&
        (payload['error'] as String).startsWith('order_edit_') &&
        !const {401, 403}.contains(response.statusCode)) {
      final message = (payload['message'] as String).trim();
      if (message.isNotEmpty && !message.contains(RegExp(r'[<>]'))) {
        return MobileApiException(
          code: payload['error'] as String,
          message: message,
          statusCode: response.statusCode,
        );
      }
    }
  } on FormatException {
    // Older servers and gateways need the existing fallback below.
  }
  final error = _adminProductionMapException(response, 'order_edit');
  // This endpoint returns user-facing business reasons in `error`, not just
  // machine codes. Preserve them without exposing auth or server failures.
  final reason = error.code.trim();
  if (const {400, 404, 409, 422}.contains(response.statusCode) &&
      error.message ==
          _adminProductionMapUnknownErrorMessage(
            code: error.code,
            fallbackCode: 'order_edit',
            statusCode: response.statusCode,
          ) &&
      reason.contains(RegExp(r'\s')) &&
      !reason.contains(RegExp(r'[<>]'))) {
    return MobileApiException(
      code: error.code,
      message: reason,
      statusCode: response.statusCode,
    );
  }
  return error;
}
