part of '../mobile_api.dart';

extension MobileApiRezkaMaster on MobileApi {
  Future<bool?> orderPrintSidePreference(
    CalculateOrderTemplate template,
  ) async {
    if (await TestModeController.instance.isEnabled()) return null;
    final response = await _sendAuthorized(() => _post(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/calculate/print-side'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode(template.toJson()),
        ));
    if (response.statusCode != 200) {
      throw _adminApiException(response,
          fallbackCode: 'print_side_preference_failed',
          fallbackMessage: 'Saqlangan taraf yuklanmadi');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['standard_print_side'] as bool?;
  }

  Future<void> rezkaMasterSavePrintSide({
    required String orderId,
    required bool standard,
    required bool previous,
  }) =>
      _saveRezkaMasterSettings('print-side', {
        'order_id': orderId,
        'standard_print_side': standard,
        'previous_standard_print_side': previous,
      });

  Future<
      ({
        List<AdminWorker> workers,
        List<AdminRoleAssignment> assignments,
      })> rezkaMasterWorkers() async {
    final response = await _sendAuthorized(() => _get(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/rezka-master/workers'),
          headers: _headers(requireToken()),
        ));
    if (response.statusCode != 200) {
      throw _adminApiException(response,
          fallbackCode: 'rezka_workers_load_failed',
          fallbackMessage: 'Rezka ishchilari yuklanmadi');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      workers: (data['workers'] as List)
          .map((row) => AdminWorker.fromJson(row as Map<String, dynamic>))
          .toList(),
      assignments: (data['assignments'] as List)
          .map((row) =>
              AdminRoleAssignment.fromJson(row as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> rezkaMasterAssignWorker({
    required String workerId,
    required List<String> apparatusIds,
    required List<String> previousApparatusIds,
  }) =>
      _saveRezkaMasterSettings('workers', {
        'worker_id': workerId,
        'apparatus_ids': apparatusIds,
        'previous_apparatus_ids': previousApparatusIds,
      });

  Future<void> rezkaMasterSaveOrderSettings({
    required String orderId,
    required bool duplicateLabels,
    required bool includeBobina,
    required bool previousDuplicateLabels,
    required bool previousIncludeBobina,
  }) =>
      _saveRezkaMasterSettings('order-settings', {
        'order_id': orderId,
        'duplicate_rezka_labels': duplicateLabels,
        'include_bobina_in_net': includeBobina,
        'previous_duplicate_rezka_labels': previousDuplicateLabels,
        'previous_include_bobina_in_net': previousIncludeBobina,
      });

  Future<void> _saveRezkaMasterSettings(
      String path, Map<String, Object> input) async {
    final response = await _sendAuthorized(() => _put(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/rezka-master/$path'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode(input),
        ));
    if (response.statusCode != 200) {
      throw _adminApiException(response,
          fallbackCode: 'rezka_settings_save_failed',
          fallbackMessage: 'Rezka sozlamalari saqlanmadi');
    }
  }
}
